---@module 'lazy'
---@type LazySpec
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown', 'markdown.mdx', 'quarto' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      file_types = { 'markdown', 'markdown.mdx', 'quarto' },
      completions = {
        blink = { enabled = true },
      },
    },
  },
  {
    'lervag/vimtex',
    ft = { 'tex', 'plaintex', 'bib' },
    init = function()
      if vim.fn.executable 'latexmk' == 1 then
        vim.g.vimtex_compiler_method = 'latexmk'
      else
        vim.g.vimtex_compiler_enabled = 0
      end
      vim.g.vimtex_quickfix_mode = 0
      vim.g.vimtex_view_method = vim.fn.executable 'zathura' == 1 and 'zathura' or 'general'
    end,
    keys = {
      { '<leader>mc', '<cmd>VimtexCompile<CR>', desc = 'LaTeX [C]ompile' },
      { '<leader>mv', '<cmd>VimtexView<CR>', desc = 'LaTeX [V]iew PDF' },
      { '<leader>mk', '<cmd>VimtexStop<CR>', desc = 'LaTeX stop compile' },
      { '<leader>mt', '<cmd>VimtexTocToggle<CR>', desc = 'LaTeX [T]OC' },
    },
  },
}
