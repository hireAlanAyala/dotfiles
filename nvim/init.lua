-- TODO: PACKAGES I MIGHT WANT LATER
-- vim-move
-- vim-autoread
-- noice
-- diffview
-- plugin wishlist
-- quick-scope (highlight f,F motion)
-- nvim-notify
-- noice (reokaces the UI for floating messages)
-- diffview (git diff)
-- flash
--
require 'config.options' -- Add this line

--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true

-- background transparent - apply after colorscheme loads
local function set_transparency()
  vim.cmd [[
    highlight Normal guibg=NONE ctermbg=NONE
    highlight NonText guibg=NONE ctermbg=NONE
    highlight SignColumn guibg=NONE ctermbg=NONE
    highlight NormalFloat guibg=NONE ctermbg=NONE
    highlight LineNr guibg=NONE ctermbg=NONE
    highlight CursorLineNr guibg=NONE ctermbg=NONE
    highlight FoldColumn guibg=NONE ctermbg=NONE
    highlight VertSplit guibg=NONE ctermbg=NONE
    highlight StatusLine guibg=NONE ctermbg=NONE
    highlight StatusLineNC guibg=NONE ctermbg=NONE
    highlight TabLine guibg=NONE ctermbg=NONE
    highlight TabLineFill guibg=NONE ctermbg=NONE
    highlight TabLineSel guibg=NONE ctermbg=NONE
    highlight Pmenu guibg=NONE ctermbg=NONE
    highlight PmenuSel guibg=NONE ctermbg=NONE
    highlight GitSignsAdd guibg=NONE ctermbg=NONE
    highlight GitSignsChange guibg=NONE ctermbg=NONE
    highlight GitSignsDelete guibg=NONE ctermbg=NONE
  ]]
end

-- Apply transparency now and after colorscheme changes
set_transparency()
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = set_transparency,
})

--  NOTE: For more options, you can see `:help option-list`

vim.o.shell = os.getenv 'HOME' .. '/.nix-profile/bin/zsh'
vim.env.PATH = vim.env.PATH .. ':' .. os.getenv 'HOME' .. '/.nix-profile/bin'
-- helps mason find the dotnet env
vim.env.DOTNET_ROOT = os.getenv 'HOME' .. '/.nix-profile'

vim.api.nvim_create_user_command('CheckMasonEnv', function()
  local mason_env = vim.fn.system 'env | grep DOTNET'
  vim.notify('Mason Environment:\n' .. mason_env)
end, {})

-- basic settings
vim.opt.number = false
vim.opt.relativenumber = true
vim.opt.showmode = false -- Don't show the mode, since it's already in the status line
vim.opt.wrap = true

-- indentation
vim.opt.breakindent = true -- Enable break indent
vim.opt.tabstop = 2 -- Tab width
vim.opt.shiftwidth = 2 -- Indent width
vim.opt.softtabstop = 2 -- Soft tab stop
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true -- Smart auto-indenting
vim.opt.autoindent = true -- Copy indent from current line

-- completion
vim.opt.updatetime = 250 -- Decrease update time
vim.opt.timeoutlen = 300 -- Decrease mapped sequence wait time, displays which-key popup sooner
vim.opt.ttimeoutlen = 50

-- visual settings
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes' -- Keep signcolumn on by default
vim.opt.list = true -- Sets how neovim will display certain whitespace characters in the editor
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.cursorline = true -- Show which line your cursor is on
-- vim.opt.scrolloff = 1000 -- Minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 10
vim.opt.showtabline = 0
vim.opt.inccommand = 'split' -- Preview substitutions live, as you type!
vim.opt.showmatch = true -- Highlight matching brackets
vim.opt.cmdheight = 1 -- Command line height
vim.opt.completeopt = 'menuone,noinsert,noselect' -- Completion options
vim.opt.showmode = false -- Don't show mode in command line
vim.opt.pumheight = 10 -- Popup menu height
vim.opt.pumblend = 10 -- Popup menu transparency
vim.opt.winblend = 0 -- Floating window transparency
vim.opt.conceallevel = 0 -- Don't hide markup
vim.opt.concealcursor = '' -- Don't hide cursor line markup
vim.opt.lazyredraw = true -- Don't redraw during macros
vim.opt.synmaxcol = 300 -- Syntax highlighting limit

-- search settings
vim.opt.ignorecase = true -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.smartcase = true
vim.opt.hlsearch = false -- disable highlight search
vim.opt.incsearch = true -- show matches as you type
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>') -- Clear highlights on search when pressing <Esc> in normal mode

-- window and tiling
vim.opt.splitright = true -- Configure how new splits should be opened
vim.opt.splitbelow = true

-- file handling
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand '~/.nvim/undodir'
vim.o.autoread = true
vim.o.autowrite = true

-- behaviour
vim.opt.hidden = true
vim.opt.errorbells = false
vim.opt.backspace = 'indent,eol,start'
vim.opt.autochdir = false
vim.opt.iskeyword:append '-'
vim.opt.path:append '**'
-- vim.opt.selection = 'exclusive'
vim.opt.mouse = 'a'

-- Folding settings
vim.opt.foldmethod = 'expr' -- Use expression for folding
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldlevel = 99 -- Start with all folds open

-- Disable treesitter folding for Neogit to prevent errors
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'NeogitStatus', 'NeogitCommit', 'NeogitPopup' },
  callback = function()
    vim.opt_local.foldmethod = 'manual'
  end,
})

-- Split behavior
vim.opt.splitbelow = true -- Horizontal splits go below
vim.opt.splitright = true -- Vertical splits go right

-- Command-line completion
vim.opt.wildmenu = true
vim.opt.wildmode = 'longest:full,full'
vim.opt.wildignore:append { '*.o', '*.obj', '*.pyc', '*.class', '*.jar' }

