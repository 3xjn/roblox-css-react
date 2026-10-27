--!strict
-- Parse browser selector strings into the CSS runtime's existing matcher IR.
-- Unsupported selector syntax raises explicitly instead of silently not matching.
local Selectors = require(script.Parent.Parent.Css.Selectors)
local Types = require(script.Parent.Parent.Css.Types)
type Token = Types.SelectorToken
local DomSelectors = {}
local function trim(value: string): string
	return value:match("^%s*(.-)%s*$") or value
end
local parseList: (string, number?) -> { Token }
local function balanced(source: string, start: number, open: string, close: string): (string, number)
	local depth, index, quote = 1, start + 1, nil :: string?
	while index <= #source do
		local character = source:sub(index, index)
		if character == "\\" then
			index += 2
			continue
		end
		if quote then
			if character == quote then
				quote = nil
			end
		elseif character == "'" or character == '"' then
			quote = character
		elseif character == open then
			depth += 1
		elseif character == close then
			depth -= 1
			if depth == 0 then
				return source:sub(start + 1, index - 1), index + 1
			end
		end
		index += 1
	end
	error("Unclosed selector group", 3)
end
local function attribute(source: string): Token
	local name, rest = source:match("^%s*([%w_%-]+)%s*(.-)%s*$")
	assert(name and rest, "Invalid selector attribute")
	if rest == "" then
		return { kind = "attribute", value = "", attribute = name }
	end
	local operator = rest:sub(1, 2)
	if operator ~= "~=" and operator ~= "|=" and operator ~= "^=" and operator ~= "$=" and operator ~= "*=" then
		operator = rest:sub(1, 1)
	end
	assert(operator == "=" or #operator == 2, "Invalid selector attribute operator")
	local raw = trim(rest:sub(#operator + 1))
	local value: string?, flag: string?
	local quote = raw:sub(1, 1)
	if quote == "'" or quote == '"' then
		local ending = 2
		while ending <= #raw and raw:sub(ending, ending) ~= quote do
			assert(raw:sub(ending, ending) ~= "\\", "Escaped selector attribute strings require a CSS syntax provider")
			ending += 1
		end
		assert(ending <= #raw, "Unclosed selector attribute value")
		value, flag = raw:sub(2, ending - 1), trim(raw:sub(ending + 1))
	else
		value, flag = raw:match("^([%w_%-]+)%s*([iIsS]?)$")
	end
	assert(
		value ~= nil and (flag == "" or flag == "i" or flag == "I" or flag == "s" or flag == "S"),
		"Invalid selector attribute value"
	)
	return {
		kind = "attribute",
		attribute = name,
		operator = operator,
		value = value :: string,
		insensitive = flag == "i" or flag == "I",
	}
end
parseList = function(source: string, depth: number?): { Token }
	assert((depth or 0) < 32 and #source <= 4096, "Selector syntax budget exceeded")
	local result: { Token } = {}
	local tokens: { Token } = {}
	local index = 1
	local function branch()
		assert(#tokens > 0, "Empty selector branch")
		table.insert(result, { kind = "selector", value = "", children = tokens })
		tokens = {}
	end
	while index <= #source do
		local character = source:sub(index, index)
		if character:match("%s") then
			repeat
				index += 1
			until index > #source or not source:sub(index, index):match("%s")
			local following = source:sub(index, index)
			if
				#tokens > 0
				and tokens[#tokens].kind ~= "combinator"
				and following ~= ""
				and following ~= ","
				and following ~= ">"
				and following ~= "+"
				and following ~= "~"
			then
				table.insert(tokens, { kind = "combinator", value = " " })
			end
		elseif character == "," then
			branch()
			index += 1
		elseif character == ">" or character == "+" or character == "~" then
			table.insert(tokens, { kind = "combinator", value = character })
			index += 1
		elseif character == "[" then
			local body
			body, index = balanced(source, index, "[", "]")
			table.insert(tokens, attribute(body))
		elseif character == "*" then
			table.insert(tokens, { kind = "universal", value = "*" })
			index += 1
		else
			local kind = if character == "."
				then "class"
				elseif character == "#" then "id"
				elseif character == ":" then "pseudo"
				else "tag"
			if kind ~= "tag" then
				index += 1
			end
			local name = source:sub(index):match("^[%w_%-]+")
			assert(name and name ~= "", "Unsupported selector token near " .. source:sub(index))
			index += #name
			local token: Token = {
				kind = kind,
				value = if kind == "pseudo" then ":" .. name:lower() elseif kind == "tag" then name:lower() else name,
			}
			if source:sub(index, index) == "(" then
				assert(kind == "pseudo", "Only pseudo classes accept selector arguments")
				local body
				body, index = balanced(source, index, "(", ")")
				if
					token.value == ":is"
					or token.value == ":where"
					or token.value == ":not"
					or token.value == ":has"
				then
					token.children = parseList(body, (depth or 0) + 1)
				elseif token.value:find(":nth%-") == 1 then
					local normalized = body:gsub("%s", ""):lower()
					local a: number?, b: number?
					if normalized == "odd" then
						a, b = 2, 1
					elseif normalized == "even" then
						a, b = 2, 0
					elseif normalized:find("n", 1, true) then
						local left, right = normalized:match("^([%+%-]?%d*)n([%+%-]?%d*)$")
						assert(left and right, "Unsupported nth selector expression")
						a = if left == "" or left == "+" then 1 elseif left == "-" then -1 else tonumber(left)
						b = if right == "" then 0 else tonumber(right)
					else
						a, b = 0, tonumber(normalized)
					end
					assert(a and b and a % 1 == 0 and b % 1 == 0, "Invalid nth selector expression")
					token.nth = { a = a, b = b }
				else
					error("Unsupported functional pseudo class " .. token.value, 2)
				end
			end
			table.insert(tokens, token)
		end
	end
	branch()
	return result
end
function DomSelectors.matches(source: string, node: Types.Node, scope: Types.Node?): boolean
	for _, branch in parseList(source) do
		local tokens = branch.children or {}
		local failure = Selectors.validate(tokens)
		assert(not failure, failure)
		if Selectors.matches(tokens, node, scope or node) then
			return true
		end
	end
	return false
end
return DomSelectors
