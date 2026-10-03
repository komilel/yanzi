# FPC 10a5:9201 on Niko

Hardware: Redmi Book Pro 14 2022, FPC Sensor Controller L:0001,
firmware `021.26.2.031`.

This module packages [Kiwironic's patched fingerprint-ocv](https://github.com/Kiwironic/fingerprint-ocv)
and its three required submodules at fixed revisions and hashes. No vendor
binary, kernel module, vcpkg download, or upstream install script is used.
Local patches start the D-Bus Manager even when no sensor is ready yet and
correct verification cleanup. Releasing a pending scan previously resumed its
queue wait instead of cancelling it, causing `PendingGetError` crashes. Stops
now cancel the old worker before allowing a new scan, and owner-change signals
are checked against the actual claimant.

## Configuration

`hosts/niko/default.nix` enables the driver, standard `fprintd-*` tools, and
fingerprint authentication specifically for `sudo`, `sddm`, and `polkit-1`.
Noctalia lockscreen authentication is enabled in `home/modules/niri.nix` and
uses the standard fingerprint D-Bus interface directly.

`services.fprintd.enable` stays **false**: enabling it would enable fingerprint
authentication throughout PAM by default. The reusable module still defaults
`pamServices` to an empty list for enrollment-only bring-up.

The replacement `fprintd.service` exposes `net.reactivated.Fprint` on the system
bus. Standard fprintd tools, PAM module and polkit policies are retained; both
systemd and D-Bus activation point at fingerprint-ocv, never the stock driver.
USB autosuspend is disabled for this sensor only. Raw sensor access is not
granted to desktop users.

The daemon runs as root to own the standard D-Bus service and open USB, with no
capabilities, no IP sockets, restricted device access, and a read-only filesystem
except its private temporary directory and `/var/lib/fprint`. The template
directory is `0700`; template files must be `0600`. Core dumps are disabled
because the daemon holds decrypted biometric templates in memory.

A system-sleep hook stops the daemon before suspend/hibernation and starts it
again after waking. It waits for the Device D-Bus object, not just the bus name,
while user sessions are still frozen. This is intended to avoid the observed
USB-disconnect crash and Noctalia re-arming before the reader is ready; physical
suspend/resume testing is still required. The wait is bounded; a missing/broken
reader never removes password fallback.

## Build and activate

New files are untracked until you add them to Git. Until then, use `path:.` so
Nix includes them without changing the Git index:

```sh
nix build 'path:.#fingerprint-ocv'
nix build 'path:.#checks.x86_64-linux.fingerprint-pam'
nix build 'path:.#nixosConfigurations.Niko.config.system.build.toplevel'
sudo nixos-rebuild test --flake 'path:.#Niko'
```

`test` activates the configuration without making it the boot default: rebooting
restores the previous boot generation and its PAM rules. It still applies the
whole flake, so inspect other pending configuration changes first.
The configured local PAM services gain fingerprint authentication with password
fallback. SSH and all other PAM services are unchanged. Once the interactive
authentication checks below pass, use `sudo nixos-rebuild switch --flake
'path:.#Niko'` to make this configuration the boot default.

## Hardware testing (interactive)

After activation, first inspect the service:

```sh
systemctl status fprintd --no-pager
```

Enroll from a regular terminal in your graphical session. Noctalia's polkit
agent is enabled in `home/modules/niri.nix` so it can ask for your password
before allowing enrollment. Always name the target account explicitly:

```sh
fprintd-enroll -f right-index-finger komi
```

Expect 20–40 presses. Lift and shift/rotate the finger slightly between presses.
Wait for `enroll-completed`. Do not pipe enrollment through `head`/`tail` or put
it under `timeout`. If polkit cannot display a prompt, diagnose the session's
polkit agent rather than weakening its authorization policy. Check the effective
Noctalia setting with `noctalia config export full`: `shell.polkit_agent` must be
`true`. Configuration changes are normally hot-reloaded; if no prompt appears
after activation, log out and back in to restart the graphical session.

For enrollment before the graphical agent is available, this is an authorized
password-based alternative:

```sh
sudo fprintd-enroll -f right-index-finger komi
```

Do **not** omit `komi` when using sudo: fprintd defaults to the calling user,
which becomes `root`. A successful root enrollment is not visible to normal
`fprintd-verify` as komi, and repeating enrollment as root does not fix that.
Fingerprints are separated by account; do not delete or copy another account's
templates to work around this.

Then test verification:

```sh
fprintd-verify komi
```

Test the enrolled finger several times and also an **unenrolled finger**, which
must be rejected. Check logs and template permissions if anything fails:

```sh
sudo journalctl -u fprintd -b --no-pager -n 80
sudo stat -c '%a %U:%G %n' /var/lib/fprint /var/lib/fprint/fpc9201.bin
```

Do not start a second daemon while the service is running. It will compete for
the USB device. Do not delete templates without asking: re-enrollment needs
physical interaction again.

## Authentication and interactive checks

Niko's explicit opt-in is:

```nix
services.fingerprint-ocv.pamServices = ["sudo" "sddm" "polkit-1"];
```

| Surface | Integration / test |
|---------|--------------------|
| Noctalia lockscreen | Native D-Bus verification, `lockscreen.fingerprint = true`. Lock with Mod+Shift+Z, then touch the reader. Also test unlocking with your password. |
| `sudo` | PAM. Run `sudo -k; sudo -v` to force a fresh challenge, then touch the reader. Repeat without touching it and confirm password fallback. |
| SDDM graphical login | PAM. Save your work before logging out. Select komi, press Enter/click Login with the password field empty, then touch the reader. Alternatively, submit a valid password to skip the fingerprint wait. SilentSDDM does not start authentication until Login is triggered. |
| Desktop authorization | PAM `polkit-1`; Noctalia renders the agent dialog. A fresh authorization challenge should offer the fingerprint prompt before password entry. |

Only listed PAM services gain `pam_fprintd`. The fingerprint rule is
**sufficient**, not required: password fallback stays intact. The timeout is
10 seconds (`services.fingerprint-ocv.pamTimeout`), with at most three failed
scans. PAM is serial: `sudo` and polkit may wait for that timeout before asking
for a password. SDDM first checks the submitted password: success skips only the
fingerprint rule, then executes the unchanged `login` substack, including keyring
authentication. An empty/incorrect password still starts fingerprint verification
with the bounded timeout. This preliminary check never grants authentication on
its own. Noctalia's lockscreen handles the sensor separately, so its password
entry remains immediately usable.

Keep the PAM `login` stack password-only. Noctalia uses that stack for typed
passwords; the current implementation does not actually strip `pam_fprintd`,
despite an outdated source comment. Adding fingerprints to `login` would make
password unlock wait for another fingerprint challenge. Console login, `su`,
password/account-changing tools and SSH remain unchanged. SSH fingerprint
authentication is explicitly prohibited by the module.

Do not leave `fprintd-verify` running while testing a lockscreen or PAM prompt;
only one client can claim the reader at a time. Do not automate screen locking
or log out while work is unsaved. Test a complete suspend/resume cycle while
locked: the service should stop before sleep and restart after waking, and the
lockscreen should recognize the finger again without first unlocking by password.
Also test password unlock followed by another fingerprint lock/unlock, and repeat
SDDM login with both an empty field and a valid password. If anything fails, use
your password and inspect `journalctl -u fprintd -b` and
`journalctl -u systemd-suspend -b`. General USB hot-unplug handling remains an
upstream limitation; the sleep hook is a targeted workaround, not a full driver
hotplug repair.

Fingerprint authentication does not provide the login password to unlock GNOME
Keyring or decrypt disks. A fingerprint-only SDDM login may therefore leave
Keyring asking for its password separately. SSH private-key prompts require that
key's passphrase, which may differ from the account password; storing it in the
keyring still requires unlocking the keyring after a fingerprint-only login.

Observed on Niko: Noctalia password/fingerprint unlock, suspend recovery, sudo,
and SDDM's password fast path work. SDDM fingerprint authentication succeeds, but
the subsequent Niri session has twice shown a black screen with
`DRM: Page flip commit failed (Invalid argument)`. The graphics/session handoff
needs separate testing; fingerprint-only SDDM login is not yet considered reliable.
Do not re-enroll or lower matching thresholds to work around that rendering error.

## Validation and limitations

The package runs hardware-free tests during every build:

- Synthetic-image matching, rejection of blank/unrelated scans, safe merge.
- Encrypted template save/load, account separation, deletion persistence,
  `0600` file permissions, truncated/wrong-key rejection and failed-write handling.
- Daemon startup and Manager D-Bus discovery/introspection on a private session
  bus with no USB sensor or changes to the host's system bus.
- The real Device D-Bus implementation with an idle fake sensor: release during
  a pending scan, repeated stop/start, claimant isolation and client disconnects.
  This test reproduces the observed queue crash when the local fix is removed.

The separate `fingerprint-pam` flake check runs the evaluated SDDM controls through
libpam with mock factors and private configuration files. It checks the password
fast path, fingerprint success, password fallback, failed authentication and
account-policy rejection, without using real passwords or changing `/etc/pam.d`.

These checks do **not** prove hardware reliability or the false-accept rate.
Physical enrollment, negative verification and suspend/resume must be tested.

This is community reverse-engineered, image-based convenience authentication,
not Apple Touch ID or a formally audited biometric implementation. Template
crypto and key derivation are inherited from the driver and are not TPM-backed;
filesystem permissions remain the essential protection. Keep password fallback
and do not lower the matching threshold to work around poor enrollment.

Nix rebuilds keep OpenCV and the executable together, avoiding the shared-library
version mismatch seen with imperative installations.
