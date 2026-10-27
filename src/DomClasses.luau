--!strict
-- Renderer-owned DOM interface identities. Native SDK inspection and source
-- values are separate views: a raw GuiObject never acquires source DOM APIs.
local SourceType = require(script.Parent.SourceType)
local Operations = require(script.Parent.SourceOperations)
local Records = require(script.Parent.Records)
local Functions = require(script.Parent.FunctionValues)
local Symbols = require(script.Parent.SourceSymbols)
local Nulls = require(script.Parent.Nulls)
local DomClasses = {}
export type Kind = "node" | "element" | "html" | "document" | "fragment" | "shadow"
local identities: { [any]: Kind } = setmetatable({}, { __mode = "k" }) :: any
local prototypes: { [string]: any } = {}
export type Implementation = { read: (any, string) -> any, contains: (any, any) -> boolean }
local implementations: { [string]: Implementation } = {}
function DomClasses.registerImplementation(kind: Kind, implementation: Implementation)
	assert(not implementations[kind], "DOM kind implementation is already registered")
	implementations[kind] = implementation
end
function DomClasses.readNode(owner: any, key: string): any
	local kind = identities[owner]
	if not kind then return Operations.intrinsicError("TypeError", "Illegal Node receiver") end
	return assert(implementations[kind], "This Node kind has no native implementation").read(owner, key)
end
function DomClasses.contains(owner: any, other: any): boolean
	local kind = identities[owner]
	if not kind then return Operations.intrinsicError("TypeError", "Illegal Node receiver") end
	if other == nil or Nulls.isNull(other) then return false end
	if not identities[other] then return Operations.intrinsicError("TypeError", "contains requires a registered source Node") end
	return assert(implementations[kind], "This Node kind has no native implementation").contains(owner, other)
end
local constructorToken = {}
local function nativeElement(value: any): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA("GuiObject")
end
local function kindOf(value: any): Kind?
	return if type(value) == "table" then identities[value] else nil
end
local function member(value: any, kind: string, native: boolean): boolean
	if native and nativeElement(value) then return kind == "node" or kind == "element" or kind == "html" end
	local actual = kindOf(value)
	if kind == "node" then return actual ~= nil end
	if kind == "element" then return actual == "element" or actual == "html" end
	if kind == "fragment" then return actual == "fragment" or actual == "shadow" end
	return actual == kind
end
function DomClasses.kind(value: any): Kind? return kindOf(value) end
function DomClasses.prototype(kind: Kind): any
	return assert(prototypes[kind], "Unknown DOM interface kind")
end
-- Public fields cannot establish the renderer's identity. Registration is weak
-- and contains no per-owner callbacks or values that can root its key.
function DomClasses.register<T>(value: T, kind: Kind): T
	assert(type(value) == "table", "DOM identities require a renderer-owned proxy")
	local implementation = implementations[kind]
	local nodeType: any = if implementation then implementation.read(value, "nodeType") else (value :: any).nodeType
	local expected = if kind == "html" or kind == "element" then 1 elseif kind == "document" then 9
		elseif kind == "fragment" or kind == "shadow" then 11 else nodeType
	assert(type(nodeType) == "number" and nodeType % 1 == 0 and nodeType >= 1 and nodeType <= 12 and nodeType == expected,
		"DOM class registration disagrees with the native node kind")
	if kind == "shadow" then assert(member((value :: any).host, "element", false), "A shadow root requires a registered Element host") end
	identities[value] = kind
	return value :: T
end
local function state(owner: any): any
	local meta = if type(owner) == "table" then getmetatable(owner) else nil
	return assert(if type(meta) == "table" then rawget(meta, constructorToken) else nil, "Illegal DOM interface receiver")
