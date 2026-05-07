local M = {}

local function zathura_forward_search()
  if vim.fn.executable 'zathura' ~= 1 then return nil end

  return {
    executable = 'zathura',
    args = { '--synctex-forward', '%l:1:%f', '%p' },
  }
end

M.filetypes = {
  extension = {
    qmd = 'quarto',
    rmd = 'rmd',
    ipynb = 'json',
    mdx = 'markdown.mdx',
  },
}

M.servers = {
  pyright = {
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = 'workspace',
          typeCheckingMode = 'basic',
          useLibraryCodeForTypes = true,
        },
      },
    },
  },
  ruff = {
    on_attach = function(client) client.server_capabilities.hoverProvider = false end,
    init_options = {
      settings = {
        lineLength = 100,
      },
    },
  },
  marksman = {},
  texlab = {
    settings = {
      texlab = {
        auxDirectory = '.',
        bibtexFormatter = 'texlab',
        build = {
          executable = 'latexmk',
          args = { '-pdf', '-interaction=nonstopmode', '-synctex=1', '%f' },
          forwardSearchAfter = false,
          onSave = false,
        },
        chktex = {
          onEdit = false,
          onOpenAndSave = true,
        },
        diagnosticsDelay = 300,
        forwardSearch = zathura_forward_search(),
        latexFormatter = 'latexindent',
      },
    },
  },
  bashls = {},
  dockerls = {},
  docker_compose_language_service = {},
  jsonls = {},
  taplo = {},
  ts_ls = {},
  yamlls = {
    settings = {
      yaml = {
        keyOrdering = false,
        validate = true,
      },
    },
  },
}

M.tools = {
  'black',
  'isort',
  'latexindent',
  'markdownlint-cli2',
  'prettier',
  'ruff',
  'shellcheck',
  'shfmt',
  'taplo',
}

M.parsers = {
  'bibtex',
  'csv',
  'dockerfile',
  'json',
  'latex',
  'python',
  'r',
  'regex',
  'toml',
  'tsx',
  'typescript',
  'yaml',
}

M.formatters_by_ft = {
  python = { 'ruff_fix', 'ruff_organize_imports', 'ruff_format' },
  markdown = { 'prettier' },
  ['markdown.mdx'] = { 'prettier' },
  json = { 'prettier' },
  jsonc = { 'prettier' },
  yaml = { 'prettier' },
  toml = { 'taplo' },
  tex = { 'latexindent' },
  plaintex = { 'latexindent' },
  bib = { 'latexindent' },
  sh = { 'shfmt' },
  bash = { 'shfmt' },
  zsh = { 'shfmt' },
}

M.format_on_save = {
  lua = true,
  python = true,
  markdown = true,
  ['markdown.mdx'] = true,
  json = true,
  jsonc = true,
  yaml = true,
  toml = true,
  tex = true,
  plaintex = true,
  sh = true,
  bash = true,
  zsh = true,
}

M.linters_by_ft = {
  python = { 'ruff' },
  markdown = { 'markdownlint-cli2' },
  ['markdown.mdx'] = { 'markdownlint-cli2' },
}

return M
