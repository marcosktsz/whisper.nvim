local config = require("whisper.config")
local prompts = require("whisper.prompts")

local M = {}

local has_plenary, plenary = pcall(require, "plenary.curl")
if not has_plenary then
	error("whisper.nvim requires plenary.nvim. Please install it.")
end

local function create_completion_request(context_before, context_after, file_type)
	local opts = config.get()

	local system_prompt = prompts.create_system_prompt()
	local few_shots = prompts.create_few_shot_examples()
	local user_input = prompts.create_user_input(context_before, context_after, file_type)

	local messages = {
		{
			role = "system",
			content = system_prompt,
		},
	}

	for _, example in ipairs(few_shots) do
		table.insert(messages, example)
	end

	table.insert(messages, {
		role = "user",
		content = user_input,
	})

	return {
		model = opts.openrouter.model,
		messages = messages,
		max_tokens = opts.openrouter.max_tokens,
		temperature = opts.openrouter.temperature,
		stream = false,
	}
end

function M.get_completion(context_before, context_after, file_type, callback)
	local opts = config.get()

	if not opts.openrouter.api_key then
		callback(nil, "OpenRouter API key not configured")
		return
	end

	local payload = create_completion_request(context_before, context_after, file_type)
	local url = opts.openrouter.base_url .. "/chat/completions"

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
				local content = data.choices[1].message.content
				local completions = prompts.parse_completion_response(content)

				if #completions > 0 then
						local filtered_completion = prompts.filter_completion_text(completions[1], context_before, context_after)
					if filtered_completion and filtered_completion ~= "" then
						callback(filtered_completion, nil)
					else
						callback(nil, "Completion was filtered out due to context overlap")
					end
				else
					callback(nil, "No valid completions found in response")
				end
			else
				callback(nil, "No completion found in response")
			end
		end,
		on_error = function(err)
			callback(nil, "Request failed: " .. tostring(err))
		end,
	})
end

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
			local result = "Connection successful"
			if completion and completion ~= "" then
				result = result .. ": " .. completion
			end
			callback(true, result)
		end
	end)
end

return M
