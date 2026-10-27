--!strict
local SourceType = require(script.Parent.SourceType)
local value = table.freeze(setmetatable(
	{},
	table.freeze({
		__tostring = function()
			return "null"
		end,
	})
))
local emptySpread = table.freeze({})
local Nulls = { value = value, emptySpread = emptySpread, typeOf = SourceType.typeOf, typeIs = SourceType.typeIs }
function Nulls.isNull(item: any): boolean
	return rawequal(item, value)
end
function Nulls.isNullish(item: any): boolean
	return item == nil or rawequal(item, value)
end
function Nulls.nullIs(_observedNull: any, item: any): boolean
	return Nulls.isNull(item)
end
function Nulls.nullishIs(_observedNull: any, item: any): boolean
	return Nulls.isNullish(item)
end
function Nulls.truthy(item: any): boolean
	return item ~= nil
		and item ~= false
		and not rawequal(item, value)
		and item ~= ""
		and not (type(item) == "number" and (item == 0 or item ~= item))
end
function Nulls.optional(item: any): any
	return if rawequal(item, value) then nil else item
end
function Nulls.spreadable(item: any): any
	return if Nulls.isNullish(item) then emptySpread else item
end
function Nulls.coalesce(item: any, fallback: () -> any): any
	return if Nulls.isNullish(item) then fallback() else item
end
function Nulls.coalesceValue(item: any, fallback: any): any
	return if Nulls.isNullish(item) then fallback else item
end
function Nulls.andValue(item: any, nextValue: () -> any): any
	return if Nulls.truthy(item) then nextValue() else item
end
function Nulls.orValue(item: any, nextValue: () -> any): any
	return if Nulls.truthy(item) then item else nextValue()
end
return Nulls
