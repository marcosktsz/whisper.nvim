local config = require("whisper.config")

local M = {}

-- Store active completion state
M.completion_instance = nil
M.completion_ns = nil

-- Initialize namespace for virtual text
function M.init()
	M.completion_ns = vim.api.nvim_create_namespace("whisper_completion")
end

local function split_completion_text(text)
	local lines = vim.split(text, "\n", { plain = true })
	local first_line = lines[1] or ""
	local other_lines = {}

	for i = 2, #lines do
		table.insert(other_lines, { { lines[i], "Comment" } })
	end

	return {
		first_line = first_line,
		other_lines = other_lines,
	}
end

local function trim_start(str)
	return str:match("^%s*(.*)") or str
end

-- Clear any existing completion display
function M.clear_completion()
	if
		M.completion_instance
		and M.completion_instance.bufnr
		and vim.api.nvim_buf_is_valid(M.completion_instance.bufnr)
	then
		-- Clear all extmarks in our namespace
		vim.api.nvim_buf_clear_namespace(M.completion_instance.bufnr, M.completion_ns, 0, -1)
	end
	M.completion_instance = nil
end

-- Render completion as floating (at end of line)
local function render_floating(bufnr, line_before_cursor, processed_text)
	local opts = {
		id = 1,
		hl_mode = "combine",
		virt_text_pos = "eol",
	}

	if processed_text.first_line ~= "" then
		opts.virt_text = { { trim_start(line_before_cursor) .. processed_text.first_line, "Comment" } }
	end

	local current_line = vim.fn.line(".") - 1
	vim.api.nvim_buf_set_extmark(bufnr, M.completion_ns, current_line, 0, opts)
end

-- Render completion as standard (inline)
local function render_standard(bufnr, processed_text)
	local opts = {
		id = 1,
		hl_mode = "combine",
		virt_text_win_col = vim.fn.virtcol(".") - 1,
	}

	if processed_text.first_line ~= "" then
		opts.virt_text = { { processed_text.first_line, "Comment" } }
	end

	if #processed_text.other_lines > 0 then
		opts.virt_lines = processed_text.other_lines
	end

	local current_line = vim.fn.line(".") - 1
	local current_col = vim.fn.col(".") - 1
	vim.api.nvim_buf_set_extmark(bufnr, M.completion_ns, current_line, current_col, opts)
end

function M.show_completion(completion_text, line_before_cursor, line_after_cursor)
	if not completion_text or completion_text == "" then
		return
	end

	-- Use vim.schedule to avoid fast event context issues
	vim.schedule(function()
		-- Only show in insert mode
		local mode = vim.api.nvim_get_mode().mode
		if mode ~= "i" and mode ~= "ic" then
			return
		end

		M.clear_completion()

		local bufnr = vim.api.nvim_get_current_buf()
		local processed_text = split_completion_text(completion_text)

		-- Determine if we should render floating or standard
		-- Floating: when there's text after cursor and completion doesn't contain it
		local is_floating = (#line_after_cursor > 0)
			and (not processed_text.first_line:find(line_after_cursor, 1, true))

		if is_floating then
			render_floating(bufnr, line_before_cursor, processed_text)
		else
			render_standard(bufnr, processed_text)
		end

		-- Store completion instance
		M.completion_instance = {
			bufnr = bufnr,
			completion_text = completion_text,
			line_before_cursor = line_before_cursor,
			line_after_cursor = line_after_cursor,
			is_floating = is_floating,
		}
	end)
end

-- Accept the current completion
function M.accept_completion()
	if not M.completion_instance then
		return false
	end

	-- Use vim.schedule to avoid fast event context issues
	vim.schedule(function()
		local instance = M.completion_instance
		if not instance then
			return
		end

		local completion_text = instance.completion_text
		if not completion_text or completion_text == "" then
			return
		end

		-- Use LSP util for better text insertion (similar to Supermaven)
		local cursor = vim.api.nvim_win_get_cursor(0)
		local range = {
			start = {
				line = cursor[1] - 1,
				character = cursor[2],
			},
			["end"] = {
				line = cursor[1] - 1,
				character = cursor[2],
			},
		}

		-- Apply the text edit
		vim.lsp.util.apply_text_edits(
			{ { range = range, newText = completion_text } },
			vim.api.nvim_get_current_buf(),
			"utf-8"
		)

		-- Move cursor to end of completion
		local lines = vim.split(completion_text, "\n", { plain = true })
		local line_count = #lines - 1
		local last_line = lines[#lines] or ""
		local new_cursor_pos = { cursor[1] + line_count, cursor[2] + #last_line }
		vim.api.nvim_win_set_cursor(0, new_cursor_pos)

		M.clear_completion()
	end)
	return true
end

-- Check if there's an active completion
function M.has_completion()
	return M.completion_instance ~= nil
		and M.completion_instance.completion_text ~= nil
		and M.completion_instance.completion_text ~= ""
end

-- Get current completion text
function M.get_completion()
	return M.completion_instance and M.completion_instance.completion_text or nil
end

return M
