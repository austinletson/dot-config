return {
  'tpope/vim-fugitive',

  lazy = false,

  -- vim-rhubarb adds GitHub support for :GBrowse
  dependencies = {
    'tpope/vim-rhubarb',
  },

  keys = {
    { '<leader>gh', '<cmd>0Gclog<cr>', desc = 'Git file history' },
    { '<leader>gB', '<cmd>GBrowse<cr>', desc = 'Git browse on GitHub' },
    { '<leader>gD', '<cmd>Gvdiffsplit<cr>', desc = 'Git diff split' },
  },
}
