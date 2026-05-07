---@module 'lazy'
---@type LazySpec
return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      local languages = require 'custom.languages'

      lint.linters_by_ft = languages.linters_by_ft or {}

      local function runnable_linters(filetype)
        local names = lint.linters_by_ft[filetype] or {}
        local available = {}

        for _, name in ipairs(names) do
          local linter = lint.linters[name]
          local command = linter and linter.cmd
          if type(command) == 'function' then command = command() end
          if type(command) == 'string' and vim.fn.executable(command) == 1 then table.insert(available, name) end
        end

        return available
      end

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          if not vim.bo.modifiable then return end

          local linters = runnable_linters(vim.bo.filetype)
          if #linters > 0 then lint.try_lint(linters) end
        end,
      })
    end,
  },
}
