{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    extraPackages = with pkgs; [plantuml xdg-utils];

    # Local CLI rendering only: no HTTP server, Docker or encoder plugin.
    pluginRC.komi-plantuml = ''
      require("komi.plantuml").setup({
        command = "${lib.getExe pkgs.plantuml}",
        viewer = "${lib.getExe' pkgs.xdg-utils "xdg-open"}",
      })
    '';

    keymaps = [
      {
        key = "<leader>up";
        mode = "n";
        action = "<cmd>PlantumlPreview ascii<CR>";
        desc = "PlantUML: local text preview";
      }
      {
        key = "<leader>ug";
        mode = "n";
        action = "<cmd>PlantumlPreview png<CR>";
        desc = "PlantUML: local PNG preview";
      }
      {
        key = "<leader>us";
        mode = "n";
        action = "<cmd>PlantumlPreview svg<CR>";
        desc = "PlantUML: local SVG preview";
      }
    ];
  };
}
