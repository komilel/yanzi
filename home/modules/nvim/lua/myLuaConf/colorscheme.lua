require("lze").load(
  {
    "tokyonight.nvim",
    after = function ()
      require("tokyonight").setup({
        style = "night", -- The theme comes in three styles, `storm`, a darker variant `night` and `day`
        light_style = "day", -- The theme is used when the background is set to light
        transparent = true, -- Enable this to disable setting the background color
        terminal_colors = true, -- Configure the colors used when opening a `:terminal` in Neovim
        styles = {
          -- Style to be applied to different syntax groups
          -- Value is any valid attr-list value for `:help nvim_set_hl`
          comments = {},
          keywords = { italic = true },
          functions = {},
          variables = { bold = true },
          -- Background styles. Can be "dark", "transparent" or "normal"
          sidebars = "transparent", -- style for sidebars, see below
          floats = "transparent", -- style for floating windows
        },
      })

      vim.cmd[[colorscheme tokyonight]]
    end
  }
)
