-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.colorscheme.catppuccin" },

  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.python-ruff" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.lean" },


  { import = "astrocommunity.test.neotest" },
  { import = "astrocommunity.diagnostics.trouble-nvim" },

  { import = "astrocommunity.file-explorer.oil-nvim" },

  { import = "astrocommunity.motion.flash-nvim" },
  { import = "astrocommunity.motion.mini-surround" },
  { import = "astrocommunity.motion.mini-ai" },
  { import = "astrocommunity.editing-support.mini-operators" },

  -- { import = "astrocommunity.completion.avante-nvim" },
  { import = "astrocommunity.editing-support.copilotchat-nvim" },
  
  { import = "astrocommunity.git.neogit" },
  { import = "astrocommunity.git.diffview-nvim" },
  { import = "astrocommunity.git.octo-nvim" },

  
  { import = "astrocommunity.search.grug-far-nvim" },

  -- import/override with your plugins folder
}
