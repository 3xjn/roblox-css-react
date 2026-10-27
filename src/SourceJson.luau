--!strict
-- Source JSON preserves null, array holes, record order and callback receivers.
-- Native decoding is used only for a validated JSON string token, so JSON null
-- and ordered records never pass through a lossy native table conversion.
-- Lone UTF-16 surrogates are valid JSON/JavaScript but explicitly unsupported
-- by this boundary's Unicode scalar string representation.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Functions = require(script.Parent.FunctionValues)
local SourceType = require(script.Parent.SourceType)
local SourceJson = {}
local function invoke(callback: any, receiver: any, args: any): any
	return Functions.invokeReference(
		Functions.reference(receiver, function() return callback end, "method", false),
		function() return args end,
		false
	)
end

local numberString = require(script.Parent.NumberStrings).toString

local function quote(value: string): string
	assert(utf8.len(value) ~= nil, "Source JSON requires Unicode scalar strings")
	return '"'
		.. value:gsub('[%z\1-\31\\"]', function(char)
			local replacements: { [string]: string } = {
				['"'] = '\\"',
				["\\"] = "\\\\",
				["\b"] = "\\b",
				["\f"] = "\\f",
				["\n"] = "\\n",
				["\r"] = "\\r",
				["\t"] = "\\t",
			}
			return replacements[char] or string.format("\\u%04x", string.byte(char))
		end)
		.. '"'
end

local function indentString(space: any): string
	if type(space) == "number" then
		return string.rep(" ", if space ~= space then 0 else math.clamp(math.floor(space), 0, 10))
	end
	if type(space) ~= "string" then
		return ""
	end
	local text = space :: string
	local units, last = 0, 0
	for at, code in utf8.codes(text) do
		local width = if code > 0xFFFF then 2 else 1
		if units + width > 10 then
			assert(units == 10, "Indent truncation through a UTF-16 surrogate is unsupported")
			break
		end
		units += width
		last = at + #utf8.char(code) - 1
	end
	return text:sub(1, last)
end

function SourceJson.stringify(value: any, replacer: any?, space: any?): string?
	local gap = indentString(space)
	local propertyList: { string }? = nil
	if type(replacer) == "table" and Arrays.owns(replacer) then
		propertyList = {}
		local seen = {}
		for i = 1, #replacer do
			local item = replacer[i]
			if type(item) == "string" or type(item) == "number" then
				local key = if type(item) == "number" then numberString(item) else item
				if not seen[key] then
					seen[key] = true
					table.insert(propertyList :: { string }, key)
				end
			end
		end
	end
	local ancestors: { [any]: boolean } = {}
	local serialize: (any, string, number, boolean) -> string?
	serialize = function(holder: any, key: string, depth: number, arraySlot: boolean): string?
		local item = if Arrays.owns(holder) then holder[assert(tonumber(key)) + 1] else holder[key]
		local toJSON = if type(item) == "function" then Functions.getProperty(item, "toJSON")
			elseif type(item) == "table" and not Nulls.isNull(item) then item.toJSON else nil
		if type(toJSON) == "function" then
			item = invoke(toJSON, item, Arrays.adopt({key}, 1))
		end
		if type(replacer) == "function" then
			item = invoke(replacer, holder, Arrays.adopt({key, item}, 2))
		end
		local kind = SourceType.typeOf(item)
		if Nulls.isNull(item) then
			return "null"
		end
		if kind == "string" then
			return quote(item)
		end
		if kind == "boolean" then
			return if item then "true" else "false"
		end
		if kind == "number" then
			return if item ~= item or math.abs(item) == math.huge then "null" else numberString(item)
		end
		if kind == "undefined" or kind == "function" or kind == "symbol" then
			return if arraySlot then "null" else nil
		end
		assert(kind == "object" and type(item) == "table", "Source JSON requires ordinary data, or a replacer for native values")
		assert(not ancestors[item], "Converting circular structure to JSON")
		ancestors[item] = true
		local isArray = Arrays.owns(item)
		local entries = {}
		if isArray then
			for i = 1, #item do
				table.insert(entries, serialize(item, tostring(i - 1), depth + 1, true) or "null")
			end
		else
			for _, name in propertyList or Records.keys(item) do
				local encoded = serialize(item, name, depth + 1, false)
				if encoded ~= nil then
					table.insert(entries, quote(name) .. (if gap == "" then ":" else ": ") .. encoded)
				end
			end
		end
		ancestors[item] = nil
		local open, close = if isArray then "[" else "{", if isArray then "]" else "}"
		if #entries == 0 then
			return open .. close
		end
		if gap == "" then
			return open .. table.concat(entries, ",") .. close
		end
		local indent = string.rep(gap, depth + 1)
		return open
			.. "\n"
			.. indent
			.. table.concat(entries, ",\n" .. indent)
			.. "\n"
			.. string.rep(gap, depth)
			.. close
	end
	return serialize(Records.adopt({ [""] = value }, { "" }), "", 0, false)
end

