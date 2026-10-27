--!strict
-- Standard Error data/prototypes. Host stack text deliberately remains a Luau
-- traceback; Node-only captureStackTrace/prepareStackTrace APIs are not supplied.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local SourceType = require(script.Parent.SourceType)
local Functions = require(script.Parent.FunctionValues)
local Symbols = require(script.Parent.SourceSymbols)
local Errors = {}
local stateToken = {}
local domExceptionCodes = {
	INDEX_SIZE_ERR=1, DOMSTRING_SIZE_ERR=2, HIERARCHY_REQUEST_ERR=3, WRONG_DOCUMENT_ERR=4,
	INVALID_CHARACTER_ERR=5, NO_DATA_ALLOWED_ERR=6, NO_MODIFICATION_ALLOWED_ERR=7, NOT_FOUND_ERR=8,
	NOT_SUPPORTED_ERR=9, INUSE_ATTRIBUTE_ERR=10, INVALID_STATE_ERR=11, SYNTAX_ERR=12,
	INVALID_MODIFICATION_ERR=13, NAMESPACE_ERR=14, INVALID_ACCESS_ERR=15, VALIDATION_ERR=16,
	TYPE_MISMATCH_ERR=17, SECURITY_ERR=18, NETWORK_ERR=19, ABORT_ERR=20, URL_MISMATCH_ERR=21,
	QUOTA_EXCEEDED_ERR=22, TIMEOUT_ERR=23, INVALID_NODE_TYPE_ERR=24, DATA_CLONE_ERR=25,
}
local domExceptionNameCodes = {
	IndexSizeError=1, HierarchyRequestError=3, WrongDocumentError=4, InvalidCharacterError=5,
	NoModificationAllowedError=7, NotFoundError=8, NotSupportedError=9, InUseAttributeError=10,
	InvalidStateError=11, SyntaxError=12, InvalidModificationError=13, NamespaceError=14,
	InvalidAccessError=15, TypeMismatchError=17, SecurityError=18, NetworkError=19,
	AbortError=20, URLMismatchError=21, QuotaExceededError=22, TimeoutError=23,
	InvalidNodeTypeError=24, DataCloneError=25,
}
local function stateOf(value: any): any
	return (getmetatable(value) :: any)[stateToken]
end
local function object(value: any): boolean
	local kind = SourceType.typeOf(value)
	return not Nulls.isNull(value) and (kind == "object" or kind == "function")
end
local function packet(...: any): any
	return Arrays.adopt({ ... }, select("#", ...))
end
local function construct(constructor: any, args: any, newTarget: any): any
	local state = stateOf(constructor)
	assert(not state.realm.closed, "Source Error realm is destroyed")
	local ops = state.ops
	local parent = ops.get(newTarget, "prototype")
	local result = ops.object(if object(parent) then parent else state.instancePrototype)
	local isDOMException = state.name == "DOMException"
	ops.setIntrinsicTag(result, if isDOMException then "DOMException" else "Error")
	-- Stack is host-owned nonstandard data, not a browser/V8 stack simulation.
	ops.defineDataProperty(result, "stack", debug.traceback("", 2), true, false, true)
	if isDOMException then
		local message = if args[1] == nil then "" else ops.string(args[1])
		local name = if args[2] == nil then "Error" else ops.string(args[2])
		ops.defineDataProperty(result, "message", message, false, false, true)
		ops.defineDataProperty(result, "name", name, false, false, true)
		ops.defineDataProperty(result, "code", domExceptionNameCodes[name] or 0, false, false, true)
	elseif args[1] ~= nil then
		ops.defineDataProperty(result, "message", ops.string(args[1]), true, false, true)
	end
	if not isDOMException then
		local options = args[2]
		if object(options) and ops.binary("in", "cause", options) then
			ops.defineDataProperty(result, "cause", ops.get(options, "cause"), true, false, true)
		end
	end
	return result
