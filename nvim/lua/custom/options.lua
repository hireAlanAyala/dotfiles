-- Shell and environment setup
vim.o.shell = os.getenv 'HOME' .. '/.nix-profile/bin/zsh'
vim.env.PATH = vim.env.PATH .. ':' .. os.getenv 'HOME' .. '/.nix-profile/bin'
-- helps mason find the dotnet env
vim.env.DOTNET_ROOT = os.getenv 'HOME' .. '/.nix-profile'

-- Basic settings
vim.opt.number = false
vim.opt.relativenumber = true
vim.opt.showmode = false -- Don't show the mode, since it's already in the status line
vim.opt.wrap = true
vim.opt.compatible = false

-- Indentation
vim.opt.breakindent = true -- Enable break indent
vim.opt.tabstop = 2 -- Tab width
vim.opt.shiftwidth = 2 -- Indent width
vim.opt.softtabstop = 2 -- Soft tab stop
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true -- Smart auto-indenting
vim.opt.autoindent = true -- Copy indent from current line

-- Completion
vim.opt.updatetime = 250 -- Decrease update time
vim.opt.timeoutlen = 300 -- Decrease mapped sequence wait time, displays which-key popup sooner
vim.opt.ttimeoutlen = 50

-- Visual settings
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

-- Search settings
vim.opt.ignorecase = true -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.smartcase = true
vim.opt.hlsearch = false -- disable highlight search
vim.opt.incsearch = true -- show matches as you type

-- Window and tiling
vim.opt.splitright = true -- Configure how new splits should be opened
vim.opt.splitbelow = true

-- File handling
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand '~/.nvim/undodir'
vim.o.autoread = true
vim.o.autowrite = true

-- Behaviour
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

-- Command-line completion
vim.opt.wildmenu = true
vim.opt.wildmode = 'longest:full,full'
vim.opt.wildignore:append { '*.o', '*.obj', '*.pyc', '*.class', '*.jar' }

-- Better diff options
vim.opt.diffopt:append 'linematch:60'

-- Performance improvements (commented out by default)
-- vim.opt.redrawtime = 10000
-- vim.opt.maxmempattern = 20000

-- Session options
vim.o.sessionoptions = vim.o.sessionoptions:gsub(',?options,?', '')
vim.g.session_directory = '~/.config/nvim/sessions/'

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- Create undo directory if it doesn't exist
local undodir = vim.fn.expand '~/.nvim/undodir'
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end

-- Override treesitter foldexpr to handle Neogit buffers
local original_foldexpr = vim.treesitter.foldexpr
vim.treesitter.foldexpr = function()
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return '0'
  end
  local ok, bufname = pcall(vim.api.nvim_buf_get_name, bufnr)
  if not ok then
    return '0'
  end
  local ok2, filetype = pcall(function()
    return vim.bo[bufnr].filetype
  end)
  if not ok2 then
    return '0'
  end
  if bufname:match 'Neogit' or filetype:match 'Neogit' then
    return '0'
  end
  return original_foldexpr()
end