local config = require("whisper.config")
local completion = require("whisper.completion")
local ui = require("whisper.ui")
local http = require("whisper.http")

local M = {}

M.initialized = false
M.autocmds = {}

function M.setup(opts)
	if M.initialized then
		return
	end

	config.setup(opts)

	ui.init()

	M.setup_autocmds()

	M.setup_keybindings()

	M.initialized = true

	vim.notify("whisper.nvim initialized", vim.log.levels.INFO)
end

function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("WhisperCompletion", { clear = true })

	M.autocmds.text_changed = vim.api.nvim_create_autocmd({ "TextChangedI" }, {
		group = group,
		callback = function()
			completion.request_completion()
		end,
	})

	M.autocmds.cursor_moved = vim.api.nvim_create_autocmd({ "CursorMovedI" }, {
		group = group,
		callback = function()
			completion.request_completion()
		end,
	})

	M.autocmds.insert_leave = vim.api.nvim_create_autocmd({ "InsertLeave" }, {
		group = group,
		callback = function()
			completion.cancel_completion()
		end,
	})

	M.autocmds.buf_leave = vim.api.nvim_create_autocmd({ "BufLeave" }, {
		group = group,
		callback = function()
			completion.cancel_completion()
		end,
	})
end

function M.setup_keybindings()
	local opts = config.get()

	vim.keymap.set("i", opts.keymaps.accept, function()
		if completion.has_completion() then
			if completion.accept_completion() then
				return ""
			end
		end
		return opts.keymaps.accept
	end, { expr = true, silent = true, desc = "Accept whisper completion" })

	vim.keymap.set("i", opts.keymaps.reject, function()
		if completion.has_completion() then
			completion.cancel_completion()
			return "" -- Don't insert the key
		end
		return opts.keymaps.reject
	end, { expr = true, silent = true, desc = "Reject whisper completion" })
end

function M.complete()
	completion.request_completion()
end

function M.test_connection()
	http.test_connection(function(success, message)
		if success then
			vim.notify("whisper.nvim: " .. message, vim.log.levels.INFO)
		else
			vim.notify("whisper.nvim: Connection failed - " .. message, vim.log.levels.ERROR)
		end
	end)
end

function M.disable()
	completion.cancel_completion()

	for _, autocmd_id in pairs(M.autocmds) do
		vim.api.nvim_del_autocmd(autocmd_id)
	end
	M.autocmds = {}

	M.initialized = false
	vim.notify("whisper.nvim disabled", vim.log.levels.INFO)
end

function M.enable()
	if not M.initialized then
		vim.notify("whisper.nvim: Call setup() first", vim.log.levels.WARN)
		return
	end

	M.setup_autocmds()
	vim.notify("whisper.nvim enabled", vim.log.levels.INFO)
end

return M