end
-- Shared schemas/callbacks recover private state from the live owner. Global
-- weak registries never acquire a closure pointing back to their own key.
local constructorSchema = {
	tag = "Function",
	hasOwn = function(owner: any, key: any): boolean
		return Records.hasOwn(stateOf(owner).fields, key)
	end,
	get = function(owner: any, key: any): any
		local state = stateOf(owner)
		return state.ops.get(state.fields, key)
	end,
	ownKeys = function(owner: any): any
		return Records.ownKeys(stateOf(owner).fields)
	end,
	enumerable = function(owner: any, key: any): boolean
		local state = stateOf(owner)
		local descriptor = state.ops.getOwnPropertyDescriptor(state.fields, key)
		return descriptor ~= nil and descriptor.enumerable == true
	end,
	getOwnPropertyDescriptor = function(owner: any, key: any): any
		local state = stateOf(owner)
		return state.ops.getOwnPropertyDescriptor(state.fields, key)
	end,
	prototype = function(owner: any): any
		return stateOf(owner).constructorPrototype
	end,
	call = function(owner: any, _receiver: any, args: any): any
		local state = stateOf(owner)
		if state.name == "DOMException" then
			state.ops.raise(construct(state.constructors.TypeError,
				packet("Class constructor DOMException cannot be invoked without 'new'"), state.constructors.TypeError))
		end
		return construct(owner, args, owner)
	end,
	set = function(owner: any, key: any, value: any)
		local state = stateOf(owner)
		state.ops.set(state.fields, key, value)
	end,
	define = function(owner: any, key: any, value: any)
		local state = stateOf(owner)
		state.ops.define(state.fields, key, value)
	end,
	remove = function(owner: any, key: any): boolean
		local state = stateOf(owner)
		return state.ops.remove(state.fields, key)
	end,
}
local constructorMetatable = {
	__call = function(owner: any, ...: any): any
		local state = stateOf(owner)
		if state.name == "DOMException" then
			state.ops.raise(construct(state.constructors.TypeError,
				packet("Class constructor DOMException cannot be invoked without 'new'"), state.constructors.TypeError))
		end
		return construct(owner, packet(...), owner)
	end,
	__index = function(owner: any, key: any): any
		local state = stateOf(owner)
		-- Native roblox-ts's new ABI is not an own JavaScript property.
		if key == "new" then return state.nativeNew end
		if key == "instanceof" then return state.nativeInstanceof end
		return state.ops.get(owner, key)
	end,
}

function Errors.create(ops: any): any
	local realm: any = { closed = false }
	local releases: { () -> () } = {}
	local functionPrototype = ops.getPrototype(ops.functionValue(function() end, "", 0, "method"))
	local errorPrototype = ops.object()
	local constructors: any = {}
	for _, name in { "Error", "EvalError", "RangeError", "ReferenceError", "SyntaxError", "TypeError", "URIError", "DOMException" } do
		local prototype = if name == "Error" then errorPrototype else ops.object(errorPrototype)
		local fields = ops.object()
		local state: any = { ops = ops, realm = realm, fields = fields, instancePrototype = prototype,
			name = name, constructors = constructors,
			constructorPrototype = if name == "Error" then functionPrototype else constructors.Error }
		local constructor: any = {}
		local metadata = table.clone(constructorMetatable) :: any
		metadata[stateToken] = state
		setmetatable(constructor, metadata)
		SourceType.register(constructor, "function")
		state.nativeNew = function(...: any): any
			return construct(constructor, packet(...), constructor)
		end
		-- roblox-ts RuntimeLib.instanceof explicitly delegates to this gateway.
		-- It is part of the native ABI, not an own JavaScript property.
		state.nativeInstanceof = function(value: any): boolean
			return ops.binary("instanceof", value, constructor)
		end
		ops.defineDataProperty(fields, "length", if name == "DOMException" then 0 else 1, false, false, true)
		ops.defineDataProperty(fields, "name", name, false, false, true)
		ops.defineDataProperty(fields, "prototype", prototype, false, false, false)
		if name == "DOMException" then
			for constant, code in domExceptionCodes do
				ops.defineDataProperty(fields, constant, code, false, true, false)
			end
		end
		ops.defineDataProperty(prototype, "constructor", constructor, true, false, true)
		ops.defineDataProperty(prototype, "name", if name == "DOMException" then "Error" else name, true, false, true)
		ops.defineDataProperty(prototype, "message", "", true, false, true)
		if name == "DOMException" then
			ops.defineDataProperty(prototype, "code", 0, false, true, false)
			ops.defineDataProperty(prototype, Symbols.Symbol.toStringTag, "DOMException", false, false, true)
			for constant, code in domExceptionCodes do
				ops.defineDataProperty(prototype, constant, code, false, true, false)
			end
		end
		state.callDispatch = function(_receiver: any, args: any): any
			if name == "DOMException" then
				ops.raise(construct(constructors.TypeError,
					packet("Class constructor DOMException cannot be invoked without 'new'"), constructors.TypeError))
			end
			return construct(constructor, args, constructor)
		end
		Records.setReceiver(fields, constructor)
		Functions.callable(constructor, fields, state.callDispatch)
		local releaseObject: () -> () = ops.registerObject(constructor, constructorSchema)
		local releaseConstructor: () -> () = ops.registerConstructor(constructor, construct, true)
		table.insert(releases, releaseObject)
		table.insert(releases, releaseConstructor)
		constructors[name] = constructor
	end
	local toString = ops.functionValue(function(receiver: any): string
		if not object(receiver) then
			ops.raise(construct(constructors.TypeError, packet("Error.prototype.toString requires an object"), constructors.TypeError))
		end
		local name = ops.get(receiver, "name")
		name = if name == nil then "Error" else ops.string(name)
		local message = ops.get(receiver, "message")
		message = if message == nil then "" else ops.string(message)
		return if name == "" then message elseif message == "" then name else name .. ": " .. message
	end, "toString", 0, "method")
	ops.defineDataProperty(errorPrototype, "toString", toString, true, false, true)
	constructors.destroy = function()
		if realm.closed then return end
		realm.closed = true
		for index = #releases, 1, -1 do releases[index]() end
		table.clear(releases)
	end
	return table.freeze(constructors)
end

return Errors
