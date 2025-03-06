return { -- override nvim-cmp plugin
  "hrsh7th/nvim-cmp",
  -- override the options table that is used in the `require("cmp").setup()` call
  opts = function(_, opts)
    -- opts parameter is the default options table
    -- the function is lazy loaded so cmp is able to be required
    local cmp = require "cmp"
    -- modify the mapping part of the table
    opts.mapping["<C-n>"] = cmp.mapping.select_next_item()
    opts.mapping["<C-p>"] = cmp.mapping.select_prev_item()
    opts.mapping["<C-y>"] = cmp.mapping.confirm { select = true }
    opts.mapping["<C-space>"] = cmp.mapping.complete {}
    opts.mapping["<C-b>"] =cmp.mapping.scroll_docs(-4)
    opts.mapping["<C-f>"] =cmp.mapping.scroll_docs(4)
  end,
}

