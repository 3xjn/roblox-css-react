--!strict
-- A parsed ECMAScript regular-expression subset. A bounded backtracking VM
-- owns matching; Lua string patterns are never used to interpret regex syntax.
-- Unsupported syntax, Unicode folding and native string representations fail
-- explicitly. Each regex owns its program/state; there is no global cache.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Values = require(script.Parent.SourceValues)
local SourceType = require(script.Parent.SourceType)
local RegExp = {}
local stateKey = {}
local identities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local MAX_INSTRUCTIONS, MAX_STEPS, MAX_STACK = 10000, 1000000, 100000
local function fail(message: string): never error("UnsupportedRegExp: " .. message, 3) end
local function syntax(message: string): never error("SyntaxError: " .. message, 3) end
local function codes(text: string, unicode: boolean): ({ number }, { number })
	assert(utf8.len(text) ~= nil, "UnsupportedRegExp: input requires Unicode scalar strings")
	local result, offsets, offset = {}, { 0 }, 0
	for _, value in utf8.codes(text) do
		if value >= 0xD800 and value <= 0xDFFF then fail("lone UTF-16 input surrogates are not represented by native scalar strings") end
		if value > 0xFFFF and not unicode then
			local scalar = value - 0x10000
			table.insert(result, 0xD800 + math.floor(scalar / 0x400))
			offset += 1
			table.insert(offsets, offset)
			table.insert(result, 0xDC00 + scalar % 0x400)
			offset += 1
		else table.insert(result, value); offset += if value > 0xFFFF then 2 else 1 end
		table.insert(offsets, offset)
	end
	return result, offsets
end
local function slice(input: { number }, first: number, finish: number): string
	local parts, at = {}, first + 1
	while at <= finish do
		local value = input[at]
		if value >= 0xD800 and value <= 0xDBFF then
			local following = input[at + 1]
			if at + 1 > finish or following == nil or following < 0xDC00 or following > 0xDFFF then
				fail("match/capture contains a lone UTF-16 surrogate, unsupported by native scalar strings")
			end
			value = 0x10000 + (value - 0xD800) * 0x400 + following - 0xDC00
			at += 1
		elseif value >= 0xDC00 and value <= 0xDFFF then fail("match/capture begins with a lone UTF-16 surrogate") end
		table.insert(parts, utf8.char(value))
		at += 1
	end
	return table.concat(parts)
end
local function flagsOf(flags: string): any
	local result = {}
	for at = 1, #flags do
		local flag = flags:sub(at, at)
		if result[flag] then syntax("duplicate regular-expression flag " .. flag) end
		if flag == "v" then fail("Unicode set notation (v flag) is not implemented") end
		if not (flag == "d" or flag == "g" or flag == "i" or flag == "m" or flag == "s" or flag == "u" or flag == "y") then
			syntax("invalid regular-expression flag " .. flag)
		end
		result[flag] = true
	end
	return result
