"""urix — TUI клиент (curses), общается с urixd по RPC."""

import curses
import random
import time

C_GREEN = 1
C_YELLOW = 2
C_HEADER = 3
C_CYAN = 4
C_RED = 5
C_MAGENTA = 6

SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
DISSOLVE_SEQ = "@#*+· "
RAINBOW = [C_RED, C_YELLOW, C_GREEN, C_CYAN, C_MAGENTA]

TAB_APPS = 0
TAB_SERVERS = 1
TAB_MODES = 2
NUM_TABS = 3


def _safe(win, y, x, text, maxlen, attr=0):
    try:
        win.addnstr(y, x, text, maxlen, attr)
    except curses.error:
        pass


def tui_main(stdscr, client):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.init_pair(C_GREEN, curses.COLOR_GREEN, -1)
    curses.init_pair(C_YELLOW, curses.COLOR_YELLOW, -1)
    curses.init_pair(C_HEADER, curses.COLOR_BLACK, curses.COLOR_WHITE)
    curses.init_pair(C_CYAN, curses.COLOR_CYAN, -1)
    curses.init_pair(C_RED, curses.COLOR_RED, -1)
    curses.init_pair(C_MAGENTA, curses.COLOR_MAGENTA, -1)

    tab = TAB_APPS
    search = ""
    cursor = [0] * NUM_TABS
    scroll = [0] * NUM_TABS
    search_mode = False
    input_mode = False
    input_prompt = ""
    input_buf = ""
    input_callback = None

    # Data (populated via RPC)
    apps = []           # [{root_pid, name, total_pids, proxied_pids, pids}]
    servers = []        # [{index, name, proto, active}]
    mode_infos = []     # [{id, name, desc, active, exclusive, available}]
    pings = {}          # index → ms
    pinging = set()     # indices being pinged
    xray_running = False

    # Animation state
    spin_frame = 0
    switching = False
    switch_target = -1
    anim_phase = None
    anim_start = 0
    anim_old_name = ""
    anim_new_name = ""
    anim_char_delays = []
    mode_switching = False

    last_refresh = 0
    status_msg = ""
    status_time = 0

    # Pending RPC tracking
    pending_refresh_apps = 0
    pending_refresh_servers = 0
    pending_refresh_modes = 0

    def set_status(msg):
        nonlocal status_msg, status_time
        status_msg = msg
        status_time = time.time()

    def request_refresh():
        nonlocal pending_refresh_apps, pending_refresh_servers, pending_refresh_modes
        pending_refresh_apps = client.send("app.list")
        pending_refresh_servers = client.send("server.list")
        pending_refresh_modes = client.send("mode.list")
        # Also get status
        client.send("status")

    def filtered_apps():
        if not search:
            return apps
        s = search.lower()
        return [a for a in apps if s in a["name"].lower() or s in str(a["root_pid"])]

    def filtered_servers():
        if not search:
            return servers
        s = search.lower()
        return [sv for sv in servers if s in sv.get("name", "").lower()]

    def process_messages():
        nonlocal apps, servers, mode_infos, xray_running, pings
        nonlocal switching, switch_target, anim_phase, anim_start, anim_old_name, anim_new_name, anim_char_delays
        nonlocal mode_switching

        for msg in client.poll():
            # Response
            if "id" in msg and "result" in msg:
                rid = msg["id"]
                result = msg["result"]
                if rid == pending_refresh_apps:
                    apps[:] = result if isinstance(result, list) else []
                elif rid == pending_refresh_servers:
                    servers[:] = result if isinstance(result, list) else []
                elif rid == pending_refresh_modes:
                    mode_infos[:] = result if isinstance(result, list) else []
                elif isinstance(result, dict):
                    # Status response
                    if "xray_running" in result:
                        xray_running = result.get("xray_running", False)
                    # Ping streaming
                    if "ms" in result and "index" in result:
                        idx = result["index"]
                        pings[idx] = result["ms"]
                        pinging.discard(idx)
                    if result.get("done") is True and "total" in result:
                        pinging.clear()
                        set_status(f"Пинг: {len(pings)} серверов")
                    # Server select response
                    if "name" in result and rid and switching:
                        anim_new_name = result["name"]
                        anim_phase = "appear"
                        anim_start = time.time()
                        switching = False
                        request_refresh()
                    # Mode toggle response
                    if "message" in result:
                        set_status(result["message"])
                        mode_switching = False
                        request_refresh()

            # Error
            elif "id" in msg and "error" in msg:
                set_status(msg["error"].get("message", "Ошибка"))
                switching = False
                mode_switching = False

            # Event
            elif "event" in msg:
                ev = msg["event"]
                data = msg.get("data", {})
                if ev in ("app.changed", "watcher.match"):
                    request_refresh()
                elif ev == "server.switched":
                    request_refresh()
                elif ev == "mode.changed":
                    request_refresh()

    def toggle_app(idx):
        filt = filtered_apps()
        if idx >= len(filt):
            return
        app = filt[idx]
        if app["proxied_pids"] > 0:
            # Remove all pids
            for pid in app.get("pids", []):
                client.send("app.remove", {"pid": pid})
            set_status(f"- {app['name']}")
        else:
            client.send("app.add_name", {"name": app["name"]})
            set_status(f"+ {app['name']}")
        request_refresh()

    def select_server(idx):
        nonlocal switching, switch_target, anim_phase, anim_start, anim_old_name, anim_char_delays
        filt = filtered_servers()
        if idx >= len(filt) or switching:
            return
        srv = filt[idx]
        switching = True
        switch_target = srv["index"]
        # Find current active name
        old_name = ""
        for s in servers:
            if s.get("active"):
                old_name = s.get("name", "")
                break
        anim_old_name = old_name
        anim_new_name = srv["name"]
        anim_phase = "dissolve"
        anim_start = time.time()
        max_len = max(len(old_name), len(anim_new_name), 1)
        anim_char_delays = [random.uniform(0, 0.6) for _ in range(max_len)]
        client.send("server.select", {"index": srv["index"]})

    def start_input(prompt, callback):
        nonlocal input_mode, input_prompt, input_buf, input_callback
        input_mode = True
        input_prompt = prompt
        input_buf = ""
        input_callback = callback

    # Initial data load
    request_refresh()
    stdscr.timeout(100)

    while True:
        now = time.time()
        spin_frame = (spin_frame + 1) % len(SPINNER)

        process_messages()

        if now - last_refresh > 3:
            request_refresh()
            last_refresh = now
        if now - status_time > 5:
            status_msg = ""

        stdscr.erase()
        h, w = stdscr.getmaxyx()

        # === Tab bar ===
        labels = [" [1] Приложения ", " [2] Серверы ", " [3] Режим "]
        col = 0
        for ti, label in enumerate(labels):
            attr = curses.color_pair(C_HEADER) | curses.A_BOLD if ti == tab else curses.color_pair(C_CYAN)
            _safe(stdscr, 0, col, label, w - col, attr)
            col += len(label)
        _safe(stdscr, 0, col, "\u2500" * max(0, w - col), max(0, w - col), curses.color_pair(C_CYAN))

        # === Input/search bar ===
        if input_mode:
            _safe(stdscr, 1, 1, f"{input_prompt}: {input_buf}\u2588", w - 2, curses.color_pair(C_YELLOW))
        elif search_mode:
            _safe(stdscr, 1, 1, f"Поиск: {search}\u2588", w - 2, curses.color_pair(C_YELLOW))
        elif search:
            _safe(stdscr, 1, 1, f"Поиск: {search}", w - 2, curses.color_pair(C_YELLOW))
        else:
            _safe(stdscr, 1, 1, "/ поиск", w - 2, curses.color_pair(C_CYAN))

        list_h = max(1, h - 5)
        cur = cursor[tab]
        scr = scroll[tab]

        # === Draw current tab ===
        if tab == TAB_APPS:
            filt = filtered_apps()
            _draw_apps(stdscr, w, h, list_h, filt, cur, scr)
        elif tab == TAB_SERVERS:
            filt = filtered_servers()
            _draw_servers(stdscr, w, h, list_h, filt, cur, scr, pings, pinging, switching, switch_target, spin_frame)
        else:
            filt = mode_infos
            _draw_modes(stdscr, w, h, list_h, filt, cur, scr, mode_switching, spin_frame)

        cur_len = len(filt)

        # === Status bar (with animation) ===
        n_proxied = sum(1 for a in apps if a.get("proxied_pids", 0) > 0)
        prefix = f" Прокси: {n_proxied} | Xray: {'ON' if xray_running else 'OFF'} | "
        _safe(stdscr, h - 2, 0, " " * w, w - 1, curses.color_pair(C_CYAN))
        _safe(stdscr, h - 2, 0, prefix, w - 1, curses.color_pair(C_CYAN))

        srv_x = len(prefix)
        srv_w = w - srv_x - 1
        _render_server_anim(stdscr, h, w, srv_x, srv_w, now, anim_phase, anim_start,
                            anim_old_name, anim_new_name, anim_char_delays, servers)
        # Check if anim is done
        if anim_phase == "appear":
            groups = _build_char_groups(anim_new_name)
            appear_dur = len(groups) * 0.05
            total_dur = appear_dur + 2.0
            if now - anim_start > total_dur:
                anim_phase = None

        if status_msg:
            sx = srv_x + len(anim_new_name if anim_phase else "") + 2
            _safe(stdscr, h - 2, min(sx, w - len(status_msg) - 2), status_msg, w, curses.color_pair(C_YELLOW))

        # === Help bar ===
        if tab == TAB_APPS:
            ht = " [Enter] toggle  [/] search  [r] run  [1][2][3] tabs  [q] quit"
        elif tab == TAB_SERVERS:
            ht = " [Enter] select  [p] ping  [u] update  [a] add URL  [1][2][3]  [q] quit"
        else:
            ht = " [Enter] toggle  [1][2][3] tabs  [q] quit"
        _safe(stdscr, h - 1, 0, ht.ljust(w), w - 1, curses.color_pair(C_HEADER))

        stdscr.refresh()

        # === Input ===
        try:
            key = stdscr.getch()
        except curses.error:
            continue
        if key == -1:
            continue

        if input_mode:
            if key == 27:
                input_mode = False
            elif key in (curses.KEY_BACKSPACE, 127, 8):
                input_buf = input_buf[:-1]
            elif key in (10, 13):
                input_mode = False
                if input_callback and input_buf.strip():
                    input_callback(input_buf.strip())
            elif 32 <= key <= 126:
                input_buf += chr(key)
            continue

        if search_mode:
            if key == 27:
                search_mode = False
                search = ""
                cursor[tab] = 0
            elif key in (curses.KEY_BACKSPACE, 127, 8):
                search = search[:-1]
                cursor[tab] = 0
            elif key in (10, 13):
                search_mode = False
            elif 32 <= key <= 126:
                search += chr(key)
                cursor[tab] = 0
            continue

        # Navigation
        if key == ord("q"):
            break
        elif key == ord("1"):
            tab = TAB_APPS; search = ""
        elif key == ord("2"):
            tab = TAB_SERVERS; search = ""
        elif key == ord("3"):
            tab = TAB_MODES; search = ""; request_refresh()
        elif key == ord("/"):
            search_mode = True; search = ""; cursor[tab] = 0
        elif key in (curses.KEY_UP, ord("k")):
            cursor[tab] = max(0, cursor[tab] - 1)
        elif key in (curses.KEY_DOWN, ord("j")):
            cursor[tab] = min(cur_len - 1, cursor[tab] + 1) if cur_len > 0 else 0
        elif key == curses.KEY_PPAGE:
            cursor[tab] = max(0, cursor[tab] - list_h)
        elif key == curses.KEY_NPAGE:
            cursor[tab] = min(cur_len - 1, cursor[tab] + list_h) if cur_len > 0 else 0

        # Tab-specific
        elif tab == TAB_APPS:
            if key in (10, 13) and cur_len > 0:
                toggle_app(cursor[tab])
            elif key == ord("r"):
                def run_cb(cmd_str):
                    client.send("app.run", {"cmd": cmd_str.split()})
                    set_status(f"Запуск: {cmd_str.split()[0]}")
                start_input("Команда", run_cb)

        elif tab == TAB_SERVERS:
            if key in (10, 13) and cur_len > 0:
                select_server(cursor[tab])
            elif key == ord("p"):
                pings.clear()
                pinging.update(s["index"] for s in servers)
                set_status("Пингую...")
                client.send("server.ping")
            elif key == ord("u"):
                set_status("Обновляю подписку...")
                client.send("sub.update")
            elif key == ord("a"):
                def sub_cb(url):
                    set_status("Загружаю...")
                    client.send("sub.load", {"url": url})
                start_input("URL подписки", sub_cb)

        elif tab == TAB_MODES:
            if key in (10, 13) and cur_len > 0 and not mode_switching:
                ci = cursor[tab]
                if ci < len(mode_infos):
                    mi = mode_infos[ci]
                    if mi.get("available"):
                        mode_switching = True
                        client.send("mode.toggle", {"id": mi["id"]})
                    else:
                        set_status(f"{mi['name']}: недоступен")

        # Clamp
        if cur_len > 0:
            cursor[tab] = max(0, min(cursor[tab], cur_len - 1))
        else:
            cursor[tab] = 0
        if cursor[tab] < scroll[tab]:
            scroll[tab] = cursor[tab]
        if cursor[tab] >= scroll[tab] + list_h:
            scroll[tab] = cursor[tab] - list_h + 1


