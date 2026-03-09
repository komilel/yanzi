{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    autocmds = [
      # TS indent is a no-go, so use default indent from nvim
      {
        event = ["BufEnter"];
        pattern = ["*.cs"];
        desc = "Built-in indent rules for C#";
        callback = lib.generators.mkLuaInline ''
          function()
            vim.bo.indentexpr = ""
            vim.bo.smartindent = true
          end
        '';
      }
    ];
  };
}
