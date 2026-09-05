# crush.nvim

Neovim integration for [Crush](https://github.com/anthropics/crush), the terminal-first AI assistant.

![demo](docs/demo.gif)

## Features

- **Persistent floating terminal** with automatic session resume per directory
- **Minimize to bubble** -- hiding the popup parks it in a small status bubble
  ("working" / "done"); click it (or press `m`) to restore the session instantly
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
  bubble = true,              -- show a status bubble when the popup is hidden
  bubble_timeout = 5000,      -- ms to keep the bubble after finishing (0 = keep until restored)     -- ms of silence before marking as unread
  keymaps = {
    toggle = "<leader>cc",    -- toggle crush terminal
    shell = "<leader>ct",     -- toggle plain shell
    selection = "<leader>cr", -- pipe visual selection to crush
    file = "<leader>cf",      -- pipe current file to crush
  },
})
```

Set any keymap to `false` to disable it and define your own.

Toggle (`<leader>cc`) doubles as minimize: pressing it while the popup is open
hides it into the bubble, and pressing it again restores the same session.

## Statusline

Two variables drive statusline integration:

- `vim.g.crush_unread` is `true` when Crush finishes responding while the
  terminal is hidden.
- `vim.g.crush_status` is `"working"` while Crush is producing output hidden,
  `"done"` once it finishes, and `""` otherwise.

```lua
-- lualine example
{
  function()
    if vim.g.crush_status == "working" then return "✻ crush" end
    if vim.g.crush_unread then return "* crush" end
    return ""
  end,
  color = { fg = "#f38ba8" },
}
```

## API

```lua
local crush = require("crush")

crush.toggle()        -- toggle the crush terminal (minimizes to bubble when open)
crush.minimize()      -- hide the popup into the status bubble
crush.restore()       -- bring the popup back (same as clicking the bubble)
crush.toggle_shell()  -- toggle the plain shell
crush.run_selection()  -- pipe visual selection (call from visual mode)
crush.run_file()       -- pipe current file
crush.is_unread()      -- check if there are unread messages
crush.is_bubble_visible() -- check if the status bubble is showing
```

## Requirements

- Neovim >= 0.10
- [Crush](https://github.com/anthropics/crush) installed and on PATH
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim)

## License

MIT
