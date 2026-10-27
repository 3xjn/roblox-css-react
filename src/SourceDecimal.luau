--!strict
-- Exact binary64 -> shortest decimal. Integer limbs stay below 2^52; only
-- exact integer digits use string.format. No printf float approximation or
-- native string-to-number roundtrip decides which decimal is emitted.
-- ECMA-262 Number::toString, including its closest/even selection rule:
-- https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-tostring
local SourceDecimal = {}
type Integer = { number }
local base = 10000000

local function fromNumber(value: number): Integer
	local result = {}
	repeat
		local remainder = math.fmod(value, base)
		table.insert(result, remainder)
		value = (value - remainder) / base
	until value == 0
	return result
end
local function multiply(value: Integer, factor: number)
	local carry = 0
	for index = 1, #value do
		local product = value[index] * factor + carry
		carry = math.floor(product / base)
		value[index] = product - carry * base
	end
	while carry > 0 do
		local remainder = math.fmod(carry, base)
		table.insert(value, remainder)
		carry = (carry - remainder) / base
	end
end
local function addOne(value: Integer, direction: number)
	local index = 1
	while direction ~= 0 do
		local digit = (value[index] or 0) + direction
		if digit == base then
			value[index] = 0
			direction = 1
		elseif digit < 0 then
			value[index] = base - 1
			direction = -1
		else
			value[index] = digit
			direction = 0
		end
		index += 1
	end
	while #value > 1 and value[#value] == 0 do
		table.remove(value)
	end
