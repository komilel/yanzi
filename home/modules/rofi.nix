{config, lib, ...}: {
  xdg.configFile."rofi".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/yanzi/home/modules/rofi" ;
}
