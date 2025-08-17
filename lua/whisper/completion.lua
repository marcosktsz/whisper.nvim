local config = require("whisper.config")
local http = require("whisper.http")
local ui = require("whisper.ui")

local M = {}

-- Debounce timer
M.debounce_timer = nil
M.last_request_id = 0

-- Get surrounding context for completion
local function get_context()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- Convert to 0-indexed
	local col = cursor[2]

	local opts = config.get()
	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	-- Calculate context range
	local start_line = math.max(0, row - opts.completion.min_context_lines)
	local end_line = math.min(total_lines - 1, row + opts.completion.min_context_lines)

	-- Get lines
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

	-- Get current line and cursor position within context
	local current_line_in_context = row - start_line + 1
	local current_line = lines[current_line_in_context] or ""

	-- Split current line at cursor
	local line_before_cursor = current_line:sub(1, col)
	local line_after_cursor = current_line:sub(col + 1)

	-- Build context with cursor marker
	local context_lines = {}
	for i, line in ipairs(lines) do
		if i == current_line_in_context then
			table.insert(context_lines, line_before_cursor .. "<CURSOR>" .. line_after_cursor)
		else
			table.insert(context_lines, line)
		end
	end

	return {
		context = table.concat(context_lines, "\n"),
		current_line = current_line,
		line_before_cursor = line_before_cursor,
		line_after_cursor = line_after_cursor,
		cursor_row = row,
		cursor_col = col,
	}
end

-- Check if completion should be triggered
local function should_trigger_completion()
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
	local opts = config.get()

	-- Check if filetype is enabled
	if not vim.tbl_contains(opts.completion.enabled_filetypes, filetype) then
		return false
	end

	-- Don't trigger in insert mode if we're not in insert mode
	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" then
		return false
	end

	return true
end

-- Request completion with debouncing
function M.request_completion()
	if not should_trigger_completion() then
		ui.clear_completion()
		return
	end

	-- Cancel previous timer
	if M.debounce_timer then
		M.debounce_timer:stop()
		M.debounce_timer = nil
	end

	local opts = config.get()

	-- Set up debounced request
	M.debounce_timer = vim.defer_fn(function()
		M.debounce_timer = nil
		M.last_request_id = M.last_request_id + 1
		local request_id = M.last_request_id

		local context_data = get_context()
		local filetype = vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "filetype")

		http.get_completion(context_data.context, context_data.line_before_cursor, filetype, function(completion, error)
			-- Only process if this is the latest request
			if request_id ~= M.last_request_id then
				return
			end

			if error then
				vim.notify("Whisper completion error: " .. error, vim.log.levels.ERROR)
				return
			end

			if completion and completion ~= "" then
				-- Display completion
				ui.show_completion(completion, context_data.cursor_row, context_data.cursor_col)
			end
		end)
	end, opts.completion.debounce_ms)
end

-- Cancel any pending completion
function M.cancel_completion()
	if M.debounce_timer then
		M.debounce_timer:stop()
		M.debounce_timer = nil
	end
	ui.clear_completion()
end

-- Accept current completion
function M.accept_completion()
	return ui.accept_completion()
end

-- Check if completion is available
function M.has_completion()
	return ui.has_completion()
end

return M

