return {
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        -- first key is the mode
        n = {
          -- second key is the lefthand side of the map
          ["-"] = { "<cmd>Oil<cr>", desc = "Oil: Open parent directory" },
        },
      },
    },
  },
}
