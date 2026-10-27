--!strict

-- ECMA-262 String search over Unicode scalar strings. Native plain byte
-- search does the matching; only the zero-based UTF-16 positions are mapped.
-- No mutable cache, service, listener, string prototype or boxed value is used.
local Strings = {}

local function length(value: string): number
	assert(type(value) == "string", "String search requires primitive strings")
	local count = utf8.len(value)
	assert(count ~= nil, "String search requires valid UTF-8")
	if count == #value then
		return count
	end
	local units = 0
	for _, code in utf8.codes(value) do
		assert(code <= 0x10FFFF, "String search requires Unicode scalar values")
		assert(code < 0xD800 or code > 0xDFFF, "String search does not represent lone surrogates")
		units += if code > 0xFFFF then 2 else 1
	end
	return units
end

local function position(value: number?, fallback: number, size: number): number
	if value == nil then
		return fallback
	end
	assert(type(value) == "number", "String search position requires a number")
	if value ~= value then
		return 0
	end
	return math.clamp(if value < 0 then math.ceil(value) else math.floor(value), 0, size)
end

-- A split surrogate boundary has no byte boundary. includes can start after
-- the pair; startsWith/endsWith cannot match a nonempty scalar string there.
local function boundary(value: string, unit: number, size: number): (number, boolean)
	if size == #value then
		return unit + 1, true
	end
	local units = 0
	for byte, code in utf8.codes(value) do
		if units == unit then
			return byte, true
		end
		local width = if code > 0xFFFF then 2 else 1
		if units + width > unit then
			return byte + 4, false
		end
		units += width
	end
	return #value + 1, true
end

function Strings.startsWith(value: string, search: string, from: number?): boolean
	local size = length(value)
	length(search)
	local start, exact = boundary(value, position(from, 0, size), size)
	return search == "" or (exact and value:sub(start, start + #search - 1) == search)
end

function Strings.includes(value: string, search: string, from: number?): boolean
	local size = length(value)
	length(search)
	local start = boundary(value, position(from, 0, size), size)
	return search == "" or string.find(value, search, start, true) ~= nil
end

function Strings.endsWith(value: string, search: string, untilPosition: number?): boolean
	local size = length(value)
	length(search)
	local finish, exact = boundary(value, position(untilPosition, size, size), size)
	if search == "" then
		return true
	end
	local start = finish - #search
	return exact and start >= 1 and value:sub(start, finish - 1) == search
end

return table.freeze(Strings)
