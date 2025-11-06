local M = {}

M.config = {
  notes_dir = vim.fn.expand("~/documents/notes"),
  default_extension = ".md",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  vim.api.nvim_create_user_command("Note", function(args)
    if args.args ~= "" then
      -- If content provided, use old behavior
      require("custom.smart-notes.core").create_note(args.args)
    else
      -- Otherwise open popup
      require("custom.smart-notes.popup").open(M.config.notes_dir)
    end
  end, {
    nargs = "*",
    desc = "Create a new note with smart placement",
  })
  
  vim.api.nvim_create_user_command("QuickNote", function()
    local input = vim.fn.input("Note content: ")
    if input and input ~= "" then
      require("custom.smart-notes.core").create_note(input)
    end
  end, {
    desc = "Quick note with inline input",
  })
  
  vim.keymap.set("n", "<leader>nn", function()
    require("custom.smart-notes.popup").open(M.config.notes_dir)
  end, { desc = "New note (popup)" })
  
  vim.keymap.set("n", "<leader>nq", "<cmd>QuickNote<cr>", { desc = "Quick note" })
end

return M