# === Drawing functions ===

def _draw_apps(stdscr, w, h, list_h, filt, cursor, scroll):
    hdr = f"  {'':>3} {'Приложение':<25} {'Проц':>5}  {'Статус':<10}"
    _safe(stdscr, 2, 0, hdr.ljust(w), w - 1, curses.color_pair(C_HEADER))
    for i in range(list_h):
        idx = scroll + i
        if idx >= len(filt):
            break
        a = filt[idx]
        total, pc = a["total_pids"], a["proxied_pids"]
        if pc == total:
            marker, status = "\u25c9", "[PROXY]"
            color = curses.color_pair(C_GREEN) | curses.A_BOLD
        elif pc > 0:
            marker, status = "\u25d4", f"[{pc}/{total}]"
            color = curses.color_pair(C_RED)
        else:
            marker, status = "\u25cb", ""
            color = 0
        line = f"  {marker}  {a['name']:<25} ({total:>3})  {status}"
        y = 3 + i
        if y >= h - 2:
            break
        _safe(stdscr, y, 0, line.ljust(w), w - 1, curses.A_REVERSE if idx == cursor else color)
    if not filt:
        _safe(stdscr, 4, 3, "Нет приложений", w - 4, curses.color_pair(C_CYAN))


def _draw_servers(stdscr, w, h, list_h, filt, cursor, scroll, pings, pinging, switching, switch_target, spin_frame):
    hdr = f"  {'':>3} {'Сервер':<32} {'Протокол':<12} {'Пинг':>8}"
    _safe(stdscr, 2, 0, hdr.ljust(w), w - 1, curses.color_pair(C_HEADER))
    for i in range(list_h):
        idx = scroll + i
        if idx >= len(filt):
            break
        srv = filt[idx]
        ri = srv["index"]
        if ri in pinging:
            ping_str = SPINNER[spin_frame]
        elif ri in pings:
            ms = pings[ri]
            ping_str = f"{ms}ms" if ms is not None else "fail"
        else:
            ping_str = ""
        is_switching = switching and ri == switch_target
        if is_switching:
            marker = SPINNER[spin_frame]
            color = curses.color_pair(C_YELLOW) | curses.A_BOLD
        elif srv.get("active"):
            marker = "\u25c9"
            color = curses.color_pair(C_GREEN) | curses.A_BOLD
        else:
            marker = "\u25cb"
            color = 0
        line = f"  {marker}  {srv['name']:<32} {srv['proto']:<12} {ping_str:>8}"
        y = 3 + i
        if y >= h - 2:
            break
        attr = curses.A_REVERSE if idx == cursor else color
        _safe(stdscr, y, 0, line.ljust(w), w - 1, attr)
        # Colored ping overlay
        if idx != cursor and ping_str and ri in pings:
            px = 2 + 3 + 2 + 32 + 12
            ms_val = pings.get(ri)
            if ms_val is None:
                pc = curses.color_pair(C_RED)
            elif ms_val < 100:
                pc = curses.color_pair(C_GREEN)
            elif ms_val < 250:
                pc = curses.color_pair(C_YELLOW)
            else:
                pc = curses.color_pair(C_RED)
            if px + 8 <= w:
                _safe(stdscr, y, px, f"{ping_str:>8}", 8, pc | curses.A_BOLD)
    if not filt:
        _safe(stdscr, 4, 3, "Нет серверов. [a] добавить подписку", w - 4, curses.color_pair(C_CYAN))


