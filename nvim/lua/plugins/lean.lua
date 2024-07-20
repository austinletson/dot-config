return {
  "Julian/lean.nvim",
  event = { "BufReadPre *.lean", "BufNewFile *.lean" },

  dependencies = {
    "neovim/nvim-lspconfig",
    "nvim-lua/plenary.nvim",
  },

  -- see details below for full configuration options
  opts = {
    lsp = {},
    mappings = true,
  },
}
