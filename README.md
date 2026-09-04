# crush.nvim

Neovim integration for [Crush](https://github.com/anthropics/crush), the terminal-first AI assistant.

![demo](demo.gif)

## Features

- **Persistent floating terminal** with automatic session resume per directory
- **Unread indicator** (`vim.g.crush_unread`) for statusline integration -- fires after Crush finishes responding
- **Visual selection pipe** -- send highlighted code to Crush with a prompt
- **File pipe** -- send the current file to Crush with a prompt
- **Auto-reload** -- buffers update automatically when Crush edits files on disk

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hangarbay/crush.nvim",
  dependencies = { "akinsho/toggleterm.nvim" },
  keys = {
    { "<leader>cc", desc = "Toggle Crush" },
    { "<leader>ct", desc = "Toggle terminal" },
    { "<leader>cr", mode = "v", desc = "Crush: run on selection" },
    { "<leader>cf", desc = "Crush: send file to Crush" },
  },
  opts = {},
}
```

## Configuration

All options with their defaults:

```lua
require("crush").setup({
  cmd = "crush",              -- path to crush binary
  yolo = true,                -- auto-accept all permissions
  resume_session = true,      -- resume last session for current directory
  direction = "float",        -- "float", "vertical", or "horizontal"
  float_opts = {
    border = "rounded",
    width_ratio = 0.85,       -- percentage of screen width
    height_ratio = 0.85,      -- percentage of screen height
  },
  shell_direction = "float",  -- direction for the generic shell terminal
  unread_debounce = 2000,     -- ms of silence before marking as unread
  keymaps = {
    toggle = "<leader>cc",    -- toggle crush terminal
    shell = "<leader>ct",     -- toggle plain shell
    selection = "<leader>cr", -- pipe visual selection to crush
    file = "<leader>cf",      -- pipe current file to crush
  },
})
```

Set any keymap to `false` to disable it and define your own.

## Statusline

`vim.g.crush_unread` is set to `true` when Crush finishes responding while the terminal is hidden. Use it in your statusline:

```lua
-- lualine example
{
  function()
    if vim.g.crush_unread then return "* crush" end
    return ""
  end,
  color = { fg = "#f38ba8" },
}
```

## API

```lua
local crush = require("crush")

crush.toggle()        -- toggle the crush terminal
crush.toggle_shell()  -- toggle the plain shell
crush.run_selection()  -- pipe visual selection (call from visual mode)
crush.run_file()       -- pipe current file
crush.is_unread()      -- check if there are unread messages
```

## Requirements

- Neovim >= 0.10
- [Crush](https://github.com/anthropics/crush) installed and on PATH
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim)

## License

MIT
