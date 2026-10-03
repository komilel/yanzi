{
  config,
  lib,
  ...
}: {
  xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/yanzi/home/modules/niri";

  # Noctalia defaults this off; without an agent polkit cannot ask for the
  # password required to enroll fingerprints (or authorize other desktop tasks).
  xdg.configFile."noctalia/config.toml".text = ''
    [shell]
    polkit_agent = true

    [lockscreen]
    fingerprint = true
  '';
}
