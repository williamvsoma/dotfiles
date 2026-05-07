---@module 'lazy'
---@type LazySpec
return {
  {
    'GCBallesteros/jupytext.nvim',
    lazy = false,
    opts = {
      style = 'markdown',
      output_extension = 'md',
      force_ft = 'markdown',
    },
  },
  {
    'benlubas/molten-nvim',
    version = '^1.0.0',
    build = ':UpdateRemotePlugins',
    cmd = {
      'MoltenInit',
      'MoltenEvaluateLine',
      'MoltenEvaluateOperator',
      'MoltenEvaluateVisual',
      'MoltenReevaluateCell',
      'MoltenHideOutput',
      'MoltenDelete',
    },
    init = function()
      vim.g.molten_auto_open_output = false
      vim.g.molten_image_provider = 'none'
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_text_output = true
      vim.g.molten_wrap_output = true
    end,
    keys = {
      { '<leader>mi', '<cmd>MoltenInit<CR>', desc = '[M]olten [I]nit kernel' },
      { '<leader>ml', '<cmd>MoltenEvaluateLine<CR>', desc = '[M]olten evaluate [L]ine' },
      { '<leader>me', ':<C-u>MoltenEvaluateVisual<CR>gv', mode = 'v', desc = '[M]olten [E]valuate selection' },
      { '<leader>mo', '<cmd>MoltenHideOutput<CR>', desc = '[M]olten hide [O]utput' },
      { '<leader>mr', '<cmd>MoltenReevaluateCell<CR>', desc = '[M]olten [R]erun cell' },
      { '<leader>md', '<cmd>MoltenDelete<CR>', desc = '[M]olten [D]elete cell' },
    },
  },
  {
    'Vigemus/iron.nvim',
    ft = { 'python', 'r', 'lua', 'sh', 'bash', 'zsh' },
    cmd = { 'IronRepl', 'IronRestart', 'IronFocus', 'IronHide' },
    keys = {
      { '<leader>rs', '<cmd>IronRepl<CR>', desc = '[R]EPL [S]tart' },
      { '<leader>rr', '<cmd>IronRestart<CR>', desc = '[R]EPL [R]estart' },
      { '<leader>rf', '<cmd>IronFocus<CR>', desc = '[R]EPL [F]ocus' },
      { '<leader>rh', '<cmd>IronHide<CR>', desc = '[R]EPL [H]ide' },
    },
    config = function()
      local iron = require 'iron.core'
      local view = require 'iron.view'

      iron.setup {
        config = {
          scratch_repl = true,
          repl_definition = {
            bash = { command = { 'bash' } },
            lua = { command = { 'lua' } },
            python = { command = { 'ipython', '--no-autoindent' } },
            r = { command = { 'R', '--quiet', '--no-save' } },
            sh = { command = { 'sh' } },
            zsh = { command = { 'zsh' } },
          },
          repl_open_cmd = view.split.vertical.botright(80),
        },
        keymaps = {
          clear = '<leader>rL',
          cr = '<leader>r<CR>',
          exit = '<leader>rq',
          interrupt = '<leader>rI',
          mark_motion = '<leader>rm',
          mark_visual = '<leader>rm',
          remove_mark = '<leader>rd',
          send_file = '<leader>rF',
          send_line = '<leader>rl',
          send_mark = '<leader>rs',
          send_motion = '<leader>rc',
          visual_send = '<leader>rc',
        },
        ignore_blank_lines = true,
      }
    end,
  },
  {
    'quarto-dev/quarto-nvim',
    ft = { 'quarto', 'markdown' },
    dependencies = {
      'jmbuhr/otter.nvim',
      'neovim/nvim-lspconfig',
    },
    opts = {
      lspFeatures = {
        enabled = true,
        chunks = 'curly',
        languages = { 'python', 'r', 'julia', 'bash', 'html' },
        diagnostics = {
          enabled = true,
          triggers = { 'BufWritePost' },
        },
        completion = {
          enabled = true,
        },
      },
      codeRunner = {
        enabled = true,
        default_method = 'molten',
      },
    },
  },
}
