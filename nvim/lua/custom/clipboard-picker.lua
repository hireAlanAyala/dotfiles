-- Clipboard picker using cliphist with native nvim buffers
local M = {}

local entries = {}
local list_buf, preview_buf
local list_win, preview_win
local preview_job = nil
local current_image = nil
local daemon_mode = false

local function load_entries()
  entries = {}
  local output = vim.fn.systemlist("cliphist list")
  for _, line in ipairs(output) do
    local id, content = line:match("^(%d+)%s+(.*)$")
    if id then
      local is_image = content:match("^%[%[ binary data .* %]%]$") ~= nil
      table.insert(entries, { id = id, display = content, is_image = is_image })
    end
  end
end

local function clear_image()
  if current_image then
    pcall(function() current_image:clear() end)
    current_image = nil
  end
end

local function hide_picker()
  clear_image()
  if daemon_mode then
    -- Toggle special workspace to hide
    vim.fn.system("hyprctl dispatch togglespecialworkspace clipboard")
  else
    vim.cmd("quitall!")
  end
end

local function update_preview()
  if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then return end

  -- Cancel previous job if still running
  if preview_job then
    vim.fn.jobstop(preview_job)
    preview_job = nil
  end

  -- Clear previous image
  clear_image()

  local cursor = vim.api.nvim_win_get_cursor(list_win)
  local idx = cursor[1]
  local entry = entries[idx]

  if not entry then return end

  if entry.is_image then
    -- Save image to temp file async, then render with image.nvim (kitty protocol)
    local tmp_path = "/tmp/clipboard-preview-image"
    preview_job = vim.fn.jobstart({ "sh", "-c", "cliphist decode " .. entry.id .. " > " .. tmp_path }, {
      on_exit = function()
        preview_job = nil
        vim.schedule(function()
          if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
            -- Clear buffer
            vim.api.nvim_buf_set_option(preview_buf, "modifiable", true)
            vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {})
            vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)

            -- Render image with image.nvim
            local ok, image_api = pcall(require, "image")
            if ok and preview_win and vim.api.nvim_win_is_valid(preview_win) then
              current_image = image_api.hijack_buffer(tmp_path, preview_win, preview_buf)
            end
          end
        end)
      end,
    })
  else
    -- Text preview - async loading
    local lines = {}
    preview_job = vim.fn.jobstart("cliphist decode " .. entry.id, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          lines = data
        end
      end,
      on_exit = function()
        preview_job = nil
        vim.schedule(function()
          if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
            vim.api.nvim_buf_set_option(preview_buf, "modifiable", true)
            vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
            vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
          end
        end)
      end,
    })
  end
end

local function select_entry()
  local cursor = vim.api.nvim_win_get_cursor(list_win)
  local entry = entries[cursor[1]]
  if entry then
    -- Synchronous copy to ensure clipboard is set before hiding
    local content = vim.fn.system("cliphist decode " .. entry.id)
    vim.fn.system("wl-copy", content)
    -- Signal for auto-paste
    vim.fn.writefile({}, "/tmp/clipboard-picker-selected")
  end
  hide_picker()
  -- Auto-paste after hiding (detached so it runs after window hides)
  if entry then
    vim.fn.jobstart({ "sh", "-c", "sleep 0.1 && wtype -M shift -k Insert" }, { detach = true })
  end
end

local function close_picker()
  hide_picker()
end

local function setup_picker_ui()
  load_entries()

  if #entries == 0 then
    print("No clipboard entries")
    if not daemon_mode then
      vim.cmd("quitall!")
    end
    return
  end

  -- Create buffers
  list_buf = vim.api.nvim_create_buf(false, true)
  preview_buf = vim.api.nvim_create_buf(false, true)

  -- Fill list buffer
  local lines = {}
  for _, entry in ipairs(entries) do
    table.insert(lines, entry.display)
  end
  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(list_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(list_buf, "buftype", "nofile")

  -- Preview buffer setup
  vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(preview_buf, "buftype", "nofile")

  -- Create split layout: list on left, preview on right
  vim.cmd("vsplit")
  -- After vsplit: cursor is in original (right) window, new window is on left
  preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(preview_win, preview_buf)

  vim.cmd("wincmd h")
  list_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(list_win, list_buf)
  vim.api.nvim_win_set_width(list_win, 50)

  -- No wrap on list, wrap on preview
  vim.api.nvim_win_set_option(list_win, "wrap", false)
  vim.api.nvim_win_set_option(preview_win, "wrap", true)

  -- Keymaps for list buffer
  local opts = { buffer = list_buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", select_entry, opts)
  vim.keymap.set("n", "<Esc>", close_picker, opts)
  vim.keymap.set("n", "q", close_picker, opts)

  -- Update preview on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_buf,
    callback = update_preview,
  })

  -- Initial preview
  update_preview()
end

-- Standard pick function (non-daemon mode)
function M.pick()
  vim.defer_fn(function()
    setup_picker_ui()
  end, 50)
end

-- Daemon mode: stay running, refresh on each pick call
function M.daemon()
  daemon_mode = true

  -- Initial setup
  vim.defer_fn(function()
    setup_picker_ui()
  end, 100)
end

-- Refresh and show (called from toggle script)
function M.show()
  -- Clean up old buffers/windows
  clear_image()
  if list_buf and vim.api.nvim_buf_is_valid(list_buf) then
    vim.api.nvim_buf_delete(list_buf, { force = true })
  end
  if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
    vim.api.nvim_buf_delete(preview_buf, { force = true })
  end

  -- Close all windows and start fresh
  vim.cmd("only")

  -- Refresh entries and rebuild UI
  setup_picker_ui()
end

return M
