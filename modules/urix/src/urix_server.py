"""urix — asyncio daemon: RPC dispatch, event broadcasting, watcher."""

import asyncio
import json
import os
import pwd
import signal
import struct
import sys
import threading
import time

from urix_config import (
    CGROUP_PATH, PIDFILE, SOCKET_PATH,
    load_config, save_config, is_running, ensure_data_dir,
)
from urix_process import (
    get_app_groups, get_proxied_pids, add_pids_to_cgroup,
    remove_pid_from_cgroup, run_in_cgroup, _get_app_name,
)
from urix_subscription import (
    ping_server, fetch_subscription, apply_server,
    load_subscription, update_subscription,
)
from urix_modes import get_mode_info, get_active_modes, apply_modes
from urix_service import service_start, service_stop
from urix_watcher import watcher_loop
from urix_rpc import encode_response, encode_error, encode_event


class UrixDaemon:
    def __init__(self, socket_path=SOCKET_PATH):
        self.socket_path = socket_path
        self.subscribers = set()
        self.clients = set()
        self.loop = None
        self.watcher_thread = None
        self.event_queue = None
        self.config_lock = asyncio.Lock()

        self.methods = {
            "subscribe": self._handle_subscribe,
            "status": self._handle_status,
            "app.list": self._handle_app_list,
            "app.add": self._handle_app_add,
            "app.add_name": self._handle_app_add_name,
            "app.remove": self._handle_app_remove,
            "app.run": self._handle_app_run,
            "app.auto_list": self._handle_app_auto_list,
            "server.list": self._handle_server_list,
            "server.select": self._handle_server_select,
            "server.ping": self._handle_server_ping,
            "server.ping_one": self._handle_server_ping_one,
            "sub.load": self._handle_sub_load,
            "sub.update": self._handle_sub_update,
            "sub.url": self._handle_sub_url,
            "mode.list": self._handle_mode_list,
            "mode.toggle": self._handle_mode_toggle,
            "watcher.status": self._handle_watcher_status,
        }

    async def run(self):
        self.loop = asyncio.get_running_loop()
        self.event_queue = asyncio.Queue()

        # Ensure data directory exists
        ensure_data_dir()

        # Startup
        msgs = await self.loop.run_in_executor(None, service_start)
        for m in msgs:
            print(f"[init] {m}")

        # Start watcher
        self._start_watcher()

        # Clean stale socket
        if os.path.exists(self.socket_path):
            try:
                s = __import__("socket").socket(__import__("socket").AF_UNIX)
                s.connect(self.socket_path)
                s.close()
                print(f"Другой экземпляр urixd уже запущен на {self.socket_path}")
                sys.exit(1)
            except (ConnectionRefusedError, FileNotFoundError):
                os.unlink(self.socket_path)

        server = await asyncio.start_unix_server(self._handle_client, self.socket_path)
        os.chmod(self.socket_path, 0o666)
        print(f"[init] Слушаю {self.socket_path}")

        # Signal handlers
        self._server = server
        self._stop_event = asyncio.Event()
        for sig in (signal.SIGTERM, signal.SIGINT):
            self.loop.add_signal_handler(sig, self._signal_stop)

        # Event broadcaster
        asyncio.ensure_future(self._event_broadcaster())

        # Wait for stop signal
        await self._stop_event.wait()

        # Cleanup
        print("\n[shutdown] Останавливаю...")
        for w in list(self.clients):
            try:
                w.close()
            except Exception:
                pass
        self.clients.clear()
        self.subscribers.clear()
        server.close()
        await server.wait_closed()
        await self.loop.run_in_executor(None, service_stop)
        try:
            os.unlink(self.socket_path)
        except OSError:
            pass

    def _signal_stop(self):
        self._stop_event.set()

    async def _handle_client(self, reader, writer):
        self.clients.add(writer)
        try:
            while True:
                line = await reader.readline()
                if not line:
                    break
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    continue
                method = msg.get("method", "")
                params = msg.get("params", {})
                req_id = msg.get("id")

                handler = self.methods.get(method)
                if not handler:
                    await self._send(writer, encode_error(-32601, f"Unknown: {method}", req_id))
                    continue

                try:
                    result = await handler(params, writer=writer, req_id=req_id)
                    if result is not None:
                        await self._send(writer, encode_response(result, req_id))
                except Exception as e:
                    await self._send(writer, encode_error(-1, str(e), req_id))

        except (ConnectionResetError, BrokenPipeError, asyncio.IncompleteReadError,
                asyncio.CancelledError):
            pass
        finally:
            self.subscribers.discard(writer)
            self.clients.discard(writer)
            try:
                writer.close()
            except Exception:
                pass

    async def _send(self, writer, msg):
        try:
            writer.write(msg.encode() if isinstance(msg, str) else msg)
            await writer.drain()
        except (ConnectionResetError, BrokenPipeError):
            self.subscribers.discard(writer)

    async def _broadcast(self, event, data):
        msg = encode_event(event, data)
        dead = set()
        for w in list(self.subscribers):
            try:
                w.write(msg.encode())
                await w.drain()
            except (ConnectionResetError, BrokenPipeError):
                dead.add(w)
        self.subscribers -= dead

    def _start_watcher(self):
        def on_event(etype, data):
            try:
                self.loop.call_soon_threadsafe(self.event_queue.put_nowait, (etype, data))
            except Exception:
                pass

        self.watcher_thread = threading.Thread(
            target=watcher_loop, args=(on_event,), daemon=True
        )
        self.watcher_thread.start()
        print("[init] Watcher запущен")

    async def _event_broadcaster(self):
        while True:
            etype, data = await self.event_queue.get()
            if etype == "match":
                await self._broadcast("watcher.match", data)
                await self._broadcast("app.changed", {
                    "name": data.get("name", "?"), "proxied": True
                })

    # --- Handlers ---

    async def _handle_subscribe(self, params, writer, req_id):
        self.subscribers.add(writer)
        return {"ok": True}

    async def _handle_status(self, params, **kw):
        xray_pid = None
        try:
            xray_pid = int(open(PIDFILE).read().strip())
        except (FileNotFoundError, ValueError):
            pass
        return {
            "xray_pid": xray_pid,
            "xray_running": is_running(),
            "watcher_running": self.watcher_thread is not None and self.watcher_thread.is_alive(),
            "active_modes": get_active_modes(),
        }

    async def _handle_app_list(self, params, **kw):
        def do():
            proxied = set(get_proxied_pids())
            result = []
            for root_pid, name, pids in get_app_groups():
                pc = sum(1 for p in pids if p in proxied)
                result.append({
                    "root_pid": root_pid,
                    "name": name,
                    "total_pids": len(pids),
                    "proxied_pids": pc,
                    "pids": pids,
                })
            return result
        return await self.loop.run_in_executor(None, do)

    async def _handle_app_add(self, params, **kw):
        pid = params.get("pid")
        if not pid:
            raise ValueError("pid required")
        count = add_pids_to_cgroup([pid])
        name = _get_app_name(pid)
        await self._broadcast("app.changed", {"name": name, "proxied": True})
        return {"ok": True, "name": name, "count": count}

    async def _handle_app_add_name(self, params, **kw):
        name = params.get("name", "")
        groups = get_app_groups()
        found = [(r, n, p) for r, n, p in groups if name.lower() in n.lower()]
        if not found:
            raise ValueError(f'Не найдено: "{name}"')
        total = 0
        matched_name = ""
        async with self.config_lock:
            cfg = load_config()
            auto = cfg.get("auto_proxy", [])
            for root_pid, app_name, pids in found:
                total += add_pids_to_cgroup(pids)
                matched_name = app_name
                if app_name.lower() not in [a.lower() for a in auto]:
                    auto.append(app_name)
            cfg["auto_proxy"] = auto
            save_config(cfg)
        await self._broadcast("app.changed", {"name": matched_name, "proxied": True})
        return {"ok": True, "name": matched_name, "count": total}

    async def _handle_app_remove(self, params, **kw):
        pid = params.get("pid")
        if not pid:
            raise ValueError("pid required")
        remove_pid_from_cgroup(pid)
        return {"ok": True}

    async def _handle_app_run(self, params, writer, **kw):
        cmd = params.get("cmd", [])
        if not cmd:
            raise ValueError("cmd required")
        # Get client UID via SO_PEERCRED
        sock = writer.get_extra_info("socket")
        cred = sock.getsockopt(__import__("socket").SOL_SOCKET,
                               __import__("socket").SO_PEERCRED,
                               struct.calcsize("iII"))
        _, uid, gid = struct.unpack("iII", cred)
        pw = pwd.getpwuid(uid)
        child_pid = await self.loop.run_in_executor(
            None, run_in_cgroup, cmd, uid, gid, pw.pw_dir, pw.pw_name
        )
        return {"ok": True, "pid": child_pid}

    async def _handle_app_auto_list(self, params, **kw):
        cfg = load_config()
        return cfg.get("auto_proxy", [])

    async def _handle_server_list(self, params, **kw):
        cfg = load_config()
        servers = cfg.get("servers", [])
        active = cfg.get("active_server", -1)
        result = []
        for i, srv in enumerate(servers):
            uri = srv.get("uri", "")
            if "type=xhttp" in uri:
                proto = "XHTTP"
            elif "security=reality" in uri:
                proto = "Reality"
            elif "type=ws" in uri:
                proto = "WS"
            else:
                proto = "TCP"
            result.append({
                "index": i,
                "name": srv.get("name", "?"),
                "proto": proto,
                "active": i == active,
            })
        return result

    async def _handle_server_select(self, params, writer, req_id):
        index = params.get("index")
        if index is None:
            raise ValueError("index required")

        async def do():
            import io
            old = sys.stdout
            sys.stdout = io.StringIO()
            try:
                apply_server(index)
            finally:
                sys.stdout = old
            cfg = load_config()
            servers = cfg.get("servers", [])
            name = servers[index].get("name", "?") if index < len(servers) else "?"
            await self._broadcast("server.switched", {"index": index, "name": name})
            await self._send(writer, encode_response({"ok": True, "name": name}, req_id))

        asyncio.ensure_future(do())
        return None  # response sent by the task

    async def _handle_server_ping(self, params, writer, req_id):
        cfg = load_config()
        servers = cfg.get("servers", [])

        async def ping_one(i, srv):
            ms = await self.loop.run_in_executor(None, ping_server, srv.get("uri", ""))
            await self._send(writer, encode_response(
                {"index": i, "ms": ms, "done": False}, req_id
            ))

        tasks = [ping_one(i, srv) for i, srv in enumerate(servers)]
        await asyncio.gather(*tasks)
        await self._send(writer, encode_response({"done": True, "total": len(servers)}, req_id))
        return None

    async def _handle_server_ping_one(self, params, **kw):
        index = params.get("index")
        cfg = load_config()
        servers = cfg.get("servers", [])
        if index is None or index >= len(servers):
            raise ValueError("invalid index")
        ms = await self.loop.run_in_executor(None, ping_server, servers[index].get("uri", ""))
        return {"index": index, "ms": ms}

    async def _handle_sub_load(self, params, **kw):
        url = params.get("url", "")
        if not url:
            raise ValueError("url required")
        servers = await self.loop.run_in_executor(None, load_subscription, url)
        return {"ok": True, "count": len(servers) if servers else 0}

    async def _handle_sub_update(self, params, **kw):
        servers = await self.loop.run_in_executor(None, update_subscription)
        if servers is None:
            raise ValueError("Подписка не настроена")
        return {"ok": True, "count": len(servers)}

    async def _handle_sub_url(self, params, **kw):
        cfg = load_config()
        return {"url": cfg.get("subscription_url", "")}

    async def _handle_mode_list(self, params, **kw):
        return get_mode_info()

    async def _handle_mode_toggle(self, params, writer, req_id):
        mode_id = params.get("id", "")
        if not mode_id:
            raise ValueError("id required")

        async def do():
            modes = get_active_modes()
            toggling_to = not modes.get(mode_id, False)

            if mode_id == "tun":
                if toggling_to:
                    modes = {"tun": True, "socks5": False, "http": False, "perapp": False}
                else:
                    modes["tun"] = False
            else:
                if modes.get("tun"):
                    await self._send(writer, encode_error(-1, "Сначала выключи TUN", req_id))
                    return
                modes[mode_id] = toggling_to

            ok, message = await self.loop.run_in_executor(None, apply_modes, modes)
            await self._broadcast("mode.changed", {"id": mode_id, "active": toggling_to})
            await self._send(writer, encode_response({"ok": ok, "message": message}, req_id))

        asyncio.ensure_future(do())
        return None

    async def _handle_watcher_status(self, params, **kw):
        cfg = load_config()
        return {
            "running": self.watcher_thread is not None and self.watcher_thread.is_alive(),
            "auto_proxy": cfg.get("auto_proxy", []),
        }


def run_daemon(socket_path=SOCKET_PATH):
    if os.geteuid() != 0:
        print("urixd требует root: sudo ./urixd")
        sys.exit(1)
    daemon = UrixDaemon(socket_path)
    asyncio.run(daemon.run())
