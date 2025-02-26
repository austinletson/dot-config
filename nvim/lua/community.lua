-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.test.neotest" },
  { import = "astrocommunity.file-explorer.oil-nvim" },

  { import = "astrocommunity.motion.mini-surround" },
  { import = "astrocommunity.motion.mini-ai" },
  { import = "astrocommunity.editing-support.mini-operators" },
  { import = "astrocommunity.editing-support.mini-operators" },

  { import = "astrocommunity.completion.avante-nvim" },

  -- import/override with your plugins folder
}
