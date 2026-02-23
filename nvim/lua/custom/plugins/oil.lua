return {
  'stevearc/oil.nvim',
  lazy = false,  -- Load oil immediately to ensure proper initialization
  ---@module 'oil'
  ---@type oil.SetupOpt
  opts = {
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
    },
    keymaps = {
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
  },
  config = function(_, opts)
    require('oil').setup(opts)

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

    -- Open oil at startup when no file is specified
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        -- Skip for clipboard picker
        if vim.g.clipboard_picker then return end

        -- Filechooser mode - open oil at the specified directory
        if vim.g.filechooser_mode then
          local oil = require('oil')
          local start_dir = vim.g.filechooser_start_dir or vim.fn.getcwd()
          local mode_text = vim.g.filechooser_mode == 'save' and 'SAVE' or
                           vim.g.filechooser_mode == 'directory' and 'DIRECTORY' or 'OPEN'

          -- Global keymaps (ephemeral nvim instance)
          -- Using <Tab> because <S-CR> and <C-CR> don't work reliably:
          -- terminal escape sequences aren't recognized by nvim even with CSI u encoding
          vim.keymap.set({'n', 'v'}, '<Tab>', function()
            local current_dir = oil.get_current_dir()
            if not current_dir then return end

            local paths = {}
            local entry = oil.get_cursor_entry()

            if vim.g.filechooser_mode == 'save' then
              -- Save mode: always use current directory + suggested filename
              local save_name = vim.g.filechooser_save_filename or ''
              if save_name ~= '' then
                table.insert(paths, current_dir .. save_name)
              else
                table.insert(paths, current_dir)
              end
            elseif entry and (entry.type == 'file' or (entry.type == 'directory' and vim.g.filechooser_directory == 1)) then
              table.insert(paths, current_dir .. entry.name)
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
            vim.notify('File Picker: ' .. mode_text .. ' | <Tab> confirm | <Esc> cancel')
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

    -- Track image preview state
    local image_preview_state = {
      image = nil,
      win = nil,
      buf = nil,
      last_file = nil,
    }

    local function close_image_preview()
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

    local function open_image_preview(filepath)
      -- Skip if same file
      if image_preview_state.last_file == filepath then
        return
      end

      local ok, image_api = pcall(require, 'image')
      if not ok then return end

      -- Close any existing oil preview first
      local oil_util_ok, oil_util = pcall(require, 'oil.util')
      if oil_util_ok then
        local oil_preview_win = oil_util.get_preview_win()
        if oil_preview_win and vim.api.nvim_win_is_valid(oil_preview_win) then
          pcall(vim.api.nvim_win_close, oil_preview_win, true)
        end
      end

      -- Close previous image preview
      close_image_preview()

      -- Get oil window dimensions for positioning
      local oil_win = vim.api.nvim_get_current_win()
      local oil_width = vim.api.nvim_win_get_width(oil_win)

      -- Create preview buffer
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })

      -- Calculate window size - maximize available space
      -- Leave space for oil buffer on the left
      local width = math.max(20, vim.o.columns - oil_width - 4)
      local height = math.max(10, vim.o.lines - 4)
      local col = math.min(oil_width + 2, vim.o.columns - width - 2)
      local row = 1

      -- Create floating window (not a preview window to avoid conflicts)
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
      image_preview_state.last_file = filepath

      -- Render image
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then
          image_preview_state.image = image_api.hijack_buffer(filepath, win, buf)
        end
      end, 10)
    end

    -- Debounce timer for preview
    local preview_timer = nil

    -- Auto-preview files when cursor moves in oil buffer
    vim.api.nvim_create_autocmd('CursorMoved', {
      pattern = 'oil://*',
      callback = function()
        -- Debounce rapid cursor movements
        if preview_timer then
          vim.fn.timer_stop(preview_timer)
        end

        preview_timer = vim.fn.timer_start(50, function()
          preview_timer = nil
          vim.schedule(function()
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
          end)
        end)
      end,
    })

    -- Clean up image preview when leaving oil buffer
    vim.api.nvim_create_autocmd('BufLeave', {
      pattern = 'oil://*',
      callback = close_image_preview,
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
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
}

