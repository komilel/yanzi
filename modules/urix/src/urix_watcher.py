"""urix — watcher: netlink cn_proc подписка на fork/exec."""

import os
import socket
import struct
import time

from urix_config import CGROUP, CGROUP_PATH, load_config
from urix_process import _get_app_name, add_pids_to_cgroup


def check_and_add_pid(pid):
    """Check if a pid belongs to an auto_proxy app. Returns (pid, name) if added, else None."""
    try:
        cfg = load_config()
        auto = [n.lower() for n in cfg.get("auto_proxy", [])]
        if not auto:
            return None
        try:
            cg = open(f"/proc/{pid}/cgroup").read()
            if f"/{CGROUP}\n" in cg:
                return None
        except FileNotFoundError:
            return None
        app_name = _get_app_name(pid)
        if app_name.lower() in auto:
            add_pids_to_cgroup([pid])
            return (pid, app_name)
        cur = pid
        visited = set()
        while cur > 1 and cur not in visited:
            visited.add(cur)
            try:
                ppid = int(open(f"/proc/{cur}/stat").read().split(")")[1].split()[1])
                uid = os.stat(f"/proc/{cur}").st_uid
                if uid < 1000:
                    break
                name = _get_app_name(cur)
                if name.lower() in auto:
                    add_pids_to_cgroup([pid])
                    return (pid, name)
                pcg = open(f"/proc/{ppid}/cgroup").read()
                if f"/{CGROUP}\n" in pcg:
                    add_pids_to_cgroup([pid])
                    return (pid, name)
                cur = ppid
            except (FileNotFoundError, PermissionError, ValueError, IndexError):
                break
    except Exception:
        pass
    return None


def watcher_loop(on_event=None):
    """Subscribe to process events via netlink cn_proc.

    on_event(event_type, data) is called for:
      - ("match", {"pid": N, "name": "..."}) — when a process is auto-added
      - ("fork_add", {"pid": N}) — when a child of proxied parent is added

    This function blocks forever. Run in a thread.
    """
    NETLINK_CONNECTOR = 11
    CN_IDX_PROC = 1
    PROC_CN_MCAST_LISTEN = 1
    PROC_EVENT_FORK = 0x00000001
    PROC_EVENT_EXEC = 0x00000002

    try:
        sock = socket.socket(socket.AF_NETLINK, socket.SOCK_DGRAM, NETLINK_CONNECTOR)
        sock.bind((0, CN_IDX_PROC))
    except Exception as e:
        print(f"[watcher] FATAL: cannot create netlink socket: {e}", flush=True)
        return

    cn_msg = struct.pack("=II II HH I", CN_IDX_PROC, 0, 0, 0, 4, 0, PROC_CN_MCAST_LISTEN)
    nl_hdr = struct.pack("=I HH II", 16 + len(cn_msg), 0, 0, 0, 0)
    try:
        sock.send(nl_hdr + cn_msg)
    except Exception as e:
        print(f"[watcher] FATAL: cannot subscribe to cn_proc: {e}", flush=True)
        return

    print("[watcher] netlink cn_proc subscribed, listening...", flush=True)

    while True:
        try:
            data = sock.recv(4096)
            if len(data) < 40:
                continue
            event_offset = 36
            what = struct.unpack_from("=I", data, event_offset)[0]

            if what == PROC_EVENT_EXEC:
                if len(data) >= event_offset + 24:
                    child_pid = struct.unpack_from("=I", data, event_offset + 16)[0]
                    result = check_and_add_pid(child_pid)
                    if result:
                        print(f"[watcher] match: {result[1]} (PID {result[0]})", flush=True)
                        if on_event:
                            on_event("match", {"pid": result[0], "name": result[1]})

            elif what == PROC_EVENT_FORK:
                if len(data) >= event_offset + 32:
                    parent_pid = struct.unpack_from("=I", data, event_offset + 16)[0]
                    child_pid = struct.unpack_from("=I", data, event_offset + 24)[0]
                    try:
                        pcg = open(f"/proc/{parent_pid}/cgroup").read()
                        if f"/{CGROUP}\n" in pcg:
                            add_pids_to_cgroup([child_pid])
                            if on_event:
                                on_event("fork_add", {"pid": child_pid})
                    except (FileNotFoundError, PermissionError):
                        pass
        except Exception:
            time.sleep(1)
