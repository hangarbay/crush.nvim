local M = {}

local defaults = {
  cmd = "crush",
  yolo = true,
  resume_session = true,
  direction = "float",
  float_opts = {
    border = "rounded",
    width_ratio = 0.85,
    height_ratio = 0.85,
  },
  shell_direction = "float",
  unread_debounce = 2000,
  keymaps = {
    toggle = "<leader>cc",
    shell = "<leader>ct",
    selection = "<leader>cr",
    file = "<leader>cf",
  },
}

M.config = {}

local crush_visible = false
local crush_term = nil
local shell_term = nil
local done_timer = nil

local function build_cmd(config)
  local parts = { config.cmd }

  if config.yolo then
    table.insert(parts, "--yolo")
  end

  if config.resume_session then
    local cwd = vim.fn.getcwd()
    local ok, result = pcall(vim.fn.system, {
      config.cmd, "session", "last", "--cwd", cwd, "--json",
    })
    if ok and vim.v.shell_error == 0 then
      local success, data = pcall(vim.json.decode, result)
      if success and data and data.meta and data.meta.id then
        table.insert(parts, "--session")
        table.insert(parts, data.meta.id)
      end
    end
  end

  return table.concat(parts, " ")
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  local config = M.config

  local Terminal = require("toggleterm.terminal").Terminal

  vim.g.crush_unread = false
  done_timer = vim.uv.new_timer()

  require("toggleterm").setup({
    size = function(term)
      if term.direction == "horizontal" then
        return math.floor(vim.o.lines * 0.4)
      elseif term.direction == "vertical" then
        return math.floor(vim.o.columns * 0.45)
      end
    end,
    open_mapping = false,
    shade_terminals = false,
    on_close = function()
      vim.cmd("checktime")
    end,
  })

  crush_term = Terminal:new({
    cmd = build_cmd(config),
    direction = config.direction,
    hidden = true,
    close_on_exit = true,
    float_opts = config.direction == "float" and {
      border = config.float_opts.border,
      width = function()
        return math.floor(vim.o.columns * config.float_opts.width_ratio)
      end,
      height = function()
        return math.floor(vim.o.lines * config.float_opts.height_ratio)
      end,
      winblend = 0,
    } or nil,
    on_open = function()
      crush_visible = true
      vim.g.crush_unread = false
      done_timer:stop()
      vim.schedule(function()
        vim.cmd("startinsert!")
      end)
    end,
    on_close = function()
      crush_visible = false
    end,
    on_stdout = function()
      if not crush_visible then
        done_timer:stop()
        done_timer:start(config.unread_debounce, 0, vim.schedule_wrap(function()
          vim.g.crush_unread = true
        end))
      end
    end,
  })

  shell_term = Terminal:new({
    direction = config.shell_direction,
    hidden = true,
    on_open = function() vim.cmd("startinsert!") end,
  })

  if config.keymaps.toggle then
    vim.keymap.set("n", config.keymaps.toggle, function()
      M.toggle()
    end, { desc = "Toggle Crush" })
  end

  if config.keymaps.shell then
    vim.keymap.set("n", config.keymaps.shell, function()
      M.toggle_shell()
    end, { desc = "Toggle terminal" })
  end

  if config.keymaps.selection then
    vim.keymap.set("v", config.keymaps.selection, function()
      M.run_selection()
    end, { desc = "Crush: run on selection" })
  end

  if config.keymaps.file then
    vim.keymap.set("n", config.keymaps.file, function()
      M.run_file()
    end, { desc = "Crush: explain current file" })
  end
end

function M.toggle()
  if crush_term then
    crush_term:toggle()
  end
end

function M.toggle_shell()
  if shell_term then
    shell_term:toggle()
  end
end

function M.run_selection()
  local Terminal = require("toggleterm.terminal").Terminal
  local config = M.config

  local lines = vim.fn.getregion(
    vim.fn.getpos("v"), vim.fn.getpos("."),
    { type = vim.fn.mode() }
  )
  local text = table.concat(lines, "\n")
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "n", false
  )
  local prompt = vim.fn.input("Crush prompt: ")
  if prompt == "" then return end

  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(text, "\n"), tmp)

  local run = Terminal:new({
    cmd = string.format(
      "cat %s | %s run %s; echo '\\n[press any key to close]'; read -n1",
      vim.fn.shellescape(tmp),
      config.cmd,
      vim.fn.shellescape(prompt)
    ),
    direction = config.direction,
    close_on_exit = true,
    float_opts = config.direction == "float" and {
      border = config.float_opts.border,
      width = function()
        return math.floor(vim.o.columns * config.float_opts.width_ratio)
      end,
      height = function()
        return math.floor(vim.o.lines * config.float_opts.height_ratio)
      end,
    } or nil,
    on_open = function() vim.cmd("startinsert!") end,
    on_close = function()
      vim.fn.delete(tmp)
      vim.cmd("checktime")
    end,
  })
  run:toggle()
end

function M.run_file()
  local Terminal = require("toggleterm.terminal").Terminal
  local config = M.config

  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file open", vim.log.levels.WARN)
    return
  end
  local prompt = vim.fn.input("Crush prompt (for " .. vim.fn.expand("%:t") .. "): ")
  if prompt == "" then prompt = "explain this file" end

  local run = Terminal:new({
    cmd = string.format(
      "cat %s | %s run %s; echo '\\n[press any key to close]'; read -n1",
      vim.fn.shellescape(file),
      config.cmd,
      vim.fn.shellescape(prompt)
    ),
    direction = config.direction,
    close_on_exit = true,
    float_opts = config.direction == "float" and {
      border = config.float_opts.border,
      width = function()
        return math.floor(vim.o.columns * config.float_opts.width_ratio)
      end,
      height = function()
        return math.floor(vim.o.lines * config.float_opts.height_ratio)
      end,
    } or nil,
    on_open = function() vim.cmd("startinsert!") end,
    on_close = function() vim.cmd("checktime") end,
  })
  run:toggle()
end

function M.is_unread()
  return vim.g.crush_unread or false
end

return M
