-- Custom user commands

vim.api.nvim_create_user_command('CheckMasonEnv', function()
  local mason_env = vim.fn.system 'env | grep DOTNET'
  vim.notify('Mason Environment:\n' .. mason_env)
end, {})

-- Image preview command using viu
vim.api.nvim_create_user_command('ImagePreview', function(opts)
  local file = opts.args ~= '' and opts.args or vim.fn.expand('%:p')
  if not file or file == '' then
    vim.notify('No file specified', vim.log.levels.ERROR)
    return
  end
  
  -- Check if file is an image
  local ext = file:match('%.([^%.]+)$')
  if not ext then
    vim.notify('File has no extension', vim.log.levels.ERROR)
    return
  end
  
  ext = ext:lower()
  local image_exts = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'tiff' }
  if not vim.tbl_contains(image_exts, ext) then
    vim.notify('Not an image file: ' .. file, vim.log.levels.ERROR)
    return
  end
  
  -- Open image in terminal with viu
  vim.cmd('split')
  vim.cmd('terminal viu "' .. file .. '"')
  vim.cmd('startinsert')
end, { nargs = '?', complete = 'file' })