def _draw_modes(stdscr, w, h, list_h, modes, cursor, scroll, switching, spin_frame):
    hdr = f"  {'':>3} {'Режим':<30} {'Описание':<30}"
    _safe(stdscr, 2, 0, hdr.ljust(w), w - 1, curses.color_pair(C_HEADER))
    for i in range(list_h):
        idx = scroll + i
        if idx >= len(modes):
            break
        mi = modes[idx]
        if switching and idx == cursor:
            marker = SPINNER[spin_frame]
            color = curses.color_pair(C_YELLOW) | curses.A_BOLD
        elif mi.get("active"):
            marker = "\u25c9"
            color = curses.color_pair(C_GREEN) | curses.A_BOLD
        elif not mi.get("available"):
            marker = "\u2717"
            color = curses.color_pair(C_RED)
        else:
            marker = "\u25cb"
            color = 0
        name = mi["name"] + (" *" if mi.get("exclusive") else "")
        line = f"  {marker}  {name:<30} {mi.get('desc', ''):<30}"
        y = 3 + i
        if y >= h - 2:
            break
        _safe(stdscr, y, 0, line.ljust(w), w - 1, curses.A_REVERSE if idx == cursor else color)
    legend_y = 3 + min(list_h, len(modes)) + 1
    if legend_y < h - 2:
        _safe(stdscr, legend_y, 3, "* эксклюзивный — отключает остальные", w - 4, curses.color_pair(C_CYAN))


