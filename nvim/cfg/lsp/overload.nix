{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    startPlugins = with pkgs.vimPlugins; [
      lsp-overloads-nvim
    ];

    autocmds = [
      {
        event = ["LspAttach"];
        callback = lib.generators.mkLuaInline ''
          function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client.server_capabilities.signatureHelpProvider then
              require("lsp-overloads").setup(client, {
                display_automatically = true,
              })
            end
          end
        '';
      }
    ];
  };
}