-- Better diff options
vim.opt.diffopt:append 'linematch:60'

-- Performance improvements
-- vim.opt.redrawtime = 10000
-- vim.opt.maxmempattern = 20000

-- Center screen when jumping
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search result (centered)' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous search result (centered)' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Half page down (centered)' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Half page up (centered)' })

-- Better window navigation
-- NOTE: currently handled by tmux + nvim plugin
-- vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
-- vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
-- vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
-- vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Splitting & Resizing
vim.keymap.set('n', '<leader>sv', ':vsplit<CR>', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>sh', ':split<CR>', { desc = 'Split window horizontally' })
vim.keymap.set('n', '<C-Up>', ':resize +2<CR>', { desc = 'Increase window height' })
vim.keymap.set('n', '<C-Down>', ':resize -2<CR>', { desc = 'Decrease window height' })
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', { desc = 'Decrease window width' })
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', { desc = 'Increase window width' })

-- Move lines up/down
vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Better indenting in visual mode
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left and reselect' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right and reselect' })

-- Quick file navigation
vim.keymap.set('n', '<leader>e', ':Explore<CR>', { desc = 'Open file explorer' })
vim.keymap.set('n', '<leader>ff', ':find ', { desc = 'Find file' })

-- Better J behavior
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })

local augroup = vim.api.nvim_create_augroup('UserConfig', {})

-- Return to last edit position when opening files
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Create directories when saving files
vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup,
  callback = function()
    local dir = vim.fn.expand '<afile>:p:h'
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
  end,
})

-- Create undo directory if it doesn't exist
local undodir = vim.fn.expand '~/.nvim/undodir'
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

vim.o.sessionoptions = vim.o.sessionoptions:gsub(',?options,?', '')
vim.g.session_directory = '~/.config/nvim/sessions/'

-- Auto session management for tmux resurrect
local function auto_session()
  local session_dir = vim.fn.expand '~/.config/nvim/sessions/'
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, 'p')
  end

  -- Get current tmux session name for session file
  local tmux_session = vim.fn.system('tmux display-message -p "#S"'):gsub('\n', '')
  if tmux_session == '' then
    tmux_session = 'default'
  end

  local session_file = session_dir .. tmux_session .. '.vim'

  -- Auto save session on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if vim.fn.argc() == 0 then -- Only save if no arguments passed
        vim.cmd('mksession! ' .. session_file)
      end
    end,
  })

  -- Auto restore session if no files opened
  if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then
    vim.defer_fn(function()
      vim.cmd('source ' .. session_file)
    end, 100)
  end
end

-- Only enable auto session in tmux
if vim.env.TMUX then
  auto_session()
end

-- Manual session save command
vim.api.nvim_create_user_command('SaveSession', function()
  local session_dir = vim.fn.expand '~/.config/nvim/sessions/'
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, 'p')
  end

  local tmux_session = vim.fn.system('tmux display-message -p "#S"'):gsub('\n', '')
  if tmux_session == '' then
    tmux_session = 'default'
  end

  local session_file = session_dir .. tmux_session .. '.vim'
  vim.cmd('mksession! ' .. session_file)
  print('Session saved: ' .. session_file)
end, {})

-- [[ Terminal ]]

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Function to copy buffer paths to clipboard
local function copy_path(type)
  local paths = {
    full = vim.fn.expand '%:p',
    relative = vim.fn.expand '%',
    filename = vim.fn.expand '%:t',
  }
  vim.fn.setreg('+', paths[type])
  print('Copied: ' .. paths[type])
end

-- Copy path keymaps
vim.keymap.set('n', '<leader>cp', function()
  copy_path 'full'
end, { desc = 'Copy full path' })
vim.keymap.set('n', '<leader>cr', function()
  copy_path 'relative'
end, { desc = 'Copy relative path' })
vim.keymap.set('n', '<leader>cf', function()
  copy_path 'filename'
end, { desc = 'Copy filename' })

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
-- vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- hide vim terminal mode status line
vim.o.showmode = false
vim.o.compatible = false

-- Terminal configuration
vim.api.nvim_create_autocmd('TermOpen', {
  pattern = '*',
  callback = function()
    -- Disable line numbers in terminal
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'

    -- Start in insert mode
    vim.cmd 'startinsert'

    -- Set terminal buffer options
    vim.opt_local.scrollback = 10000

    -- Make normal mode behave more like terminal mode
    -- This preserves the terminal's view of the scrollback
    vim.opt_local.scrolloff = 0
    vim.opt_local.sidescrolloff = 0

    -- Don't set modifiable = false as it can interfere with DAP debugging
  end,
})

-- vim.keymap.del('t', '<Tab>')

-- vim-tmux-navigator keymaps for seamless navigation between nvim and tmux panes
-- These work with the tmux vim-tmux-navigator plugin for unified navigation
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Navigate left (nvim/tmux)' })
vim.keymap.set('n', '<C-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Navigate right (nvim/tmux)' })
vim.keymap.set('n', '<C-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Navigate down (nvim/tmux)' })
vim.keymap.set('n', '<C-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Navigate up (nvim/tmux)' })

-- TODO: add permanent marks
-- TODO: on quit add a timestamped
-- TODO: unused code is too dark
-- TODO: remove :terminal status line for zsh status line

