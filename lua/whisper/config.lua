local M = {}

M.defaults = {
	openrouter = {
		api_key = nil,
		base_url = "https://openrouter.ai/api/v1",
		model = "inception/mercury-coder",
		max_tokens = 50,
		temperature = 0.1,
	},

	completion = {
		debounce_ms = 75,
		trigger_chars = { " ", ".", "(", ")", "{", "}", "[", "]", ",", ";" },
		min_context_lines = 3,
		max_context_lines = 10,
		enabled_filetypes = { "lua", "python", "javascript", "typescript", "rust", "go", "java", "c", "cpp" },
	},

	ui = {
		virtual_text = {
			hl_group = "Comment",
			prefix = "  ",
		},
	},

	keymaps = {
		accept = "<Tab>",
		reject = "<Esc>",
		next_suggestion = "<C-]>",
		prev_suggestion = "<C-[>",
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

	if not M.options.openrouter.api_key then
		M.options.openrouter.api_key = vim.env.OPENROUTER_API_KEY
	end

	if not M.options.openrouter.api_key then
		vim.notify(
			"whisper.nvim: OpenRouter API key not provided. Set it in your config or OPENROUTER_API_KEY env var.",
			vim.log.levels.WARN
		)
	end

	return M.options
end

function M.get()
	return M.options
end

return M
