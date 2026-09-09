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
  bubble = true,             -- keep a status bubble while Crush is parked (working / done / idle)
  bubble_timeout = 5000,     -- ms before a "✓ done" bubble settles to the idle bubble (0 = keep it)
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
local bubble_win = nil
local bubble_buf = nil
local bubble_timer = nil
local bubble_ns = nil
local bubble_rendered = nil
local exiting = false

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

local function close_bubble()
  if bubble_timer then bubble_timer:stop() end
  if bubble_win and vim.api.nvim_win_is_valid(bubble_win) then
    vim.api.nvim_win_close(bubble_win, true)
  end
  bubble_win = nil
  bubble_rendered = nil
end

local function refresh_bubble()
  local config = M.config
  if config.bubble == false or crush_visible then return end
  local state = vim.g.crush_status or ""
  if state == "" then
    close_bubble()
    return
  end

  local logo = " ◆ crush"
  local status = state == "working" and " ✻ working…"
    or state == "done" and " ✓ done"
    or ""
  local hint = " click or press m to restore"
  local text = logo
  if status ~= "" then text = text .. "  " .. status end
  local width = math.min(
    math.max(vim.fn.strdisplaywidth(text), vim.fn.strdisplaywidth(hint)) + 2,
    math.max(vim.o.columns - 4, 10)
  )

  if not (bubble_buf and vim.api.nvim_buf_is_valid(bubble_buf) and bubble_rendered == state) then
    if bubble_buf and vim.api.nvim_buf_is_valid(bubble_buf) then
      vim.api.nvim_buf_set_lines(bubble_buf, 0, -1, false, { text, hint })
    else
      bubble_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[bubble_buf].bufhidden = "wipe"
      vim.api.nvim_buf_set_lines(bubble_buf, 0, -1, false, { text, hint })
      vim.keymap.set("n", "<LeftRelease>", function() M.restore() end,
        { buffer = bubble_buf, nowait = true, silent = true })
      vim.keymap.set("n", "<CR>", function() M.restore() end,
        { buffer = bubble_buf, nowait = true, silent = true })
      vim.keymap.set("n", "m", function() M.restore() end,
        { buffer = bubble_buf, nowait = true, silent = true })
    end

    vim.api.nvim_buf_clear_namespace(bubble_buf, bubble_ns, 0, -1)
    vim.api.nvim_buf_add_highlight(bubble_buf, bubble_ns, "CrushBubbleLogo", 0, 0, #logo)
    if status ~= "" then
      vim.api.nvim_buf_add_highlight(bubble_buf, bubble_ns,
        state == "working" and "CrushBubbleWorking" or "CrushBubbleDone",
        0, #logo + 2, #logo + 2 + #status)
    end
    vim.api.nvim_buf_add_highlight(bubble_buf, bubble_ns, "CrushBubbleHint", 1, 0, -1)
  end

  local win_conf = {
    relative = "editor",
    row = vim.o.lines - 4,
    col = vim.o.columns - width - 2,
    width = width,
    height = 2,
  }

  if bubble_win and vim.api.nvim_win_is_valid(bubble_win) then
    vim.api.nvim_win_set_config(bubble_win, win_conf)
  else
    bubble_win = vim.api.nvim_open_win(bubble_buf, false, vim.tbl_extend("force", win_conf, {
      border = "rounded",
      style = "minimal",
      zindex = 60,
      focusable = true,
    }))
  end
  bubble_rendered = state

  if bubble_timer then bubble_timer:stop() end
  if state == "done" and config.bubble_timeout and config.bubble_timeout > 0 then
    bubble_timer:start(config.bubble_timeout, 0, vim.schedule_wrap(function()
      if vim.g.crush_status == "done" then
        vim.g.crush_status = "idle"
        refresh_bubble()
      end
    end))
  end
end

local function refresh_bubble_for_current_tab()
  local config = M.config
  if config.bubble == false then return end
  local current_tab = vim.api.nvim_get_current_tabpage()
  if bubble_win and vim.api.nvim_win_is_valid(bubble_win) then
    if vim.api.nvim_win_get_tabpage(bubble_win) == current_tab then
      return -- already showing in this tab
    end
    vim.api.nvim_win_close(bubble_win, true)
    bubble_win = nil
    bubble_rendered = nil
  end
  refresh_bubble()
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  local config = M.config

  local Terminal = require("toggleterm.terminal").Terminal

  vim.g.crush_unread = false
  vim.g.crush_status = ""
  done_timer = vim.uv.new_timer()
  bubble_timer = vim.uv.new_timer()
  bubble_ns = vim.api.nvim_create_namespace("crush_bubble")
  vim.api.nvim_set_hl(0, "CrushBubbleLogo", { default = true, link = "Special" })
  vim.api.nvim_set_hl(0, "CrushBubbleWorking", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "CrushBubbleDone", { default = true, link = "MoreMsg" })
  vim.api.nvim_set_hl(0, "CrushBubbleHint", { default = true, link = "Comment" })

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
      close_bubble()
      vim.g.crush_unread = false
      vim.g.crush_status = ""
      done_timer:stop()
      if bubble_timer then bubble_timer:stop() end
      vim.schedule(function()
        vim.cmd("startinsert!")
      end)
    end,
    on_close = function()
      crush_visible = false
      if exiting then
        exiting = false
      else
        if vim.g.crush_status == "" then vim.g.crush_status = "idle" end
        refresh_bubble()
      end
    end,
    on_stdout = function()
      if not crush_visible then
        vim.g.crush_status = "working"
        done_timer:stop()
        done_timer:start(config.unread_debounce, 0, vim.schedule_wrap(function()
          vim.g.crush_unread = true
          vim.g.crush_status = "done"
          refresh_bubble()
        end))
        refresh_bubble()
      end
    end,
    on_exit = function(_, _, exit_code)
      local was_visible = crush_visible
      crush_visible = false
      if done_timer then done_timer:stop() end
      if bubble_timer then bubble_timer:stop() end
      if was_visible then
        -- Crush was quit from the open popup: dismiss it entirely.
        exiting = true
        close_bubble()
        vim.g.crush_unread = false
        vim.g.crush_status = ""
      else
        -- The session ended while parked: keep Crush minimized so it can be restored.
        if vim.g.crush_status == "" or vim.g.crush_status == "working" then
          if exit_code == 0 then
            vim.g.crush_unread = true
            vim.g.crush_status = "done"
          else
            vim.g.crush_status = "idle"
          end
        end
        refresh_bubble()
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

  -- Floating windows live in one tabpage; keep the bubble visible in
  -- whichever tab (or window) the user is currently in.
  local bubble_group = vim.api.nvim_create_augroup("CrushBubble", { clear = true })
  vim.api.nvim_create_autocmd({ "TabEnter", "WinEnter" }, {
    group = bubble_group,
    callback = refresh_bubble_for_current_tab,
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = bubble_group,
    callback = function()
      if bubble_win and not vim.api.nvim_win_is_valid(bubble_win) then
        bubble_win = nil
        bubble_rendered = nil
      end
      vim.schedule(refresh_bubble_for_current_tab)
    end,
  })
end

function M.toggle()
  if not crush_term then return end
  crush_term:toggle()
  if crush_visible then
    close_bubble()
  else
    refresh_bubble()
  end
end

function M.minimize()
  if crush_term and crush_visible then
    M.toggle()
  end
end

function M.restore()
  if crush_term and not crush_visible then
    close_bubble()
    vim.g.crush_unread = false
    vim.g.crush_status = ""
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

function M.is_bubble_visible()
  return bubble_win ~= nil and vim.api.nvim_win_is_valid(bubble_win)
end

M._refresh_bubble = refresh_bubble

return M
