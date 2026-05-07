# Neovim Configuration

This Neovim config lives in the `nvim` stow package:

```sh
cd ~/dotfiles
stow nvim
```

It started from Kickstart and keeps that shape: core editor behavior stays in
`init.lua`, while data science, AI, Markdown, and LaTeX additions live in
`lua/custom`.

## Layout

- `init.lua`: leader keys, editor options, Lazy plugin setup, shared LSP,
  formatting, completion, Treesitter, Telescope, theme, and the
  `custom.plugins` import.
- `lua/custom/languages.lua`: the central language table. Add LSP servers,
  Mason tools, Treesitter parsers, formatters, filetypes, and linters here.
- `lua/custom/plugins/ai.lua`: AI assistant commands through CodeCompanion.
- `lua/custom/plugins/data.lua`: notebooks, Quarto, Molten kernels, and REPL
  workflow.
- `lua/custom/plugins/docs.lua`: rendered Markdown and LaTeX authoring through
  VimTeX.
- `lua/custom/plugins/lint.lua`: filetype linting via `nvim-lint`.

## Language Coverage

Data science and AI engineering:

- Python: `pyright` for type-aware LSP diagnostics, `ruff` for linting and
  code actions, and Ruff formatting on save.
- Notebooks: `.ipynb` opens through Jupytext as Markdown-style text, with
  Molten available for Jupyter kernel execution.
- Quarto: `.qmd` files use Quarto/Otter so fenced Python, R, Julia, Bash, and
  HTML chunks get language features.
- Project formats: JSON, YAML, TOML, Dockerfile, shell, TypeScript/TSX parsers,
  plus LSP support for JSON, YAML, TOML, Docker, Bash, and TypeScript.

Markdown and LaTeX:

- Markdown: Marksman LSP, Markdownlint linting, Prettier formatting, and inline
  rendering.
- LaTeX: TexLab LSP, VimTeX compile/view/navigation, latexindent formatting,
  and Zathura forward search when `zathura` is installed.

AI:

- CodeCompanion is lazy-loaded behind `<leader>a`.
- The default adapter is OpenAI. Set `OPENAI_API_KEY` in your shell before
  starting Neovim.

## Keymaps

General Kickstart keys still apply:

- `<leader>f`: format current buffer.
- `<leader>sh`: search help.
- `<leader>sf`: search files.
- `<leader>sg`: live grep.
- `<leader>sd`: search diagnostics.
- `grd`, `grr`, `gri`, `grt`: LSP definition, references, implementation, and
  type definition through Telescope.

AI:

- `<leader>aa`: CodeCompanion actions.
- `<leader>ac`: toggle AI chat.
- Visual `<leader>ae`: add selection to AI chat.

Data and notebooks:

- `<leader>mi`: initialize a Molten kernel.
- `<leader>ml`: evaluate current line.
- Visual `<leader>me`: evaluate selection.
- `<leader>mr`: rerun current Molten cell.
- `<leader>mo`: hide Molten output.
- `<leader>md`: delete Molten cell.

REPL:

- `<leader>rs`: start REPL.
- `<leader>rr`: restart REPL.
- `<leader>rf`: focus REPL.
- `<leader>rh`: hide REPL.
- `<leader>rl`: send current line.
- Visual/operator `<leader>rc`: send selection or motion.

Markdown and LaTeX:

- `<leader>mc`: compile LaTeX.
- `<leader>mv`: view LaTeX PDF.
- `<leader>mt`: toggle LaTeX table of contents.
- `<leader>mk`: stop LaTeX compiler.

## External Dependencies

Lazy installs Neovim plugins. Mason installs most language tools listed in
`lua/custom/languages.lua`, including Pyright, Ruff, Marksman, TexLab, Prettier,
markdownlint-cli2, latexindent, shellcheck, shfmt, Taplo, and Stylua.

Some workflows still need system or Python packages:

- Molten needs Neovim Python support and Jupyter packages, typically:

  ```sh
  python -m pip install --user pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip
  ```

- Jupytext support needs:

  ```sh
  python -m pip install --user jupytext
  ```

- LaTeX compile/view needs a TeX distribution, `latexmk`, and optionally
  `zathura`.
- Iron REPL uses `ipython` for Python, `R` for R files, and shell interpreters
  from your `PATH`.

## Maintenance

- Open `:Lazy` to install, update, or inspect plugins.
- Open `:Mason` to inspect language tools.
- Run `:checkhealth` after adding new language features.
- Add future language servers, formatters, linters, and parsers in
  `lua/custom/languages.lua` first, then add a plugin module only when Neovim
  needs editor behavior beyond LSP/format/lint.
