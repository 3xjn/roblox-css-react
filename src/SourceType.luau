--!strict

local SourceType = {}
local classifications: { [any]: string } = setmetatable({}, { __mode = "k" })
-- Native boundary constructors and symbols have private identity; source data
-- cannot gain callable/symbol classification by copying public properties.
function SourceType.register(value: any, kind: string)
	assert(type(value) == "table" and (kind == "function" or kind == "symbol"), "Invalid source identity")
	classifications[value] = kind
	return value
end
-- The shared source-null sentinel has table identity and object classification.
-- Platform objects retain object classification rather than Roblox typeof names.
function SourceType.typeOf(value: any): string
	local kind = type(value)
	if kind == "table" and classifications[value] then return classifications[value] end
	if kind == "nil" then
		return "undefined"
	end
	if kind == "string" or kind == "number" or kind == "boolean" or kind == "function" then
		return kind
	end
	if kind == "table" or kind == "userdata" or kind == "vector" or kind == "buffer" then
		return "object"
	end
	error(`JavaScript typeof needs a representation for {kind}`, 2)
end
function SourceType.typeIs(value: any, kind: string): boolean
	return SourceType.typeOf(value) == kind
end
return SourceType
