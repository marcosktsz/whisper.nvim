-- whisper.nvim - AI completion plugin for Neovim
-- Main plugin entry point

if vim.g.loaded_whisper then
  return
end
vim.g.loaded_whisper = 1

-- Check for required dependencies
if not pcall(require, "plenary") then
  vim.notify("whisper.nvim requires plenary.nvim", vim.log.levels.ERROR)
  return
end

-- Create user commands
vim.api.nvim_create_user_command("WhisperComplete", function()
  require("whisper").complete()
end, { desc = "Manually trigger whisper completion" })

vim.api.nvim_create_user_command("WhisperTest", function()
  require("whisper").test_connection()
end, { desc = "Test connection to OpenRouter" })

vim.api.nvim_create_user_command("WhisperEnable", function()
  require("whisper").enable()
end, { desc = "Enable whisper completions" })

vim.api.nvim_create_user_command("WhisperDisable", function()
  require("whisper").disable()
end, { desc = "Disable whisper completions" })