end
local function parse(pattern: string, flags: any): any
	local input = codes(pattern, flags.u == true)
	local at, captureCount, depth = 1, 0, 0
	local names: { [string]: number }, references: { any } = {}, {}
	local expression: () -> any
	local function current(): number? return input[at] end
	local function take(): number
		local value = current()
		if value == nil then syntax("unexpected end of pattern") end
		at += 1
		return value :: number
	end
	local function checked(value: number): any
		if flags.i and value > 127 then fail("case-insensitive non-ASCII pattern literals/ranges need a Unicode case-folding provider") end
		return { kind = "literal", value = value }
	end
	local function hex(count: number): number?
		local result = 0
		for offset = 0, count - 1 do
			local value = input[at + offset]
			local digit = if value == nil then nil elseif value >= 48 and value <= 57 then value - 48
				elseif value >= 65 and value <= 70 then value - 55 elseif value >= 97 and value <= 102 then value - 87 else nil
			if digit == nil then return nil end
			result = result * 16 + digit
		end
		at += count
		return result
	end
	local function escape(inClass: boolean): any
		local value = take()
		local name = utf8.char(value)
		if name == "d" or name == "D" or name == "w" or name == "W" or name == "s" or name == "S" then
			return { kind = "set", name = name:lower(), inverted = name ~= name:lower() }
		end
		if name == "b" then return if inClass then checked(8) else { kind = "boundary", inverted = false } end
		if name == "B" and not inClass then return { kind = "boundary", inverted = true } end
		local controls = { n = 10, r = 13, t = 9, v = 11, f = 12 }
		if controls[name] then return checked(controls[name]) end
		if name == "c" then
			local nextValue = current()
			if nextValue and (nextValue >= 65 and nextValue <= 90 or nextValue >= 97 and nextValue <= 122) then
				at += 1
				return checked(nextValue % 32)
			end
			fail("legacy/malformed control escapes are not implemented")
		end
		if name == "x" then
			local result = hex(2)
			if result ~= nil then return checked(result) end
			if flags.u then syntax("invalid hexadecimal escape") end
			return checked(value)
		end
		if name == "u" then
			if flags.u and current() == 123 then
				at += 1
				local start = at
				while current() and current() ~= 125 do at += 1 end
				local finish = at
				if take() ~= 125 or finish == start or finish - start > 6 then syntax("invalid Unicode code point escape") end
				local saved = at
				at = start
				local result = hex(finish - start)
				at = saved
				if result == nil or result > 0x10FFFF then syntax("invalid Unicode code point escape") end
				return checked(result :: number)
			end
			local result = hex(4)
			if result ~= nil then
				if flags.u and result >= 0xD800 and result <= 0xDBFF and current() == 92 and input[at + 1] == 117 then
					local saved = at
					at += 2
					local low = hex(4)
					if low and low >= 0xDC00 and low <= 0xDFFF then result = 0x10000 + (result - 0xD800) * 0x400 + low - 0xDC00
					else at = saved end
				end
				return checked(result)
			end
			if flags.u then syntax("invalid Unicode escape") end
			return checked(value)
		end
		if name == "0" then
			if current() and (current() :: number) >= 48 and (current() :: number) <= 57 then fail("legacy octal escapes are not implemented") end
			return checked(0)
		end
		if value >= 49 and value <= 57 then
			if inClass then fail("legacy numeric escapes in character classes are not implemented") end
			local number = value - 48
			while current() and (current() :: number) >= 48 and (current() :: number) <= 57 do number = number * 10 + take() - 48 end
			local reference = { kind = "reference", index = number }
			table.insert(references, reference)
			return reference
		end
		if name == "k" and current() == 60 and not inClass then
			at += 1
			local parts = {}
			while current() and current() ~= 62 do table.insert(parts, utf8.char(take())) end
			if take() ~= 62 then syntax("unterminated named backreference") end
			local reference = { kind = "reference", name = table.concat(parts) }
			table.insert(references, reference)
			return reference
		end
		if name == "p" or name == "P" then
			if not flags.u or current() ~= 123 then fail("Unicode property escapes require Unicode mode and braces") end
			at += 1
			local parts = {}
			while current() and current() ~= 125 do table.insert(parts, utf8.char(take())) end
			if take() ~= 125 or #parts == 0 then syntax("invalid Unicode property escape") end
			local prop = table.concat(parts)
			if prop ~= "Zs" and prop ~= "Cf" and prop ~= "White_Space" then
				fail("Unicode property escape " .. prop .. " is not implemented")
			end
			return { kind = "set", name = prop, inverted = name == "P" }
		end
		if flags.u and not (name == "^" or name == "$" or name == "\\" or name == "." or name == "*" or name == "+"
			or name == "?" or name == "(" or name == ")" or name == "[" or name == "]" or name == "{" or name == "}"
			or name == "|" or name == "/" or inClass and name == "-") then syntax("invalid identity escape in Unicode mode") end
		return checked(value)
	end
	local function characterClass(): any
		local inverted = current() == 94
		if inverted then at += 1 end
		local items = {}
		while current() ~= 93 do
			if current() == nil then syntax("unterminated character class") end
			local first = if take() == 92 then escape(true) else checked(input[at - 1])
			if current() == 45 and input[at + 1] ~= nil and input[at + 1] ~= 93 then
				at += 1
				local last = if take() == 92 then escape(true) else checked(input[at - 1])
				if first.kind ~= "literal" or last.kind ~= "literal" then fail("legacy class-escape range endpoints are not implemented") end
				if first.value > last.value then syntax("character class range is out of order") end
				table.insert(items, { kind = "range", first = first.value, last = last.value })
			else table.insert(items, first) end
		end
		at += 1
		return { kind = "class", items = items, inverted = inverted }
	end
	local function atom(): any
		local value = take()
		if value == 94 then return { kind = "start" } end
		if value == 36 then return { kind = "finish" } end
		if value == 46 then return { kind = "any" } end
		if value == 92 then return escape(false) end
		if value == 91 then return characterClass() end
		if value == 40 then
			depth += 1
			if depth > 128 then fail("pattern nesting exceeds the supported parser depth") end
			local mode, group, groupName = "group", nil :: number?, nil :: string?
			if current() == 63 then
				at += 1
				local marker = take()
				if marker == 58 then mode = "sequence"
				elseif marker == 61 then mode = "lookahead"
				elseif marker == 33 then mode = "negative"
				elseif marker == 60 then
					if current() == 61 or current() == 33 then fail("lookbehind assertions are not implemented") end
					local parts = {}
					while current() and current() ~= 62 do
						local code = take()
						if not (code >= 65 and code <= 90 or code >= 97 and code <= 122 or code == 95 or code == 36 or #parts > 0 and code >= 48 and code <= 57) then
							fail("capture names currently require ASCII identifier characters")
						end
						table.insert(parts, utf8.char(code))
					end
					if take() ~= 62 or #parts == 0 then syntax("invalid named capture") end
					groupName = table.concat(parts)
					if names[groupName] then fail("duplicate named captures across alternatives are not implemented") end
				else fail("inline modifiers, atomic groups and other group extensions are not implemented") end
			end
			if mode == "group" then
				captureCount += 1
				group = captureCount
				if groupName then names[groupName] = group end
			end
			local child = expression()
			if take() ~= 41 then syntax("unterminated capture group") end
			depth -= 1
			return if mode == "sequence" then child else { kind = mode, child = child, index = group }
		end
		if value == 41 then syntax("unmatched closing parenthesis") end
		if value == 42 or value == 43 or value == 63 then syntax("nothing to repeat") end
		if flags.u and (value == 123 or value == 125 or value == 93) then syntax("unescaped syntax character in Unicode mode") end
		return checked(value)
	end
	local function term(): any
		local child = atom()
		local minimum, maximum = nil :: number?, nil :: number?
		if current() == 42 then at += 1; minimum, maximum = 0, math.huge
		elseif current() == 43 then at += 1; minimum, maximum = 1, math.huge
		elseif current() == 63 then at += 1; minimum, maximum = 0, 1
		elseif current() == 123 then
			local saved = at
			at += 1
			local function digits(): number?
				local result, count = 0, 0
				while current() and (current() :: number) >= 48 and (current() :: number) <= 57 do
					result = result * 10 + take() - 48
					count += 1
				end
				return if count > 0 then result else nil
			end
			minimum = digits()
			maximum = minimum
			if current() == 44 and minimum ~= nil then at += 1; maximum = digits() or math.huge end
			if minimum == nil or current() ~= 125 then
				if flags.u then syntax("invalid quantifier") end
				at, minimum, maximum = saved, nil, nil
			else
				at += 1
				if (maximum :: number) < minimum then syntax("quantifier range is out of order") end
			end
		end
		if minimum == nil then return child end
		if child.kind == "start" or child.kind == "finish" or child.kind == "boundary" then syntax("assertion cannot be quantified") end
		if child.kind == "lookahead" or child.kind == "negative" then fail("legacy quantified lookahead assertions are not implemented") end
		local greedy = current() ~= 63
		if not greedy then at += 1 end
		return { kind = "repeat", child = child, minimum = minimum, maximum = maximum, greedy = greedy }
	end
	expression = function(): any
		local branches, sequence = {}, {}
		while current() and current() ~= 41 do
			if current() == 124 then
				at += 1
				table.insert(branches, { kind = "sequence", children = sequence })
				sequence = {}
			else table.insert(sequence, term()) end
		end
		table.insert(branches, { kind = "sequence", children = sequence })
		return if #branches == 1 then branches[1] else { kind = "choice", children = branches }
	end
	local ast = expression()
	if at <= #input then syntax("unmatched closing parenthesis") end
	for _, reference in references do
		if reference.name then reference.index = names[reference.name] end
		if reference.index == nil or reference.index > captureCount then fail("legacy numeric escapes or unresolved named backreferences are not implemented") end
	end
	return { ast = ast, captures = captureCount, names = names }
end
local function compile(ast: any): any
	local program, loopId = {}, 0
	local emit: (any) -> ()
	local function instruction(value: any): number
		if #program >= MAX_INSTRUCTIONS then fail("pattern exceeds the supported instruction budget") end
		table.insert(program, value)
		return #program
	end
	local function captureSlots(node: any, result: any)
		if node.kind == "group" then table.insert(result, node.index * 2); table.insert(result, node.index * 2 + 1) end
		if node.child then captureSlots(node.child, result) end
		for _, child in node.children or {} do captureSlots(child, result) end
	end
	emit = function(node: any)
		if node.kind == "sequence" then for _, child in node.children do emit(child) end
		elseif node.kind == "choice" then
			local exits = {}
			for at, child in node.children do
				if at < #node.children then
					local split = instruction({ op = "split", first = #program + 2 })
					emit(child)
					table.insert(exits, instruction({ op = "jump" }))
					program[split].second = #program + 1
				else emit(child) end
			end
			for _, exit in exits do program[exit].target = #program + 1 end
		elseif node.kind == "group" then
			instruction({ op = "save", slot = node.index * 2 })
			emit(node.child)
			instruction({ op = "save", slot = node.index * 2 + 1 })
		elseif node.kind == "repeat" then
			if node.minimum > MAX_INSTRUCTIONS or node.maximum ~= math.huge and node.maximum > MAX_INSTRUCTIONS then fail("quantifier exceeds the supported instruction budget") end
			local slots = {}
			captureSlots(node.child, slots)
			for _ = 1, node.minimum do instruction({ op = "clear", slots = slots }); emit(node.child) end
			local optional = if node.maximum == math.huge then 1 else node.maximum - node.minimum
			local exits = {}
			for _ = 1, optional do
				loopId += 1
				local mark = loopId
				local split = instruction({ op = "split" })
				local start = #program + 1
				instruction({ op = "mark", id = mark })
				instruction({ op = "clear", slots = slots })
				emit(node.child)
				instruction({ op = "progress", id = mark })
				if node.maximum == math.huge then instruction({ op = "jump", target = split }) end
				local finish = #program + 1
				program[split].first, program[split].second = if node.greedy then start else finish, if node.greedy then finish else start
				table.insert(exits, { pc = split, greedy = node.greedy })
			end
			-- Every optional iteration may exit the entire repeat, not merely
			-- skip to the next unrolled optional copy (important for captures).
			for _, exit in exits do program[exit.pc][if exit.greedy then "second" else "first"] = #program + 1 end
		elseif node.kind == "lookahead" or node.kind == "negative" then
			instruction({ op = "look", inverted = node.kind == "negative", program = compile(node.child) })
		else instruction({ op = node.kind, value = node.value, items = node.items, inverted = node.inverted, name = node.name, index = node.index }) end
	end
	emit(ast)
	instruction({ op = "match" })
	return program
end
local function line(value: number?): boolean return value == 10 or value == 13 or value == 0x2028 or value == 0x2029 end
local function space(value: number): boolean
	return value >= 9 and value <= 13 or value == 32 or value == 160 or value == 5760
		or value >= 8192 and value <= 8202 or value == 8232 or value == 8233 or value == 8239
		or value == 8287 or value == 12288 or value == 65279
end
local function folded(value: number, flags: any): number
	if not flags.i then return value end
	if value >= 97 and value <= 122 then return value - 32 end
	if flags.u and value == 0x17F then return 83 end
	if flags.u and value == 0x212A then return 75 end
	return value
end
local function word(value: number?, flags: any): boolean
	if value == nil then return false end
	local code = folded(value, flags)
	return code >= 65 and code <= 90 or code >= 97 and code <= 122 or code >= 48 and code <= 57 or code == 95
end
local function itemMatches(item: any, value: number, flags: any): boolean
	if item.kind == "set" then
		local found = if item.name == "d" then value >= 48 and value <= 57
			elseif item.name == "s" or item.name == "White_Space" then space(value)
			elseif item.name == "Zs" then value == 32 or value == 160 or value == 5760 or value >= 8192 and value <= 8202 or value == 8239 or value == 8287 or value == 12288
			elseif item.name == "Cf" then value == 0x00AD or value >= 0x0600 and value <= 0x0605 or value == 0x061C or value == 0x06DD or value == 0x070F or value == 0x08E2 or value == 0x180E or value >= 0x200B and value <= 0x200F or value >= 0x202A and value <= 0x202E or value >= 0x2060 and value <= 0x2064 or value >= 0x2066 and value <= 0x206F or value == 0xFEFF or value >= 0xFFF9 and value <= 0xFFFB
			else word(value, flags)
		return if item.inverted then not found else found
	end
	if item.kind == "literal" then return folded(value, flags) == folded(item.value, flags) end
	if value >= item.first and value <= item.last then return true end
	if flags.i then
		local canonical = folded(value, flags)
		if canonical >= item.first and canonical <= item.last then return true end
		if canonical >= 65 and canonical <= 90 and canonical + 32 >= item.first and canonical + 32 <= item.last then return true end
	end
	return false
end
local execute: (any, any, number, any, any, any, number) -> any
execute = function(program: any, input: any, start: number, initial: any, flags: any, budget: any, depth: number): any
	if depth > 128 then fail("lookahead nesting exceeds the supported execution depth") end
	local pc, position = 1, start
	local captures: any, marks: any = initial, {}
	local stack: { any } = {}
	while true do
		budget.steps += 1
		if budget.steps > MAX_STEPS then fail("matching exceeded the explicit execution budget") end
		local operation = program[pc]
		local failed = false
		if operation.op == "match" then return { position = position, captures = captures } end
		if operation.op == "split" then
			if #stack >= MAX_STACK then fail("backtracking exceeded the explicit stack budget") end
			table.insert(stack, { pc = operation.second, position = position, captures = captures, marks = marks })
			pc = operation.first
		elseif operation.op == "jump" then pc = operation.target
		elseif operation.op == "save" then captures = table.clone(captures); captures[operation.slot] = position; pc += 1
		elseif operation.op == "clear" then
			captures = table.clone(captures)
			for _, slot in operation.slots do captures[slot] = nil end
			pc += 1
		elseif operation.op == "mark" then marks = table.clone(marks); marks[operation.id] = position; pc += 1
		elseif operation.op == "progress" then failed = marks[operation.id] == position; pc += 1
		elseif operation.op == "start" then failed = not (position == 0 or flags.m and line(input[position])); pc += 1
		elseif operation.op == "finish" then failed = not (position == #input or flags.m and line(input[position + 1])); pc += 1
		elseif operation.op == "boundary" then
			local boundary = word(input[position], flags) ~= word(input[position + 1], flags)
			failed = if operation.inverted then boundary else not boundary
			pc += 1
		elseif operation.op == "look" then
			local result = execute(operation.program, input, position, captures, flags, budget, depth + 1)
			failed = if operation.inverted then result ~= nil else result == nil
			if result and not operation.inverted then captures = result.captures end
			pc += 1
		elseif operation.op == "reference" then
			local first, finish = captures[operation.index * 2], captures[operation.index * 2 + 1]
			if first ~= nil and finish ~= nil then
				for at = first + 1, finish do
					local a, b = input[at], input[position + at - first]
					if b == nil then failed = true; break end
					if flags.i and a > 127 and b > 127 and a ~= b and folded(a, flags) ~= folded(b, flags) then
						fail("non-ASCII backreference case folding needs a Unicode provider")
					end
					if folded(a, flags) ~= folded(b, flags) then failed = true; break end
				end
				position += finish - first
			end
			pc += 1
		else
			local value = input[position + 1]
			if value == nil then failed = true
			elseif operation.op == "any" then failed = not flags.s and line(value)
			elseif operation.op == "class" then
				local found = false
				for _, item in operation.items do if itemMatches(item, value, flags) then found = true; break end end
				failed = if operation.inverted then found else not found
			else failed = not itemMatches({ kind = operation.op, value = operation.value, name = operation.name, inverted = operation.inverted }, value, flags) end
			position += 1
			pc += 1
		end
		if failed then
			local previous = table.remove(stack)
			if not previous then return nil end
			pc, position, captures, marks = previous.pc, previous.position, previous.captures, previous.marks
		end
	end
end
local function stateOf(value: any): any
	assert(identities[value], "TypeError: RegExp method requires a native regular-expression receiver")
	return (getmetatable(value) :: any)[stateKey]
end
local function sourceText(pattern: string): string
	if pattern == "" then return "(?:)" end
	local parts, escaped = {}, false
	for _, value in utf8.codes(pattern) do
		local text = utf8.char(value)
		if value == 10 then text = "\\n" elseif value == 13 then text = "\\r"
		elseif value == 0x2028 then text = "\\u2028" elseif value == 0x2029 then text = "\\u2029"
		elseif value == 47 and not escaped then text = "\\/" end
		table.insert(parts, text)
		escaped = value == 92 and not escaped
	end
	return table.concat(parts)
end
function RegExp.create(pattern: string, flags: string?): any
	assert(type(pattern) == "string" and (flags == nil or type(flags) == "string"), "Native RegExp creation requires primitive strings")
	local active = flagsOf(flags or "")
	local parsed = parse(pattern, active)
	local canonical = {}
	for _, name in { "d", "g", "i", "m", "s", "u", "y" } do if active[name] then table.insert(canonical, name) end end
	local state = { source = sourceText(pattern), pattern = pattern, flags = table.concat(canonical), active = active,
		program = compile(parsed.ast), captures = parsed.captures, names = parsed.names, lastIndex = 0 :: any }
	local value = setmetatable({}, { [stateKey] = state })
	identities[value] = true
	return value
end
function RegExp.owns(value: any): boolean return identities[value] == true end
function RegExp.read(value: any, property: string): any
	local state = stateOf(value)
	if property == "lastIndex" or property == "source" or property == "flags" then return state[property] end
	local aliases = { global = "g", ignoreCase = "i", multiline = "m", dotAll = "s", unicode = "u", sticky = "y", hasIndices = "d" }
	if property == "unicodeSets" then return false end
	local flag = aliases[property]
	assert(flag, `Unsupported native RegExp property {property}`)
	return state.active[flag] == true
end
function RegExp.writeLastIndex(value: any, nextIndex: any)
	assert(not table.isfrozen(value), "TypeError: RegExp.lastIndex is not writable")
	stateOf(value).lastIndex = nextIndex
end
local function search(value: any, subject: string, suppliedIndex: number?): any
	local state = stateOf(value)
	local number = if suppliedIndex ~= nil then suppliedIndex else Values.Number(state.lastIndex)
	local last = if number ~= number or number <= 0 then 0 else math.min(math.floor(number), 9007199254740991)
	local input, offsets = codes(subject, state.active.u == true)
	local requested = if state.active.g or state.active.y then last else 0
	if requested > offsets[#offsets] then
		if state.active.g or state.active.y then RegExp.writeLastIndex(value, 0) end
		return nil
	end
	local start = 0
	while offsets[start + 1] < requested do start += 1 end
	if offsets[start + 1] ~= requested then fail("Unicode lastIndex inside a surrogate pair is not implemented") end
	local budget = { steps = 0 }
	for at = start, #input do
		local result = execute(state.program, input, at, {}, state.active, budget, 0)
		if result then
			if state.active.g or state.active.y then RegExp.writeLastIndex(value, offsets[result.position + 1]) end
			return { start = at, finish = result.position, captures = result.captures, input = input, offsets = offsets, state = state }
		end
		if state.active.y then break end
	end
	if state.active.g or state.active.y then RegExp.writeLastIndex(value, 0) end
	return nil
end
function RegExp.test(value: any, subject: string, suppliedIndex: number?): boolean return search(value, subject, suppliedIndex) ~= nil end
function RegExp.exec(value: any, subject: string, suppliedIndex: number?): any
	local match = search(value, subject, suppliedIndex)
	if not match then return Nulls.value end
	local state = match.state
	local result = Arrays.adopt({}, state.captures + 1)
	local indices = if state.active.d then Arrays.adopt({}, state.captures + 1) else nil
	Arrays.set(result, 0, slice(match.input, match.start, match.finish))
	if indices then Arrays.set(indices, 0, Arrays.adopt({ match.offsets[match.start + 1], match.offsets[match.finish + 1] }, 2)) end
	for capture = 1, state.captures do
		local first, finish = match.captures[capture * 2], match.captures[capture * 2 + 1]
		if first ~= nil and finish ~= nil then
			Arrays.set(result, capture, slice(match.input, first, finish))
			if indices then Arrays.set(indices, capture, Arrays.adopt({ match.offsets[first + 1], match.offsets[finish + 1] }, 2)) end
		end
	end
	local groupNames = {}
	for name in state.names do table.insert(groupNames, name) end
	table.sort(groupNames, function(a, b) return state.names[a] < state.names[b] end)
	local groups = if #groupNames > 0 then Records.adopt({}, groupNames) else nil
	local indexGroups = if groups and indices then Records.adopt({}, groupNames) else nil
	if groups then
		Records.setPrototype(groups, Nulls.value)
		if indexGroups then Records.setPrototype(indexGroups, Nulls.value) end
		for _, name in groupNames do
			groups[name] = result[state.names[name] + 1]
			if indexGroups then indexGroups[name] = indices[state.names[name] + 1] end
		end
	end
	Arrays.defineProperty(result, "index", match.offsets[match.start + 1])
	Arrays.defineProperty(result, "input", subject)
	Arrays.defineProperty(result, "groups", groups)
	if indices then
		Arrays.defineProperty(indices, "groups", indexGroups)
		Arrays.defineProperty(result, "indices", indices)
	end
	return result
end
function RegExp.length(subject: string): number
	local _input, offsets = codes(subject, false)
	return offsets[#offsets]
end
function RegExp.slice(subject: string, first: number, finish: number): string
	local input = codes(subject, false)
	assert(first >= 0 and finish >= first and finish <= #input, "Invalid native UTF-16 slice")
	return slice(input, first, finish)
end
function RegExp.advance(subject: string, index: number, unicode: boolean): number
	local input = codes(subject, false)
	local first, second = input[index + 1], input[index + 2]
	return index + (if unicode and first and second and first >= 0xD800 and first <= 0xDBFF and second >= 0xDC00 and second <= 0xDFFF then 2 else 1)
end
local function construct(pattern: any, flags: any): any
	if RegExp.owns(pattern) then
		local state = stateOf(pattern)
		return RegExp.create(state.pattern, if flags == nil then state.flags else Values.String(flags))
	end
	return RegExp.create(if pattern == nil then "" else Values.String(pattern), if flags == nil then "" else Values.String(flags))
end
RegExp.Constructor = SourceType.register(table.freeze(setmetatable({ new = construct }, {
	__call = function(_self, pattern: any, flags: any): any
		if RegExp.owns(pattern) and flags == nil then return pattern end
		return construct(pattern, flags)
	end,
})), "function")
return RegExp
