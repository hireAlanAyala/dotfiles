-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  EXPERIMENTAL  ·  clipboard history browsed inside oil                      ║
-- ╠══════════════════════════════════════════════════════════════════════════╣
-- ║ This is a SECOND attempt at an nvim clipboard picker. The first one        ║
-- ║ (custom floating windows) lives at `custom/clipboard-picker.lua` and was   ║
-- ║ buggy: it couldn't center in Wayland, and you couldn't close it / change   ║
-- ║ focus without restarting.                                                   ║
-- ║                                                                             ║
-- ║ This version takes a different tack: it materializes each cliphist entry    ║
-- ║ as a REAL temp file and just opens oil on that directory, so oil's own       ║
-- ║ preview machinery (<leader>op, image float, text float) works for free.     ║
-- ║                                                                             ║
-- ║ Correctness notes:                                                          ║
-- ║  * Type is decided by sniffing the decoded BYTES (magic numbers), never by  ║
-- ║    cliphist's hint text or a filename. Images get their real extension so    ║
-- ║    oil previews them; text gets none -- unless its one-liner happens to end  ║
-- ║    in an image extension, in which case ".txt" is appended so oil's          ║
-- ║    extension-based preview still routes it as text.                          ║
-- ║  * Filenames carry NO index. Order comes from mtime; uniqueness from a       ║
-- ║    " (N)" suffix applied only on a real collision.                           ║
-- ║                                                                             ║
-- ║ Centering + focus + closing are handled at the COMPOSITOR level: the        ║
-- ║ launcher (`arch/bin/clipboard-oil-experimental`) opens a normal floating    ║
-- ║ ghostty window (hypr windowrule floats + centers it). It is NOT a special   ║
-- ║ workspace daemon, so it focuses and closes like any other window.           ║
-- ║                                                                             ║
-- ║ Entry point:  require('custom.experimental.clipboard-oil').start()          ║
-- ║ Launched with `nvim --cmd "let g:clipboard_oil=1" -c "lua ...start()"`.     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

local M = {}

-- How many of the most-recent cliphist entries to surface. Capped so a huge
-- history doesn't make startup crawl (each entry is decoded + written to disk).
local MAX_ENTRIES = 100

-- Where the throwaway files live. Wiped and rebuilt on every start().
local function session_dir()
  return vim.fn.stdpath('cache') .. '/clipboard-oil'
end

