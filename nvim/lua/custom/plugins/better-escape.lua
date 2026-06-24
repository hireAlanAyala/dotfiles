return {
  'max397574/better-escape.nvim',
  config = function()
    local uv = vim.uv or vim.loop

    -- Track the start of the current run of consecutive `j`s. A held `j`
    -- (auto-repeat) keeps the same start time; a fresh `j` after any other key
    -- resets it. This lets the terminal `jk` distinguish a quick intentional
    -- escape (single `j` then `k`) from `j` held to scroll a TUI like visidata
    -- and then pressing `k` (navigation, which must NOT escape).
    local j_run_start = 0
    local prev_typed = nil
    vim.on_key(function(_, typed)
      if typed == 'j' then
        if prev_typed ~= 'j' then
          j_run_start = uv.now()
        end
      end
      if typed ~= '' then
        prev_typed = typed
      end
    end)

    -- If the `j` run lasted longer than this (ms) before `k`, treat it as held
    -- (scrolling) and pass `k` through to the terminal instead of escaping.
    -- A deliberate escape is a very quick `j`->`k`; bump this if yours is slower.
    local HELD_MS = 200

    require('better_escape').setup({
      default_mappings = false,
      mappings = {
        i = { j = { k = "<Esc>", j = "<Esc>" } },
        c = { j = { k = "<Esc>", j = "<Esc>" } },
        v = { j = { k = "<Esc>" } },
        s = { j = { k = "<Esc>" } },
        t = {
          j = {
            k = function()
              if uv.now() - j_run_start > HELD_MS then
                return "k" -- `j` was held (scrolling) -> send `k` to the terminal
              end
              return "<C-\\><C-n>" -- quick `j`->`k` -> leave terminal mode
            end,
          },
        },
      },
    })
  end,
}