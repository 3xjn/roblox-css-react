--!strict
-- ECMAScript URI encoding over Luau's scalar UTF-8 strings.
local Errors = require(script.Parent.SourceErrors)
local Nulls = require(script.Parent.Nulls)
local Numbers = require(script.Parent.SourceNumbers)
local SourceUri = {}

local uriKinds: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function uriError(message: string): never
	local value = Errors.Error(message)
	value.name = "URIError"
	uriKinds[value] = true
	error(value, 3)
end

local URIError: any
URIError = table.freeze(setmetatable({
	new = function(message: any?): any
		local text = if message == nil then "" else tostring(message)
		local value = Errors.Error(text)
		value.name = "URIError"
		uriKinds[value] = true
		return value
	end,
	instanceof = function(value: any): boolean
		return uriKinds[value] == true
	end,
}, {
	__call = function(_self: any, message: any?): any
		return URIError.new(message)
	end,
}))

local function sourceString(value: any): string
	if value == nil then
		return "undefined"
	elseif Nulls.isNull(value) then
		return "null"
	elseif type(value) == "string" then
		return value
	elseif type(value) == "boolean" or type(value) == "number" then
		return if type(value) == "number" then Numbers.toString(value) else tostring(value)
	end
	return uriError("URI functions require primitive string coercion")
end

local function encodeURIComponent(value: any): string
	local input = sourceString(value)
	if not utf8.len(input) then
		uriError("URI malformed")
	end
	local output = table.create(#input)
	for index = 1, #input do
		local byte = string.byte(input, index)
		local allowed = (byte >= 48 and byte <= 57)
			or (byte >= 65 and byte <= 90)
			or (byte >= 97 and byte <= 122)
			or byte == 45 or byte == 95 or byte == 46 or byte == 33
			or byte == 126 or byte == 42 or byte == 39 or byte == 40 or byte == 41
		output[index] = if allowed then string.char(byte) else string.format("%%%02X", byte)
	end
	return table.concat(output)
end

local function decodeURIComponent(value: any): string
	local input = sourceString(value)
	local output = table.create(#input)
	local index = 1
	while index <= #input do
		local byte = string.byte(input, index)
		if byte == 37 then
			local pair = string.sub(input, index + 1, index + 2)
			if #pair ~= 2 or not string.match(pair, "^%x%x$") then
				uriError("URI malformed")
			end
			output[#output + 1] = string.char(assert(tonumber(pair, 16)))
			index += 3
		else
			output[#output + 1] = string.char(byte)
			index += 1
		end
	end
	local decoded = table.concat(output)
	if not utf8.len(decoded) then
		uriError("URI malformed")
	end
	return decoded
end

SourceUri.URIError = URIError
SourceUri.encodeURIComponent = encodeURIComponent
SourceUri.decodeURIComponent = decodeURIComponent
return SourceUri
