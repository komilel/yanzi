{ config, ... }: {
  xdg.configFile."dunst/dunstrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/yanzi/home/modules/dunst/dunstrc" ;
}
