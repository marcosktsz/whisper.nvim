local config = require("whisper.config")

local M = {}

-- Store active completion state
M.current_completion = nil
M.completion_bufnr = nil
M.completion_ns = nil
M.extmark_id = nil

-- Initialize namespace for virtual text
function M.init()
  M.completion_ns = vim.api.nvim_create_namespace("whisper_completion")
end

-- Clear any existing completion display
function M.clear_completion()
  if M.extmark_id and M.completion_bufnr and vim.api.nvim_buf_is_valid(M.completion_bufnr) then
    vim.api.nvim_buf_del_extmark(M.completion_bufnr, M.completion_ns, M.extmark_id)
  end
  M.current_completion = nil
  M.completion_bufnr = nil
  M.extmark_id = nil
end

-- Display completion as virtual text
function M.show_completion(completion_text, row, col)
  if not completion_text or completion_text == "" then
    return
  end
  
  M.clear_completion()
  
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = config.get()
  
  -- Store completion state
  M.current_completion = completion_text
  M.completion_bufnr = bufnr
  
  -- Create virtual text
  local virt_text = {
    { opts.ui.virtual_text.prefix .. completion_text, opts.ui.virtual_text.hl_group }
  }
  
  -- Set extmark with virtual text
  M.extmark_id = vim.api.nvim_buf_set_extmark(bufnr, M.completion_ns, row, col, {
    virt_text = virt_text,
    virt_text_pos = "eol", -- Display at end of line
    hl_mode = "combine",
  })
end

-- Accept the current completion
function M.accept_completion()
  if not M.current_completion then
    return false
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2] -- Convert to 0-indexed
  
  -- Insert the completion text at cursor position
  vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { M.current_completion })
  
  -- Move cursor to end of inserted text
  local new_col = col + #M.current_completion
  vim.api.nvim_win_set_cursor(0, { row + 1, new_col })
  
  M.clear_completion()
  return true
end

-- Check if there's an active completion
function M.has_completion()
  return M.current_completion ~= nil
end

-- Get current completion text
function M.get_completion()
  return M.current_completion
end

return M