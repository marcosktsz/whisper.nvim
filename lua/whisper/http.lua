local config = require("whisper.config")

local M = {}

-- Check if plenary is available
local has_plenary, plenary = pcall(require, "plenary.curl")
if not has_plenary then
	error("whisper.nvim requires plenary.nvim. Please install it.")
end

-- Create completion request payload
local function create_completion_request(context, cursor_line, file_type)
	local opts = config.get()

	local prompt = string.format(
		[[You are an AI coding assistant. Complete the code based on the context.

File type: %s
Context:
%s

Complete the current line after the cursor. Provide only the completion text, no explanations.]],
		file_type or "text",
		context
	)

	return {
		model = opts.openrouter.model,
		messages = {
			{
				role = "user",
				content = prompt,
			},
		},
		max_tokens = opts.openrouter.max_tokens,
		temperature = opts.openrouter.temperature,
		stream = false, -- Start with non-streaming for simplicity
	}
end

-- Make async request to OpenRouter
function M.get_completion(context, cursor_line, file_type, callback)
	local opts = config.get()

	if not opts.openrouter.api_key then
		callback(nil, "OpenRouter API key not configured")
		return
	end

	local payload = create_completion_request(context, cursor_line, file_type)
	local url = opts.openrouter.base_url .. "/chat/completions"

	-- Make async HTTP request using plenary
	plenary.post(url, {
		headers = {
			["Authorization"] = "Bearer " .. opts.openrouter.api_key,
			["Content-Type"] = "application/json",
			["HTTP-Referer"] = "https://github.com/whisper-nvim/whisper.nvim",
			["X-Title"] = "whisper.nvim",
		},
		body = vim.json.encode(payload),
		callback = function(response)
			if response.status ~= 200 then
				local error_msg = string.format("HTTP %d: %s", response.status, response.body or "Unknown error")
				callback(nil, error_msg)
				return
			end

			local ok, data = pcall(vim.json.decode, response.body)
			if not ok then
				callback(nil, "Failed to parse response JSON")
				return
			end

			if data.choices and data.choices[1] and data.choices[1].message then
				local completion = data.choices[1].message.content
				-- Clean up the completion
				completion = completion:gsub("^%s+", ""):gsub("%s+$", "")
				callback(completion, nil)
			else
				callback(nil, "No completion found in response")
			end
		end,
		on_error = function(err)
			callback(nil, "Request failed: " .. tostring(err))
		end,
	})
end

-- Test function for debugging
function M.test_connection(callback)
	local opts = config.get()

	if not opts.openrouter.api_key then
		callback(false, "API key not configured")
		return
	end

	M.get_completion("print('hello world')", "", "lua", function(completion, error)
		if error then
			callback(false, error)
		else
			callback(true, "Connection successful: " .. (completion or ""))
		end
	end)
end

return M
