return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>fq"] = { function() require("snacks").picker.qflist() end, desc = "Find quickfix list" },
        },
      },
    },
  },
}
