--!strict
local SourceType = require(script.Parent.SourceType)
local Symbols = {}
local registered: { [string]: any } = {}
local registeredKeys: { [any]: string } = setmetatable({}, { __mode = "k" }) :: any
local identities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local descriptionToken = {}
local function create(description: any?): any
	assert(description == nil or type(description) == "string", "Symbol description requires a primitive string")
	local value = table.freeze(setmetatable({}, {
		[descriptionToken] = description,
		__tostring = function(): string return "Symbol(" .. (description or "") .. ")" end,
	}))
	identities[value] = true
	return SourceType.register(value, "symbol")
end
function Symbols.description(value: any): string?
	assert(identities[value], "Symbol.description requires a Symbol")
	return (getmetatable(value) :: any)[descriptionToken]
end
local constructor: any = setmetatable({ iterator = create("Symbol.iterator"),
	toPrimitive = create("Symbol.toPrimitive"), hasInstance = create("Symbol.hasInstance"),
	toStringTag = create("Symbol.toStringTag"),
	match = create("Symbol.match"), matchAll = create("Symbol.matchAll"), replace = create("Symbol.replace"),
	search = create("Symbol.search"), split = create("Symbol.split") }, {
	__call = function(_self: any, description: string?): any return create(description) end,
})
constructor["for"] = function(key: string): any
	assert(type(key) == "string", "Symbol.for requires a primitive string")
	if registered[key] == nil then
		registered[key] = create(key)
		registeredKeys[registered[key]] = key
	end
	return registered[key]
end
constructor.keyFor = function(value: any): string?
	assert(identities[value], "Symbol.keyFor requires a Symbol")
	return registeredKeys[value]
end
Symbols.Symbol = SourceType.register(table.freeze(constructor), "function")
return Symbols
