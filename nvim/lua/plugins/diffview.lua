return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>gh"] = { "<cmd>DiffviewFileHistory %<cr>", desc = "Git file history" },
        },
      },
    },
  },
}