end
local function digits(value: Integer): string
	local parts = { string.format("%.0f", value[#value]) }
	for index = #value - 1, 1, -1 do
		table.insert(parts, string.format("%07d", value[index]))
	end
	return table.concat(parts)
end
local function exact(value: Integer, exponent: number): (string, number)
	local remaining = math.abs(exponent)
	local width = if exponent >= 0 then 28 else 12
	local factor = if exponent >= 0 then 268435456 else 244140625
	while remaining >= width do
		multiply(value, factor)
		remaining -= width
	end
	if remaining > 0 then
		multiply(value, (if exponent >= 0 then 2 else 5) ^ remaining)
	end
	local text = digits(value)
	local point = #text + math.min(exponent, 0)
	return (text:gsub("0+$", "")), point
end
local function compare(a: string, point: number, b: string, other: number): number
	if point ~= other then
		return if point < other then -1 else 1
	end
	for index = 1, math.max(#a, #b) do
		local left, right = string.byte(a, index) or 48, string.byte(b, index) or 48
		if left ~= right then
			return if left < right then -1 else 1
		end
	end
	return 0
end
local function increment(text: string): string
	for index = #text, 1, -1 do
		local byte = string.byte(text, index)
		if byte < 57 then
			return string.sub(text, 1, index - 1) .. string.char(byte + 1) .. string.rep("0", #text - index)
		end
	end
	return "1" .. string.rep("0", #text)
end
local function roundUp(exactDigits: string, count: number, floor: string): boolean
	local first = string.byte(exactDigits, count + 1) or 48
	if first ~= 53 then
		return first > 53
	end
	for index = count + 2, #exactDigits do
		if string.byte(exactDigits, index) ~= 48 then
			return true
		end
	end
	return (string.byte(floor, #floor) - 48) % 2 == 1
end
local function format(text: string, point: number): string
	text = text:gsub("0+$", "")
	if point > 0 and point <= 21 then
		if #text <= point then
			return text .. string.rep("0", point - #text)
		end
		return string.sub(text, 1, point) .. "." .. string.sub(text, point + 1)
	end
	if point > -6 and point <= 0 then
		return "0." .. string.rep("0", -point) .. text
	end
	local exponent = point - 1
	return string.sub(text, 1, 1)
		.. (if #text > 1 then "." .. string.sub(text, 2) else "")
		.. "e"
		.. (if exponent >= 0 then "+" else "-")
		.. string.format("%.0f", math.abs(exponent))
end

function SourceDecimal.toPrecision(value: number, precision: number): string
	if value ~= value or value == math.huge or value == -math.huge then return SourceDecimal.toString(value) end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	local source, point = "0", 1
	if value ~= 0 then
		local binary = buffer.create(8)
		buffer.writef64(binary, 0, value)
		local low, high = buffer.readu32(binary, 0), buffer.readu32(binary, 4)
		local encoded = math.floor(high / 1048576)
		local significand = (high % 1048576) * 4294967296 + low
		local exponent = -1074
		if encoded ~= 0 then significand += 4503599627370496; exponent = encoded - 1075 end
		source, point = exact(fromNumber(significand), exponent)
	end
	local result = string.sub(source, 1, precision) .. string.rep("0", math.max(0, precision - #source))
	if (string.byte(source, precision + 1) or 48) >= 53 then
		result = increment(result)
		if #result > precision then point += 1; result = string.sub(result, 1, precision) end
	end
	local exponent = point - 1
	if exponent < -6 or exponent >= precision then
		return sign .. string.sub(result, 1, 1) .. (if precision > 1 then "." .. string.sub(result, 2) else "")
			.. "e" .. (if exponent >= 0 then "+" else "-") .. string.format("%.0f", math.abs(exponent))
	elseif point <= 0 then
		return sign .. "0." .. string.rep("0", -point) .. result
	elseif point >= precision then
		return sign .. result .. string.rep("0", point - precision)
	end
	return sign .. string.sub(result, 1, point) .. "." .. string.sub(result, point + 1)
end

function SourceDecimal.toFixed(value: number, places: number): string
	if value ~= value or value == math.huge or value == -math.huge or math.abs(value) >= 1e21 then
		return SourceDecimal.toString(value)
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	local source, point = "0", 1
	if value ~= 0 then
		local binary = buffer.create(8)
		buffer.writef64(binary, 0, value)
		local low, high = buffer.readu32(binary, 0), buffer.readu32(binary, 4)
		local encoded = math.floor(high / 1048576)
		local significand = (high % 1048576) * 4294967296 + low
		local exponent = -1074
		if encoded ~= 0 then significand += 4503599627370496; exponent = encoded - 1075 end
		source, point = exact(fromNumber(significand), exponent)
	end
	local count = point + places
	local whole = if count <= 0 then "0" else string.sub(source, 1, count) .. string.rep("0", math.max(0, count - #source))
	local nextDigit = if count < 0 then 48 else string.byte(source, count + 1) or 48
	if nextDigit >= 53 then whole = increment(whole) end
	if places > 0 then
		if #whole <= places then whole = string.rep("0", places + 1 - #whole) .. whole end
		whole = string.sub(whole, 1, #whole - places) .. "." .. string.sub(whole, #whole - places + 1)
	end
	return sign .. whole
end

function SourceDecimal.toString(value: number): string
	assert(type(value) == "number", "Decimal conversion requires a primitive number")
	if value ~= value then
		return "NaN"
	end
	if value == math.huge then
		return "Infinity"
	end
	if value == -math.huge then
		return "-Infinity"
	end
	if value == 0 then
		return "0"
	end
	-- Preserve the cheap, exact path for ordinary counters and dimensions.
	if math.abs(value) <= 9007199254740991 and value % 1 == 0 then
		return string.format("%.0f", value)
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	local binary = buffer.create(8)
	buffer.writef64(binary, 0, value)
	local low, high = buffer.readu32(binary, 0), buffer.readu32(binary, 4)
	local encodedExponent = math.floor(high / 1048576)
	local significand = (high % 1048576) * 4294967296 + low
	local exponent = -1074
	if encodedExponent ~= 0 then
		significand += 4503599627370496
		exponent = encodedExponent - 1075
	end
	local source, point = exact(fromNumber(significand), exponent)
	local lower, upper = fromNumber(significand), fromNumber(significand)
	local lowerExponent = exponent - 1
	if significand == 4503599627370496 and exponent > -1074 then
		multiply(lower, 4)
		lowerExponent = exponent - 2
	else
		multiply(lower, 2)
	end
	addOne(lower, -1)
	multiply(upper, 2)
	addOne(upper, 1)
	local lowerDigits, lowerPoint = exact(lower, lowerExponent)
	local upperDigits, upperPoint = exact(upper, exponent - 1)
	local inclusive = significand % 2 == 0
	local function inside(candidate: string, location: number): boolean
		local first = compare(candidate, location, lowerDigits, lowerPoint)
		local last = compare(candidate, location, upperDigits, upperPoint)
		return (first > 0 or inclusive and first == 0) and (last < 0 or inclusive and last == 0)
	end
	for count = 1, 17 do
		local floor = string.sub(source, 1, count)
		local ceiling = increment(floor)
		local ceilingPoint = point + #ceiling - #floor
		local below, above = inside(floor, point), inside(ceiling, ceilingPoint)
		if below or above then
			if above and (not below or roundUp(source, count, floor)) then
				return sign .. format(ceiling, ceilingPoint)
			end
			return sign .. format(floor, point)
		end
	end
	error("Binary64 shortest decimal interval was not resolved", 2)
end
return SourceDecimal
