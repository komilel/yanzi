{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fingerprint-ocv;
  command = lib.concatStringsSep " " [
    (lib.getExe cfg.package)
    "--bus=system"
    "--data-path=/var/lib/fprint"
    "--min-score=${toString cfg.minScore}"
    "--min-area=${toString cfg.minArea}"
  ];

  # These hooks run while user.slice is frozen. Restore both the bus service
  # and its Device object before Noctalia receives PrepareForSleep(false).
  sleepHook = pkgs.writeShellApplication {
    name = "fingerprint-ocv-sleep";
    runtimeInputs = [pkgs.systemd pkgs.coreutils];
    text = ''
      case "$1" in
        pre)
          if ! timeout 10s systemctl --no-ask-password stop fprintd.service; then
            echo "fingerprint-ocv: failed to stop before sleep" >&2
          fi
          ;;
        post)
          if ! timeout 10s systemctl --no-ask-password start fprintd.service; then
            echo "fingerprint-ocv: failed to start after sleep; use password" >&2
            exit 0
          fi
          # Type=dbus becomes ready before USB/TLS initialization finishes.
          for ((attempt = 0; attempt < 50; attempt++)); do
            if busctl --system --timeout=100ms call net.reactivated.Fprint \
              /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager \
              GetDefaultDevice >/dev/null 2>&1; then
              exit 0
            fi
            sleep 0.1
          done
          echo "fingerprint-ocv: sensor not ready after sleep; use password" >&2
          ;;
      esac
    '';
  };

  # Keep upstream clients, PAM module and authorization policy, but make even
  # D-Bus's non-systemd activation fallback launch our driver, never libfprint.
  fprintdCompat = pkgs.symlinkJoin {
    name = "fprintd-fpc9201";
    paths = [pkgs.fprintd];
    postBuild = ''
      service=share/dbus-1/system-services/net.reactivated.Fprint.service
      rm "$out/$service"
      substitute ${pkgs.fprintd}/$service "$out/$service" \
        --replace-fail "Exec=${pkgs.fprintd}/libexec/fprintd" "Exec=${command}"
      rm "$out/lib/systemd/system/fprintd.service"
    '';
  };
in {
  options.services.fingerprint-ocv = {
    enable = lib.mkEnableOption "the FPC 10a5:9201 userspace fingerprint driver";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix {};
      description = "Patched fingerprint-ocv driver package.";
    };

    minScore = lib.mkOption {
      type = lib.types.float;
      default = 0.30;
      description = "Image match threshold; lowering it weakens authentication.";
    };

    minArea = lib.mkOption {
      type = lib.types.ints.positive;
      default = 150000;
      description = "Minimum stitched fingerprint area required during enrollment.";
    };

    pamTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = ''
        Seconds to wait for a fingerprint before falling back to password
        authentication in opt-in PAM services. PAM cannot prompt for both
        simultaneously, so keep this bounded.
      '';
    };

    pamServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["sudo"];
      description = ''
        PAM services to explicitly enable fingerprint authentication for, after
        hardware verification. Empty by default: enrollment tools and the driver
        are available without changing password authentication.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.services.fprintd.enable;
        message = "fingerprint-ocv replaces fprintd; leave services.fprintd.enable disabled to avoid enabling fingerprints in every PAM service.";
      }
      {
        assertion = cfg.minScore >= 0.1 && cfg.minScore <= 1.0;
        message = "services.fingerprint-ocv.minScore must be between 0.1 and 1.0.";
      }
      {
        assertion = cfg.minArea <= 4294967295;
        message = "services.fingerprint-ocv.minArea must fit the driver's 32-bit argument.";
      }
      {
        assertion = lib.all (name:
          !config.security.pam.services.${name}.fprintAuth
          || builtins.elem name cfg.pamServices)
        (builtins.attrNames config.security.pam.services);
        message = "Enable fingerprint PAM services explicitly through services.fingerprint-ocv.pamServices.";
      }
      {
        assertion = !(builtins.elem "sshd" cfg.pamServices);
        message = "Do not enable fingerprint-ocv for SSH authentication.";
      }
    ];

    # Do not enable services.fprintd: its default turns on fingerprint auth
    # throughout PAM. Only opt-in services below get pam_fprintd.
    services.fprintd.package = fprintdCompat;
    security.pam.services = lib.genAttrs cfg.pamServices (name: {
      fprintAuth = true;
      rules.auth =
        {
          fprintd =
            {
              settings = {
                timeout = cfg.pamTimeout;
                max-tries = 3;
              };
            }
            # SDDM delegates to "login", which must stay password-only for
            # Noctalia. Fingerprints belong in the SDDM stack itself.
            // lib.optionalAttrs (name == "sddm" && !config.security.pam.services.sddm.useDefaultRules) {
              order = config.security.pam.services.sddm.rules.auth.login.order - 10;
              control = "sufficient";
              modulePath = "${fprintdCompat}/lib/security/pam_fprintd.so";
            };
        }
        // lib.optionalAttrs (name == "sddm" && !config.security.pam.services.sddm.useDefaultRules) {
          # SDDM already has the submitted password in its PAM conversation.
          # A valid password skips ONLY the fingerprint rule, then runs the
          # unchanged login substack (including keyring/password checks).
          # Empty/incorrect passwords still reach bounded fingerprint auth.
          unix-before-fprintd = {
            order = config.security.pam.services.sddm.rules.auth.login.order - 20;
            control = "[success=1 default=ignore]";
            modulePath = config.security.pam.pam_unixModulePath;
            settings = {
              try_first_pass = true;
              nodelay = true;
              nullok = config.security.pam.services.sddm.allowNullPassword;
            };
          };
        };
    });

    environment.systemPackages = [cfg.package fprintdCompat];
    services.dbus.packages = [fprintdCompat];
    security.polkit.enable = true;

    # The daemon opens USB as root. Do not grant users direct sensor access or
    # install the upstream uaccess rule; all operations go through D-Bus/polkit.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="10a5", ATTR{idProduct}=="9201", TEST=="power/control", ATTR{power/control}="on"
    '';

    # Stop cleanly before USB disappears; wait for rediscovery before sessions
    # thaw. Restart-on-failure alone races Noctalia's one-shot resume attempt.
    environment.etc."systemd/system-sleep/fingerprint-ocv".source = lib.getExe sleepHook;

    systemd.services.fprintd = {
      description = "FPC 10a5:9201 fingerprint reader (fingerprint-ocv)";
      wantedBy = ["multi-user.target"];
      requires = ["dbus.service"];
      after = ["dbus.service" "systemd-udevd.service"];

      serviceConfig = {
        Type = "dbus";
        BusName = "net.reactivated.Fprint";
        ExecStart = command;
        Restart = "on-failure";
        RestartSec = "2s";

        StateDirectory = "fprint";
        StateDirectoryMode = "0700";
        UMask = "0077";
        # The process holds decrypted biometric templates in memory.
        LimitCORE = 0;
        User = "root";
        Group = "root";

        # Raw USB access is necessary, but no capabilities or network access.
        DevicePolicy = "closed";
        DeviceAllow = ["char-usb_device rw"];
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK"];
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };
  };
}
