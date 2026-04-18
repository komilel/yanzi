"""urix — управление сервисом (xray, cgroup, iptables). Вызывается из демона."""

import os
import signal
import subprocess
import time

from urix_config import (
    XRAY_CONFIG, PIDFILE, CGROUP, CGROUP_PATH, MARK, TABLE, TPROXY_PORT,
    load_config, is_running, run_quiet,
)
from urix_process import get_app_groups, add_pids_to_cgroup
from urix_modes import get_active_modes, _rebuild_xray_inbounds, start_perapp


def service_start():
    """Start xray, create cgroup, setup iptables. Returns status messages."""
    messages = []

    # Rebuild xray.json with saved modes before starting
    modes = get_active_modes()
    _rebuild_xray_inbounds(modes)

    if is_running():
        messages.append(f"Xray уже запущен (PID {open(PIDFILE).read().strip()})")
    else:
        proc = subprocess.Popen(
            ["xray", "run", "-c", XRAY_CONFIG],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        with open(PIDFILE, "w") as f:
            f.write(str(proc.pid))
        messages.append(f"Xray запущен (PID {proc.pid})")
        time.sleep(1)

    if modes.get("perapp"):
        start_perapp()
        messages.append("Per-app включён")

        # Auto-add apps from config
        cfg = load_config()
        auto = cfg.get("auto_proxy", [])
        if auto:
            for root_pid, name, pids in get_app_groups():
                if name.lower() in [a.lower() for a in auto]:
                    add_pids_to_cgroup(pids)
                    messages.append(f"+ {name} ({len(pids)} процессов)")

    return messages


def service_stop():
    """Stop xray, remove iptables, cleanup cgroup. Returns status messages."""
    messages = []

    run_quiet(f"iptables -t mangle -D OUTPUT -m cgroup --path {CGROUP} -j MARK --set-mark {MARK}")
    for proto in ("tcp", "udp"):
        run_quiet(
            f"iptables -t mangle -D PREROUTING -m mark --mark {MARK} -p {proto} "
            f"-j TPROXY --on-port {TPROXY_PORT} --tproxy-mark {MARK}"
        )
    run_quiet(f"ip rule del fwmark {MARK} table {TABLE}")
    run_quiet(f"ip route del local 0.0.0.0/0 dev lo table {TABLE}")

    from urix_process import get_proxied_pids
    for pid in get_proxied_pids():
        try:
            with open("/sys/fs/cgroup/cgroup.procs", "w") as f:
                f.write(str(pid))
        except OSError:
            pass

    if os.path.exists(CGROUP_PATH):
        try:
            os.rmdir(CGROUP_PATH)
            messages.append("Cgroup удалена")
        except OSError:
            pass

    if os.path.exists(PIDFILE):
        try:
            pid = int(open(PIDFILE).read().strip())
            os.kill(pid, signal.SIGTERM)
            messages.append(f"Xray остановлен (PID {pid})")
        except (OSError, ValueError):
            pass
        try:
            os.unlink(PIDFILE)
        except OSError:
            pass

    return messages
