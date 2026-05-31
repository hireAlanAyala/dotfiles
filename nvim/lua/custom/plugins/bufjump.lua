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
        fn()
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
