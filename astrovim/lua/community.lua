-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.python" },
  -- { import = "astrocommunity.pack.json" },

  { import = "astrocommunity.test.neotest" },
  { import = "astrocommunity.diagnostics.trouble-nvim" },

  { import = "astrocommunity.file-explorer.oil-nvim" },

  { import = "astrocommunity.motion.flash-nvim" },
  { import = "astrocommunity.motion.mini-surround" },
  { import = "astrocommunity.motion.mini-ai" },

  { import = "astrocommunity.git.diffview-nvim" },

  { import = "astrocommunity.search.grug-far-nvim" },

  { import = "astrocommunity.code-runner.overseer-nvim" },
}
