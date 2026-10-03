{pkgs, ...}: {
  programs.nvf.settings.vim = {
    startPlugins = [pkgs.vimPlugins.lsp-overloads-nvim];

    # v2 registers its own LspAttach handler. setup(client, opts) was the v1 API.
    pluginRC.lsp-overloads = ''
      require("lsp-overloads").setup({
        display_automatically = true,
      })
    '';
  };
}
