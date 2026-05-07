---@module 'lazy'
---@type LazySpec
return {
  {
    'olimorris/codecompanion.nvim',
    cmd = {
      'CodeCompanion',
      'CodeCompanionActions',
      'CodeCompanionChat',
      'CodeCompanionCmd',
    },
    keys = {
      { '<leader>aa', '<cmd>CodeCompanionActions<CR>', desc = '[A]I [A]ctions' },
      { '<leader>ac', '<cmd>CodeCompanionChat Toggle<CR>', desc = '[A]I [C]hat' },
      { '<leader>ae', '<cmd>CodeCompanionChat Add<CR>', mode = 'v', desc = '[A]I add s[E]lection' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    ---@module 'codecompanion'
    ---@type CodeCompanion.Config
    opts = {
      strategies = {
        chat = { adapter = 'openai' },
        inline = { adapter = 'openai' },
      },
      opts = {
        log_level = 'ERROR',
      },
    },
  },
}
