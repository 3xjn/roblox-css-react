--!strict
-- Nondecimal binary64 formatting is translated from V8 12.0.267,
-- src/numbers/conversions.cc DoubleToRadixCString (BSD; see LICENSE.v8).
-- https://github.com/v8/v8/blob/12.0.267/src/numbers/conversions.cc#L1252
local Decimal = require(script.Parent.SourceDecimal)
local Nulls = require(script.Parent.Nulls)
local SourceNumbers = {}
local alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
local minimum = 5e-324

local function nextPositive(value: number): number
	local bits = buffer.create(8)
	buffer.writef64(bits, 0, value)
	local low, high = buffer.readu32(bits, 0), buffer.readu32(bits, 4)
	if low == 4294967295 then
		low = 0
		high += 1
	else
		low += 1
	end
	buffer.writeu32(bits, 0, low)
	buffer.writeu32(bits, 4, high)
	return buffer.readf64(bits, 0)
end

function SourceNumbers.toString(value: number, radix: number?): string
	if type(value) ~= "number" then
		return require(script.Parent.SourceOperations).intrinsicError("TypeError", "Number.toString requires a primitive number")
	end
	local base = if radix == nil then 10 else radix
	if type(base) ~= "number" then
		return require(script.Parent.SourceOperations).intrinsicError("TypeError", "Native radix conversion requires a primitive number")
	end
	base = if base < 0 then math.ceil(base) else math.floor(base)
	if base ~= base or base < 2 or base > 36 then
		return require(script.Parent.SourceOperations).intrinsicError("RangeError", "toString() radix argument must be between 2 and 36")
	end
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
	if base == 10 then
		return Decimal.toString(value)
	end
	local negative = value < 0
	if negative then
		value = -value
	end
	local integer = math.floor(value)
	local fraction = value - integer
	local delta = math.max(minimum, 0.5 * (nextPositive(value) - value))
	local fractional: { number } = {}
	if fraction >= delta then
		repeat
			fraction *= base
			delta *= base
			local digit = math.floor(fraction)
			table.insert(fractional, digit)
			fraction -= digit
			if fraction > 0.5 or (fraction == 0.5 and digit % 2 == 1) then
				if fraction + delta > 1 then
					while true do
						local last = table.remove(fractional)
						if last == nil then
							integer += 1
							break
						end
						if last + 1 < base then
							table.insert(fractional, last + 1)
							break
						end
					end
					break
				end
			end
		until fraction < delta
	end
	local reversed: { string } = {}
	while integer / base >= 9007199254740992 do
		integer /= base
		table.insert(reversed, "0")
	end
	repeat
		local remainder = math.fmod(integer, base)
		local digit = math.floor(remainder)
		table.insert(reversed, string.sub(alphabet, digit + 1, digit + 1))
		integer = (integer - remainder) / base
	until integer <= 0
	local output = if negative then { "-" } else {}
	for index = #reversed, 1, -1 do
		table.insert(output, reversed[index])
	end
	if #fractional > 0 then
		table.insert(output, ".")
		for _, digit in fractional do
			table.insert(output, string.sub(alphabet, digit + 1, digit + 1))
		end
	end
	return table.concat(output)
end

function SourceNumbers.optionalToString(value: any, radix: () -> number?): string?
	if Nulls.isNullish(value) then
		return nil
	end
	return SourceNumbers.toString(value, radix())
end

return SourceNumbers
