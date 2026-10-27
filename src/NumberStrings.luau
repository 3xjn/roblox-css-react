--!strict
-- Shared primitive NumberToString conversion. Select the shortest significant
-- decimal precision which round trips, then apply ECMAScript's fixed/exponent
-- boundaries. No value-dependent cache or source record coercion is involved.
local NumberStrings = {}
function NumberStrings.toString(value: number): string
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
	local result = ""
	for precision = 1, 17 do
		result = string.format("%." .. precision .. "g", value)
		if tonumber(result) == value then
			break
		end
	end
	local mantissa, exponentText = result:match("^([^eE]+)[eE]([+-]?%d+)$")
	if not mantissa then
		return result
	end
	local exponent = assert(tonumber(exponentText))
	local absolute = math.abs(value)
	if absolute >= 1e-6 and absolute < 1e21 then
		local negative = mantissa:sub(1, 1) == "-"
		local digits = mantissa:gsub("^-", ""):gsub("%.", "")
		local dot = (mantissa:gsub("^-", "")):find("%.")
		local decimal = (dot and dot - 1 or #digits) + exponent
		local fixed = if decimal <= 0
			then "0." .. string.rep("0", -decimal) .. digits
			elseif decimal >= #digits then digits .. string.rep("0", decimal - #digits)
			else digits:sub(1, decimal) .. "." .. digits:sub(decimal + 1)
		return (if negative then "-" else "") .. fixed
	end
	return mantissa .. "e" .. (if exponent >= 0 then "+" else "-") .. tostring(math.abs(exponent))
end

return table.freeze(NumberStrings)
