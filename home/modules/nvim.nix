{config, lib, ...}: {
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/yanzi/home/modules/nvim" ;
}
