"""urix — конфигурация и общие утилиты."""

import json
import os
import subprocess

DATA_DIR = os.environ.get("URIX_DATA_DIR", "/var/lib/urix")
XRAY_CONFIG = os.path.join(DATA_DIR, "xray.json")
PIDFILE = os.path.join(DATA_DIR, "xray.pid")
WATCHPIDFILE = os.path.join(DATA_DIR, "watcher.pid")
CONFIG_FILE = os.path.join(DATA_DIR, "config.json")
CGROUP = "urix"
CGROUP_PATH = f"/sys/fs/cgroup/{CGROUP}"
MARK = "0x2"
TABLE = "200"
TPROXY_PORT = "12345"
SOCKET_PATH = "/run/urix.sock"


def ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def load_config():
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"auto_proxy": []}


def save_config(cfg):
    ensure_data_dir()
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")


def is_running():
    if not os.path.exists(PIDFILE):
        return False
    try:
        pid = int(open(PIDFILE).read().strip())
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


def run_quiet(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True)