-- Identify an image purely from its CONTENT (magic bytes) -- never from
-- cliphist's "[[ binary data ]]" hint or a filename. Returns the canonical
-- extension (one oil's preview understands) or nil for anything non-image.
local function image_ext(bytes)
  if #bytes < 12 then return nil end
  local h = bytes
  if h:sub(1, 8) == '\137PNG\r\n\26\n' then return 'png' end
  if h:sub(1, 3) == '\255\216\255' then return 'jpg' end          -- JPEG (SOI + marker)
  if h:sub(1, 6) == 'GIF87a' or h:sub(1, 6) == 'GIF89a' then return 'gif' end
  if h:sub(1, 4) == 'RIFF' and h:sub(9, 12) == 'WEBP' then return 'webp' end
  return nil
end

-- MIME type wl-copy should advertise for an image extension.
local function image_mime(ext)
  return 'image/' .. (ext == 'jpg' and 'jpeg' or ext)
end

-- Extensions oil's preview treats as images (oil.lua is_image). We sniff content
-- to TYPE entries, but oil still ROUTES its preview by extension -- so a text
-- entry whose one-liner ends in one of these (e.g. content "screenshot.png")
-- must be neutralized, or oil would try to image-preview real text.
local OIL_IMAGE_EXTS = { png = true, jpg = true, jpeg = true, gif = true, webp = true, avif = true }

-- Turn arbitrary clipboard text into a safe, single-line, bounded filename stem.
local function sanitize(s)
  s = s:gsub('[%z\1-\31]', ' ')   -- control chars / NUL / newlines -> space
  s = s:gsub('/', '\u{2215}')      -- path separator -> division slash (looks the same)
  s = s:gsub('%s+', ' ')           -- collapse runs of whitespace
  s = s:gsub('^%s+', ''):gsub('%s+$', '')
  s = s:gsub('^%.+', '')           -- no leading dots (hidden-file / ext confusion)
  if vim.fn.strchars(s) > 60 then s = vim.fn.strcharpart(s, 0, 60) .. '…' end
  if s == '' then s = 'untitled' end
  return s
end

-- Decode one cliphist entry to raw bytes. vim.system with text=false returns a
-- byte-safe Lua string (Vimscript strings can't hold NUL, which corrupts images;
-- this is the bug the old code worked around with shell redirection).
local function decode(id)
  local res = vim.system({ 'cliphist', 'decode', id }, { text = false }):wait()
  return res.stdout or ''
end

-- Decide the filename for one decoded entry. `taken` (name->true) makes names
-- collision-free with a " (N)" suffix. No index: order comes from mtime.
local function name_for(raw, taken)
  local function unique(stem, ext)
    local n = 1
    while true do
      local name = (n == 1) and (stem .. ext) or string.format('%s (%d)%s', stem, n, ext)
      if not taken[name] then
        taken[name] = true
        return name
      end
      n = n + 1
    end
  end

  local img = image_ext(raw)
  if img then
    -- Images: name "image" + real extension so oil's preview renders them.
    return unique('image', '.' .. img)
  end
  -- Text (and any non-image bytes): name after the first line. Normally no
  -- extension -- but if the one-liner itself ends in an image extension,
  -- append ".txt" so oil's extension-based preview still treats it as text.
  local stem = sanitize(raw:match('^[^\n]*') or '')
  local trailing = stem:match('%.(%a+)$')
  local ext = (trailing and OIL_IMAGE_EXTS[trailing:lower()]) and '.txt' or ''
  return unique(stem, ext)
end

-- Decode + write the clipboard entries ASYNCHRONOUSLY, so the bulk
-- decode/write never blocks the UI loop (the old synchronous build froze nvim
-- for seconds, which is what made the first preview feel sync). `on_ready` is
-- called as soon as the dir exists with the entry count; files then stream in
-- and oil's watch_for_changes refreshes the listing. `on_done` fires once every
-- entry has been written.
local POOL = 10 -- max concurrent `cliphist decode` jobs

local function build_dir_async(on_ready, on_done)
  local dir = session_dir()
  vim.fn.delete(dir, 'rf')
  vim.fn.mkdir(dir, 'p')

  -- Collect ids only; type + one-liner come from the decoded bytes, not the
  -- list's hint text. cliphist ids increase with recency.
  local ids = {}
  for _, line in ipairs(vim.fn.systemlist({ 'cliphist', 'list' })) do
    if #ids >= MAX_ENTRIES then break end
    local id = line:match('^(%d+)\t') or line:match('^(%d+)%s')
    if id then ids[#ids + 1] = id end
  end

  on_ready(dir, #ids)
  if #ids == 0 then on_done(dir, 0); return end

  local taken = {}
  local next_idx, remaining = 1, #ids

  local function launch()
    local idx = next_idx
    if idx > #ids then return end
    next_idx = idx + 1
    local id = ids[idx]
    vim.system({ 'cliphist', 'decode', id }, { text = false }, function(res)
      vim.schedule(function()
        local raw = res.stdout or ''
        local path = dir .. '/' .. name_for(raw, taken)
        local fd = io.open(path, 'wb')
        if fd then
          fd:write(raw)
          fd:close()
          -- Stable mtime from the cliphist id: higher id = newer, so oil's
          -- { mtime desc } sorts newest-first, AND the value is identical across
          -- launches so oil's thumbnail cache key (path+mtime+size) stays valid
          -- and repeat image previews hit the cache instead of regenerating.
          pcall(vim.loop.fs_utime, path, tonumber(id), tonumber(id))
        end
        remaining = remaining - 1
        if remaining == 0 then on_done(dir, #ids) end
        launch() -- pull the next id as this job finishes (bounded concurrency)
      end)
    end)
  end

  for _ = 1, math.min(POOL, #ids) do launch() end
end

-- Copy the entry under the cursor to the system clipboard, then quit. The temp
-- file holds the exact clipboard bytes, so this is just wl-copy of the file --
-- no cliphist round-trip, no id bookkeeping. The MIME type is decided by
-- sniffing the bytes again (not the filename), so it can't disagree with the
-- actual content.
function M.copy_current()
  local ok, oil = pcall(require, 'oil')
  if not ok then return end
  local entry = oil.get_cursor_entry()
  local dir = oil.get_current_dir()
  if not entry or entry.type ~= 'file' or not dir then
    vim.notify('clipboard-oil: not on an entry', vim.log.levels.WARN)
    return
  end
  local f = io.open(dir .. entry.name, 'rb')
  if not f then return end
  local bytes = f:read('*a')
  f:close()

  local img = image_ext(bytes)
  local args = img and { 'wl-copy', '--type', image_mime(img) } or { 'wl-copy' }
  vim.system(args, { stdin = bytes }):wait()
  -- Leave a marker so the launcher can auto-paste into the previously focused app.
  pcall(vim.fn.writefile, {}, '/tmp/clipboard-oil-selected')
  M.quit()
end

function M.quit()
  vim.cmd('qa!')
end

-- Clean-picker window options: nowrap (truncate) + conceallevel (hide oil's
-- leading entry-id "/070" column). Oil re-applies its own win_options via
-- set_win_options on BufEnter/WinEnter/BufWinEnter and on deferred ticks, so we
-- re-assert ours; callers also re-run this after a refresh.
local function apply_win_opts()
  pcall(vim.api.nvim_set_option_value, 'wrap', false, { scope = 'local', win = 0 })
  pcall(vim.api.nvim_set_option_value, 'conceallevel', 3, { scope = 'local', win = 0 })
  pcall(vim.api.nvim_set_option_value, 'concealcursor', 'nvic', { scope = 'local', win = 0 })
end

-- Buffer-local setup for the picker's oil buffer.
local function setup_buffer()
  local o = { buffer = 0, nowait = true, silent = true }
  -- <Tab> = pick the entry under the cursor (copy to clipboard + paste + close).
  vim.keymap.set('n', '<Tab>', M.copy_current, vim.tbl_extend('force', o, { desc = 'Copy entry + paste' }))
  -- Close keys do nothing -- the picker is dismissed only by picking (<Tab>).
  -- <CR> is also neutralized: oil's default would open the temp file in this
  -- floating window, and with no close key you'd be stranded there.
  vim.keymap.set('n', 'q', '<Nop>', vim.tbl_extend('force', o, { desc = 'clipboard-oil: disabled' }))
  vim.keymap.set('n', '<Esc>', '<Nop>', vim.tbl_extend('force', o, { desc = 'clipboard-oil: disabled' }))
  vim.keymap.set('n', '<CR>', '<Nop>', vim.tbl_extend('force', o, { desc = 'clipboard-oil: disabled' }))

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'WinEnter' }, { buffer = 0, callback = apply_win_opts })
  apply_win_opts()
  vim.defer_fn(apply_win_opts, 50)
  vim.defer_fn(apply_win_opts, 200)
end

-- Entry point. Kick off the async build, open oil as soon as the dir exists,
-- wire the picker keymaps; files stream in without blocking the UI.
function M.start()
  -- Tells the shared oil VimEnter handler not to auto-open cwd -- we're about to
  -- open the curated dir ourselves. This is the only hook into the global config.
  vim.g.clipboard_oil = 1
  -- Drop the icon column (global oil setting, but harmless: this is a throwaway
  -- picker process). Set before oil renders so the first paint is already clean.
  pcall(require('oil').set_columns, {})

  vim.defer_fn(function()
    build_dir_async(
      function(dir, count) -- on_ready: dir exists (maybe empty); open oil now
        if count == 0 then
          vim.notify('clipboard-oil: history is empty', vim.log.levels.INFO)
          vim.defer_fn(M.quit, 800)
          return
        end
        require('oil').open(dir)
        vim.schedule(function()
          if vim.bo.filetype == 'oil' then
            setup_buffer()
          else
            vim.api.nvim_create_autocmd('FileType', { pattern = 'oil', once = true, callback = setup_buffer })
          end
        end)
      end,
      function(_, count) -- on_done: every entry written; ensure all are shown
        if count == 0 then return end
        pcall(function()
          if vim.bo.filetype == 'oil' then
            -- force=true: never stop on a "Discard changes?" prompt (that would
            -- be a hit-enter wedge). The picker buffer is never meant to be edited.
            require('oil.actions').refresh.callback({ force = true })
          end
        end)
        -- A refresh re-applies oil's win_options, so re-assert ours afterwards.
        vim.defer_fn(apply_win_opts, 30)
      end
    )
  end, 30)
end

return M
