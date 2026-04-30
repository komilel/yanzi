{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    extraPackages = with pkgs; [
      curl # for downloading the generated diagrams
      plantuml # well
    ];

    startPlugins = with pkgs.vimPlugins; [
      LibDeflate-nvim
    ];

    lazy.plugins = with pkgs.vimPlugins; {
      "plantuml.nvim" = {
        enabled = true;
        package = plantuml-nvim;

        setupModule = "plantuml";
        setupOpts = {
          # default opts
          base_url = "https://www.plantuml.com/plantuml";
          reload_events = [];
          viewer = "xdg-open";
          docker_image = "plantuml/plantuml-server:tomcat";
        };

        keys = [
          {
            key = "<leader>up";
            mode = "n";
            action = "<cmd>PlantumlPreview ascii<CR>";
            desc = "Plantuml: preview ascii";
          }

          {
            key = "<leader>ug";
            mode = "n";
            action = "<cmd>PlantumlPreview png<CR>";
            desc = "Plantuml: preview png";
          }

          {
            key = "<leader>us";
            mode = "n";
            action = "<cmd>PlantumlStartDocker<CR>";
            desc = "Plantuml: start docker";
          }
        ];
      };
    };
  };
}