-- vim rooter but native: https://www.reddit.com/r/neovim/comments/zy5s0l/you_dont_need_vimrooter_usually_or_how_to_set_up/
-- -- Array of file names indicating root directory. Modify to your liking.
-- local root_names = { '.git', 'Makefile' }
--
-- -- Cache to use for speed up (at cost of possibly outdated results)
-- local root_cache = {}
--
-- local set_root = function()
--   -- Get directory path to start search from
--   local path = vim.api.nvim_buf_get_name(0)
--   if path == '' then return end
--   path = vim.fs.dirname(path)
--
--   -- Try cache and resort to searching upward for root directory
--   local root = root_cache[path]
--   if root == nil then
--     local root_file = vim.fs.find(root_names, { path = path, upward = true })[1]
--     if root_file == nil then return end
--     root = vim.fs.dirname(root_file)
--     root_cache[path] = root
--   end
--
--   -- Set current directory
--   vim.fn.chdir(root)
-- end
--
-- local root_augroup = vim.api.nvim_create_augroup('MyAutoRoot', {})
-- vim.api.nvim_create_autocmd('BufEnter', { group = root_augroup, callback = set_root })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  {
    'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
    config = function()
      -- Override Sleuth for F# files (force spaces)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'fsharp',
        callback = function()
          vim.bo.expandtab = true
          vim.bo.tabstop = 4
          vim.bo.shiftwidth = 4
          vim.bo.softtabstop = 4
        end,
      })
    end,
  },

  -- vim-tmux-navigator for seamless navigation between nvim and tmux panes
  {
    'christoomey/vim-tmux-navigator',
    lazy = false,
  },

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to force a plugin to be loaded.
  --
  --

  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`. This is equivalent to the following Lua:
  --    require('gitsigns').setup({ ... })
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '┃' },
        change = { text = '┃' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      signs_staged = {
        add = { text = '┃' },
        change = { text = '┃' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      signs_staged_enable = true,
      signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
      numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
      linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
      word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
      watch_gitdir = {
        follow_files = true,
      },
      auto_attach = true,
      attach_to_untracked = false,
      current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
        delay = 1000,
        ignore_whitespace = false,
        virt_text_priority = 100,
        use_focus = true,
      },
      current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
      sign_priority = 6,
      update_debounce = 100,
      status_formatter = nil, -- Use default
      max_file_length = 40000, -- Disable if file is longer than this (in lines)
      preview_config = {
        -- Options passed to nvim_open_win
        style = 'minimal',
        relative = 'cursor',
        row = 0,
        col = 1,
      },
      on_attach = function(bufnr)
        -- Remove background from gitsigns
        vim.cmd [[
          highlight GitSignsAdd guibg=NONE ctermbg=NONE
          highlight GitSignsChange guibg=NONE ctermbg=NONE
          highlight GitSignsDelete guibg=NONE ctermbg=NONE
          highlight GitSignsAddNr guibg=NONE ctermbg=NONE
          highlight GitSignsChangeNr guibg=NONE ctermbg=NONE
          highlight GitSignsDeleteNr guibg=NONE ctermbg=NONE
          highlight GitSignsAddLn guibg=NONE ctermbg=NONE
          highlight GitSignsChangeLn guibg=NONE ctermbg=NONE
          highlight GitSignsDeleteLn guibg=NONE ctermbg=NONE
          highlight GitSignsCurrentLineBlame guibg=NONE ctermbg=NONE
        ]]

        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Next [C]hange/hunk' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Previous [C]hange/hunk' })

        -- Actions
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = '[H]unk [S]tage' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = '[H]unk [R]eset' })

        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[H]unk [S]tage (visual)' })

        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[H]unk [R]eset (visual)' })

        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = '[H]unk [S]tage Buffer' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = '[H]unk [R]eset Buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = '[H]unk [P]review' })
        map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = '[H]unk Preview [I]nline' })

        map('n', '<leader>hb', function()
          gitsigns.blame_line { full = true }
        end, { desc = '[H]unk [B]lame Line' })

        map('n', '<leader>hd', gitsigns.diffthis, { desc = '[H]unk [D]iff This' })

        map('n', '<leader>hD', function()
          gitsigns.diffthis '~'
        end, { desc = '[H]unk [D]iff This (~)' })

        map('n', '<leader>hQ', function()
          gitsigns.setqflist 'all'
        end, { desc = '[H]unk [Q]uickfix List (all)' })
        map('n', '<leader>hq', gitsigns.setqflist, { desc = '[H]unk [Q]uickfix List' })

        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle [B]lame Line' })
        map('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = '[T]oggle [W]ord Diff' })

        -- Text object
        map({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { desc = '[I]nner [H]unk' })
      end,
    },
  },
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- optional - Diff integration

      -- Only one of these is needed.
      'nvim-telescope/telescope.nvim', -- optional
      'ibhagwan/fzf-lua', -- optional
      'echasnovski/mini.pick', -- optional
    },
    config = true,
  },
  {
    'sindrets/diffview.nvim',
  },
  {
    'max397574/better-escape.nvim',
    config = function()
      require('better_escape').setup()
    end,
  },
  {
    'stevearc/oil.nvim',
    event = { 'VimEnter */*,.*', 'BufNew */*,.*' }, -- had to disable in order for keys config to work
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
        width = 40,
        height = 20,
        border = 'rounded',
      },
      view_options = {
        show_hidden = true,
      },
    },
    keys = {
      { '-', '<CMD>Oil<CR>', desc = 'Open parent directory' },
    },
    -- Optional dependencies
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
  },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `config` key, the configuration only runs
  -- after the plugin has been loaded:
  --  config = function() ... end

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default whick-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>c', group = '[C]ode', mode = { 'n', 'x' } },
        { '<leader>d', group = '[D]ebug' },
        { '<leader>e', group = '[E]valuate' },
        { '<leader>n', group = '[N]avigate' },
        { '<leader>r', group = '[R]ename' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>w', group = '[W]orkspace' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },

      -- - <leader>f - Find/Files (telescope, fzf, file operations)
      -- - <leader>g - Git (git status, blame, diff, commits)
      -- - <leader>l - LSP/Language (code actions, diagnostics, formatting)
      -- - <leader>s - Search (grep, find and replace, symbols)
      -- - <leader>b - Buffers (buffer navigation, close, list)
      -- - <leader>w - Windows (window splits, resize, navigation)
      -- - <leader>t - Terminal/Tabs (terminal toggle, tab operations)
      -- - <leader>d - Debug/Diagnostics (DAP, error navigation)
      -- - <leader>c - Code (commenting, refactoring, snippets)
      -- - <leader>n - Navigation (file tree, jumps, marks)
      -- - <leader>r - Run/REPL (run tests, execute code)
      -- - <leader>h - Help/Hunk (help docs, git hunks)

      config = function(_, opts)
        -- Set up which-key with the provided opts
        local wk = require 'which-key'
        wk.setup(opts)

        -- Function to yank diagnostic messages
        local function yank_diagnostic()
          print 'yank_diagnostic'
          local diagnostics = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
          if #diagnostics == 0 then
            vim.notify('No diagnostics found at cursor position', vim.log.levels.WARN)
            return
          end

          -- Concatenate all diagnostic messages with newlines
          local messages = {}
          for _, diagnostic in ipairs(diagnostics) do
            table.insert(messages, diagnostic.message)
          end
          local message_text = table.concat(messages, '\n')

          -- Yank to system clipboard and default register
          vim.fn.setreg('+', message_text)
          vim.fn.setreg('"', message_text)

          vim.notify('Diagnostic message yanked to clipboard', vim.log.levels.INFO)
        end

        -- Register our yank diagnostic mapping
        wk.add {
          { 'yd', yank_diagnostic, desc = 'Yank diagnostic message', mode = 'n' },
        }
      end,
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      { 'nvim-telescope/telescope-live-grep-args.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      local builtin = require 'telescope.builtin'
      local actions = require 'telescope.actions'
      local action_state = require 'telescope.actions.state'

      local function remove_qf_item(prompt_bufnr)
        local selected_entry = action_state.get_selected_entry()

        if not selected_entry then
          print 'No entry selected!'
          return
        end

        -- Get the current quickfix list
        local qflist = vim.fn.getqflist()

        -- Remove the selected entry
        local new_qflist = {}
        for _, item in ipairs(qflist) do
          if item.lnum ~= selected_entry.lnum or item.bufnr ~= selected_entry.bufnr then
            table.insert(new_qflist, item)
          end
        end

        -- Update the quickfix list
        vim.fn.setqflist(new_qflist, 'r')

        -- Close the current Telescope prompt
        actions.close(prompt_bufnr)

        -- Reopen the Quickfix picker
        vim.defer_fn(function()
          require('telescope.builtin').quickfix()
        end, 50) -- Small delay to avoid flicker
      end

      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local conf = require('telescope.config').values

      -- our picker function: colors
      local colors = function(opts)
        opts = opts or {}
        pickers
          .new(opts, {
            prompt_title = 'colors',
            finder = finders.new_table {
              results = {
                { 'red', '#ff0000' },
                { 'green', '#00ff00' },
                { 'blue', '#0000ff' },
              },
              entry_maker = function(entry)
                return {
                  value = entry, -- best practice reference to the original entry, for later use
                  display = entry[1],
                  ordinal = entry[1],
                }
              end,
            },
            sorter = conf.generic_sorter(opts),
            -- prompt_bufnr represents the picker as it is a buffer in nvim
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                print(prompt_bufnr)
                -- returns a table hash
                -- this differs from the string passed in because internally it's packed into a table with multiple key:value pairs
                -- it's possible to get selection after closing the buffer
                local selection = action_state.get_selected_entry()
                print('selection', selection)
                -- inspect takes tables, functions, etc and turns them to strings for printing
                print('inspected selection', vim.inspect(selection))
                vim.api.nvim_put({ selection[1] }, '', false, true)
              end)

              return true
            end,
          })
          :find()
      end

      local function git_log_source_picker(opts)
        opts = opts or {}

        pickers
          .new(opts, {
            prompt_title = 'Git File Content Search (-S)',
            finder = finders.new_job(
              function(prompt)
                if not prompt or prompt == '' then
                  return nil
                end
                return { 'git', 'log', '-S', prompt, '--source', '--all', '--pretty=format:%h %ad %s', '--date=short' }
              end,
              nil, -- This should be `nil` because entry_maker will handle formatting
              {
                entry_maker = function(entry)
                  -- Split the log entry into commit hash, date, and message
                  local parts = vim.split(entry, ' ', { trimempty = true })

                  -- Ensure we have at least <commit_hash> <date> <message>
                  if #parts < 3 then
                    return nil
                  end

                  local commit_hash = parts[1]
                  local date = parts[2]
                  local message = table.concat(parts, ' ', 3) -- Preserve full commit message
                  local display = string.format('%-10s %-12s %s', commit_hash, date, message)

                  -- Debugging Output
                  print('display', display)

                  local result = {
                    value = commit_hash, -- The actual commit hash
                    display = display, -- How it looks in Telescope UI
                    ordinal = commit_hash .. ' ' .. date .. ' ' .. message, -- Used for searching
                    commit = commit_hash, -- Store the commit hash for selection
                  }

                  -- Debugging Output
                  print('result', vim.inspect(result))

                  return result
                end,
              }
            ),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_, map)
              map('i', '<CR>', function(prompt_bufnr)
                local selection = action_state.get_selected_entry()

                if not selection or not selection.commit then
                  print '⚠️ No valid commit selected!'
                  return
                end

                actions.close(prompt_bufnr)
                vim.cmd('Git show ' .. selection.commit) -- Open commit details
              end)
              return true
            end,
          })
          :find()
      end

      local previewers = require 'telescope.previewers'
      local utils = require 'telescope.utils'

      -- local function git_history_search(opts)
      --   opts = opts or {}
      --
      --   -- Prompt for the search term if not provided
      --   local search_term = opts.search_term or vim.fn.input 'Search git history for: '
      --   if search_term == '' then
      --     return
      --   end
      --
      --   -- Create the git command
      --   local git_cmd = {
      --     'git',
      --     'log',
      --     '-S',
      --     search_term,
      --     '--source',
      --     '--all',
      --     '--pretty=format:%h %ad %s',
      --     '--date=short',
      --   }
      --
      --   -- Create custom previewer that properly handles multiple preview requests
      --   local previewer = previewers.new_buffer_previewer {
      --     title = 'Git Commit Preview',
      --     get_buffer_by_name = function(_, entry)
      --       return entry.value
      --     end,
      --     define_preview = function(self, entry)
      --       local commit_hash = entry.value:match '^(%w+)'
      --
      --       -- Clear the buffer content
      --       vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
      --
      --       -- Run git show and handle the output
      --       local stdout, ret, stderr = utils.get_os_command_output {
      --         'git',
      --         'show',
      --         commit_hash,
      --       }
      --
      --       if ret == 0 then
      --         vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, stdout)
      --         -- Optional: Set filetype for syntax highlighting
      --         vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'git')
      --       else
      --         vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, stderr)
      --       end
      --     end,
      --   }
      --
      --   pickers
      --     .new(opts, {
      --       prompt_title = 'Git History Search: ' .. search_term,
      --       finder = finders.new_oneshot_job(git_cmd, opts),
      --       sorter = conf.generic_sorter(opts),
      --       previewer = previewer,
      --       attach_mappings = function(buffer_number)
      --         -- Add custom key mappings here
      --         actions.select_default:replace(function()
      --           local selection = action_state.get_selected_entry()
      --           local commit_hash = selection.value:match '^(%w+)'
      --
      --           -- Close telescope
      --           actions.close(buffer_number)
      --
      --           -- Open commit in a new split
      --           vim.cmd 'vsplit'
      --           vim.cmd('terminal git show ' .. commit_hash)
      --           vim.cmd 'startinsert'
      --         end)
      --
      --         return true
      --       end,
      --     })
      --     :find()
      -- end

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          mappings = {
            n = {
              ['n'] = 'move_selection_next',
              ['N'] = 'move_selection_previous',
            },
          },
          file_ignore_patterns = { 'node_modules' },
          vimgrep_arguments = {
            'rg',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--hidden',
            '--glob=!node_modules',
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            find_command = { 'rg', '--files', '--hidden', '--no-ignore', '--glob', '!node_modules' },
          },
          live_grep = {
            vimgrep_arguments = {
              'rg',
              '--color=never',
              '--no-heading',
              '--with-filename',
              '--line-number',
              '--column',
              '--smart-case',
              '--hidden',
              '--no-ignore',
              '--glob=!node_modules',
            },
          },
          buffers = {
            mappings = {
              n = {
                ['dd'] = 'delete_buffer',
              },
            },
          },
          quickfix = {
            mappings = {
              n = { ['d'] = remove_qf_item },
            },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
          live_grep_args = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- Override the default vimgrep_arguments to ensure compatibility
            vimgrep_arguments = {
              'rg',
              '--color=never',
              '--no-heading',
              '--with-filename',
              '--line-number',
              '--column',
              '--smart-case',
              '--hidden',
              '--glob=!node_modules',
            },
            -- define mappings, e.g.
            mappings = { -- extend mappings
              i = {
                ['<C-k>'] = function(prompt_bufnr)
                  require('telescope-live-grep-args.actions').quote_prompt()(prompt_bufnr)
                end,
                ['<C-i>'] = function(prompt_bufnr)
                  require('telescope-live-grep-args.actions').quote_prompt { postfix = ' --iglob ' }(prompt_bufnr)
                end,
                ['<C-t>'] = function(prompt_bufnr)
                  require('telescope-live-grep-args.actions').quote_prompt { postfix = ' -t ' }(prompt_bufnr)
                end,
              },
            },
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      pcall(require('telescope').load_extension, 'live_grep_args')

      -- See `:help telescope.builtin`
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', require('telescope').extensions.live_grep_args.live_grep_args, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
      -- vim.keymap.set('n', '<leader>gs', git_history_search, { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>gc', function()
        colors(require('telescope.themes').get_dropdown {})
      end)

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        require('telescope').extensions.live_grep_args.live_grep_args {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      },
    },
  },
  { 'Bilal2453/luvit-meta', lazy = true },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by nvim-cmp
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- Find references for the word under your cursor.
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('<leader>nds', require('telescope.builtin').lsp_document_symbols, '[N]avigate [D]ocument [S]ymbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('<leader>nws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[N]avigate [W]orkspace [S]ymbols')

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = true })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- pyright = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        ts_ls = {},

        -- Additional language servers
        nil_ls = {}, -- Nix
        gopls = {}, -- Go
        pyright = {}, -- Python
        rust_analyzer = {}, -- Rust
        clangd = {}, -- C/C++

        lua_ls = {
          -- cmd = {...},
          -- filetypes = { ...},
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
        fsautocomplete = {
          -- cmd = { vim.fn.stdpath 'data' .. '/mason/bin/fsautocomplete', '--adaptive-lsp-server-enabled' },
          cmd = { 'dotnet', 'fsautocomplete', '--adaptive-lsp-server-enabled' },
          -- cmd = {
          --   vim.fn.stdpath 'data' .. '/mason/bin/fsautocomplete',
          --   '--framework',
          --   'net9.0', -- Force usage of .NET 9.0 runtime
          -- },
          -- cmd_env = {
          --   DOTNET_ROOT = os.getenv 'HOME' .. '/.nix-profile', -- Ensure it points to the Nix environment
          --   PATH = vim.env.PATH .. ':' .. os.getenv 'HOME' .. '/.nix-profile/bin',
          --   DOTNET_MULTILEVEL_LOOKUP = '0', -- Prevents .NET from searching outside Nix environment
          -- },
          filetypes = { 'fsharp', 'fs', 'fsx', 'fsproj' }, -- Set the relevant file types
          root_dir = require('lspconfig.util').root_pattern('*.sln', '*.fsproj', '.git'), -- Detect the project root
          settings = {
            FSharp = {
              automaticWorkspaceInit = true, -- Automatically load context for scripts
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --  To check the current status of installed tools and/or manually install
      --  other tools, you can run
      --    :Mason
      --
      --  You can press `g?` for help in this menu.
      require('mason').setup()

      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      -- Remove "fsautocomplete" from the list
      ensure_installed = vim.tbl_filter(function(server)
        return server ~= 'fsautocomplete'
      end, ensure_installed)
      vim.list_extend(ensure_installed, {
        -- Formatters
        'stylua', -- Lua formatter

        -- Debuggers
        'js-debug-adapter', -- JavaScript/TypeScript debugging

        -- Tools that are NOT language servers (LSPs are automatically included from servers table)
        -- 'prettier', -- JavaScript/TypeScript formatter
        -- 'black', -- Python formatter
        -- 'eslint', -- JavaScript linter
        -- 'shellcheck', -- Shell script linter
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      print('mason bin: ', vim.fn.stdpath 'data' .. '/mason/bin/fantomas')

      require('mason-lspconfig').setup {
        automatic_installation = true,
        handlers = {
          function(server_name)
            if server_name == 'fsautocomplete' then
              return -- skip fsautocomplete, you set it up manually
            end

            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = {
      'mfussenegger/nvim-dap',
      'nvim-neotest/nvim-nio',
      'theHamsta/nvim-dap-virtual-text',
      -- no longer eneded
      -- {
      --   'folke/neodev.nvim',
      --   config = function()
      --     require('neodev').setup {
      --       library = { plugins = { 'nvim-dap-ui' }, types = true },
      --     }
      --   end,
      -- },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      dapui.setup {
        layouts = {
          {
            elements = {
              { id = 'scopes', size = 0.25 },
              { id = 'breakpoints', size = 0.25 },
              { id = 'stacks', size = 0.25 },
              { id = 'watches', size = 0.25 },
            },
            position = 'left',
            size = 40,
          },
          {
            elements = {
              { id = 'repl', size = 0.5 },
              { id = 'console', size = 0.5 },
            },
            position = 'bottom',
            size = 10,
          },
        },
      }

      -- Setup virtual text
      require('nvim-dap-virtual-text').setup()

      -- Debug control
      vim.keymap.set('n', '<leader>dc', dap.continue, { desc = 'Debug: Continue (or start)' })
      vim.keymap.set('n', '<leader>dr', dap.restart, { desc = 'Debug: Restart' })
      vim.keymap.set('n', '<leader>dq', dap.terminate, { desc = 'Debug: Quit' })

      -- Stepping (think: directions)
      vim.keymap.set('n', '<leader>dl', dap.step_over, { desc = 'Debug: Next line' })
      vim.keymap.set('n', '<leader>dj', dap.step_into, { desc = 'Debug: Into function' })
      vim.keymap.set('n', '<leader>dk', dap.step_out, { desc = 'Debug: Out of function' })
      vim.keymap.set('n', '<leader>dh', dap.step_back, { desc = 'Debug: Previous line' })

      -- Breakpoints & UI
      vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, { desc = 'Debug: Breakpoint' })
      vim.keymap.set('n', '<leader>dt', require('dapui').toggle, { desc = 'Debug: Toggle UI' })

      -- Evaluate expressions (both normal and visual mode)
      vim.keymap.set({ 'n', 'v' }, '<leader>de', function()
        -- INFO: this warning is ok, tj had it in his video
        require('dapui').eval(nil, { enter = true })
      end, { desc = 'Debug: Evaluate expression' })

      -- Event hooks
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- Language configs
      dap.adapters.coreclr = {
        type = 'executable',
        command = os.getenv 'HOME' .. '/.nix-profile/bin/netcoredbg',
        args = { '--interpreter=vscode' },
      }

      local dotnet_config = {
        {
          type = 'coreclr',
          name = 'Launch - netcoredbg',
          request = 'launch',
          program = function()
            local cwd = vim.fn.getcwd()
            local dlls = vim.fn.glob(cwd .. '/bin/Debug/**/*.dll', false, true)

            if #dlls == 0 then
              return vim.fn.input('No DLLs found. Enter path manually: ', cwd .. '/bin/Debug/', 'file')
            elseif #dlls == 1 then
              return dlls[1]
            else
              -- Use Neovim's UI selector (can be telescope, dressing.nvim, etc.)
              local co = coroutine.running()
              vim.ui.select(dlls, { prompt = 'Select DLL to debug' }, function(choice)
                coroutine.resume(co, choice)
              end)
              return coroutine.yield()
            end
          end,
        },
      }

      dap.configurations.cs = dotnet_config
      dap.configurations.fsharp = dotnet_config

      -- JavaScript/TypeScript debugging with js-debug-adapter
      dap.adapters['pwa-node'] = {
        type = 'server',
        host = 'localhost',
        port = '${port}',
        executable = {
          command = 'js-debug-adapter',
          args = { '${port}' },
        },
      }

      -- Chrome/Browser debugging
      dap.adapters['pwa-chrome'] = {
        type = 'server',
        host = 'localhost',
        port = '${port}',
        executable = {
          command = 'js-debug-adapter',
          args = { '${port}' },
        },
      }

      local js_config = {
        {
          name = 'Launch Node.js Program',
          type = 'pwa-node',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = '${workspaceFolder}',
          sourceMaps = true,
          resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
          console = 'integratedTerminal',
        },
        {
          name = 'Launch via npm',
          type = 'pwa-node',
          request = 'launch',
          cwd = '${workspaceFolder}',
          runtimeExecutable = 'npm',
          runtimeArgs = { 'run-script', 'debug' },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
          console = 'integratedTerminal',
        },
        {
          name = 'Attach to Process',
          type = 'pwa-node',
          request = 'attach',
          processId = function()
            return require('dap.utils').pick_process()
          end,
          cwd = '${workspaceFolder}',
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
        },
        {
          name = 'Debug Jest Tests',
          type = 'pwa-node',
          request = 'launch',
          cwd = '${workspaceFolder}',
          runtimeExecutable = 'node',
          runtimeArgs = { '--inspect-brk', 'node_modules/.bin/jest', '--runInBand' },
          console = 'integratedTerminal',
          internalConsoleOptions = 'neverOpen',
          resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
        },
        {
          name = 'Debug Current File',
          type = 'pwa-node',
          request = 'launch',
          program = '${file}',
          cwd = '${workspaceFolder}',
          sourceMaps = true,
          resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
          console = 'integratedTerminal',
        },
      }

      -- TypeScript-specific configuration
      local ts_config = {
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'Debug TypeScript',
          program = '${workspaceFolder}/src/server.ts',
          cwd = '${workspaceFolder}',
          runtimeArgs = { '-r', 'ts-node/register' },
          sourceMaps = true,
          outFiles = {
            '${workspaceFolder}/dist/**/*.js',
            '${workspaceFolder}/build/**/*.js',
            '${workspaceFolder}/out/**/*.js',
            '${workspaceFolder}/**/*.js',
          },
          resolveSourceMapLocations = {
            '${workspaceFolder}/**',
            '!**/node_modules/**',
          },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
          console = 'integratedTerminal',
        },
        {
          name = 'Debug Current TypeScript File',
          type = 'pwa-node',
          request = 'launch',
          program = '${file}',
          cwd = '${workspaceFolder}',
          runtimeArgs = { '-r', 'ts-node/register' },
          sourceMaps = true,
          outFiles = {
            '${workspaceFolder}/dist/**/*.js',
            '${workspaceFolder}/build/**/*.js',
            '${workspaceFolder}/out/**/*.js',
            '${workspaceFolder}/**/*.js',
          },
          resolveSourceMapLocations = {
            '${workspaceFolder}/**',
            '!**/node_modules/**',
          },
          skipFiles = { '<node_internals>/**', 'node_modules/**' },
          console = 'integratedTerminal',
        },
      }

      dap.configurations.javascript = js_config
      dap.configurations.typescript = ts_config
    end,
  },
  { 'Olical/conjure' },
  { 'ionide/Ionide-vim' },
  -- {
  --   'liquidz/vim-iced',
  --   ft = { 'clojure' },
  --   config = function()
  --     vim.g.iced_enable_default_key_mappings = true
  --   end,
  --   dependencies = {
  --     { 'guns/vim-sexp', ft = { 'clojure' } },
  --     {
  --       'ctrlpvim/ctrlp.vim',
  --       cond = vim.fn.executable 'ctrlp' == 1,
  --     },
  --   },
  -- },
  -- {
  --   "folke/flash.nvim",
  --   event = "VeryLazy",
  --   ---@type Flash.Config
  --   opts = {},
  --   -- stylua: ignore
  --   keys = {
  --     { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
  --     { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
  --     { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
  --     { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
  --     { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  --   },
  -- },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = {
        timeout_ms = 500,
        lsp_format = 'fallback',
      },
      formatters_by_ft = {
        lua = { 'stylua' },
        go = { 'gofmt' }, -- Uses system gofmt
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
        javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
        typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
        jsx = { 'prettierd', 'prettier', stop_after_first = true },
        tsx = { 'prettierd', 'prettier', stop_after_first = true },
        ts = { 'prettierd', 'prettier', stop_after_first = true },
        js = { 'prettierd', 'prettier', stop_after_first = true },
        fsharp = { 'fantomas' },
        fs = { 'fantomas' },
        fsx = { 'fantomas' },
        fsproj = { 'fantomas' },
      },
      formatters = {
        prettier = {
          append_args = { '--config', vim.fn.expand '~/.config/nvim/formatters/prettierrc' },
          env = {
            tab_widh = 1,
          },
          tabWidth = 2,
        },
        prettierd = {
          append_args = { '--config', vim.fn.expand '~/.config/nvim/formatters/.prettierrc.json' },
          env = {
            string.format('PRETTIERD_DEFAULT_CONFIG=%s', vim.fn.expand '~/.config/nvim/formatters/.prettierrc.json'),
          },
          tabWidth = 2,
        },
        fantomas = {
          command = vim.fn.stdpath 'data' .. '/mason/bin/fantomas', -- Use Mason's installed fantomas binary
          args = { '--indent-size', '4', '--no-newline-at-end' }, -- Example args, adjust as needed
          stdin = true, -- Pipe input directly from the buffer
        },
      },
    },
  },

  { -- Autocompletion
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',

    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
      },
      'saadparwaiz1/cmp_luasnip',

      -- Adds other completion capabilities.
      --  nvim-cmp does not ship with all sources by default. They are split
      --  into multiple repos for maintenance purposes.
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-buffer',
    },
    config = function()
      -- See `:help cmp`
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'
      luasnip.config.setup {}

      cmp.setup.filetype({ 'sql' }, {
        sources = {
          { name = 'vim-dadbod-completion' },
          { name = 'buffer' },
        },
      })

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = 'menu,menuone,noinsert' },

        -- For an understanding of why these mappings were
        -- chosen, you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        mapping = cmp.mapping.preset.insert {
          -- Select the [n]ext item
          ['<C-n>'] = cmp.mapping.select_next_item(),
          -- Select the [p]revious item
          ['<C-p>'] = cmp.mapping.select_prev_item(),

          -- Scroll the documentation window [b]ack / [f]orward
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),

          -- Accept ([y]es) the completion.
          --  This will auto-import if your LSP supports it.
          --  This will expand snippets if the LSP sent a snippet.
          ['<C-y>'] = cmp.mapping.confirm { select = true },

          -- If you prefer more traditional completion keymaps,
          -- you can uncomment the following lines
          --['<CR>'] = cmp.mapping.confirm { select = true },
          --['<Tab>'] = cmp.mapping.select_next_item(),
          --['<S-Tab>'] = cmp.mapping.select_prev_item(),

          -- Manually trigger a completion from nvim-cmp.
          --  Generally you don't need this, because nvim-cmp will display
          --  completions whenever it has completion options available.
          ['<C-Space>'] = cmp.mapping.complete {},

          -- Think of <c-l> as moving to the right of your snippet expansion.
          --  So if you have a snippet that's like:
          --  function $name($args)
          --    $body
          --  end
          --
          -- <c-l> will move you to the right of each of the expansion locations.
          -- <c-h> is similar, except moving you backwards.
          ['<C-l>'] = cmp.mapping(function()
            if luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            end
          end, { 'i', 's' }),
          ['<C-h>'] = cmp.mapping(function()
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            end
          end, { 'i', 's' }),

          -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
          --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
          --
        },
        sources = {
          -- WARNING: if you ever add a plugin with completion, you want to make sure you add it to sources #here
          -- https://github.com/hrsh7th/nvim-cmp/wiki/List-of-sources
          {
            name = 'lazydev',
            -- set group index to 0 to skip loading LuaLS completions as lazydev recommends it
            group_index = 0,
          },
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
          { name = 'fsautocomplete' },
        },
      }

      cmp.setup.cmdline(':', {
        sources = {
          { name = 'path' },
          { name = 'cmdline' },
        },
      })

      cmp.setup.cmdline('/', {
        sources = {
          { name = 'buffer' },
        },
      })

      local function is_specific_buffer()
        local name_of_buffer = 'term_input' -- Replace this with your buffer name
        return vim.api.nvim_buf_get_name(0):match(name_of_buffer) ~= nil
      end

      -- Create an autocommand for setting specific configuration for your buffer
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*',
        callback = function()
          if is_specific_buffer() then
            cmp.setup.buffer {
              sources = {
                { name = 'cmp-buffer' },
                { name = 'hrsh7th/cmp-path' },
                { name = 'hrsh7th/cmp-cmdline' },
              },
            }
          end
        end,
      })
    end,
  },
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', lazy = true },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true }, -- Optional
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },
  {
    'folke/ts-comments.nvim',
    opts = {},
    event = 'VeryLazy',
    enabled = vim.fn.has 'nvim-0.10.0' == 1,
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true,
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
  },
  {
    'windwp/nvim-ts-autotag',
    config = function()
      require('nvim-ts-autotag').setup {
        opts = {
          -- Defaults
          enable_close = true, -- Auto close tags
          enable_rename = true, -- Auto rename pairs of tags
          enable_close_on_slash = false, -- Auto close on trailing </
        },
      }
    end,
  },
  {
    'olrtg/nvim-emmet',
    config = function()
      -- Simple single-key expansion
      vim.keymap.set({ 'i', 'n' }, '<C-e>', function()
        require('nvim-emmet').expand_abbr()
      end, { desc = 'Emmet expand abbreviation' })
    end,
  },
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'
      vim.o.termguicolors = true

      -- You can configure highlights by doing something like:
      vim.cmd.hi 'Normal guibg=NONE ctermbg=NONE'
      vim.cmd.hi 'NonText guibg=NONE ctermbg=NONE'
      vim.cmd.hi 'Comment gui=none'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        'typescript',
        'javascript',
        'tsx',
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
      -- Add this for HTML in template strings
      injections = {
        enable = true,
      },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
  {
    'ThePrimeagen/vim-be-good',
  },
  {
    'mbbill/undotree',
  },
  -- INFO: don't need this because I can use the diagnostics quick fix key map from above
  -- {
  --   'rachartier/tiny-inline-diagnostic.nvim',
  --   event = 'VeryLazy', -- Or `LspAttach`
  --   config = function()
  --     require('tiny-inline-diagnostic').setup()
  --     vim.diagnostic.config { virtual_text = false }
  --   end,
  -- },
  -- {
  --   'rachartier/tiny-code-action.nvim',
  --   dependencies = {
  --     { 'nvim-lua/plenary.nvim' },
  --     { 'nvim-telescope/telescope.nvim' },
  --   },
  --   event = 'LspAttach',
  --   config = function()
  --     require('tiny-code-action').setup()
  --   end,
  -- },
  -- The following two comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  --    For additional information, see `:help lazy.nvim-lazy.nvim-structuring-your-plugins`
  -- { import = 'custom.plugins' },
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
