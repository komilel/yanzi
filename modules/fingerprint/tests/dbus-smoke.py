"""Smoke-test the daemon on a private bus without a USB device or system changes."""

import pathlib
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET


binary = str(pathlib.Path(sys.argv[1]).resolve())


def call(method):
    return subprocess.run(
        [
            "dbus-send",
            "--session",
            "--print-reply",
            "--reply-timeout=1000",
            "--dest=net.reactivated.Fprint",
            "/net/reactivated/Fprint/Manager",
            method,
        ],
        capture_output=True,
        text=True,
        timeout=3,
    )


with tempfile.TemporaryDirectory() as directory:
    with open(pathlib.Path(directory) / "daemon.log", "w+") as log:
        daemon = subprocess.Popen([binary, "--bus=session"], cwd=directory, stdout=log, stderr=log)
        try:
            for attempt in range(100):
                if daemon.poll() is not None:
                    log.seek(0)
                    raise RuntimeError(f"Daemon exited ({daemon.returncode}): {log.read()}")
                devices = call("net.reactivated.Fprint.Manager.GetDevices")
                if devices.returncode == 0:
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError(f"Daemon did not acquire its bus name: {devices.stderr}")

            assert "array [" in devices.stdout, devices.stdout
            assert "object path" not in devices.stdout, "Build sandbox must not expose USB hardware"

            default = call("net.reactivated.Fprint.Manager.GetDefaultDevice")
            assert default.returncode != 0
            assert "net.reactivated.Fprint.Error.NoSuchDevice" in default.stderr, default.stderr

            introspection = call("org.freedesktop.DBus.Introspectable.Introspect")
            assert introspection.returncode == 0, introspection.stderr
            start = introspection.stdout.index("<!DOCTYPE")
            end = introspection.stdout.rindex("</node>") + len("</node>")
            node = ET.fromstring(introspection.stdout[start:end])
            interface = node.find("interface[@name='net.reactivated.Fprint.Manager']")
            assert interface is not None
            methods = {method.attrib["name"] for method in interface.findall("method")}
            assert {"GetDevices", "GetDefaultDevice"} <= methods
            assert daemon.poll() is None, "Daemon must survive D-Bus calls without a sensor"
            print("Private D-Bus startup, discovery, errors and introspection passed")
        finally:
            daemon.terminate()
            try:
                daemon.wait(timeout=5)
            except subprocess.TimeoutExpired:
                daemon.kill()
                daemon.wait()
