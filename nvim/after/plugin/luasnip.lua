local ls = require 'luasnip'

local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local l = require('luasnip.extras').lambda
local rep = require('luasnip.extras').rep
local p = require('luasnip.extras').partial
local m = require('luasnip.extras').match
local n = require('luasnip.extras').nonempty
local dl = require('luasnip.extras').dynamic_lambda
-- stands for format
local fmt = require('luasnip.extras.fmt').fmt
local fmta = require('luasnip.extras.fmt').fmta
local types = require 'luasnip.util.types'
local conds = require 'luasnip.extras.conditions'
local conds_expand = require 'luasnip.extras.conditions.expand'

ls.setup {
  history = true,
  -- Snippets aren't automatically removed if their text is deleted.
  -- `delete_check_events` determines on which events (:h events) a check for
  -- deleted snippets is performed.
  -- This can be especially useful when `history` is enabled.
  delete_check_events = 'TextChanged',
  update_events = 'TextChanged,TextChangedI',
  enable_autosnippets = true,
}

local all = {
  ls.parser.parse_snippet('expand', '-- tgus us wgat expanded'),
}

ls.add_snippets('all', all)

local lua = {
  ls.parser.parse_snippet('lf', 'local $1 = function($2)\n  $0\nend'),
  s('req', fmt("local {} = require('{}')", { i(1, 'default'), rep(1) })),
}

ls.add_snippets('lua', lua)

local js_filetypes = {
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
  'coffeescript',
  'jsx',
  'tsx',
  'svelte',
  'vue',
  'mjs',
  'cjs',
  'es6',
}

local js = {
  s('cl', fmt('console.log({}, "{}")', { i(1, 'test'), rep(1) })),
}

local allJs = function()
  local snippets = {}
  for _, extension in ipairs(js_filetypes) do
    snippets[extension] = js
  end
  return snippets
end

ls.add_snippets(nil, allJs())

-- -- source snippets
-- INFO: no need to reload vim, just hit the key binding to reload
vim.keymap.set('n', '<leader><leader>s', '<cmd>source ~/.config/nvim/after/plugin/luasnip.lua<CR>')
