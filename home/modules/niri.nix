{config, lib, ...}: {
  xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/yanzi/home/modules/niri";
}
