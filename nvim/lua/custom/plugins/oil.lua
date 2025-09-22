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
      win_options = {
        winblend = 0,
      },
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
        }
      end,
    })

    -- Open oil at startup when no file is specified
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        local arg = vim.fn.argv(0)
        -- Only open oil if no file argument was provided
        if arg == '' then
          require('oil').open(vim.fn.getcwd())
        end
      end,
    })
  end,
  keys = {
    { '-', function() require('oil').open() end, desc = 'Open parent directory', mode = 'n' },
    { '<C-\\>-', function() require('oil').open() end, desc = 'Open parent directory', mode = 't' },
  },
  -- Optional dependencies
  dependencies = { { 'echasnovski/mini.icons', opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
}

