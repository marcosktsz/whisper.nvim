local config = require("whisper.config")
local http = require("whisper.http")
local ui = require("whisper.ui")

local M = {}

M.debounce_timer = nil
M.last_request_id = 0

local function get_context()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]

	local opts = config.get()
	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	local start_line = math.max(0, row - opts.completion.min_context_lines)
	local end_line = math.min(total_lines - 1, row + opts.completion.min_context_lines)

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

	local current_line_in_context = row - start_line + 1
	local current_line = lines[current_line_in_context] or ""

	local line_before_cursor = current_line:sub(1, col)
	local line_after_cursor = current_line:sub(col + 1)

	local context_before_lines = {}
	for i = 1, current_line_in_context - 1 do
		table.insert(context_before_lines, lines[i])
	end
	table.insert(context_before_lines, line_before_cursor)
	local context_before = table.concat(context_before_lines, "\n")

	local context_after_lines = { line_after_cursor }
	for i = current_line_in_context + 1, #lines do
		table.insert(context_after_lines, lines[i])
	end
	local context_after = table.concat(context_after_lines, "\n")

	return {
		context_before = context_before,
		context_after = context_after,
		current_line = current_line,
		line_before_cursor = line_before_cursor,
		line_after_cursor = line_after_cursor,
		cursor_row = row,
		cursor_col = col,
	}
end

local function should_trigger_completion()
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
	local opts = config.get()

	if not vim.tbl_contains(opts.completion.enabled_filetypes, filetype) then
		return false
	end

	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" then
		return false
	end

	return true
end

function M.request_completion()
	if M.debounce_timer then
		M.debounce_timer:stop()
		M.debounce_timer = nil
	end

	local opts = config.get()

	M.debounce_timer = vim.defer_fn(function()
		M.debounce_timer = nil

		vim.schedule(function()
			if not should_trigger_completion() then
				ui.clear_completion()
				return
			end

			M.last_request_id = M.last_request_id + 1
			local request_id = M.last_request_id

			local context_data = get_context()
			local filetype = vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "filetype")

			http.get_completion(
				context_data.context_before,
				context_data.context_after,
				filetype,
				function(completion, error)
					if request_id ~= M.last_request_id then
						return
					end

					if error then
						vim.notify("Whisper completion error: " .. error, vim.log.levels.ERROR)
						return
					end

					if completion and completion ~= "" then
						ui.show_completion(completion, context_data.line_before_cursor, context_data.line_after_cursor)
					end
				end
			)
		end)
	end, opts.completion.debounce_ms)
end

function M.cancel_completion()
	if M.debounce_timer then
		M.debounce_timer:stop()
		M.debounce_timer = nil
	end
	ui.clear_completion()
end

function M.accept_completion()
	return ui.accept_completion()
end

function M.has_completion()
	return ui.has_completion()
end

return M