end
local constructorSchema: Operations.NativeObject = {
	tag = "Function",
	hasOwn = function(owner: any, key: any): boolean return Records.hasOwn(state(owner).fields, key) end,
	get = function(owner: any, key: any, receiver: any): any return Records.readOwn(state(owner).fields, key, receiver) end,
	ownKeys = function(owner: any): any return Records.ownKeys(state(owner).fields) end,
	enumerable = function(owner: any, key: any): boolean
		local desc = Records.descriptor(state(owner).fields, key)
		return desc ~= nil and desc.enumerable
	end,
	getOwnPropertyDescriptor = function(owner: any, key: any): any return Operations.getOwnPropertyDescriptor(state(owner).fields, key) end,
	properties = function(owner: any): any return state(owner).fields end,
	prototype = function(owner: any): any
		local current = state(owner)
		local explicit, parent = Records.getPrototype(current.fields)
		return if explicit then parent else current.parent
	end,
	call = function(owner: any): never return state(owner).nativeNew() end,
	ordinaryHasInstance = function(_owner: any, value: any): boolean?
		return if typeof(value) == "Instance" then false else nil
	end,
}
local function constructor(name: string, kind: Kind, parent: any?): any
	local prototype = Operations.object(if parent then Operations.get(parent, "prototype") else nil)
	prototypes[kind] = prototype
	local fields = Operations.object()
	local owner: any = {}
	local definition: any = { fields = fields, parent = parent or Operations.getPrototype(Operations.functionValue(function() end, "", 0, "method")) }
	local function illegal(): never
		if kind == "document" or kind == "fragment" then
			error("Native capability required: detached " .. name .. " construction is not implemented", 2)
		end
		return Operations.intrinsicError("TypeError", "Illegal constructor: " .. name)
	end
	-- These SDK gateways have explicit ABIs and are excluded from source keys.
	definition.nativeNew = illegal
	definition.nativeInstanceof = function(value: any): boolean return member(value, kind, true) end
	definition.dispatch = illegal
	setmetatable(owner, { [constructorToken] = definition, __call = illegal,
		__index = function(self: any, key: any): any
			local current = state(self)
			if key == "new" then return current.nativeNew end
			if key == "instanceof" then return current.nativeInstanceof end
			return Operations.get(self, key)
		end })
	SourceType.register(owner, "function")
	Operations.defineDataProperty(fields, "name", name, false, false, true)
	Operations.defineDataProperty(fields, "length", 0, false, false, true)
	Operations.defineDataProperty(fields, "prototype", prototype, false, false, false)
	Operations.defineDataProperty(prototype, "constructor", owner, true, false, true)
	Operations.defineDataProperty(prototype, Symbols.Symbol.toStringTag, name, false, false, true)
	Records.setReceiver(fields, owner)
	Functions.callable(owner, fields, definition.dispatch)
	Operations.registerObject(owner, constructorSchema)
	-- The canonical owner anchors this lease for the module's intrinsic lifetime.
	definition.constructorLease = Operations.registerConstructor(owner, illegal)
	return owner
end
DomClasses.Node = constructor("Node", "node", nil)
DomClasses.Element = constructor("Element", "element", DomClasses.Node)
DomClasses.HTMLElement = constructor("HTMLElement", "html", DomClasses.Element)
local DocumentFragment = constructor("DocumentFragment", "fragment", DomClasses.Node)
DomClasses.ShadowRoot = constructor("ShadowRoot", "shadow", DocumentFragment)
DomClasses.Document = constructor("Document", "document", DomClasses.Node)
for name, value in {
	DOCUMENT_POSITION_DISCONNECTED = 1, DOCUMENT_POSITION_PRECEDING = 2,
	DOCUMENT_POSITION_FOLLOWING = 4, DOCUMENT_POSITION_CONTAINS = 8,
	DOCUMENT_POSITION_CONTAINED_BY = 16, DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 32,
} do
	for _, owner in { DomClasses.Node, DomClasses.Element, prototypes.node, prototypes.element, prototypes.document } do
		Operations.defineDataProperty(owner, name, value, false, true, false)
	end
end
return DomClasses
