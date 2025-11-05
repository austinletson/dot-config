return {
  {
    'olimorris/codecompanion.nvim',
    opts = {
      strategies = {
        chat = {
          adapter = 'anthropic',
          model = 'claude-sonnet-4-20250514',
        },
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    keys = {
      { '<Leader>Po', ':CodeCompanionChat<cr>', desc = 'Open code companion chat', mode = 'n' },
    },
  },
}
