"""urix — управление процессами и cgroup."""

import os

from urix_config import CGROUP, CGROUP_PATH


def get_proxied_pids():
    try:
        return [int(p) for p in open(f"{CGROUP_PATH}/cgroup.procs").read().split()]
    except FileNotFoundError:
        return []


def _get_app_name(pid):
    """Determine a human-readable app name from pid's cmdline."""
    try:
        cmdline = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\x00")
        exe = os.path.basename(cmdline[0].decode(errors="replace"))
        for prefix in (".",):
            if exe.startswith(prefix):
                exe = exe[1:]
        if exe.endswith("-wrapped"):
            exe = exe[:-8]
        if exe.endswith("-wrapp"):
            exe = exe[:-6]
        if exe in ("electron", "electron-wrapped", "electron-wrapp"):
            for arg in cmdline[1:]:
                a = arg.decode(errors="replace")
                if ".asar" in a:
                    parts = a.split("/")
                    for i, p in enumerate(parts):
                        if p == "opt" and i + 1 < len(parts):
                            return parts[i + 1]
                    for p in parts:
                        if len(p) > 33 and p[32] == "-":
                            pkg = p[33:]
                            while pkg and (pkg[-1].isdigit() or pkg[-1] == "."):
                                pkg = pkg[:-1]
                            pkg = pkg.rstrip("-")
                            if len(pkg) > 2:
                                return pkg
                    break
        return exe
    except (FileNotFoundError, PermissionError, IndexError):
        return "?"


def get_app_groups():
    """Group user processes by their top-level application.
    Returns list of (root_pid, app_name, [all_pids]) sorted by name.
    """
    session_pids = set()
    for pid_s in os.listdir("/proc"):
        if not pid_s.isdigit():
            continue
        try:
            uid = os.stat(f"/proc/{pid_s}").st_uid
            if uid < 1000:
                continue
            ppid = int(open(f"/proc/{pid_s}/stat").read().split(")")[1].split()[1])
            if ppid == 1:
                session_pids.add(int(pid_s))
        except (FileNotFoundError, PermissionError, ValueError, IndexError):
            continue

    apps = {}
    for pid_s in os.listdir("/proc"):
        if not pid_s.isdigit():
            continue
        pid = int(pid_s)
        try:
            uid = os.stat(f"/proc/{pid}").st_uid
            if uid < 1000:
                continue
            comm = open(f"/proc/{pid}/comm").read().strip()
            if comm.startswith("["):
                continue
            app_root = pid
            cur = pid
            visited = set()
            while cur > 1 and cur not in visited:
                visited.add(cur)
                ppid = int(open(f"/proc/{cur}/stat").read().split(")")[1].split()[1])
                if ppid in session_pids or ppid <= 1:
                    app_root = cur
                    break
                cur = ppid
            if app_root not in apps:
                apps[app_root] = []
            apps[app_root].append(pid)
        except (FileNotFoundError, PermissionError, ValueError, IndexError):
            continue

    result = []
    skip = {"systemd", "dbus-daemon", "at-spi2-registryd", "at-spi-bus-launcher"}
    for root_pid, pids in apps.items():
        name = _get_app_name(root_pid)
        if name in skip or root_pid in session_pids:
            continue
        result.append((root_pid, name, pids))
    result.sort(key=lambda x: x[1].lower())
    return result


def add_pids_to_cgroup(pids):
    """Add a list of pids to the urix cgroup. Returns count of added."""
    count = 0
    for pid in pids:
        try:
            with open(f"{CGROUP_PATH}/cgroup.procs", "w") as f:
                f.write(str(pid))
            count += 1
        except OSError:
            pass
    return count



def remove_pid_from_cgroup(pid):
    """Move a PID back to the root cgroup."""
    with open("/sys/fs/cgroup/cgroup.procs", "w") as f:
        f.write(str(pid))


def run_in_cgroup(cmd, uid, gid, home, user):
    """Fork, add child to cgroup, drop privileges, exec cmd. Returns child PID."""
    pid = os.fork()
    if pid == 0:
        with open(f"{CGROUP_PATH}/cgroup.procs", "w") as f:
            f.write(str(os.getpid()))
        os.setgid(gid)
        os.setuid(uid)
        os.environ["HOME"] = home
        os.environ["USER"] = user
        os.execvp(cmd[0], cmd)
    return pid
