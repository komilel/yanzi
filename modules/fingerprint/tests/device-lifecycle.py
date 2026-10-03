"""Real Device D-Bus lifecycle regression checks on an isolated session bus."""

import os
import pathlib
import subprocess
import sys
import tempfile
import time

import dbus


binary = str(pathlib.Path(sys.argv[1]).resolve())
interface = "net.reactivated.Fprint.Device"
address = os.environ["DBUS_SESSION_BUS_ADDRESS"]


def connect():
    bus = dbus.bus.BusConnection(address)
    device = dbus.Interface(
        bus.get_object("net.reactivated.Fprint", "/net/reactivated/Device/0"),
        interface,
    )
    return bus, device


def expect_error(name, call):
    try:
        call()
    except dbus.DBusException as error:
        assert error.get_dbus_name() == f"net.reactivated.Fprint.Error.{name}", error
    else:
        raise AssertionError(f"Expected {name}")


with tempfile.TemporaryDirectory() as directory:
    with open(pathlib.Path(directory) / "fixture.log", "w+") as log:
        fixture = subprocess.Popen([binary], cwd=directory, stdout=log, stderr=log)
        try:
            for attempt in range(100):
                assert fixture.poll() is None, "Device fixture crashed at startup"
                try:
                    bus, device = connect()
                    device.Claim("")
                    break
                except dbus.DBusException:
                    time.sleep(0.05)
            else:
                raise RuntimeError("Device fixture did not become ready")

            # Noctalia releases an active verification on password unlock.
            for _ in range(30):
                device.VerifyStart("any")
                device.Release()
                device.Claim("")

            # PAM times out, stops, and releases; also permit stop/start under
            # one claim without leaving an old worker consuming new images.
            for _ in range(30):
                device.VerifyStart("any")
                device.VerifyStop()
                device.VerifyStart("any")
                device.VerifyStop()
                device.Release()
                device.Claim("")

            device.VerifyStart("any")
            outsider_bus, outsider = connect()
            expect_error("AlreadyInUse", lambda: outsider.Claim(""))
            expect_error("PermissionDenied", outsider.Release)
            outsider_bus.close()
            time.sleep(0.05)
            # The unrelated owner's disappearance must not drop our claim.
            device.VerifyStop()
            device.Release()
            bus.close()

            # An active client's disappearance must clean up for the next
            # client. Each iteration leaves a Queue::Get pending intentionally.
            for _ in range(20):
                bus, device = connect()
                for attempt in range(100):
                    try:
                        device.Claim("")
                        break
                    except dbus.DBusException as error:
                        assert error.get_dbus_name().endswith("AlreadyInUse"), error
                        time.sleep(0.01)
                else:
                    raise RuntimeError("Disconnected client kept its claim")
                device.VerifyStart("any")
                bus.close()
                time.sleep(0.01)

            assert fixture.poll() is None, "Device fixture crashed during lifecycle tests"
            print("Release, repeated stop/start, owner isolation and disconnect cleanup passed")
        except Exception:
            log.flush()
            log.seek(0)
            print(log.read(), file=sys.stderr)
            raise
        finally:
            fixture.terminate()
            try:
                fixture.wait(timeout=5)
            except subprocess.TimeoutExpired:
                fixture.kill()
                fixture.wait()
