return {
  "kwkarlwang/bufjump.nvim",
  lazy = false,
  config = function()
    require("bufjump").setup()

    -- Remember each buffer's cursor position when we leave it. bufjump walks the
    -- jumplist whose positions are stale (they record where the cursor was when
    -- a jump entry was added, not where you were when you left). We restore the
    -- last-leave position so <M-o>/<M-i> lands you where you actually were.
    vim.api.nvim_create_autocmd('BufLeave', {
      callback = function(args)
        -- The buffer being left can already be invalid here -- e.g. a floating
        -- preview window torn down mid-wipe fires BufLeave for a dead buffer.
        -- Writing a buffer-scoped var on it throws, so bail on an invalid id.
        if not vim.api.nvim_buf_is_valid(args.buf) then return end
        local ok, pos = pcall(vim.api.nvim_win_get_cursor, 0)
        if not ok then return end
        vim.b[args.buf].bufjump_last_pos = pos
        -- Remember whether we were on the last line, so terminals that grew
        -- while we were away can still snap to the live edge on return.
        local total = vim.api.nvim_buf_line_count(args.buf)
        vim.b[args.buf].bufjump_at_end = pos[1] >= total
      end,
    })

    local function with_restore(fn)
      return function()
        local prev_buf = vim.api.nvim_get_current_buf()
        fn()
        -- bufjump only moves when there's a different buffer to jump to. If the
        -- buffer didn't change we're at the end of the jumplist (e.g. already at
        -- the most "in" buffer) — do nothing, so we don't move the cursor within
        -- the current buffer.
        if vim.api.nvim_get_current_buf() == prev_buf then
          return
        end
        if vim.bo.buftype == 'terminal' and vim.b.bufjump_at_end then
          vim.cmd('normal! G')
        else
          local pos = vim.b.bufjump_last_pos
          if pos then pcall(vim.api.nvim_win_set_cursor, 0, pos) end
        end
      end
    end

    vim.keymap.set("n", "<M-o>", with_restore(require("bufjump").backward), { desc = "Jump to previous buffer" })
    vim.keymap.set("n", "<M-i>", with_restore(require("bufjump").forward), { desc = "Jump to next buffer" })
  end,
}
