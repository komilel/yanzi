{lib, ...}: {
  programs.nvf.settings.vim = {
    augroups = [{name = "komi_editor";}];
    autocmds = [
      # Treesitter indentation excludes cs; set the fallback once, not on BufEnter.
      {
        event = ["FileType"];
        pattern = ["cs"];
        group = "komi_editor";
        desc = "Built-in indent rules for C#";
        callback = lib.generators.mkLuaInline ''
          function(args)
            vim.bo[args.buf].indentexpr = ""
            vim.bo[args.buf].smartindent = true
          end
        '';
      }
      {
        event = ["LspAttach"];
        group = "komi_editor";
        desc = "Initialize inlay hints without resetting the buffer's toggle";
        callback = lib.generators.mkLuaInline ''
          function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client:supports_method("textDocument/inlayHint", args.buf)
                and not vim.b[args.buf].komi_inlay_hints_initialized then
              vim.b[args.buf].komi_inlay_hints_initialized = true
              vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
            end
          end
        '';
      }
    ];
  };
}
