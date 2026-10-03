"""Check the evaluated SDDM stack with libpam and mock authentication factors."""

import ctypes
import json
import pathlib
import re
import sys
import tempfile


rules = json.loads(pathlib.Path(sys.argv[1]).read_text())
pam = ctypes.CDLL(sys.argv[2])
module = str(pathlib.Path(sys.argv[3]).resolve())


class Conversation(ctypes.Structure):
    _fields_ = [("callback", ctypes.c_void_p), ("data", ctypes.c_void_p)]


pam.pam_start_confdir.argtypes = [
    ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(Conversation),
    ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p),
]
pam.pam_putenv.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
pam.pam_authenticate.argtypes = [ctypes.c_void_p, ctypes.c_int]
pam.pam_acct_mgmt.argtypes = [ctypes.c_void_p, ctypes.c_int]
pam.pam_end.argtypes = [ctypes.c_void_p, ctypes.c_int]

sddm = [line for line in rules["sddm"].splitlines() if line.startswith("auth ")]
assert len(sddm) == 3, sddm
assert "[success=1 default=ignore]" in sddm[0] and "pam_unix.so" in sddm[0], sddm
assert "try_first_pass" in sddm[0] and "nodelay" in sddm[0], sddm
assert "sufficient" in sddm[1] and "pam_fprintd.so" in sddm[1], sddm
assert re.match(r"auth substack login\b", sddm[2]), sddm
assert "pam_fprintd" not in rules["login"]
assert "pam_fprintd" not in rules["sshd"]

# Preserve the evaluated PAM controls and ordering, changing only factor
# implementations. No mock is loaded by the real system's PAM configuration.
def replace_module(line, role):
    return re.sub(r"/[^\s]+\.so[^#]*", f"{module} {role} ", line).split("#")[0]


with tempfile.TemporaryDirectory() as directory:
    path = pathlib.Path(directory)
    (path / "sddm").write_text("\n".join([
        replace_module(sddm[0], "guard"),
        replace_module(sddm[1], "fingerprint"),
        "auth substack login",
        f"account required {module} account",
    ]) + "\n")
    login = []
    for line in rules["login"].splitlines():
        if not line.startswith("auth "):
            continue
        if "# unix-early " in line:
            role = "early"
        elif "# gnome_keyring " in line:
            role = "keyring"
        elif "# unix " in line:
            role = "password"
        elif "# deny " in line:
            role = "deny"
        else:
            raise AssertionError(f"Unexpected login rule: {line}")
        login.append(replace_module(line, role))
    assert len(login) == 4, login
    (path / "login").write_text("\n".join(login) + "\n")

    cases = [
        # guard, fingerprint, password, account, auth_ok, account_ok, trace
        (0, 7, 0, 0, True, True, ["guard", "early", "keyring", "password", "account"]),
        (7, 0, 7, 0, True, True, ["guard", "fingerprint", "account"]),
        (7, 7, 0, 0, True, True, ["guard", "fingerprint", "early", "keyring", "password", "account"]),
        (7, 7, 7, 0, False, False, ["guard", "fingerprint", "early", "keyring", "password", "deny"]),
        # The guard must NOT grant authentication or bypass account policy.
        (0, 0, 7, 0, False, False, ["guard", "early", "keyring", "password", "deny"]),
        (7, 0, 7, 7, True, False, ["guard", "fingerprint", "account"]),
    ]
    for guard, finger, password, account, auth_ok, account_ok, expected in cases:
        trace = path / "trace"
        trace.unlink(missing_ok=True)
        handle = ctypes.c_void_p()
        conversation = Conversation()
        assert pam.pam_start_confdir(
            b"sddm", b"fixture", ctypes.byref(conversation),
            str(path).encode(), ctypes.byref(handle),
        ) == 0
        try:
            environment = dict(TRACE=str(trace), guard=guard, fingerprint=finger,
                               password=password, account=account, early=0, keyring=0, deny=7)
            for name, value in environment.items():
                assert pam.pam_putenv(handle, f"{name}={value}".encode()) == 0
            result = pam.pam_authenticate(handle, 0)
            assert (result == 0) == auth_ok, (
                environment, result, (path / "sddm").read_text(),
                (path / "login").read_text(), trace.read_text() if trace.exists() else "no trace",
            )
            if result == 0:
                result = pam.pam_acct_mgmt(handle, 0)
                assert (result == 0) == account_ok, (environment, result)
            assert trace.read_text().splitlines() == expected, (environment, trace.read_text())
        finally:
            pam.pam_end(handle, 0)
    print("Evaluated SDDM PAM: password fast path, fingerprint, fallback, denial and account policy passed")
