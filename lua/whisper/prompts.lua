local M = {}

function M.create_system_prompt()
	return [[You are an AI code completion engine. Provide contextually appropriate completions:

- Code completions in code context
- Comment/documentation text in comments
- String content in string literals
- Prose in markdown/documentation files

Input markers:

- `<contextAfterCursor>`: Context after cursor
- `<cursorPosition>`: Current cursor location
- `<contextBeforeCursor>`: Context before cursor

Note that the user input will be provided in **reverse** order: first the context after cursor, followed by the context before cursor.

Guidelines:

1. Offer completions after the `<cursorPosition>` marker.
2. Make sure you have maintained the user's existing whitespace and indentation. This is REALLY IMPORTANT!
3. Provide multiple completion options when possible.
4. Return completions separated by the marker `<endCompletion>`.
5. The returned message will be further parsed and processed. DO NOT include additional comments or markdown code block fences. Return the result directly.
6. Keep each completion option concise, limiting it to a single line or a few lines.
7. Create entirely new code completion that DO NOT REPEAT OR COPY any user's existing code around `<cursorPosition>`.
8. Provide at most 3 completion items.]]
end

function M.create_few_shot_examples()
	return {
		{
			role = "user",
			content = [[# language: lua
<contextAfterCursor>
	end
	return result
end

local processed_data = transform_data(raw_data, {
	uppercase = true,
	remove_spaces = false
})
<contextBeforeCursor>
function transform_data(data, options)
	local result = {}
	for i, item in ipairs(data) do
		<cursorPosition>]],
		},
		{
			role = "assistant",
			content = [[local processed = item
		if options.uppercase then
			processed = string.upper(processed)
		end
		if options.remove_spaces then
			processed = string.gsub(processed, "%s+", "")
		end
		table.insert(result, processed)
<endCompletion>
if type(item) == "string" then
			local processed = item
			if options.uppercase then
				processed = string.upper(processed)
			end
			if options.remove_spaces then
				processed = string.gsub(processed, "%s+", "")
			end
			table.insert(result, processed)
		else
			table.insert(result, item)
		end
<endCompletion>]],
		},
	}
end

function M.create_user_input(context_before, context_after, file_type)
	local indentation = ""
	if context_before then
		local last_line = context_before:match("[^\n]*$") or ""
		indentation = last_line:match("^%s*") or ""
	end

	return string.format(
		[[# language: %s
%s<contextAfterCursor>
%s
<contextBeforeCursor>
%s<cursorPosition>]],
		file_type or "text",
		indentation,
		context_after or "",
		context_before or ""
	)
end

local function find_longest_match(a, b)
	if type(a) ~= 'string' or type(b) ~= 'string' then
		return ''
	end

	local max_len = math.min(#a, #b)

	for len = max_len, 1, -1 do
		local suffix_a = string.sub(a, -len)
		local prefix_b = string.sub(b, 1, len)

		if suffix_a == prefix_b then
			return suffix_a
		end
	end

	return ''
end

function M.filter_completion_text(completion, context_before, context_after)
	if not completion or completion == "" then
		return completion
	end

	local filtered = completion

	if context_before and context_before ~= "" then
		local match = find_longest_match(context_before, filtered)
		if match and #match >= 1 then
			filtered = string.sub(filtered, #match + 1)
		end
	end

	if context_after and context_after ~= "" then
		local match = find_longest_match(filtered, context_after)
		if match and #match >= 1 then
			filtered = string.sub(filtered, 1, #filtered - #match)
		end
	end

	return filtered
end

function M.parse_completion_response(content)
	if not content then
		return {}
	end

	local completions = {}
	for completion in string.gmatch(content .. "<endCompletion>", "(.-)<endCompletion>") do
		completion = completion:gsub("^%s+", ""):gsub("%s+$", "")
		if completion ~= "" then
			table.insert(completions, completion)
		end
	end

	if #completions == 0 then
		local cleaned = content:gsub("^%s+", ""):gsub("%s+$", "")
		if cleaned ~= "" then
			table.insert(completions, cleaned)
		end
	end

	return completions
end

return M

