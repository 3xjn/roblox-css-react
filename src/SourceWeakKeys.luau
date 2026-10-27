--!strict
-- CanBeHeldWeakly for native source identities. Symbols keep their primitive
-- identity even though represented by native tables; registered symbols are
-- excluded independently of public fields and ordinary object shapes.
local Nulls = require(script.Parent.Nulls)
local SourceWeakKeys = {}
local symbols: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function SourceWeakKeys.registerSymbol(value: any, registered: boolean)
	assert(type(value) == "table", "Source symbols require their native identity token")
	symbols[value] = not registered
end
function SourceWeakKeys.canBeHeldWeakly(value: any): boolean
	if Nulls.isNullish(value) then
		return false
	end
	local symbolic = if type(value) == "table" then symbols[value] else nil
	if symbolic ~= nil then
		return symbolic
	end
	local kind = type(value)
	return kind == "table" or kind == "function" or kind == "userdata"
end
return SourceWeakKeys