function SourceJson.parse(text: string, reviver: any?): any
	assert(type(text) == "string", "Source JSON.parse requires a string")
	local cursor, length = 1, #text
	local function whitespace()
		while cursor <= length and text:sub(cursor, cursor):match("[ \n\r\t]") do
			cursor += 1
		end
	end
	local function tokenString(): string
		local start = cursor
		cursor += 1
		while cursor <= length do
			local char = text:sub(cursor, cursor)
			assert(string.byte(char) >= 32, "Control character in JSON string")
			if char == '"' then
				cursor += 1
				return game:GetService("HttpService"):JSONDecode(text:sub(start, cursor - 1))
			elseif char == "\\" then
				cursor += 1
				local escape = text:sub(cursor, cursor)
				if escape == "u" then
					local hex = text:sub(cursor + 1, cursor + 4)
					assert(#hex == 4 and hex:match("^%x%x%x%x$"), "Invalid JSON unicode escape")
					local code = assert(tonumber(hex, 16))
					cursor += 4
					if code >= 0xD800 and code <= 0xDBFF then
						assert(
							text:sub(cursor + 1, cursor + 2) == "\\u",
							"Unpaired UTF-16 surrogate cannot be represented in Luau"
						)
						local low = tonumber(text:sub(cursor + 3, cursor + 6), 16)
						assert(
							low and low >= 0xDC00 and low <= 0xDFFF,
							"Unpaired UTF-16 surrogate cannot be represented in Luau"
						)
						cursor += 6
					else
						assert(
							code < 0xDC00 or code > 0xDFFF,
							"Unpaired UTF-16 surrogate cannot be represented in Luau"
						)
					end
				else
					assert(escape ~= "" and ('"\\/bfnrt'):find(escape, 1, true), "Invalid JSON string escape")
				end
			end
			cursor += 1
		end
		error("Unterminated JSON string")
	end
	local parseValue: () -> any
	parseValue = function(): any
		whitespace()
		local char = text:sub(cursor, cursor)
		if char == '"' then
			return tokenString()
		end
		if char == "{" then
			cursor += 1
			whitespace()
			local result, keys, seen = {}, {}, {}
			if text:sub(cursor, cursor) ~= "}" then
				while true do
					assert(text:sub(cursor, cursor) == '"', "Expected JSON object key")
					local key = tokenString()
					whitespace()
					assert(text:sub(cursor, cursor) == ":", "Expected JSON colon")
					cursor += 1
					result[key] = parseValue()
					if not seen[key] then
						seen[key] = true
						table.insert(keys, key)
					end
					whitespace()
					if text:sub(cursor, cursor) == "}" then
						break
					end
					assert(text:sub(cursor, cursor) == ",", "Expected JSON comma")
					cursor += 1
					whitespace()
				end
			end
			cursor += 1
			return Records.adopt(result, keys)
		elseif char == "[" then
			cursor += 1
			whitespace()
			local result, count = {}, 0
			if text:sub(cursor, cursor) ~= "]" then
				while true do
					count += 1
					result[count] = parseValue()
					whitespace()
					if text:sub(cursor, cursor) == "]" then
						break
					end
					assert(text:sub(cursor, cursor) == ",", "Expected JSON comma")
					cursor += 1
				end
			end
			cursor += 1
			return Arrays.adopt(result, count)
		end
		local literals: { { any } } = { { "null", Nulls.value }, { "true", true }, { "false", false } }
		for _, literal in literals do
			if text:sub(cursor, cursor + #literal[1] - 1) == literal[1] then
				cursor += #literal[1]
				return literal[2]
			end
		end
		local start = cursor
		if char == "-" then
			cursor += 1
		end
		local digit = text:sub(cursor, cursor)
		assert(digit:match("%d"), "Expected JSON value")
		if digit == "0" then
			cursor += 1
		else
			while text:sub(cursor, cursor):match("%d") do
				cursor += 1
			end
		end
		if text:sub(cursor, cursor) == "." then
			cursor += 1
			assert(text:sub(cursor, cursor):match("%d"), "Expected JSON fraction")
			while text:sub(cursor, cursor):match("%d") do
				cursor += 1
			end
		end
		if text:sub(cursor, cursor):match("[eE]") then
			cursor += 1
			if text:sub(cursor, cursor):match("[+-]") then
				cursor += 1
			end
			assert(text:sub(cursor, cursor):match("%d"), "Expected JSON exponent")
			while text:sub(cursor, cursor):match("%d") do
				cursor += 1
			end
		end
		return assert(tonumber(text:sub(start, cursor - 1)))
	end
	local value = parseValue()
	whitespace()
	assert(cursor > length, "Unexpected data after JSON value")
	if type(reviver) ~= "function" then
		return value
	end
	local walk: (any, string) -> any
	walk = function(holder: any, key: string): any
		local isArray = Arrays.owns(holder)
		local item = if isArray then holder[assert(tonumber(key)) + 1] else holder[key]
		if type(item) == "table" and not Nulls.isNull(item) then
			local keys = if Arrays.owns(item) then Arrays.keys(item) else Records.keys(item)
			for _, child in keys do
				local replacement = walk(item, child)
				if Arrays.owns(item) then
					if replacement == nil then
						Arrays.remove(item, assert(tonumber(child)))
					else
						item[assert(tonumber(child)) + 1] = replacement
					end
				elseif replacement == nil then
					Records.remove(item, child)
				else
					item[child] = replacement
				end
			end
		end
		return invoke(reviver, holder, Arrays.adopt({key, item}, 2))
	end
	return walk(Records.adopt({ [""] = value }, { "" }), "")
end

return SourceJson
