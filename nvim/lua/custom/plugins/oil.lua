return {
  'barrettruth/canola.nvim',
  lazy = false,
  ---@module 'oil'
  ---@type oil.SetupOpt
  config = function()
    require('oil').setup({
      default_file_explorer = true,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      lsp_file_methods = {
        enabled = true,
        timeout_ms = 1000,
        autosave_changes = true,
      },
      watch_for_changes = true,
      win_options = {
        wrap = true,
      },
      preview = {
        max_width = 0.9,
        min_width = { 40, 0.4 },
        max_height = 0.9,
        min_height = { 5, 0.1 },
        border = 'rounded',
      },
      view_options = {
        show_hidden = true,
        sort = {
          { 'mtime', 'desc' },
          { 'name', 'asc' },
        },
      },
      keymaps = {
      -- Oil maps <C-h> to select_split by default, which shadows the global
      -- <C-h> = <C-w>h window-nav. Disable it so navigating left works in oil too.
      ['<C-h>'] = false,
      ['<leader>os'] = {
        function()
          local oil = require 'oil'
          local config = require 'oil.config'

          local sort_modes = {
            { 'name', 'Name' },
            { 'type', 'Type' },
            { 'size', 'Size' },
            { 'mtime', 'Modified Time' },
          }

          local current_sort = config.view_options.sort[1][1]
          local current_index = 1

          -- Find current sort mode
          for i, mode in ipairs(sort_modes) do
            if mode[1] == current_sort then
              current_index = i
              break
            end
          end

          -- Create menu items
          local items = {}
          for i, mode in ipairs(sort_modes) do
            local prefix = (i == current_index) and '● ' or '  '
            table.insert(items, prefix .. mode[2])
          end

          -- Show menu
          vim.ui.select(items, {
            prompt = 'Select sort mode:',
            format_item = function(item)
              return item
            end,
          }, function(choice, idx)
            if choice and idx then
              local selected_mode = sort_modes[idx][1]
              oil.set_sort { { selected_mode, 'asc' } }
              vim.notify('Sorted by: ' .. sort_modes[idx][2])
            end
          end)
        end,
        desc = 'Cycle sort mode',
      },
      ['<leader>oi'] = {
        function()
          local oil = require 'oil'
          local ns = vim.api.nvim_create_namespace 'oil_file_info'
          local bufnr = vim.api.nvim_get_current_buf()

          -- Check if virtual text is already displayed
          local existing = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
          if #existing > 0 then
            -- Clear existing virtual text
            vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
            vim.notify 'File info hidden'
            return
          end

          -- Add virtual text for each entry using oil's API
          local current_dir = oil.get_current_dir()
          if not current_dir then
            vim.notify 'Not in oil buffer'
            return
          end

          -- Get all files in the current directory
          local handle = vim.loop.fs_scandir(current_dir)
          if not handle then
            vim.notify 'Cannot read directory'
            return
          end

          local files = {}
          while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then
              break
            end
            files[name] = type
          end

          -- Get buffer lines and match them with files
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          for line_num, line in ipairs(lines) do
            -- Try to extract filename from line (skip parent directory)
            if not line:match '%.%./' then
              for filename, _ in pairs(files) do
                if line:find(filename, 1, true) then
                  local path = current_dir .. filename
                  local stat = vim.loop.fs_stat(path)
                  if stat then
                    local mtime_str = os.date('%Y-%m-%d %H:%M', stat.mtime.sec)

                    local size_str = ''
                    if stat.type == 'file' then
                      if stat.size < 1024 then
                        size_str = string.format('%dB', stat.size)
                      elseif stat.size < 1024 * 1024 then
                        size_str = string.format('%.1fKB', stat.size / 1024)
                      elseif stat.size < 1024 * 1024 * 1024 then
                        size_str = string.format('%.1fMB', stat.size / (1024 * 1024))
                      else
                        size_str = string.format('%.1fGB', stat.size / (1024 * 1024 * 1024))
                      end
                    elseif stat.type == 'directory' then
                      -- Calculate directory size
                      local function get_dir_size(dir_path)
                        local total_size = 0
                        local dir_handle = vim.loop.fs_scandir(dir_path)
                        if dir_handle then
                          while true do
                            local name, type = vim.loop.fs_scandir_next(dir_handle)
                            if not name then
                              break
                            end
                            local item_path = dir_path .. '/' .. name
                            local item_stat = vim.loop.fs_stat(item_path)
                            if item_stat then
                              if item_stat.type == 'file' then
                                total_size = total_size + item_stat.size
                              elseif item_stat.type == 'directory' then
                                total_size = total_size + get_dir_size(item_path)
                              end
                            end
                          end
                        end
                        return total_size
                      end

                      local dir_size = get_dir_size(path)
                      if dir_size < 1024 then
                        size_str = string.format('%dB', dir_size)
                      elseif dir_size < 1024 * 1024 then
                        size_str = string.format('%.1fKB', dir_size / 1024)
                      elseif dir_size < 1024 * 1024 * 1024 then
                        size_str = string.format('%.1fMB', dir_size / (1024 * 1024))
                      else
                        size_str = string.format('%.1fGB', dir_size / (1024 * 1024 * 1024))
                      end
                    end
                    local virt_text = string.format('  %s %s', size_str, mtime_str)

                    vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, 0, {
                      virt_text = { { virt_text, 'Comment' } },
                      virt_text_pos = 'eol',
                    })
                    break
                  end
                end
              end
            end
          end
          vim.notify 'File info shown'
        end,
        desc = 'Toggle file info',
      },
      ['K'] = {
        function()
          local oil = require 'oil'
          local entry = oil.get_cursor_entry()
          if not entry then
            return
          end

          local path = oil.get_current_dir() .. entry.name
          local stat = vim.loop.fs_stat(path)
          if not stat then
            vim.notify('Could not get file info for: ' .. path, vim.log.levels.ERROR)
            return
          end

          local info = {
            'File: ' .. entry.name,
            'Path: ' .. path,
            'Type: ' .. stat.type,
            'Size: ' .. stat.size .. ' bytes',
            'Modified: ' .. os.date('%Y-%m-%d %H:%M:%S', stat.mtime.sec),
            'Permissions: ' .. string.format('%o', stat.mode),
          }

          vim.lsp.util.open_floating_preview(info, 'text', {
            border = 'rounded',
            title = ' File Info ',
            title_pos = 'center',
          })
        end,
        desc = 'Show file info',
      },
      ['<leader>oc'] = {
        function()
          local oil = require 'oil'
          local entry = oil.get_cursor_entry()
          if not entry then
            vim.notify('No file selected', vim.log.levels.WARN)
            return
          end

          local current_dir = oil.get_current_dir()
          local source_path = current_dir .. entry.name
          local source_ext = entry.name:match '%.([^%.]+)$'

          if not source_ext then
            vim.notify('File has no extension', vim.log.levels.WARN)
            return
          end

          -- Supported formats
          local formats = {
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'tiff',
            'webp',
            'ico',
            'svg',
            'pdf',
          }

          -- Remove current format from options (case insensitive)
          local target_formats = {}
          for _, fmt in ipairs(formats) do
            if fmt:lower() ~= source_ext:lower() then
              table.insert(target_formats, fmt)
            end
          end

          if #target_formats == 0 then
            vim.notify('No conversion options available', vim.log.levels.WARN)
            return
          end

          -- Show format selection menu
          vim.ui.select(target_formats, {
            prompt = 'Convert ' .. entry.name .. ' to:',
            format_item = function(item)
              return item:upper()
            end,
          }, function(choice)
            if choice then
              local base_name = entry.name:match '(.+)%.[^%.]+$' or entry.name
              local target_path = current_dir .. base_name .. '.' .. choice

              -- Build ImageMagick command
              local cmd = string.format("convert '%s' '%s'", source_path, target_path)

              vim.notify('Converting ' .. entry.name .. ' to ' .. choice:upper() .. '...')

              -- Execute conversion
              vim.fn.jobstart(cmd, {
                on_exit = function(_, exit_code)
                  if exit_code == 0 then
                    vim.notify('Conversion successful: ' .. base_name .. '.' .. choice)
                    -- Refresh oil buffer
                    vim.cmd 'edit'
                  else
                    vim.notify('Conversion failed', vim.log.levels.ERROR)
                  end
                end,
                on_stderr = function(_, data)
                  if data and #data > 0 and data[1] ~= '' then
                    vim.notify('Error: ' .. table.concat(data, ' '), vim.log.levels.ERROR)
                  end
                end,
              })
            end
          end)
        end,
        desc = 'Convert media file',
      },
      ['<leader>ot'] = {
        function()
          local oil = require 'oil'
          local dir = oil.get_current_dir()
          if not dir then
            vim.notify('Not in oil buffer', vim.log.levels.WARN)
            return
          end

          -- Derive session name from directory basename, replacing dots with dashes
          local name = vim.fn.fnamemodify(dir:gsub('/$', ''), ':t'):gsub('%.', '-')
          if name == '' then name = 'root' end

          -- Close the oil buffer before switching away, so this session isn't
          -- left sitting in oil when we come back to it (dir/name already captured).
          pcall(oil.close)

          -- Check if session already exists
          local result = vim.system({ 'tmux', 'has-session', '-t', name }, { env = { TMUX = '' } }):wait()
          if result.code == 0 then
            -- Session exists, switch to it
            vim.fn.jobstart({ 'tmux', 'switch-client', '-t', name }, { env = { TMUX = '' } })
            vim.notify('Switched to tmux session: ' .. name)
          else
            -- Create new session and switch to it
            vim.system({ 'tmux', 'new-session', '-d', '-s', name, '-c', dir }, { env = { TMUX = '' } }):wait()
            vim.fn.jobstart({ 'tmux', 'switch-client', '-t', name }, { env = { TMUX = '' } })
            vim.notify('Created tmux session: ' .. name)
          end
        end,
        desc = 'Tmux session here',
      },
      ['<leader>od'] = {
        function()
          local oil = require 'oil'
          local current_dir = oil.get_current_dir()
          if not current_dir then
            vim.notify('Not in oil buffer', vim.log.levels.WARN)
            return
          end

          local paths = {}
          local mode = vim.fn.mode()

          if mode == 'v' or mode == 'V' or mode == '\22' then
            -- Visual mode: get all selected lines
            local start_line = vim.fn.line 'v'
            local end_line = vim.fn.line '.'
            if start_line > end_line then
              start_line, end_line = end_line, start_line
            end

            for lnum = start_line, end_line do
              local entry = oil.get_entry_on_line(0, lnum)
              if entry and entry.name ~= '..' then
                table.insert(paths, current_dir .. entry.name)
              end
            end
            -- Exit visual mode
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
          else
            -- Normal mode: just the current entry
            local entry = oil.get_cursor_entry()
            if entry and entry.name ~= '..' then
              table.insert(paths, current_dir .. entry.name)
            end
          end

          if #paths == 0 then
            vim.notify('No files selected', vim.log.levels.WARN)
            return
          end

          local cmd = { 'dragon-drop', '--and-exit', '--all' }
          for _, path in ipairs(paths) do
            table.insert(cmd, path)
          end

          vim.fn.jobstart(cmd, { detach = true })
          vim.notify('Drag ' .. #paths .. ' file(s)')
        end,
        desc = 'Drag file(s)',
        mode = { 'n', 'v' },
      },
    },
    })

    -- Clean up oil buffers on exit to prevent :oil files
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(buf)
          if name:match("oil://") then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end,
    })

    -- Set up which-key group only in oil buffers
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'oil',
      callback = function()
        local wk = require 'which-key'
        wk.add {
          { '<leader>o', group = 'Oil', buffer = 0 },
          { '<leader>os', desc = 'Sort files', buffer = 0 },
          { '<leader>oi', desc = 'Toggle inline file info', buffer = 0 },
          { '<leader>op', desc = 'Toggle preview', buffer = 0 },
          { '<leader>oc', desc = 'Convert media file', buffer = 0 },
          { '<leader>od', desc = 'Drag file(s)', buffer = 0 },
          { '<leader>ot', desc = 'Tmux session here', buffer = 0 },
        }
      end,
    })

    -- Track directory changes in oil buffers
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'oil',
      callback = function()
        local oil = require('oil')
        local current_dir = oil.get_current_dir()

        -- If we have a valid directory, store it as last visited
        if current_dir and not current_dir:match('v:null') then
          vim.g.oil_last_dir = current_dir
        end

        -- If we're in an invalid buffer, navigate to a valid location
        if not current_dir or current_dir:match('v:null') then
          vim.defer_fn(function()
            local last_dir = vim.g.oil_last_dir or vim.fn.getcwd()
            oil.open(last_dir)
          end, 10)
        end
      end,
    })

    -- When the last real file buffer is closed, nvim drops you on an empty
    -- [No Name] scratch buffer. Replace that with oil at the cwd instead, so
    -- "no buffers open" always lands in the file explorer.
    vim.api.nvim_create_autocmd('BufDelete', {
      callback = function()
        -- Ephemeral file-picker / clipboard nvim instances manage their own
        -- buffers; don't hijack them with oil.
        if vim.g.filechooser_mode or vim.g.clipboard_picker then return end

        -- Defer so the buffer is fully gone (and the replacement [No Name]
        -- buffer exists) before we look at what we landed on. Dropped
        -- automatically if nvim is exiting, so this never fires during :qa.
        vim.schedule(function()
          -- Only step in when the user is actually stranded on the empty
          -- [No Name] scratch buffer (e.g. they :bd'd their last file). If the
          -- current buffer is anything real -- a file, a terminal opened via
          -- <leader>tn, or oil itself -- leave it alone. The old version scanned
          -- *all* buffers and reopened oil whenever no file buffer existed, which
          -- (a) clobbered a terminal the user had just switched to, and (b) since
          -- oil.open() deletes the previous oil buffer, re-fired this very
          -- BufDelete and spun open->delete->open in a tight loop.
          local cur = vim.api.nvim_get_current_buf()
          if vim.bo[cur].buftype ~= '' then return end             -- terminal / oil(acwrite) / help / etc.
          if vim.api.nvim_buf_get_name(cur) ~= '' then return end  -- a real, named file buffer
          require('oil').open(vim.fn.getcwd())
        end)
      end,
    })

    -- Open oil at startup when no file is specified
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        -- Skip for clipboard picker
        if vim.g.clipboard_picker then return end

        -- Filechooser mode - open oil at the specified directory
        if vim.g.filechooser_mode then
          local oil = require('oil')
          local start_dir = vim.g.filechooser_start_dir or vim.fn.getcwd()

          -- Global keymaps (ephemeral nvim instance)
          -- Using <Tab> because <S-CR> and <C-CR> don't work reliably:
          -- terminal escape sequences aren't recognized by nvim even with CSI u encoding
          vim.keymap.set({'n', 'v'}, '<Tab>', function()
            local current_dir = oil.get_current_dir()
            if not current_dir then return end

            local paths = {}

            local function want(entry)
              return entry and entry.name ~= '..'
                and (entry.type == 'file' or (entry.type == 'directory' and vim.g.filechooser_directory == 1))
            end

            if vim.g.filechooser_mode == 'save' then
              -- Save mode: always use current directory + suggested filename
              local save_name = vim.g.filechooser_save_filename or ''
              if save_name ~= '' then
                table.insert(paths, current_dir .. save_name)
              else
                table.insert(paths, current_dir)
              end
            else
              local m = vim.fn.mode()
              if m == 'v' or m == 'V' or m == '\22' then
                -- Visual selection: collect every selected entry (multi-select)
                local s, e = vim.fn.line('v'), vim.fn.line('.')
                if s > e then s, e = e, s end
                for lnum = s, e do
                  local entry = oil.get_entry_on_line(0, lnum)
                  if want(entry) then table.insert(paths, current_dir .. entry.name) end
                end
              else
                local entry = oil.get_cursor_entry()
                if want(entry) then table.insert(paths, current_dir .. entry.name) end
              end
            end

            if #paths == 0 then
              vim.notify('No file selected', vim.log.levels.WARN)
              return
            end

            local output_file = vim.g.filechooser_output
            if output_file and output_file ~= '' then
              local file = io.open(output_file, 'w')
              if file then
                for _, path in ipairs(paths) do
                  file:write(path .. '\n')
                end
                file:close()
              end
            end

            vim.cmd('qa!')
          end, { desc = 'Confirm selection' })

          vim.keymap.set('n', '<Esc>', function() vim.cmd('qa!') end, { desc = 'Cancel' })
          vim.keymap.set('n', 'q', function() vim.cmd('qa!') end, { desc = 'Cancel' })

          vim.defer_fn(function()
            oil.open(start_dir)
          end, 50)
          return
        end

        local arg = vim.fn.argv(0)
        -- Only open oil if no file argument was provided
        if arg == '' then
          require('oil').open(vim.fn.getcwd())
        end
      end,
    })


    -- Image extensions for preview
    local image_extensions = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif' }
    local function is_image(filename)
      local ext = filename:match('%.([^%.]+)$')
      if ext then
        ext = ext:lower()
        for _, img_ext in ipairs(image_extensions) do
          if ext == img_ext then return true end
        end
      end
      return false
    end

    -- Thumbnail cache (small pre-shrunk copies for the fast first pass)
    local thumb_dir = vim.fn.stdpath('cache') .. '/oil_thumbs'
    vim.fn.mkdir(thumb_dir, 'p')

    -- Track image preview state
    local image_preview_state = {
      image = nil,
      win = nil,
      buf = nil,
      last_file = nil,
      token = 0,        -- invalidation token; bumped whenever the target changes
      job = nil,        -- in-flight thumbnail generation job (vim.system handle)
      full_timer = nil, -- timer that upgrades to full resolution after settling
    }

    -- Cancel a pending full-res upgrade
    local function cancel_full_timer()
      if image_preview_state.full_timer then
        vim.fn.timer_stop(image_preview_state.full_timer)
        image_preview_state.full_timer = nil
      end
    end

    -- Kill any in-flight thumbnail job
    local function cancel_thumb_job()
      if image_preview_state.job then
        pcall(function() image_preview_state.job:kill('sigterm') end)
        image_preview_state.job = nil
      end
    end

    local function close_image_preview()
      -- Invalidate any in-flight async work so late callbacks no-op
      image_preview_state.token = image_preview_state.token + 1
      cancel_full_timer()
      cancel_thumb_job()
      if image_preview_state.image then
        pcall(function() image_preview_state.image:clear() end)
        image_preview_state.image = nil
      end
      if image_preview_state.win and vim.api.nvim_win_is_valid(image_preview_state.win) then
        vim.api.nvim_win_close(image_preview_state.win, true)
      end
      image_preview_state.win = nil
      if image_preview_state.buf and vim.api.nvim_buf_is_valid(image_preview_state.buf) then
        vim.api.nvim_buf_delete(image_preview_state.buf, { force = true })
      end
      image_preview_state.buf = nil
      image_preview_state.last_file = nil
    end

    -- Terminal cells are roughly twice as tall as they are wide; used to convert a
    -- pixel aspect ratio into a cell-based window height.
    local CELL_RATIO = 2.0

    -- Width of the preview box as a fraction of the editor. Bump toward 0.5 for a
    -- bigger preview, down toward 0.25 for a smaller one.
    local PREVIEW_WIDTH_FRAC = 1 / 2

    -- Real terminal cell aspect ratio (cell_height_px / cell_width_px). image.nvim
    -- measures the actual pixel size of a cell; using it (instead of assuming 2.0)
    -- makes the box hug the image so it fills the full box width. Falls back to 2.0.
    local function cell_ratio()
      local ok, term = pcall(require, 'image.utils.term')
      if ok then
        local sz = term.get_size and term.get_size()
        if sz and sz.cell_width and sz.cell_height
          and sz.cell_width > 0 and sz.cell_height > 0 then
          return sz.cell_height / sz.cell_width
        end
      end
      return CELL_RATIO
    end

    -- Resize the preview window so the image fills the box width with the height
    -- derived from its aspect ratio (auto height, no distortion). The float overlays
    -- a full-width oil buffer, so it is sized against the whole editor — NOT the (zero)
    -- space beside oil, which is what previously collapsed the box to the 20-col floor.
    local function fit_preview_to_image(img)
      local st = image_preview_state
      local win = st.win
      if not (win and vim.api.nvim_win_is_valid(win)) then return end
      local iw = img and img.image_width
      local ih = img and img.image_height
      if not (iw and ih and iw > 0 and ih > 0) then return end

      local max_width = math.max(20, vim.o.columns - 2)
      local max_height = math.max(5, vim.o.lines - 4)
      local aspect = ih / iw -- image height/width in pixels
      local ratio = cell_ratio() -- real cell_height/cell_width for this terminal

      -- Target width = the chosen fraction of the editor; the image fills it and the
      -- height follows from the aspect ratio (ratio converts the px ratio -> cells).
      local width = math.min(max_width, math.max(20, math.floor(vim.o.columns * PREVIEW_WIDTH_FRAC)))
      local height = math.floor(width * aspect / ratio + 0.5)
      -- Portrait too tall for the screen: cap the height and shrink width to keep ratio.
      if height > max_height then
        height = max_height
        width = math.max(20, math.min(max_width, math.floor(height / aspect * ratio + 0.5)))
      end
      height = math.max(1, math.min(height, max_height))

      -- Right-align so the oil listing stays visible on the left.
      local col = math.max(0, vim.o.columns - width - 2)
      pcall(vim.api.nvim_win_set_config, win, {
        relative = 'editor', width = width, height = height, col = col, row = 1,
      })
    end

    -- Render the given image file into the existing preview window.
    -- Bails out if the request was superseded (token mismatch) or the window is gone.
    local function render_into_preview(display_path, token)
      if token ~= image_preview_state.token then return end
      local win, buf = image_preview_state.win, image_preview_state.buf
      if not (win and vim.api.nvim_win_is_valid(win)) then return end
      if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
      -- Bail if the file vanished (e.g. deleted temp files). hijack_buffer throws on a
      -- missing path, and the resulting vim.schedule retries spin the event loop at 100% CPU.
      if not vim.loop.fs_stat(display_path) then
        close_image_preview()
        return
      end
      local ok, image_api = pcall(require, 'image')
      if not ok then return end
      -- Drop the previous image object before drawing the next one
      if image_preview_state.image then
        pcall(function() image_preview_state.image:clear() end)
        image_preview_state.image = nil
      end
      -- Wrap hijack_buffer: it can still throw (corrupt/unsupported file) even when the
      -- path exists; an uncaught error here is what froze the editor.
      -- Override image.nvim's defaults (max_height_window_percentage = 50), which
      -- otherwise cap the image to HALF the window height and make it render at ~half
      -- the box width. 100/100 lets the image fill the whole preview box.
      local ok_render, img = pcall(image_api.hijack_buffer, display_path, win, buf, {
        max_width_window_percentage = 100,
        max_height_window_percentage = 100,
      })
      if ok_render then
        image_preview_state.image = img
        -- Shrink/grow the window box to match the image's aspect ratio.
        fit_preview_to_image(img)
      else
        close_image_preview()
      end
    end

    local function open_image_preview(filepath)
      -- Skip if same file
      if image_preview_state.last_file == filepath then
        return
      end

      -- Close any existing oil (text) preview first
      local oil_util_ok, oil_util = pcall(require, 'oil.util')
      if oil_util_ok then
        local oil_preview_win = oil_util.get_preview_win()
        if oil_preview_win and vim.api.nvim_win_is_valid(oil_preview_win) then
          pcall(vim.api.nvim_win_close, oil_preview_win, true)
        end
      end

      -- Tear down the previous preview (also bumps token + kills its job)
      close_image_preview()

      -- Claim a fresh token for this request; async callbacks capture it
      image_preview_state.token = image_preview_state.token + 1
      local token = image_preview_state.token
      image_preview_state.last_file = filepath

      -- Create preview buffer
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })

      -- Initial size: the chosen fraction of the editor wide, full height. Right-aligned
      -- so the oil listing stays visible on the left. fit_preview_to_image then trims
      -- the height to the image's aspect ratio once its dimensions are known.
      local max_width = math.max(20, vim.o.columns - 2)
      local width = math.min(max_width, math.max(20, math.floor(vim.o.columns * PREVIEW_WIDTH_FRAC)))
      local height = math.max(10, vim.o.lines - 4)
      local col = math.max(0, vim.o.columns - width - 2)
      local row = 1

      -- Create the floating window immediately (cheap) so the box appears at once
      local win = vim.api.nvim_open_win(buf, false, {
        relative = 'editor',
        width = width,
        height = height,
        col = col,
        row = row,
        style = 'minimal',
        border = 'rounded',
        title = ' ' .. vim.fn.fnamemodify(filepath, ':t') .. ' ',
        title_pos = 'center',
      })

      image_preview_state.win = win
      image_preview_state.buf = buf

      -- Sensitive trees: NEVER write a plaintext thumbnail to ~/.cache (it would
      -- outlive the vault lock and leak the pixels). Skip the magick-thumb cache
      -- entirely and render the original directly -- image.nvim's own copy lives
      -- in /tmp (tmpfs/RAM), which dies with nvim and never hits disk. Both are
      -- gocryptfs mountpoints (plaintext only while unlocked):
      --   ~/vault     -- the personal nvim vault
      --   ~/workflow  -- the encrypted workflow store (mounted only while in use)
      local no_thumb_dirs = {
        vim.fn.expand('~/vault'),
        vim.fn.expand('~/workflow'),
      }
      for _, dir in ipairs(no_thumb_dirs) do
        if filepath:sub(1, #dir + 1) == dir .. '/' then
          vim.defer_fn(function() render_into_preview(filepath, token) end, 10)
          return
        end
      end

      -- Stage 2: after settling on this file, upgrade to the full-resolution image
      local function start_full_timer()
        cancel_full_timer()
        image_preview_state.full_timer = vim.fn.timer_start(500, function()
          image_preview_state.full_timer = nil
          vim.schedule(function() render_into_preview(filepath, token) end)
        end)
      end

      -- Cache key includes mtime (sec+nsec) AND size so a file that is still being
      -- written (e.g. a freshly generated image) never reuses a thumbnail made from a partial
      -- copy: any change to the source produces a different key, invalidating it.
      local stat = vim.loop.fs_stat(filepath)
      local sig = stat
        and (stat.mtime.sec .. '_' .. (stat.mtime.nsec or 0) .. '_' .. (stat.size or 0))
        or '0'
      local thumb = thumb_dir .. '/' .. filepath:gsub('[^%w]', '_') .. '_' .. sig .. '.png'

      if vim.loop.fs_stat(thumb) then
        -- Cached thumbnail exists: render it right away, then schedule the upgrade
        vim.defer_fn(function() render_into_preview(thumb, token) end, 10)
        start_full_timer()
        return
      end

      -- Stage 1: generate a small thumbnail asynchronously (non-blocking).
      -- magick reads frame [0] (first frame of gifs/animations) and strips metadata.
      -- Write to a PER-REQUEST temp file (unique by token) and atomically rename on
      -- success. The unique name keeps overlapping jobs (rapid cursor moves) from
      -- racing on one path, and the rename means a killed/aborted job never leaves a
      -- truncated PNG that later reads as a valid "cached" thumbnail.
      local thumb_tmp = thumb .. '.' .. token .. '.tmp'
      local ok_job, job = pcall(vim.system,
        { 'magick', filepath .. '[0]', '-thumbnail', '1000x1000', '-strip', thumb_tmp },
        { text = false },
        function(res)
          vim.schedule(function()
            if token ~= image_preview_state.token then -- moved away: cancel + clean up
              pcall(os.remove, thumb_tmp)
              return
            end
            image_preview_state.job = nil
            if res.code == 0 and vim.loop.fs_stat(thumb_tmp) then
              os.rename(thumb_tmp, thumb)
              render_into_preview(thumb, token)
            else
              -- magick failed/missing: drop the partial temp and render the original
              pcall(os.remove, thumb_tmp)
              render_into_preview(filepath, token)
            end
            start_full_timer()
          end)
        end
      )

      if ok_job then
        image_preview_state.job = job
      else
        -- vim.system unavailable / magick not found: render original directly
        vim.defer_fn(function() render_into_preview(filepath, token) end, 10)
      end
    end

    -- Debounce timer for preview
    local preview_timer = nil

    -- Preview is OFF by default; toggled per-buffer with <leader>op (see below).
    local preview_enabled = false

    -- Preview whatever file is under the cursor (image -> float, else oil's text preview).
    local function preview_current_entry()
      local oil = require('oil')
      local entry = oil.get_cursor_entry()
      if not entry or entry.type ~= 'file' then
        close_image_preview()
        return
      end

      local current_dir = oil.get_current_dir()
      if not current_dir then return end
      local filepath = current_dir .. entry.name

      if is_image(entry.name) then
        open_image_preview(filepath)
      else
        close_image_preview()
        oil.open_preview()
      end
    end

    -- Close any open preview (custom image float + oil's built-in text preview).
    local function close_all_previews()
      close_image_preview()
      local ok, oil_util = pcall(require, 'oil.util')
      if ok then
        local w = oil_util.get_preview_win()
        if w and vim.api.nvim_win_is_valid(w) then
          pcall(vim.api.nvim_win_close, w, true)
        end
      end
    end

    -- Auto-preview files when cursor moves in oil buffer (only while enabled)
    vim.api.nvim_create_autocmd('CursorMoved', {
      pattern = 'oil://*',
      callback = function()
        if not preview_enabled then return end
        -- Debounce rapid cursor movements
        if preview_timer then
          vim.fn.timer_stop(preview_timer)
        end

        preview_timer = vim.fn.timer_start(80, function()
          preview_timer = nil
          vim.schedule(preview_current_entry)
        end)
      end,
    })

    -- Clean up image preview when leaving oil buffer
    vim.api.nvim_create_autocmd('BufLeave', {
      pattern = 'oil://*',
      callback = close_image_preview,
    })

    -- File preview is OFF by default; <leader>op toggles it (buffer-local in oil).
    local function toggle_preview()
      preview_enabled = not preview_enabled
      if preview_enabled then
        preview_current_entry()
        vim.notify('Oil preview: on')
      else
        close_all_previews()
        vim.notify('Oil preview: off')
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'oil',
      callback = function()
        vim.keymap.set('n', '<leader>op', toggle_preview, { buffer = 0, desc = 'Toggle preview' })

        -- Buffer-local line-move maps WITHOUT the reindent (`==`/`=gv`) used by the
        -- global <A-j>/<A-k>. Reordering lines within an oil listing is a no-op on save
        -- (a directory has no intrinsic order), so this lets you shuffle scattered
        -- entries together, then visually select + cut them as one block. The reindent
        -- is dropped because `=` can prepend/strip leading whitespace and corrupt oil's
        -- line format (oil would read it as a rename).
        vim.keymap.set('n', '<A-j>', ':m .+1<CR>', { buffer = 0, silent = true, desc = 'Move entry down' })
        vim.keymap.set('n', '<A-k>', ':m .-2<CR>', { buffer = 0, silent = true, desc = 'Move entry up' })
        vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv", { buffer = 0, silent = true, desc = 'Move entries down' })
        vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv", { buffer = 0, silent = true, desc = 'Move entries up' })
      end,
    })
  end,
  keys = {
    { '-', function()
      local oil = require('oil')

      -- If we're in an oil buffer, use oil.open() to go to parent
      if vim.bo.filetype == 'oil' then
        oil.open()
      else
        -- Get the directory of the current file
        local current_file = vim.fn.expand('%:p:h')

        -- Check if we're in a terminal buffer or if the path is invalid
        if vim.bo.buftype == 'terminal' or current_file == '' or current_file:match('term://') then
          -- Use the last visited oil directory or current working directory
          local fallback_dir = vim.g.oil_last_dir or vim.fn.getcwd()
          oil.open(fallback_dir)
        else
          -- Open oil at the current file's directory
          oil.open(current_file)
        end
      end
    end, desc = 'Open file explorer', mode = 'n' },
    { '<C-\\>-', function()
      local oil = require('oil')
      local current_dir = oil.get_current_dir()

      -- If we're in an invalid oil buffer (like v:null), go to cwd or last visited directory
      if not current_dir or current_dir:match('v:null') then
        -- Try to get the last visited directory from global variable or use cwd
        local last_dir = vim.g.oil_last_dir or vim.fn.getcwd()
        oil.open(last_dir)
      else
        -- Store current directory as last visited
        vim.g.oil_last_dir = current_dir
        oil.open()
      end
    end, desc = 'Open parent directory', mode = 't' },
  },
  -- Optional dependencies
  dependencies = { { 'echasnovski/mini.icons', opts = {} } },
}