# === Server name animation ===

def _build_char_groups(name):
    groups = []
    i = 0
    while i < len(name):
        if i + 1 < len(name) and 0x1F1E6 <= ord(name[i]) <= 0x1F1FF:
            groups.append(name[i:i+2])
            i += 2
        elif i + 1 < len(name) and ord(name[i]) > 0x2000 and ord(name[i+1]) > 0x2000:
            end = i + 1
            while end < len(name) and ord(name[end]) > 0x2000:
                end += 1
            groups.append(name[i:end])
            i = end
        else:
            groups.append(name[i])
            i += 1
    return groups


def _render_server_anim(stdscr, h, w, srv_x, srv_w, now, phase, start, old_name, new_name, delays, servers):
    if phase == "dissolve":
        elapsed = now - start
        text = old_name.ljust(max(len(old_name), len(new_name)))
        for ci, ch in enumerate(text):
            if ci >= srv_w:
                break
            d = delays[ci] if ci < len(delays) else 0
            ce = elapsed - d
            if ce < 0:
                _safe(stdscr, h - 2, srv_x + ci, ch, 1, curses.color_pair(C_CYAN))
            else:
                step = min(int(ce / 0.08), len(DISSOLVE_SEQ) - 1)
                _safe(stdscr, h - 2, srv_x + ci, DISSOLVE_SEQ[step], 1, curses.color_pair(C_YELLOW))

    elif phase == "appear":
        elapsed = now - start
        groups = _build_char_groups(new_name)
        appear_speed = 0.05
        appear_dur = len(groups) * appear_speed
        rainbow_dur = 2.0
        col = 0
        for gi, g in enumerate(groups):
            if col >= srv_w:
                break
            appear_t = gi * appear_speed
            ce = elapsed - appear_t
            if ce < 0:
                _safe(stdscr, h - 2, srv_x + col, " " * len(g), len(g), 0)
            elif elapsed < appear_dur + rainbow_dur:
                wp = (elapsed - appear_dur) / rainbow_dur
                wave = wp * (len(groups) + len(RAINBOW))
                dist = wave - gi
                if dist < 0 or dist >= len(RAINBOW):
                    _safe(stdscr, h - 2, srv_x + col, g, len(g), curses.color_pair(C_CYAN))
                else:
                    ci = int(dist) % len(RAINBOW)
                    _safe(stdscr, h - 2, srv_x + col, g, len(g), curses.color_pair(RAINBOW[ci]) | curses.A_BOLD)
            else:
                _safe(stdscr, h - 2, srv_x + col, g, len(g), curses.color_pair(C_CYAN))
            col += 2 if len(g) >= 2 and ord(g[0]) > 0x2000 else 1
    else:
        # Normal
        srv_name = ""
        for s in servers:
            if s.get("active"):
                srv_name = s.get("name", "")
                break
        if srv_name:
            _safe(stdscr, h - 2, srv_x, srv_name[:srv_w], srv_w, curses.color_pair(C_CYAN))
