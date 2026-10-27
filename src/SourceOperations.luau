--!strict
-- Operations on declaration-backed JavaScript values. Native functions and
-- opaque objects enter through explicit ABI/schema registration; the runtime
-- never infers method receivers from an untyped Lua function or __index hook.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Functions = require(script.Parent.FunctionValues)
local SourceType = require(script.Parent.SourceType)
local NumberStrings = require(script.Parent.NumberStrings)
local Values = require(script.Parent.SourceValues)
local Objects = require(script.Parent.SourceObjects)
local Symbols = require(script.Parent.SourceSymbols)
local Strings = require(script.Parent.Strings)
local Regex = require(script.Parent.SourceRegExp)
local Collections = require(script.Parent.SourceCollections)
local Operations = {}
-- A private owner token preserves every thrown JS value, including undefined,
-- without exposing native error()'s string/location conversion to source catch.
local thrownToken = {}
local intrinsicToken = {}
function Operations.intrinsicError(name: string, message: string): never
	error(setmetatable({ kind = name, message = message }, { __metatable = intrinsicToken }), 0)
end
function Operations.inspectIntrinsicError(value: any): any
	return if type(value) == "table" and getmetatable(value) == intrinsicToken then value else nil
end
local function typeError(message: string): never return Operations.intrinsicError("TypeError", message) end
function Operations.wrapThrown(value: any): any
	return setmetatable({ value = value }, { __metatable = thrownToken })
end
function Operations.raise(value: any): never
	error(Operations.wrapThrown(value), 0)
end
function Operations.caught(value: any): any
	return if type(value) == "table" and getmetatable(value) == thrownToken then rawget(value, "value") else value
end
export type NativeObject = {
	tag: string?,
	hasOwn: (any, any) -> boolean,
	get: (any, any, any) -> any,
	ownKeys: (any) -> any,
	enumerable: (any, any) -> boolean,
	prototype: ((any) -> any)?,
	set: ((any, any, any) -> ())?,
	define: ((any, any, any) -> ())?,
	remove: ((any, any) -> boolean)?,
	call: ((any, any, any) -> any)?,
	getOwnPropertyDescriptor: ((any, any) -> any)?,
	properties: ((any) -> any)?,
	ordinaryHasInstance: ((any, any) -> boolean?)?,
}
local nativeObjects: { [any]: NativeObject } = setmetatable({}, { __mode = "k" }) :: any
local nativeCalls: { [any]: (any, any, any) -> any } = setmetatable({}, { __mode = "k" }) :: any
type ConstructorLease = { invoke: (any, any, any) -> any, leases: number, supportsNewTarget: boolean }
local nativeConstructors: { [any]: ConstructorLease } = setmetatable({}, { __mode = "kv" }) :: any
local classToken, frameToken = {}, {}
local function classState(value: any): any
	if type(value) ~= "table" then return nil end
	local meta = getmetatable(value)
	return if type(meta) == "table" then rawget(meta :: any, classToken) else nil
end
local namespaceOwners: { [any]: { schema: NativeObject, leases: number } } = setmetatable({}, { __mode = "k" }) :: any
local regexSchema: NativeObject? = nil
local collectionSchema: NativeObject? = nil
local collectionPrototypes: { [string]: any } = {
	map = Records.adopt({}, {}), set = Records.adopt({}, {}),
	weakmap = Records.adopt({}, {}), weakset = Records.adopt({}, {}),
}
local objectPrototype: any = {}
local functionPrototype: any = {}
local functionHasInstance: any = nil
local arrayPrototype: any = Arrays.adopt({}, 0)
local stringPrototype: any = {}
local numberPrototype: any = {}
local booleanPrototype: any = {}
local symbolPrototype: any = {}
local iteratorPrototype: any = {}
local regexPrototype: any = {}
local arrayValuesMethod: any = nil
local stringValuesMethod: any = nil
local nan = 0 / 0
local sourceFunctions: { [any]: any } = setmetatable({}, { __mode = "kv" }) :: any
local function packet(...: any): any return Arrays.adopt({ ... }, select("#", ...)) end
local function kind(value: any): string return SourceType.typeOf(value) end
local function isObject(value: any): boolean
	local tag = kind(value)
	return not Nulls.isNull(value) and (tag == "object" or tag == "function")
end
local function index(name: any): number?
	if type(name) ~= "string" then return nil end
	local value = tonumber(name)
	return if value and value >= 0 and value < 4294967295 and value % 1 == 0
		and NumberStrings.toString(value) == name then value else nil
end
local function units(value: string): { number }
	assert(utf8.len(value) ~= nil, "JavaScript strings currently require Unicode scalar UTF-8")
	local result = {}
	for _, code in utf8.codes(value) do
		assert(code < 0xD800 or code > 0xDFFF, "Lone UTF-16 surrogates are not represented by this native boundary")
		if code < 0x10000 then table.insert(result, code)
		else
			local scalar = code - 0x10000
			table.insert(result, 0xD800 + math.floor(scalar / 0x400))
			table.insert(result, 0xDC00 + scalar % 0x400)
		end
	end
	return result
end
local function unitString(code: number): string
	assert(code < 0xD800 or code > 0xDFFF, "A lone UTF-16 code unit cannot be represented by the native scalar string boundary")
	return utf8.char(code)
end
local function qualify(value: any)
	if Regex.owns(value) and not nativeObjects[value] then
		nativeObjects[value] = assert(regexSchema, "Native regex schema is not initialized") :: NativeObject
	end
	if Collections.kind(value) and not nativeObjects[value] then
		nativeObjects[value] = assert(collectionSchema, "Native collection schema is not initialized") :: NativeObject
	end
	if type(value) == "table" and not Records.owns(value) and not nativeObjects[value] and getmetatable(value) == nil and rawget(value, "exports") ~= nil and next(value, "exports") == nil then
		Records.adopt(value, { "exports" })
	end
end
local function own(value: any, key: any): boolean
	qualify(value)
	local capability = nativeObjects[value]
	if capability then return capability.hasOwn(value, key) end
	if Arrays.owns(value) then
		local slot = index(key)
		return key == "length" or (slot ~= nil and Arrays.has(value, slot)) or Arrays.hasProperty(value, key)
	end
	if Records.owns(value) then return Records.hasOwn(value, key) end
	if type(value) == "function" then
		local source = sourceFunctions[value]
		return if source then Records.hasOwn(source.properties, key) else Functions.hasOwn(value, key)
	end
	if type(value) == "string" then
		local slot = index(key)
		return key == "length" or slot ~= nil and slot < #units(value)
	end
	if type(value) == "number" or type(value) == "boolean" or kind(value) == "symbol" then return false end
	error("Native object property existence requires an explicit source schema", 3)
end
local function prototype(value: any): any
	qualify(value)
	local capability = nativeObjects[value]
	if capability then return if capability.prototype then capability.prototype(value) else objectPrototype end
	if Arrays.owns(value) then return arrayPrototype end
	if Records.owns(value) then
		local explicit, parent = Records.getPrototype(value)
		return if explicit then parent else objectPrototype
	end
	if type(value) == "function" then
		local source = sourceFunctions[value]
		if source then
			local explicit, parent = Records.getPrototype(source.properties)
			if explicit then return parent end
		end
		return functionPrototype
	end
	if type(value) == "string" then return stringPrototype end
	if type(value) == "number" then return numberPrototype end
	if type(value) == "boolean" then return booleanPrototype end
	if kind(value) == "symbol" then return symbolPrototype end
	error("Native object prototype lookup requires an explicit source schema", 3)
end
function Operations.registerObject(value: any, capability: NativeObject): () -> ()
	assert(isObject(value) and not nativeObjects[value], "Native object schema is already owned or invalid")
	nativeObjects[value] = capability
	return function() if nativeObjects[value] == capability then nativeObjects[value] = nil end end
end
function Operations.registerNative(callback: any, policy: string, name: string?, length: number?): any
	assert(policy == "free" or policy == "method", "Native callable ABI must be free or method")
	return Functions.native(callback, policy == "method", name, length)
end
-- Source-only result conversion is explicit per callable. Direct Lua calls keep
-- their native ABI (including multiple returns); no debug/signature inference.
function Operations.registerCall(callback: any, invoke: (any, any, any) -> any): () -> ()
	assert(type(callback) == "function" and not nativeCalls[callback], "Native source-call adapter is already owned or invalid")
	nativeCalls[callback] = invoke
	return function() if nativeCalls[callback] == invoke then nativeCalls[callback] = nil end end
end
function Operations.registerConstructor(callback: any, invoke: (any, any, any) -> any, supportsNewTarget: boolean?): () -> ()
	assert(isObject(callback) and kind(callback) == "function" and not sourceFunctions[callback], "Native constructor registration requires an explicit native callable")
	assert(type(invoke) == "function", "Native constructor registration requires a construction callback")
	local entry = nativeConstructors[callback]
	if entry then
		assert(entry.invoke == invoke and entry.supportsNewTarget == (supportsNewTarget == true), "Conflicting native constructor capability")
		entry.leases += 1
	else
		entry = { invoke = invoke, leases = 1, supportsNewTarget = supportsNewTarget == true }
		nativeConstructors[callback] = entry
	end
	local owner, lease: any = callback, entry
	return function()
		if not lease then return end
		lease.leases -= 1
		if lease.leases == 0 and nativeConstructors[owner] == lease then nativeConstructors[owner] = nil end
		owner, lease = nil, nil
	end
end
local function constructible(value: any): boolean
	return classState(value) ~= nil or nativeConstructors[value] ~= nil or sourceFunctions[value] ~= nil and sourceFunctions[value].form == "ordinary"
end
function Operations.construct(callback: any, args: any, newTarget: any?): any
	assert(Arrays.owns(args), "Source construction requires an adopted logical argument array")
	local target = if newTarget == nil then callback else newTarget
	if not constructible(target) then typeError("new.target is not a constructor") end
	local class = classState(callback)
	if class then return Operations.constructClass(callback, args, target) end
	local native = nativeConstructors[callback]
	if native then
		if target ~= callback and not native.supportsNewTarget then typeError("Native constructor does not support an alternate new.target") end
		local result = native.invoke(callback, args, target)
		assert(isObject(result), "Native constructor capability must return an object")
		return result
	end
	local source = sourceFunctions[callback]
	if not source or source.form ~= "ordinary" then typeError("Source new target is not a qualified constructor") end
	local parent = Operations.get(target, "prototype")
	local receiver = Operations.object(if isObject(parent) then parent else objectPrototype)
	local result = source.callback(receiver, args, target)
	return if isObject(result) then result else receiver
end
function Operations.call(callback: any, receiver: any, args: any): any
	assert(Arrays.owns(args), "Source invocation requires an adopted logical argument array")
	if classState(callback) then typeError("Class constructors cannot be invoked without new") end
	local invoke = nativeCalls[callback]
	if invoke then return invoke(callback, receiver, args) end
	local capability = nativeObjects[callback]
	if capability and capability.call then return capability.call(callback, receiver, args) end
	assert(type(callback) == "function", "TypeError: source call target is not callable")
	return Functions.invokeChecked(
		Functions.reference(receiver, function() return callback end, "dynamic", false),
		function() return args end,
		false
	)
end
function Operations.functionValue(callback: any, name: string, length: number, form: string): any
	assert(form == "ordinary" or form == "arrow" or form == "method" or form == "asyncOrdinary" or form == "asyncArrow" or form == "asyncMethod", "Unknown source callable kind")
	local state = { callback = callback, form = form, properties = Records.adopt({}, {}) }
	local function dispatch(receiver: any, args: any): any
		return (state.callback :: (any, any, any) -> any)(if state.form == "arrow" or state.form == "asyncArrow" then nil else receiver, args, nil)
	end
	local function value(...: any): any
		if state.form == "method" or state.form == "asyncMethod" then return dispatch((...), packet(select(2, ...))) end
		return dispatch(nil, packet(...))
	end
	Functions.named(value, name, length, form == "method" or form == "asyncMethod")
	Functions.source(value, dispatch, state.properties)
	sourceFunctions[value] = state
	Records.setReceiver(state.properties, value)
	Records.defineDescriptor(state.properties, "length", { kind = "data", value = length, writable = false, enumerable = false, configurable = true })
	Records.defineDescriptor(state.properties, "name", { kind = "data", value = name, writable = false, enumerable = false, configurable = true })
	if form == "ordinary" then
		local parent = Records.adopt({}, {})
		Records.defineDescriptor(parent, "constructor", { kind = "data", value = value, writable = true, enumerable = false, configurable = true })
		Records.defineDescriptor(state.properties, "prototype", { kind = "data", value = parent, writable = true, enumerable = false, configurable = false })
	end
	return value
end
function Operations.asyncFunctionValue(_callback: any, _name: string, _length: number, _form: string): never
	error("Async functions require a SourceRuntime-owned operations provider", 2)
end
function Operations.awaitValue(_value: any): never
	error("Await requires a SourceRuntime-owned asynchronous invocation", 2)
end
local function readOwn(owner: any, key: any, receiver: any): any
	local capability = nativeObjects[owner]
	if capability then return capability.get(owner, key, receiver) end
	if Arrays.owns(owner) then
		if key == "length" then return Arrays.length(owner) end
		local slot = index(key)
		return if slot ~= nil then rawget(owner, slot + 1) else rawget(owner, key)
	end
	if Records.owns(owner) then return Records.readOwn(owner, key, receiver) end
	if type(owner) == "function" then
		local source = sourceFunctions[owner]
		if source then return Records.readOwn(source.properties, key, receiver) end
		return Functions.getProperty(owner, key)
	end
	if type(owner) == "string" then
		local codes = units(owner)
		return if key == "length" then #codes else unitString(codes[assert(index(key)) + 1])
	end
	error("Native property read requires an explicit source schema", 3)
end
function Operations.toPrimitive(value: any, hint: string?): any
	if not isObject(value) then return value end
	local preferred = hint or "default"
	local exotic = Operations.get(value, Symbols.Symbol.toPrimitive)
	if not Nulls.isNullish(exotic) then
		assert(kind(exotic) == "function", "TypeError: Symbol.toPrimitive is not callable")
		local result = Operations.call(exotic, value, packet(preferred))
		assert(not isObject(result), "TypeError: Symbol.toPrimitive returned an object")
		return result
	end
	local names = if preferred == "string" then { "toString", "valueOf" } else { "valueOf", "toString" }
	for _, name in names do
		local method = Operations.get(value, name)
		if kind(method) == "function" then
			local result = Operations.call(method, value, packet())
			if not isObject(result) then return result end
		end
	end
	error("TypeError: cannot convert source object to a primitive", 2)
end
local function keyOf(value: any): any
	local primitive = Operations.toPrimitive(value, "string")
	return if kind(primitive) == "symbol" then primitive else Operations.string(primitive)
end
Operations.key = keyOf
function Operations.get(receiver: any, key: any): any
	assert(not Nulls.isNullish(receiver), "TypeError: cannot read a property of null or undefined")
	local name = keyOf(key)
	local owner, seen = receiver, {}
	while not Nulls.isNullish(owner) do
		if isObject(owner) then
			assert(not seen[owner], "Cyclic source prototype lookup")
			seen[owner] = true
		end
		if own(owner, name) then return readOwn(owner, name, receiver) end
		owner = prototype(owner)
	end
	return nil
end
function Operations.string(value: any): string
	local primitive = Operations.toPrimitive(value, "string")
	local tag = kind(primitive)
	if tag == "symbol" then typeError("Implicit string conversion of a Symbol") end
	return Values.String(primitive)
end
function Operations.number(value: any): number
	local primitive = Operations.toPrimitive(value, "number")
	assert(kind(primitive) ~= "symbol", "TypeError: cannot convert a Symbol to a number")
	return Values.Number(primitive)
end
function Operations.truthy(value: any): boolean return Nulls.truthy(value) end
local function integer(value: any): number
	local number = Operations.number(value)
	return if number ~= number or number == 0 then 0 elseif number < 0 then math.ceil(number) else math.floor(number)
end
local function lengthOf(value: any): number
	return math.clamp(integer(Operations.get(value, "length")), 0, 9007199254740991)
end
local function toLength(value: any): number return math.clamp(integer(value), 0, 9007199254740991) end
-- Ordinary descriptors are stored on the owner's private metatable. Source
-- function properties use a private record whose receiver is the function.
local function storage(value: any): any
	local source = sourceFunctions[value]
	local capability = nativeObjects[value]
	if capability and capability.properties then
		local record = capability.properties(value)
		assert(Records.owns(record), "Native descriptor storage requires an owned source record")
		return record
	end
	return if source then source.properties elseif Records.owns(value) then value else nil
end
local function descriptor(value: any, name: any): any
	if value == functionPrototype and name == Symbols.Symbol.hasInstance then
		return { kind = "data", value = functionHasInstance, writable = false, enumerable = false, configurable = false }
	end
	local record = storage(value)
	return if record then Records.descriptor(record, name) else nil
end
local function applyDescriptor(owner: any, name: any, desc: any): any
	if owner == functionPrototype and name == Symbols.Symbol.hasInstance then
		if desc.kind == "data" and rawequal(desc.value, functionHasInstance) and not desc.writable and not desc.enumerable and not desc.configurable then return owner end
		return typeError("Cannot redefine Function.prototype[Symbol.hasInstance]")
	end
	local record = storage(owner)
	if not record then typeError("Property descriptors require an ordinary source object or function") end
	Records.defineDescriptor(record, name, desc)
	return owner
end
function Operations.set(receiver: any, key: any, value: any): any
	if Nulls.isNullish(receiver) then typeError("Cannot assign a property on null or undefined") end
	local name = keyOf(key)
	if not isObject(receiver) then typeError("Cannot assign a property on a primitive value") end
	if receiver == functionPrototype and name == Symbols.Symbol.hasInstance then return typeError("Cannot assign Function.prototype[Symbol.hasInstance]") end
	qualify(receiver)
	local capability = nativeObjects[receiver]
	if capability and not capability.properties then
		assert(capability.set, "Native object has no registered property mutation API")(receiver, name, value)
		return value
	end
	local owner, visited = receiver, {}
	while not Nulls.isNullish(owner) do
		if visited[owner] then typeError("Cyclic source prototype mutation") end
		visited[owner] = true
		local desc = descriptor(owner, name)
		if desc then
			if desc.kind == "accessor" then
				if desc.set == nil then typeError("Cannot assign a property without a setter") end
				Operations.call(desc.set, receiver, packet(value))
				return value
			end
			if not desc.writable then typeError("Cannot assign a non-writable property") end
			break
		elseif own(owner, name) then
			if owner == objectPrototype and name == "__proto__" then
				if isObject(value) or Nulls.isNull(value) then Operations.setPrototype(receiver, value) end
				return value
			end
			break
		end
		owner = prototype(owner)
	end
	local record = storage(receiver)
	if record then
		local current = descriptor(receiver, name)
		if current then
			if current.kind ~= "data" or not current.writable then typeError("Cannot write receiver's property") end
			local updated = table.clone(current)
			updated.value = value
			applyDescriptor(receiver, name, updated)
		else
			applyDescriptor(receiver, name, { kind = "data", value = value, writable = true, enumerable = true, configurable = true })
		end
	elseif Arrays.owns(receiver) then
		if name == "length" then Arrays.setLength(receiver, Operations.number(value))
		else
			local slot = index(name)
			if slot ~= nil then Arrays.set(receiver, slot, value) else Arrays.defineProperty(receiver, name, value) end
		end
	elseif type(receiver) == "function" then Functions.setProperty(receiver, name, value)
	else error("Native object mutation requires an explicit source schema", 2) end
	return value
end
function Operations.defineDataProperty(receiver: any, key: any, value: any, writable: boolean, enumerable: boolean, configurable: boolean): any
	local name = keyOf(key)
	return applyDescriptor(receiver, name, { kind = "data", value = value, writable = writable, enumerable = enumerable, configurable = configurable })
end
function Operations.define(receiver: any, key: any, value: any): any
	local name = keyOf(key)
	qualify(receiver)
	local capability = nativeObjects[receiver]
	if capability and not capability.properties then
		assert(capability.define, "Native own property definition requires a registered mutation API")(receiver, name, value)
	elseif storage(receiver) then Operations.defineDataProperty(receiver, name, value, true, true, true)
	elseif Arrays.owns(receiver) then
		local slot = index(name)
		if slot ~= nil then Arrays.set(receiver, slot, value) else Arrays.defineProperty(receiver, name, value) end
	else typeError("Own data definition requires a source object or array") end
	return value
end
Operations.defineField = Operations.define
function Operations.namedValue(value: any, key: any, prefix: string?): any
	if kind(value) ~= "function" then return value end
	local name = keyOf(key)
	if kind(name) == "symbol" then
		local description = Symbols.description(name)
		name = if description == nil then "" else "[" .. description .. "]"
	end
	name = (prefix or "") .. name
	if storage(value) then Operations.defineDataProperty(value, "name", name, false, false, true)
	elseif type(value) == "function" then Functions.named(value, name) end
	return value
end
function Operations.defineMethod(owner: any, key: any, value: any): any
	local name = keyOf(key)
	Operations.namedValue(value, name)
	Operations.defineDataProperty(owner, name, value, true, false, true)
	return value
end
function Operations.defineAccessor(owner: any, key: any, get: any, set: any, enumerable: boolean, configurable: boolean?): any
	local name = keyOf(key)
	if get ~= nil and kind(get) ~= "function" or set ~= nil and kind(set) ~= "function" then typeError("Accessor must be callable or undefined") end
	local previous = descriptor(owner, name)
	if get ~= nil then Operations.namedValue(get, name, "get ") elseif previous and previous.kind == "accessor" then get = previous.get end
	if set ~= nil then Operations.namedValue(set, name, "set ") elseif previous and previous.kind == "accessor" then set = previous.set end
	return applyDescriptor(owner, name, { kind = "accessor", get = get, set = set, enumerable = enumerable, configurable = configurable ~= false })
end
function Operations.getOwnPropertyDescriptor(owner: any, key: any): any
	Operations.requireObject(owner)
	local name = keyOf(key)
	qualify(owner)
	local capability = nativeObjects[owner]
	-- This exact intrinsic descriptor does not qualify full opaque builtin
	-- reflection (which would also require all other Function prototype fields).
	if owner == functionPrototype and name == Symbols.Symbol.hasInstance then
		return Records.adopt({ value = Operations.get(owner, name), writable = false, enumerable = false, configurable = false },
			{ "value", "writable", "enumerable", "configurable" })
	end
	if capability then return assert(capability.getOwnPropertyDescriptor, "Native property descriptor reflection is not qualified")(owner, name) end
	local desc = descriptor(owner, name)
	if not desc then
		if not own(owner, name) then return nil end
		if Arrays.owns(owner) then
			desc = { kind = "data", value = readOwn(owner, name, owner), writable = true, enumerable = name ~= "length", configurable = name ~= "length" }
		elseif type(owner) == "string" then
			desc = { kind = "data", value = readOwn(owner, name, owner), writable = false, enumerable = name ~= "length", configurable = false }
		else error("Native property descriptor reflection is not qualified", 2) end
	end
	local result = Operations.object()
	if desc.kind == "data" then Operations.define(result, "value", desc.value); Operations.define(result, "writable", desc.writable)
	else Operations.define(result, "get", desc.get); Operations.define(result, "set", desc.set) end
	Operations.define(result, "enumerable", desc.enumerable)
	Operations.define(result, "configurable", desc.configurable)
	return result
end
function Operations.remove(receiver: any, key: any): boolean
	if Nulls.isNullish(receiver) then typeError("Cannot delete a property of null or undefined") end
	local name = keyOf(key)
	if receiver == functionPrototype and name == Symbols.Symbol.hasInstance then return typeError("Cannot delete Function.prototype[Symbol.hasInstance]") end
	qualify(receiver)
	local capability = nativeObjects[receiver]
	if capability and not capability.properties then return assert(capability.remove, "Native object has no registered deletion API")(receiver, name) end
	local record = storage(receiver)
	if record then return Records.remove(record, name) end
	if Arrays.owns(receiver) then
		if name == "length" then typeError("Array length is not configurable") end
		local slot = index(name)
		return if slot ~= nil then Arrays.remove(receiver, slot) else Arrays.removeProperty(receiver, name)
	end
	if type(receiver) == "function" then return Functions.removeProperty(receiver, name) end
	if type(receiver) == "string" and own(receiver, name) then typeError("String index/length is not configurable") end
	return true
end
Operations["delete"] = Operations.remove
function Operations.object(parent: any?): any
	local value = Records.adopt({}, {})
	if parent ~= nil then Operations.setPrototype(value, parent) end
	return value
end
function Operations.getPrototype(value: any): any
	Operations.requireObject(value)
	return prototype(value)
end
function Operations.setPrototype(value: any, parent: any): any
	local record = storage(value)
	if not record or not (isObject(parent) or Nulls.isNull(parent)) then typeError("setPrototype requires a source record and object/null prototype") end
	if rawequal(prototype(value), parent) then return value end
	local current, seen = parent, {}
	while not Nulls.isNullish(current) do
		if current == value or seen[current] then typeError("Cyclic source prototype chain") end
		seen[current] = true
		current = prototype(current)
	end
	Records.setPrototype(record, parent)
	return value
end
function Operations.setIntrinsicTag(value: any, tag: string): any
	local record = storage(value)
	if not record then typeError("Intrinsic tags require an ordinary source object") end
	Records.setTag(record, tag)
	return value
end
function Operations.argumentsObject(args: any, strict: boolean?): any
	return require(script.Parent.SourceArguments).create(Operations, args, strict)
end
local function frameOf(frame: any): any
	if type(frame) ~= "table" or getmetatable(frame) ~= frameToken then typeError("Invalid constructor frame") end
	return frame
end
function Operations.classThis(frame: any): any
	frame = frameOf(frame)
	if not frame.bound then Operations.intrinsicError("ReferenceError", "Must call super constructor before accessing this") end
	return frame.receiver
end
function Operations.classNewTarget(frame: any): any return frameOf(frame).newTarget end
function Operations.superConstruct(frame: any, args: any): any
	frame = frameOf(frame)
	if not frame.class.derived then typeError("super construction requires a derived constructor") end
	local receiver = Operations.construct(prototype(frame.class.constructor), args, frame.newTarget)
	-- The superclass's side effects happen even for a duplicate super call.
	if frame.bound then Operations.intrinsicError("ReferenceError", "Super constructor may only be called once") end
	frame.receiver, frame.bound = receiver, true
	if frame.class.fields then (frame.class.fields :: any)(receiver) end
	return receiver
end
function Operations.constructClass(ctor: any, args: any, target: any): any
	local class = assert(classState(ctor))
	local frame = setmetatable({ class = class, newTarget = target, bound = false, receiver = nil :: any }, frameToken)
	if not class.derived then
		local parent = Operations.get(target, "prototype")
		frame.receiver, frame.bound = Operations.object(if isObject(parent) then parent else objectPrototype), true
		if class.fields then (class.fields :: any)(frame.receiver) end
	end
	local result: any
	if class.callback then result = (class.callback :: any)(frame, args)
	elseif class.derived then result = Operations.superConstruct(frame, args) end
	if isObject(result) then return result end
	if class.derived and result ~= nil then typeError("Derived constructors may only return object or undefined") end
	return Operations.classThis(frame)
end
function Operations.classValue(name: string, base: any, derived: boolean, callback: any, fields: any, length: number): any
	local parent, constructorParent = objectPrototype, functionPrototype
	if derived then
		if Nulls.isNull(base) then parent = Nulls.value
		else
			if not constructible(base) then typeError("Class extends value is not a constructor or null") end
			parent = Operations.get(base, "prototype")
			if not isObject(parent) and not Nulls.isNull(parent) then typeError("Superclass prototype is not an object or null") end
			constructorParent = base
		end
	end
	local ctor = Operations.object(constructorParent)
	SourceType.register(ctor, "function")
	local state = { constructor = ctor, derived = derived, callback = callback, fields = fields }
	local meta = table.clone(getmetatable(ctor) :: any)
	meta[classToken] = state
	meta.__call = function(): never return typeError("Class constructors cannot be invoked without new") end
	setmetatable(ctor, meta)
	Functions.callable(ctor, ctor, meta.__call)
	-- Explicit native SDK gateways stay separate from the source property ledger.
	Records.nativeProperty(ctor, "new", function(...: any): any return Operations.construct(ctor, packet(...)) end)
	Records.nativeProperty(ctor, "instanceof", function(value: any): boolean return Operations.binary("instanceof", value, ctor) end)
	local instancePrototype = Operations.object(parent)
	Operations.defineDataProperty(instancePrototype, "constructor", ctor, true, false, true)
	Operations.defineDataProperty(ctor, "length", length, false, false, true)
	Operations.defineDataProperty(ctor, "name", name, false, false, true)
	Operations.defineDataProperty(ctor, "prototype", instancePrototype, false, false, false)
	return ctor
end
local function ownKeys(value: any): any
	qualify(value)
	local capability = nativeObjects[value]
	if capability then return capability.ownKeys(value) end
	if Arrays.owns(value) then return Arrays.ownKeys(value) end
	if Records.owns(value) then return Records.ownKeys(value) end
	if type(value) == "function" then
		if sourceFunctions[value] then return Records.ownKeys(sourceFunctions[value].properties) end
		local keys = packet("length", "name")
		Arrays.pushItems(keys, Functions.ownKeys(value))
		return keys
	end
	if type(value) == "string" then
		local keys = Arrays.adopt({}, 0)
		for position = 0, #units(value) - 1 do Arrays.push(keys, NumberStrings.toString(position)) end
		Arrays.push(keys, "length")
		return keys
	end
	if type(value) == "number" or type(value) == "boolean" or kind(value) == "symbol" then return packet() end
	error("Native object enumeration requires an explicit source schema", 3)
end
local function enumerable(value: any, key: any): boolean
	qualify(value)
	local capability = nativeObjects[value]
	if capability then return capability.enumerable(value, key) end
	if Arrays.owns(value) or type(value) == "string" then return key ~= "length" and own(value, key) end
	local desc = descriptor(value, key)
	if desc then return desc.enumerable end
	if type(value) == "function" then return key ~= "length" and key ~= "name" and Functions.hasOwn(value, key) end
	return false
end
function Operations.keys(value: any): any
	local result, seen, visited = Arrays.adopt({}, 0), {}, {}
	local owner = value
	while not Nulls.isNullish(owner) do
		if isObject(owner) then
			assert(not visited[owner], "Cyclic source prototype enumeration")
			visited[owner] = true
		end
		for _, name in ownKeys(owner) do
			if type(name) == "string" and not seen[name] then
				seen[name] = true
				if enumerable(owner, name) then Arrays.push(result, name) end
			end
		end
		owner = prototype(owner)
	end
	return result
end
function Operations.array(values: any, length: number, holes: any?): any return Arrays.literal(values, length, holes) end
function Operations.arrayPush(value: any, item: any) Arrays.push(value, item) end
function Operations.arrayHole(value: any) Arrays.setLength(value, Arrays.length(value) + 1) end
function Operations.arraySpread(value: any, input: any)
	local iterator = Operations.iterable(input)
	while true do
		local step = iterator.next(iterator)
		if step.done then break end
		Arrays.push(value, step.value)
	end
end
function Operations.spreadObject(target: any, source: any)
	if Nulls.isNullish(source) then return end
	for _, name in ownKeys(source) do
		if enumerable(source, name) then Operations.define(target, name, Operations.get(source, name)) end
	end
end
local bindingIdentities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Operations.binding(form: string, name: string): any
	assert(form == "var" or form == "let" or form == "const", "Unknown lexical binding kind")
	local cell = { form = form, name = name, initialized = form == "var", value = nil :: any }
	bindingIdentities[cell] = true
	return cell
end
local function cellOf(cell: any): any
	assert(bindingIdentities[cell], "Invalid source lexical binding")
	return cell
end
function Operations.initialize(cell: any, value: any): any
	cell = cellOf(cell)
	assert(cell.form == "var" or not cell.initialized, `Source binding {cell.name} is already initialized`)
	cell.initialized, cell.value = true, value
	return value
end
function Operations.read(cell: any): any
	cell = cellOf(cell)
	if not cell.initialized then Operations.intrinsicError("ReferenceError", `Cannot access {cell.name} before initialization`) end
	return cell.value
end
function Operations.write(cell: any, value: any): any
	cell = cellOf(cell)
	if not cell.initialized then Operations.intrinsicError("ReferenceError", `Cannot access {cell.name} before initialization`) end
	if cell.form == "const" then typeError(`Assignment to constant binding {cell.name}`) end
	cell.value = value
	return value
end

function Operations.requireObject(value: any)
	assert(not Nulls.isNullish(value), "TypeError: cannot destructure null or undefined")
end
function Operations.objectRest(value: any, exclusions: any): any
	Operations.requireObject(value)
	local skipped = {}
	for _, excluded in exclusions do skipped[keyOf(excluded)] = true end
	local result = Operations.object()
	for _, name in ownKeys(value) do
		if not skipped[name] and enumerable(value, name) then Operations.define(result, name, Operations.get(value, name)) end
	end
	return result
end
local function uint32(value: any): number
	local number = Operations.number(value)
	if number ~= number or number == 0 or math.abs(number) == math.huge then return 0 end
	return (if number < 0 then math.ceil(number) else math.floor(number)) % 4294967296
end
local function signed(value: number): number return if value >= 2147483648 then value - 4294967296 else value end
function Operations.unary(operator: string, value: any): any
	if operator == "typeof" then return kind(value) end
	if operator == "void" then return nil end
	if operator == "!" then return not Nulls.truthy(value) end
	if operator == "~" then return signed(bit32.bnot(uint32(value))) end
	if operator == "+" or operator == "numeric" then return Operations.number(value) end
	if operator == "-" then return -Operations.number(value) end
	if operator == "++" then return Operations.number(value) + 1 end
	if operator == "--" then return Operations.number(value) - 1 end
	error(`Unsupported JavaScript unary operator {operator}`, 2)
end
local function strictEqual(left: any, right: any): boolean
	if kind(left) ~= kind(right) then return false end
	if type(left) == "number" and (left ~= left or right ~= right) then return false end
	return rawequal(left, right)
end
local function looseEqual(left: any, right: any): boolean
	local a, b = kind(left), kind(right)
	if a == b then return strictEqual(left, right) end
	if Nulls.isNullish(left) and Nulls.isNullish(right) then return true end
	if a == "number" and b == "string" then return looseEqual(left, Operations.number(right)) end
	if a == "string" and b == "number" then return looseEqual(Operations.number(left), right) end
	if a == "boolean" then return looseEqual(Operations.number(left), right) end
	if b == "boolean" then return looseEqual(left, Operations.number(right)) end
	if isObject(left) and not isObject(right) and not Nulls.isNullish(right) then return looseEqual(Operations.toPrimitive(left), right) end
	if isObject(right) and not isObject(left) and not Nulls.isNullish(left) then return looseEqual(left, Operations.toPrimitive(right)) end
	return false
end
local function less(left: any, right: any): boolean?
	if type(left) == "string" and type(right) == "string" then
		local a, b = units(left), units(right)
		for at = 1, math.min(#a, #b) do
			if a[at] ~= b[at] then return a[at] < b[at] end
		end
		return #a < #b
	end
	local a, b = Operations.number(left), Operations.number(right)
	if a ~= a or b ~= b then return nil end
	return a < b
end
-- ECMAScript OrdinaryHasInstance. Native schemas may handle an explicit
-- host-only value; nil delegates to this same source prototype traversal.
local function ordinaryHasInstance(constructor: any, value: any): boolean
	if kind(constructor) ~= "function" then return false end
	if not isObject(value) then return false end
	local capability = nativeObjects[constructor]
	if capability and capability.ordinaryHasInstance then
		local handled = capability.ordinaryHasInstance(constructor, value)
		if handled ~= nil then
			assert(type(handled) == "boolean", "Native OrdinaryHasInstance hook must return boolean or nil")
			return handled
		end
	end
	local source = sourceFunctions[constructor]
	assert(not source or not source.boundInstanceofUnsupported, "Bound-function instanceof requires qualified bound-target semantics")
	local expected = Operations.get(constructor, "prototype")
	if not isObject(expected) then return typeError("Constructor prototype is not an object") end
	local current, seen = prototype(value), {}
	while not Nulls.isNullish(current) do
		if rawequal(current, expected) then return true end
		assert(not seen[current], "Cyclic source prototype lookup")
		seen[current], current = true, prototype(current)
	end
	return false
end
function Operations.binary(operator: string, left: any, right: any): any
	if operator == "===" then return strictEqual(left, right) end
	if operator == "!==" then return not strictEqual(left, right) end
	if operator == "==" then return looseEqual(left, right) end
	if operator == "!=" then return not looseEqual(left, right) end
	if operator == "in" then
		assert(isObject(right), "TypeError: the right operand of in must be an object")
		local name, current, seen = keyOf(left), right, {}
		while not Nulls.isNullish(current) do
			assert(not seen[current], "Cyclic source prototype lookup")
			seen[current] = true
			if own(current, name) then return true end
			current = prototype(current)
		end
		return false
	end
	if operator == "instanceof" then
		if not isObject(right) then return typeError("instanceof requires an object constructor") end
		local method = Operations.get(right, Symbols.Symbol.hasInstance)
		if not Nulls.isNullish(method) then
			if kind(method) ~= "function" then return typeError("Symbol.hasInstance must be callable") end
			return Nulls.truthy(Operations.call(method, right, packet(left)))
		end
		if kind(right) ~= "function" then return typeError("instanceof requires a callable constructor") end
		return ordinaryHasInstance(right, left)
	end
	if operator == "+" then
		local a = Operations.toPrimitive(left)
		local b = Operations.toPrimitive(right)
		if type(a) == "string" or type(b) == "string" then return Operations.string(a) .. Operations.string(b) end
		return Operations.number(a) + Operations.number(b)
	end
	if operator == "<" or operator == ">" or operator == "<=" or operator == ">=" then
		local a = Operations.toPrimitive(left, "number")
		local b = Operations.toPrimitive(right, "number")
		local result = if operator == "<" or operator == ">=" then less(a, b) else less(b, a)
		if result == nil then return false end
		return if operator == "<=" or operator == ">=" then not result else result
	end
	if operator == "&" then return signed(bit32.band(uint32(left), uint32(right))) end
	if operator == "|" then return signed(bit32.bor(uint32(left), uint32(right))) end
	if operator == "^" then return signed(bit32.bxor(uint32(left), uint32(right))) end
	if operator == "<<" then return signed(bit32.lshift(uint32(left), uint32(right) % 32)) end
	if operator == ">>" then return signed(bit32.arshift(uint32(left), uint32(right) % 32)) end
	if operator == ">>>" then return bit32.rshift(uint32(left), uint32(right) % 32) end
	local a = Operations.number(left)
	local b = Operations.number(right)
	if operator == "-" then return a - b end
	if operator == "*" then return a * b end
	if operator == "/" then return a / b end
	if operator == "%" then return math.fmod(a, b) end
	if operator == "**" then
		if b == 0 then return 1 end
		if a ~= a or b ~= b or math.abs(a) == 1 and math.abs(b) == math.huge then return nan end
		if a < 0 and math.abs(a) ~= math.huge and b % 1 ~= 0 and math.abs(b) ~= math.huge then return nan end
		return a ^ b
	end
	error(`Unsupported JavaScript binary operator {operator}`, 2)
end
local nativeNextMethod: any = nil
local function nativeIterator(iterator: any): any
	if not nativeObjects[iterator] then
		Operations.registerObject(iterator, {
			hasOwn = function(_owner, key) return key == "next" end,
			get = function(_owner, _key, _receiver) return nativeNextMethod end,
			ownKeys = function() return packet("next") end,
			enumerable = function() return false end,
			prototype = function() return iteratorPrototype end,
		})
	end
	return iterator
end
local function iterableFrom(value: any, method: any): any
	assert(not Nulls.isNullish(value), "TypeError: null or undefined is not iterable")
	if Arrays.owns(value) and method == arrayValuesMethod then return nativeIterator(Arrays.values(value)) end
	if type(value) == "string" and method == stringValuesMethod then
		local text = value :: string
		local cursor = 1
		return nativeIterator({ next = function()
			if cursor > #text then return { done = true } end
			local following = utf8.offset(text, 2, cursor) or #text + 1
			local item = text:sub(cursor, following - 1)
			cursor = following
			return { done = false, value = item }
		end })
	end
	assert(kind(method) == "function", "TypeError: source value has no callable Symbol.iterator")
	local iterator = Operations.call(method, value, packet())
	assert(isObject(iterator), "TypeError: Symbol.iterator returned a primitive")
	local nextMethod = Operations.get(iterator, "next")
	local done = false
	return {
		next = function()
			if done then return { done = true } end
			local result = Operations.call(nextMethod, iterator, packet())
			assert(isObject(result), "TypeError: iterator.next returned a primitive")
			done = Nulls.truthy(Operations.get(result, "done"))
			return if done then { done = true } else { done = false, value = Operations.get(result, "value") }
		end,
		close = function()
			if done then return end
			done = true
			local finish = Operations.get(iterator, "return")
			if not Nulls.isNullish(finish) then
				assert(isObject(Operations.call(finish, iterator, packet())), "TypeError: iterator.return returned a primitive")
			end
		end,
	}
end
function Operations.iterable(value: any, method: any?): any
	assert(not Nulls.isNullish(value), "TypeError: null or undefined is not iterable")
	return iterableFrom(value, if method ~= nil then method else Operations.get(value, Symbols.Symbol.iterator))
end
local iteratorIdentities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Operations.iterator(value: any): any
	local cursor = { generator = Operations.iterable(value), done = false }
	iteratorIdentities[cursor] = true
	return cursor
end
function Operations.next(cursor: any): any
	assert(iteratorIdentities[cursor], "Invalid source destructuring iterator")
	if cursor.done then return nil end
	local ok, step = pcall(cursor.generator.next, cursor.generator)
	if not ok then cursor.done = true; error(step, 0) end
	cursor.done = step.done == true
	return if cursor.done then nil else step.value
end
function Operations.close(cursor: any, abrupt: boolean?)
	assert(iteratorIdentities[cursor], "Invalid source destructuring iterator")
	if cursor.done then return end
	cursor.done = true
	if cursor.generator.close then
		if abrupt then pcall(cursor.generator.close) else cursor.generator.close() end
	end
end
function Operations.iteratorRest(cursor: any): any
	local result = Arrays.adopt({}, 0)
	while not cursor.done do
		local value = Operations.next(cursor)
		if not cursor.done then Arrays.push(result, value) end
	end
	return result
end

local function namesOf(fields: any): any
	local names = {}
	for name in next, fields do table.insert(names, name) end
	table.sort(names, function(a, b) return tostring(a) < tostring(b) end)
	return Arrays.adopt(names, #names)
end
local function builtin(value: any, fields: any, parent: any, callable: ((any, any, any) -> any)?): () -> ()
	local names = namesOf(fields)
	return Operations.registerObject(value, {
		hasOwn = function(_owner, key) return rawget(fields, key) ~= nil end,
		get = function(_owner, key, receiver)
			if value == objectPrototype and key == "__proto__" then return prototype(receiver) end
			if value == arrayPrototype and key == "length" then return Arrays.length(arrayPrototype) end
			return rawget(fields, key)
		end,
		ownKeys = function() return names end,
		enumerable = function() return false end,
		prototype = function() return parent end,
		call = callable,
	})
end
local function method(fields: any, name: any, arity: number, callback: any): any
	local value = Operations.registerNative(callback, "method", if type(name) == "string" then name else "[Symbol]", arity)
	fields[name] = value
	return value
end
local function static(fields: any, name: string, arity: number, callback: any): any
	local value = Operations.registerNative(callback, "free", name, arity)
	fields[name] = value
	return value
end
function Operations.regexp(pattern: string, flags: string): any
	local value = Regex.create(pattern, flags)
	qualify(value)
	return value
end
local function regexExec(receiver: any, input: any): any
	assert(Regex.owns(receiver), "TypeError: RegExp.exec requires a regular-expression receiver")
	local subject = Operations.string(input)
	local lastIndex = toLength(Regex.read(receiver, "lastIndex"))
	return Regex.exec(receiver, subject, lastIndex)
end
local regexFields: { [any]: any } = { constructor = Regex.Constructor }
local regexAccessors = { source = true, flags = true, global = true, ignoreCase = true, multiline = true,
	dotAll = true, unicode = true, sticky = true, hasIndices = true, unicodeSets = true }
for name in next, regexAccessors do regexFields[name] = true end
local regexExecMethod = method(regexFields, "exec", 1, regexExec)
local function executeRegexWith(receiver: any, subject: string, execute: any): any
	if kind(execute) == "function" then
		local result = Operations.call(execute, receiver, packet(subject))
		assert(isObject(result) or Nulls.isNull(result), "TypeError: RegExp.exec must return an object or null")
		return result
	end
	return regexExec(receiver, subject)
end
local function executeRegex(receiver: any, subject: string): any
	return executeRegexWith(receiver, subject, Operations.get(receiver, "exec"))
end
method(regexFields, "test", 1, function(receiver: any, input: any): boolean
	assert(isObject(receiver), "TypeError: RegExp.test requires an object receiver")
	local subject = Operations.string(input)
	local execute = Operations.get(receiver, "exec")
	if execute == regexExecMethod and Regex.owns(receiver) then
		return Regex.test(receiver, subject, toLength(Regex.read(receiver, "lastIndex")))
	end
	return not Nulls.isNull(executeRegexWith(receiver, subject, execute))
end)
method(regexFields, "toString", 0, function(receiver: any): string
	assert(isObject(receiver), "TypeError: RegExp.toString requires an object")
	return "/" .. Operations.string(Operations.get(receiver, "source")) .. "/" .. Operations.string(Operations.get(receiver, "flags"))
end)
method(regexFields, Symbols.Symbol.match, 1, function(receiver: any, input: any): any
	assert(isObject(receiver), "TypeError: Symbol.match requires an object receiver")
	local subject = Operations.string(input)
	if not Nulls.truthy(Operations.get(receiver, "global")) then return executeRegex(receiver, subject) end
	local unicode = Nulls.truthy(Operations.get(receiver, "unicode")) or Nulls.truthy(Operations.get(receiver, "unicodeSets"))
	Operations.set(receiver, "lastIndex", 0)
	local result, count = packet(), 0
	while true do
		count += 1
		assert(count <= 1000000, "UnsupportedRegExp: global matching exceeded the iteration budget")
		local match = executeRegex(receiver, subject)
		if Nulls.isNull(match) then return if #result == 0 then Nulls.value else result end
		local text = Operations.string(Operations.get(match, 0))
		Arrays.push(result, text)
		if text == "" then
			local lastIndex = toLength(Operations.get(receiver, "lastIndex"))
			Operations.set(receiver, "lastIndex", Regex.advance(subject, lastIndex, unicode))
		end
	end
end)
method(regexFields, Symbols.Symbol.search, 1, function(receiver: any, input: any): number
	assert(isObject(receiver), "TypeError: Symbol.search requires an object receiver")
	local subject = Operations.string(input)
	local previous = Operations.get(receiver, "lastIndex")
	if not Objects.is(previous, 0) then Operations.set(receiver, "lastIndex", 0) end
	local match = executeRegex(receiver, subject)
	if not Objects.is(Operations.get(receiver, "lastIndex"), previous) then Operations.set(receiver, "lastIndex", previous) end
	return if Nulls.isNull(match) then -1 else Operations.get(match, "index")
end)
method(regexFields, Symbols.Symbol.matchAll, 1, function(receiver: any, input: any): any
	assert(Regex.owns(receiver), "Native Symbol.matchAll currently requires a regular-expression receiver")
	local subject: any = Operations.string(input)
	local value: any = Operations.regexp(Regex.read(receiver, "source"), Regex.read(receiver, "flags"))
	Regex.writeLastIndex(value, toLength(Regex.read(receiver, "lastIndex")))
	local global, unicode = Regex.read(value, "global"), Regex.read(value, "unicode")
	return nativeIterator({ next = function(): any
		if value == nil then return { done = true } end
		local match = regexExec(value, subject)
		if Nulls.isNull(match) then value, subject = nil, nil; return { done = true } end
		if not global then value, subject = nil, nil
		elseif match[1] == "" then Regex.writeLastIndex(value, Regex.advance(subject, toLength(Regex.read(value, "lastIndex")), unicode)) end
		return { done = false, value = match }
	end })
end)
method(regexFields, Symbols.Symbol.split, 2, function(receiver: any, input: any, limit: any): any
	assert(Regex.owns(receiver), "Native regex splitting currently requires a regular-expression receiver")
	local subject = Operations.string(input)
	local maximum = if limit == nil then 4294967295 else uint32(limit)
	local output = packet()
	if maximum == 0 then return output end
	local flags = Regex.read(receiver, "flags")
	local splitter = Operations.regexp(Regex.read(receiver, "source"), flags .. (if Regex.read(receiver, "sticky") then "" else "y"))
	local size, unicode = Regex.length(subject), Regex.read(receiver, "unicode")
	if size == 0 then
		if Nulls.isNull(regexExec(splitter, subject)) then Arrays.push(output, "") end
		return output
	end
	local consumed, cursor = 0, 0
	while cursor < size do
		Regex.writeLastIndex(splitter, cursor)
		local match = regexExec(splitter, subject)
		if Nulls.isNull(match) then cursor = Regex.advance(subject, cursor, unicode)
		else
			local finish = math.min(toLength(Regex.read(splitter, "lastIndex")), size)
			if finish == consumed then cursor = Regex.advance(subject, cursor, unicode)
			else
				Arrays.push(output, Regex.slice(subject, consumed, cursor))
				if #output == maximum then return output end
				consumed = finish
				for capture = 2, #match do
					Arrays.push(output, match[capture])
					if #output == maximum then return output end
				end
				cursor = consumed
			end
		end
	end
	Arrays.push(output, Regex.slice(subject, consumed, size))
	return output
end)
local function substitute(template: string, match: string, subject: string, position: number, captures: any, groups: any): string
	local output, at, size = {}, 1, Regex.length(subject)
	while at <= #template do
		local char = template:sub(at, at)
		if char ~= "$" or at == #template then table.insert(output, char); at += 1
		else
			local nextChar = template:sub(at + 1, at + 1)
			if nextChar == "$" then table.insert(output, "$"); at += 2
			elseif nextChar == "&" then table.insert(output, match); at += 2
			elseif nextChar == "`" then table.insert(output, Regex.slice(subject, 0, position)); at += 2
			elseif nextChar == "'" then table.insert(output, Regex.slice(subject, position + Regex.length(match), size)); at += 2
			elseif nextChar == "<" and groups ~= nil then
				local finish = template:find(">", at + 2, true)
				if finish then
					local name = template:sub(at + 2, finish - 1)
					local value = Operations.get(groups, name)
					table.insert(output, if value == nil then "" else Operations.string(value))
					at = finish + 1
				else table.insert(output, "$"); at += 1 end
			else
				local digit = string.byte(nextChar) - 48
				local count, index = 0, nil :: number?
				if digit >= 0 and digit <= 9 then
					if digit > 0 and digit <= #captures then index, count = digit, 1 end
					local following = string.byte(template, at + 2)
					if following and following >= 48 and following <= 57 then
						local pair = digit * 10 + following - 48
						if pair > 0 and pair <= #captures then index, count = pair, 2 end
					end
				end
				if index then table.insert(output, captures[index] or ""); at += count + 1
				else table.insert(output, "$"); at += 1 end
			end
		end
	end
	return table.concat(output)
end
local function replacement(value: any, match: string, subject: string, position: number, captures: any, groups: any): string
	if kind(value) ~= "function" then return substitute(value, match, subject, position, captures, groups) end
	local args = packet(match)
	Arrays.pushItems(args, captures)
	Arrays.push(args, position, subject)
	if groups ~= nil then Arrays.push(args, groups) end
	return Operations.string(Operations.call(value, nil, args))
end
method(regexFields, Symbols.Symbol.replace, 2, function(receiver: any, input: any, replaceValue: any): string
	assert(isObject(receiver), "TypeError: Symbol.replace requires an object receiver")
	local subject = Operations.string(input)
	local replacer = if kind(replaceValue) == "function" then replaceValue else Operations.string(replaceValue)
	local global = Nulls.truthy(Operations.get(receiver, "global"))
	local unicode = false
	if global then
		unicode = Nulls.truthy(Operations.get(receiver, "unicode")) or Nulls.truthy(Operations.get(receiver, "unicodeSets"))
		Operations.set(receiver, "lastIndex", 0)
	end
	local matches = {}
	while true do
		assert(#matches < 1000000, "UnsupportedRegExp: replacement exceeded the iteration budget")
		local match = executeRegex(receiver, subject)
		if Nulls.isNull(match) then break end
		table.insert(matches, match)
		if not global then break end
		if Operations.string(Operations.get(match, 0)) == "" then
			local lastIndex = toLength(Operations.get(receiver, "lastIndex"))
			Operations.set(receiver, "lastIndex", Regex.advance(subject, lastIndex, unicode))
		end
	end
	local output, consumed, size = {}, 0, Regex.length(subject)
	for _, result in matches do
		local match = Operations.string(Operations.get(result, 0))
		local position = math.clamp(integer(Operations.get(result, "index")), 0, size)
		local captures = packet()
		for capture = 1, math.max(0, lengthOf(result) - 1) do
			local value = Operations.get(result, capture)
			Arrays.push(captures, if value == nil then nil else Operations.string(value))
		end
		local groups = Operations.get(result, "groups")
		if groups ~= nil then Operations.requireObject(groups) end
		local nextValue = replacement(replacer, match, subject, position, captures, groups)
		if position >= consumed then
			table.insert(output, Regex.slice(subject, consumed, position))
			table.insert(output, nextValue)
			consumed = position + Regex.length(match)
		end
	end
	if consumed <= size then table.insert(output, Regex.slice(subject, consumed, size)) end
	return table.concat(output)
end)
regexSchema = {
	hasOwn = function(_owner, key) return key == "lastIndex" end,
	get = function(owner, _key, _receiver) return Regex.read(owner, "lastIndex") end,
	ownKeys = function() return packet("lastIndex") end,
	enumerable = function() return false end,
	prototype = function() return regexPrototype end,
	set = function(owner, key, value)
		assert(key == "lastIndex", "Native RegExp expando/descriptor writes are currently unsupported")
		Regex.writeLastIndex(owner, value)
	end,
	remove = function(_owner, key)
		assert(key ~= "lastIndex", "TypeError: RegExp.lastIndex is not configurable")
		return true
	end,
}
Operations.registerObject(regexPrototype, {
	hasOwn = function(_owner, key) return regexFields[key] ~= nil end,
	get = function(_owner, key, receiver)
		if regexAccessors[key] then
			if receiver == regexPrototype then return if key == "source" then "(?:)" elseif key == "flags" then "" else nil end
			return Regex.read(receiver, key)
		end
		return regexFields[key]
	end,
	ownKeys = function() return namesOf(regexFields) end,
	enumerable = function() return false end,
	prototype = function() return objectPrototype end,
})
local function isRegex(value: any): boolean
	if not isObject(value) then return false end
	local match = Operations.get(value, Symbols.Symbol.match)
	return if match ~= nil then Nulls.truthy(match) else Regex.owns(value)
end
function Operations.registerNamespace(value: any, name: string): () -> ()
	local keys = if Records.owns(value) then Records.keys(value) else namesOf(value)
	for _, key in keys do
		local field = rawget(value, key)
		if type(field) == "function" then Operations.registerNative(field, "free", `{name}.{tostring(key)}`) end
	end
	local owner = namespaceOwners[value]
	if owner then
		assert(nativeObjects[value] == owner.schema, "Native namespace schema ownership changed")
		owner.leases += 1
	else
		local schema: NativeObject = {
		hasOwn = function(owner, key) return if Records.owns(owner) then Records.hasOwn(owner, key) else rawget(owner, key) ~= nil end,
		get = function(owner, key, _receiver) return rawget(owner, key) end,
		ownKeys = function(owner) return if Records.owns(owner) then Records.keys(owner) else namesOf(owner) end,
		enumerable = function() return true end,
		}
		Operations.registerObject(value, schema)
		owner = { schema = schema, leases = 1 }
		namespaceOwners[value] = owner
	end
	local closed = false
	return function()
		if closed then return end
		closed = true
		(owner :: any).leases -= 1
		if (owner :: any).leases == 0 and nativeObjects[value] == (owner :: any).schema then
			nativeObjects[value], namespaceOwners[value] = nil, nil
		end
	end
end
local objectFields: { [any]: any }, functionFields: { [any]: any }, arrayFields: { [any]: any } = {}, {}, {}
local stringFields: { [any]: any }, numberFields: { [any]: any }, booleanFields: { [any]: any }, symbolFields: { [any]: any } = {}, {}, {}, {}
method(objectFields, "toString", 0, function(receiver: any): string
	local tag = kind(receiver)
	local collection = Collections.kind(receiver)
	local capability = nativeObjects[receiver]
	local label = if Nulls.isNull(receiver) then "Null" elseif receiver == nil then "Undefined"
		elseif Arrays.owns(receiver) then "Array" elseif tag == "function" then "Function"
		elseif Records.owns(receiver) and Records.tag(receiver) then Records.tag(receiver)
		elseif capability and capability.tag then capability.tag
		elseif collection == "map" then "Map" elseif collection == "set" then "Set" elseif collection == "weakmap" then "WeakMap"
		elseif collection == "weakset" then "WeakSet"
		elseif Regex.owns(receiver) then "RegExp"
		elseif tag == "string" then "String" elseif tag == "number" then "Number"
		elseif tag == "boolean" then "Boolean" elseif tag == "symbol" then "Symbol" else "Object"
	if not Nulls.isNullish(receiver) then
		local custom = Operations.get(receiver, Symbols.Symbol.toStringTag)
		if type(custom) == "string" then label = custom end
	end
	return "[object " .. (label :: string) .. "]"
end)
method(objectFields, "valueOf", 0, function(receiver: any): any
	assert(isObject(receiver), "Boxed primitive Object.valueOf is currently unsupported")
	return receiver
end)
method(objectFields, "hasOwnProperty", 1, function(receiver: any, key: any): boolean
	Operations.requireObject(receiver)
	return own(receiver, keyOf(key))
end)
method(objectFields, "propertyIsEnumerable", 1, function(receiver: any, key: any): boolean
	Operations.requireObject(receiver)
	return enumerable(receiver, keyOf(key))
end)
method(objectFields, "isPrototypeOf", 1, function(receiver: any, value: any): boolean
	Operations.requireObject(receiver)
	if not isObject(value) then return false end
	local current, seen = prototype(value), {}
	while not Nulls.isNullish(current) do
		if rawequal(current, receiver) then return true end
		assert(not seen[current], "Cyclic source prototype lookup")
		seen[current], current = true, prototype(current)
	end
	return false
end)
objectFields.__proto__ = true -- native accessor handled by the schema above
objectFields.constructor = Objects
functionFields.name, functionFields.length = "", 0
functionHasInstance = Functions.named(method(functionFields, Symbols.Symbol.hasInstance, 1, function(receiver: any, value: any): boolean
	return ordinaryHasInstance(receiver, value)
end), "[Symbol.hasInstance]", 1, true)
method(functionFields, "toString", 0, function(receiver: any): never
	assert(kind(receiver) == "function", "TypeError: Function.toString requires a callable receiver")
	error("Function source-text serialization is unavailable at the native boundary", 2)
end)
method(functionFields, "call", 1, function(receiver: any, thisArg: any, ...: any): any
	return Operations.call(receiver, thisArg, packet(...))
end)
method(functionFields, "apply", 2, function(receiver: any, thisArg: any, args: any): any
	if Nulls.isNullish(args) then return Operations.call(receiver, thisArg, packet()) end
	assert(isObject(args), "TypeError: Function.apply arguments must be an object")
	local result = packet()
	for at = 0, lengthOf(args) - 1 do Arrays.push(result, Operations.get(args, at)) end
	return Operations.call(receiver, thisArg, result)
end)
method(functionFields, "bind", 1, function(receiver: any, thisArg: any, ...: any): any
	assert(type(receiver) == "function", "Binding a native callable table is currently unsupported")
	local initial = packet(...)
	local arity = Functions.length(receiver)
	local bound = Operations.functionValue(function(_ignored: any, args: any): any
		return Operations.call(receiver, thisArg, Arrays.concat(initial, args))
	end, "bound " .. Functions.name(receiver), math.max(0, arity - #initial), "arrow")
	sourceFunctions[bound].boundInstanceofUnsupported = true
	return bound
end)
local joinStack: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
method(arrayFields, "join", 1, function(receiver: any, separator: any): string
	Operations.requireObject(receiver)
	local length = lengthOf(receiver)
	local delimiter = if separator == nil then "," else Operations.string(separator)
	local tracked = isObject(receiver)
	if tracked and joinStack[receiver] then return "" end
	if tracked then joinStack[receiver] = true end
	local ok, result = pcall(function(): string
		local parts = {}
		for at = 0, length - 1 do
			local value = Operations.get(receiver, at)
			parts[at + 1] = if Nulls.isNullish(value) then "" else Operations.string(value)
		end
		return table.concat(parts, delimiter)
	end)
	if tracked then joinStack[receiver] = nil end
	if not ok then error(result, 0) end
	return result
end)
method(arrayFields, "toString", 0, function(receiver: any): string
	local join = Operations.get(receiver, "join")
	if kind(join) == "function" then return Operations.call(join, receiver, packet()) end
	return Operations.call(objectFields.toString, receiver, packet())
end)
arrayFields.constructor = Values.Array
arrayFields.length = 0
local callbackMethods = { map = true, filter = true, forEach = true, some = true, every = true, find = true,
	findIndex = true, flatMap = true }
for name in next, callbackMethods do
	local implementation = (Arrays :: any)[name]
	method(arrayFields, name, 1, function(receiver: any, callback: any, thisArg: any): any
		assert(Arrays.owns(receiver), `Generic array-like {name} is currently unsupported; use a source array`)
		assert(kind(callback) == "function", "TypeError: array callback is not callable")
		return implementation(receiver, function(value: any, at: number, owner: any): any
			return Operations.call(callback, thisArg, packet(value, at, owner))
		end)
	end)
end
for _, name in { "reduce", "reduceRight" } do
	local implementation = (Arrays :: any)[name]
	method(arrayFields, name, 1, function(receiver: any, callback: any, ...: any): any
		assert(Arrays.owns(receiver), `Generic array-like {name} is currently unsupported; use a source array`)
		assert(kind(callback) == "function", "TypeError: array callback is not callable")
		local invoke = function(previous: any, value: any, at: number, owner: any): any
			return Operations.call(callback, nil, packet(previous, value, at, owner))
		end
		return implementation(receiver, invoke, ...)
	end)
end
local arrayArities: { [string]: number } = { push = 1, pop = 0, shift = 0, unshift = 1, splice = 2, slice = 2, concat = 1,
	reverse = 0, fill = 1, includes = 1, indexOf = 1, at = 1 }
for name, arity in arrayArities do
	local implementation = (Arrays :: any)[name]
	method(arrayFields, name, arity, function(receiver: any, ...: any): any
		assert(Arrays.owns(receiver), `Generic array-like {name} is currently unsupported; use a source array`)
		assert(receiver ~= arrayPrototype or name == "slice" or name == "concat" or name == "includes" or name == "indexOf" or name == "at", "Mutation of native builtin prototype objects is currently unsupported")
		return implementation(receiver, ...)
	end)
end
method(arrayFields, "sort", 1, function(receiver: any, compare: any): any
	assert(compare == nil or kind(compare) == "function", "TypeError: Array.sort comparator must be callable or undefined")
	assert(Arrays.owns(receiver), "Array.sort currently requires a source array")
	local size = Arrays.length(receiver)
	local values, undefinedCount = {}, 0
	for at = 0, size - 1 do
		if Arrays.has(receiver, at) then
			local value = rawget(receiver, at + 1)
			if value == nil then undefinedCount += 1 else table.insert(values, value) end
		end
	end
	local function before(left: any, right: any): boolean
		if compare == nil then return less(Operations.string(left), Operations.string(right)) == true end
		local result = Operations.number(Operations.call(compare, nil, packet(left, right)))
		return result == result and result < 0
	end
	-- Stable merge sort over a complete property snapshot. Comparator mutations
	-- affect the receiver, not the captured sort list, as SortIndexedProperties.
	local width, count = 1, #values
	while width < count do
		local merged = {}
		for start = 1, count, width * 2 do
			local left, right = start, math.min(start + width, count + 1)
			local leftEnd, rightEnd = right, math.min(start + width * 2, count + 1)
			while left < leftEnd or right < rightEnd do
				if right >= rightEnd or left < leftEnd and not before(values[right], values[left]) then
					table.insert(merged, values[left]); left += 1
				else table.insert(merged, values[right]); right += 1 end
			end
		end
		values, width = merged, width * 2
	end
	for at, value in values do Arrays.set(receiver, at - 1, value) end
	for at = count, count + undefinedCount - 1 do Arrays.set(receiver, at, nil) end
	for at = count + undefinedCount, size - 1 do if Arrays.has(receiver, at) then Arrays.remove(receiver, at) end end
	return receiver
end)
arrayValuesMethod = method(arrayFields, "values", 0, function(receiver: any): any
	Operations.requireObject(receiver)
	local owner, cursor: any = receiver, 0
	return nativeIterator({ next = function(): any
		if owner == nil then return { done = true } end
		if cursor >= lengthOf(owner) then owner = nil; return { done = true } end
		local at = cursor
		cursor += 1
		return { done = false, value = Operations.get(owner, at) }
	end })
end)
method(arrayFields, "keys", 0, function(receiver: any): any
	assert(Arrays.owns(receiver), "Array.keys currently requires a source array")
	local cursor, done = 0, false
	return nativeIterator({ next = function(): any
		if done or cursor >= Arrays.length(receiver) then done = true; return { done = true } end
		local value = cursor
		cursor += 1
		return { done = false, value = value }
	end })
end)
method(arrayFields, "entries", 0, function(receiver: any): any
	local iterator = arrayFields.keys(receiver)
	return nativeIterator({ next = function(): any
		local step = iterator.next(iterator)
		if step.done then return step end
		return { done = false, value = packet(step.value, Operations.get(receiver, step.value)) }
	end })
end)
arrayFields[Symbols.Symbol.iterator] = arrayFields.values
stringValuesMethod = method(stringFields, Symbols.Symbol.iterator, 0, function(receiver: any): any
	assert(type(receiver) == "string", "String iteration currently requires a primitive scalar string")
	return Operations.iterable(receiver)
end)
for _, definition in { { stringFields, "string", Values.String }, { numberFields, "number", Values.Number },
	{ booleanFields, "boolean", Values.Boolean }, { symbolFields, "symbol", Symbols.Symbol } } do
	local fields, expected, constructor = definition[1], definition[2], definition[3]
	fields.constructor = constructor
	method(fields, "valueOf", 0, function(receiver: any): any
		assert(kind(receiver) == expected, `Boxed {expected} values are currently unsupported`)
		return receiver
	end)
	method(fields, "toString", 0, function(receiver: any, radix: any): string
		assert(kind(receiver) == expected, `Boxed {expected} values are currently unsupported`)
		if expected == "symbol" then return tostring(receiver) end
		if expected == "number" then
			return require(script.Parent.SourceNumbers).toString(receiver, if radix == nil then nil else Operations.number(radix))
		end
		return Values.String(receiver)
	end)
end
method(numberFields, "toFixed", 1, function(receiver: any, digits: any): string
	if type(receiver) ~= "number" then return Operations.intrinsicError("TypeError", "Number.toFixed requires a primitive number") end
	local places = if digits == nil then 0 else Operations.number(digits)
	if places ~= places then places = 0 end
	places = if places < 0 then math.ceil(places) else math.floor(places)
	if places < 0 or places > 100 then return Operations.intrinsicError("RangeError", "toFixed digits must be between 0 and 100") end
	return require(script.Parent.SourceDecimal).toFixed(receiver, places)
end)
method(numberFields, "toPrecision", 1, function(receiver: any, digits: any): string
	if type(receiver) ~= "number" then return Operations.intrinsicError("TypeError", "Number.toPrecision requires a primitive number") end
	if digits == nil then return require(script.Parent.SourceDecimal).toString(receiver) end
	local places = Operations.number(digits)
	if places ~= places then places = 0 end
	places = if places < 0 then math.ceil(places) else math.floor(places)
	if places < 1 or places > 100 then return Operations.intrinsicError("RangeError", "toPrecision digits must be between 1 and 100") end
	return require(script.Parent.SourceDecimal).toPrecision(receiver, places)
end)
for _, name in { "startsWith", "includes", "endsWith" } do
	method(stringFields, name, 1, function(receiver: any, search: any, position: any): boolean
		Operations.requireObject(receiver)
		local subject = Operations.string(receiver)
		assert(not isRegex(search), "TypeError: string search does not accept a regular expression")
		return (Strings :: any)[name](subject, Operations.string(search), if position == nil then nil else integer(position))
	end)
end
local function trimSpace(code: number): boolean
	return (code >= 0x09 and code <= 0x0D) or code == 0x20 or code == 0xA0 or code == 0x1680
		or (code >= 0x2000 and code <= 0x200A) or code == 0x2028 or code == 0x2029
		or code == 0x202F or code == 0x205F or code == 0x3000 or code == 0xFEFF
end
for _, name in { "trim", "trimStart", "trimEnd" } do
	method(stringFields, name, 0, function(receiver: any): string
		Operations.requireObject(receiver)
		local subject = Operations.string(receiver)
		local codes = units(subject)
		local first, last = 1, #codes
		if name ~= "trimEnd" then while first <= last and trimSpace(codes[first]) do first += 1 end end
		if name ~= "trimStart" then while last >= first and trimSpace(codes[last]) do last -= 1 end end
		return Regex.slice(subject, first - 1, last)
	end)
end
method(stringFields, "charCodeAt", 1, function(receiver: any, position: any): number
	Operations.requireObject(receiver)
	local subject = Operations.string(receiver)
	local codes, at = units(subject), integer(position)
	return if at >= 0 and at < #codes then codes[at + 1] else nan
end)
method(stringFields, "slice", 2, function(receiver: any, start: any, finish: any): string
	Operations.requireObject(receiver)
	local subject = Operations.string(receiver)
	local size = Regex.length(subject)
	local first = integer(start)
	local last = if finish == nil then size else integer(finish)
	first = if first < 0 then math.max(size + first, 0) else math.min(first, size)
	last = if last < 0 then math.max(size + last, 0) else math.min(last, size)
	return if last <= first then "" else Regex.slice(subject, first, last)
end)
for _, entry in { { "toLowerCase", string.lower }, { "toUpperCase", string.upper } } do
	local name, convert = entry[1] :: string, entry[2] :: (string) -> string
	method(stringFields, name, 0, function(receiver: any): string
		Operations.requireObject(receiver)
		local subject = Operations.string(receiver)
		assert(not subject:find("[\128-\255]"), "Unicode case conversion requires Unicode mapping tables")
		return convert(subject)
	end)
end
for _, entry in { { "match", Symbols.Symbol.match }, { "search", Symbols.Symbol.search } } do
	local name, symbol = entry[1], entry[2]
	method(stringFields, name, 1, function(receiver: any, search: any): any
		Operations.requireObject(receiver)
		if not Nulls.isNullish(search) then
			local hook = Operations.get(search, symbol)
			if not Nulls.isNullish(hook) then return Operations.call(hook, search, packet(receiver)) end
		end
		local subject = Operations.string(receiver)
		local regex = Operations.regexp(if search == nil then "" else Operations.string(search), "")
		return Operations.call(Operations.get(regex, symbol), regex, packet(subject))
	end)
end
method(stringFields, "matchAll", 1, function(receiver: any, search: any): any
	Operations.requireObject(receiver)
	if not Nulls.isNullish(search) then
		if isRegex(search) then assert(Operations.string(Operations.get(search, "flags")):find("g", 1, true), "TypeError: String.matchAll requires a global regular expression") end
		local hook = Operations.get(search, Symbols.Symbol.matchAll)
		if not Nulls.isNullish(hook) then return Operations.call(hook, search, packet(receiver)) end
	end
	local regex = Operations.regexp(if search == nil then "" else Operations.string(search), "g")
	return Operations.call(Operations.get(regex, Symbols.Symbol.matchAll), regex, packet(Operations.string(receiver)))
end)
method(stringFields, "split", 2, function(receiver: any, separator: any, limit: any): any
	Operations.requireObject(receiver)
	if not Nulls.isNullish(separator) then
		local hook = Operations.get(separator, Symbols.Symbol.split)
		if not Nulls.isNullish(hook) then return Operations.call(hook, separator, packet(receiver, limit)) end
	end
	local subject = Operations.string(receiver)
	local maximum = if limit == nil then 4294967295 else uint32(limit)
	local output = packet()
	if maximum == 0 then return output end
	if separator == nil then Arrays.push(output, subject); return output end
	local needle = Operations.string(separator)
	if needle == "" then
		for at = 0, math.min(Regex.length(subject), maximum) - 1 do Arrays.push(output, Regex.slice(subject, at, at + 1)) end
		return output
	end
	local cursor = 1
	while true do
		local first, finish = subject:find(needle, cursor, true)
		if not first then Arrays.push(output, subject:sub(cursor)); break end
		Arrays.push(output, subject:sub(cursor, first - 1))
		if #output == maximum then break end
		cursor = (finish :: number) + 1
	end
	return output
end)
for _, name in { "replace", "replaceAll" } do
	method(stringFields, name, 2, function(receiver: any, search: any, replaceValue: any): any
		Operations.requireObject(receiver)
		if not Nulls.isNullish(search) then
			if name == "replaceAll" and isRegex(search) then assert(Operations.string(Operations.get(search, "flags")):find("g", 1, true), "TypeError: String.replaceAll requires a global regular expression") end
			local hook = Operations.get(search, Symbols.Symbol.replace)
			if not Nulls.isNullish(hook) then return Operations.call(hook, search, packet(receiver, replaceValue)) end
		end
		local subject, needle = Operations.string(receiver), Operations.string(search)
		local replacer = if kind(replaceValue) == "function" then replaceValue else Operations.string(replaceValue)
		local output, cursor, consumed = {}, 1, 0
		if needle == "" then
			local size = Regex.length(subject)
			local finish = if name == "replace" then 0 else size
			for position = 0, finish do
				table.insert(output, replacement(replacer, "", subject, position, packet(), nil))
				if position < finish then table.insert(output, Regex.slice(subject, position, position + 1)) end
			end
			table.insert(output, Regex.slice(subject, finish, size))
			return table.concat(output)
		end
		while true do
			local first, last = subject:find(needle, cursor, true)
			if not first then break end
			local position = Regex.length(subject:sub(1, first - 1))
			table.insert(output, subject:sub(consumed + 1, first - 1))
			table.insert(output, replacement(replacer, needle, subject, position, packet(), nil))
			consumed, cursor = last :: number, (last :: number) + 1
			if name == "replace" then break end
		end
		table.insert(output, subject:sub(consumed + 1))
		return table.concat(output)
	end)
end
local objectStatics: { [any]: any } = { prototype = objectPrototype, name = "Object", length = 1 }
for _, entry in { { "getOwnPropertyNames", "string" }, { "getOwnPropertySymbols", "symbol" } } do
	local propertyKind = entry[2]
	static(objectStatics, entry[1], 1, function(value: any): any
		Operations.requireObject(value)
		qualify(value)
		assert(not nativeObjects[value] or nativeObjects[value].getOwnPropertyDescriptor or Collections.kind(value) or Regex.owns(value), "Full own-key reflection of this native boundary is not qualified")
		local result = Arrays.adopt({}, 0)
		for _, key in ownKeys(value) do if kind(key) == propertyKind then Arrays.push(result, key) end end
		return result
	end)
end
static(objectStatics, "keys", 1, function(value: any): any
	Operations.requireObject(value)
	local result = packet()
	for _, name in ownKeys(value) do if type(name) == "string" and enumerable(value, name) then Arrays.push(result, name) end end
	return result
end)
static(objectStatics, "values", 1, function(value: any): any
	local result = packet()
	for _, name in objectStatics.keys(value) do Arrays.push(result, Operations.get(value, name)) end
	return result
end)
static(objectStatics, "entries", 1, function(value: any): any
	local result = packet()
	for _, name in objectStatics.keys(value) do Arrays.push(result, packet(name, Operations.get(value, name))) end
	return result
end)
static(objectStatics, "assign", 2, function(target: any, ...: any): any
	assert(isObject(target), "Object.assign boxed primitive targets are currently unsupported")
	for at = 1, select("#", ...) do
		local source = select(at, ...)
		if not Nulls.isNullish(source) then
			for _, name in ownKeys(source) do
				if enumerable(source, name) then Operations.set(target, name, Operations.get(source, name)) end
			end
		end
	end
	return target
end)
static(objectStatics, "hasOwn", 2, function(value: any, key: any): boolean Operations.requireObject(value); return own(value, keyOf(key)) end)
static(objectStatics, "getOwnPropertyDescriptor", 2, Operations.getOwnPropertyDescriptor)
static(objectStatics, "defineProperty", 3, function(owner: any, key: any, attributes: any): any
	if not isObject(owner) then typeError("Object.defineProperty target must be an object") end
	local name = keyOf(key)
	if not isObject(attributes) then typeError("Property description must be an object") end
	-- ToPropertyDescriptor performs HasProperty/Get in this exact order. The
	-- descriptor is completed only after getters have finished, before mutation.
	local entries: any, present: any = {}, {}
	for _, field in { "enumerable", "configurable", "value", "writable", "get", "set" } do
		local at = attributes
		while not Nulls.isNullish(at) do
			if own(at, field) then
				present[field] = true
				entries[field] = Operations.get(attributes, field)
				if (field == "get" or field == "set") and entries[field] ~= nil and kind(entries[field]) ~= "function" then typeError("Accessor must be callable or undefined") end
				break
			end
			at = prototype(at)
		end
	end
	if (present.get or present.set) and (present.value or present.writable) then typeError("A descriptor cannot be both data and accessor") end
	for _, field in { "get", "set" } do
		if present[field] and entries[field] ~= nil and kind(entries[field]) ~= "function" then typeError("Accessor must be callable or undefined") end
	end
	local previous = descriptor(owner, name)
	local form = if present.get or present.set then "accessor" elseif present.value or present.writable then "data" elseif previous then previous.kind else "data"
	local desc: any = if previous and previous.kind == form then table.clone(previous) else
		{ kind = form, value = nil, writable = false, get = nil, set = nil, enumerable = if previous then previous.enumerable else false, configurable = if previous then previous.configurable else false }
	for _, field in { "enumerable", "configurable", "writable" } do if present[field] then desc[field] = Nulls.truthy(entries[field]) end end
	for _, field in { "value", "get", "set" } do if present[field] then desc[field] = entries[field] end end
	return applyDescriptor(owner, name, desc)
end)
static(objectStatics, "create", 2, function(parent: any, descriptors: any): any
	assert(descriptors == nil, "Object.create property descriptors are currently unsupported")
	assert(isObject(parent) or Nulls.isNull(parent), "TypeError: Object.create prototype must be an object or null")
	return Operations.object(parent)
end)
static(objectStatics, "getPrototypeOf", 1, function(value: any): any Operations.requireObject(value); return prototype(value) end)
static(objectStatics, "setPrototypeOf", 2, Operations.setPrototype)
static(objectStatics, "is", 2, Objects.is)
static(objectStatics, "freeze", 1, function(value: any): any
	if not isObject(value) then return value end
	local record = storage(value)
	if not record then
		if Arrays.owns(value) then return if table.isfrozen(value) then value else table.freeze(value) end
		error("Object.freeze requires qualified own-property descriptors for this native boundary", 2)
	end
	for _, key in Records.ownKeys(record) do
		local desc = table.clone(Records.descriptor(record, key))
		desc.configurable = false
		if desc.kind == "data" then desc.writable = false end
		Records.defineDescriptor(record, key, desc)
	end
	Records.preventExtensions(record)
	return value
end)
static(objectStatics, "isFrozen", 1, function(value: any): boolean
	if not isObject(value) then return true end
	local record = storage(value)
	if record then
		if Records.extensible(record) then return false end
		for _, key in Records.ownKeys(record) do
			local desc = Records.descriptor(record, key)
			if desc.configurable or desc.kind == "data" and desc.writable then return false end
		end
		return true
	end
	if Arrays.owns(value) then return table.isfrozen(value) end
	error("Object.isFrozen requires qualified own-property descriptors for this native boundary", 2)
end)
local mathStatics = {}
for name, value in next, Values.Math :: any do
	if type(value) == "function" then static(mathStatics, name, if name == "min" or name == "max" then 2 elseif name == "random" then 0 else 1, value)
	else mathStatics[name] = value end
end
local arrayStatics = { prototype = arrayPrototype, name = "Array", length = 1 }
static(arrayStatics, "isArray", 1, Arrays.owns)
static(arrayStatics, "from", 1, function(input: any, callback: any, thisArg: any): any
	assert(callback == nil or kind(callback) == "function", "TypeError: Array.from callback is not callable")
	local result, at = packet(), 0
	local iterable = if Nulls.isNullish(input) then nil else Operations.get(input, Symbols.Symbol.iterator)
	if not Nulls.isNullish(iterable) then
		local cursor = { generator = iterableFrom(input, iterable), done = false }
		iteratorIdentities[cursor] = true
		local ok, reason = pcall(function()
			while not cursor.done do
				local value = Operations.next(cursor)
				if cursor.done then break end
				Arrays.push(result, if callback == nil then value else Operations.call(callback, thisArg, packet(value, at)))
				at += 1
			end
		end)
		Operations.close(cursor)
		if not ok then error(reason, 0) end
	else
		Operations.requireObject(input)
		for position = 0, lengthOf(input) - 1 do
			local value = Operations.get(input, position)
			Arrays.push(result, if callback == nil then value else Operations.call(callback, thisArg, packet(value, position)))
		end
	end
	return result
end)
local numberStatics = { prototype = numberPrototype, name = "Number", length = 1 }
for name, value in next, Values.Number :: any do
	if type(value) == "function" then static(numberStatics, name, if name == "parseInt" then 2 else 1, value)
	else numberStatics[name] = value end
end
local symbolStatics = {}
for name, value in next, Symbols.Symbol :: any do
	if type(value) == "function" then static(symbolStatics, name, 1, value) else symbolStatics[name] = value end
end
symbolStatics.prototype = symbolPrototype
symbolStatics.name, symbolStatics.length = "Symbol", 0
for _, name in { "String", "Boolean", "parseInt", "parseFloat" } do
	Operations.registerNative((Values :: any)[name], "free", name, if name == "parseInt" then 2 else 1)
end
for name, value in next, Objects :: any do
	if type(value) == "function" then Operations.registerNative(value, "free", `Object.{name}`) end
end
nativeNextMethod = Operations.registerNative(function(receiver: any): any
	assert(nativeObjects[receiver], "TypeError: iterator.next requires its native iterator receiver")
	local step = receiver.next(receiver)
	return Records.adopt({ done = step.done == true, value = step.value }, { "done", "value" })
end, "method", "next", 0)
local iteratorFields: { [any]: any } = {}
method(iteratorFields, Symbols.Symbol.iterator, 0, function(receiver: any): any return receiver end)
builtin(iteratorPrototype, iteratorFields, objectPrototype, nil)
local unavailableFunction = Operations.registerNative(function(): never
	error("Dynamic Function construction requires a JavaScript compiler at runtime and is unsupported", 2)
end, "free", "Function", 1)
functionFields.constructor = unavailableFunction
builtin(objectPrototype, objectFields, Nulls.value, nil)
builtin(functionPrototype, functionFields, objectPrototype, function() return nil end)
builtin(arrayPrototype, arrayFields, objectPrototype, nil)
builtin(stringPrototype, stringFields, objectPrototype, nil)
builtin(numberPrototype, numberFields, objectPrototype, nil)
builtin(booleanPrototype, booleanFields, objectPrototype, nil)
builtin(symbolPrototype, symbolFields, objectPrototype, nil)
builtin(unavailableFunction, { name = "Function", length = 1, prototype = functionPrototype }, functionPrototype, function()
	return unavailableFunction()
end)
builtin(Objects, objectStatics, functionPrototype, function(_self, _receiver, args)
	if args[1] == nil or Nulls.isNull(args[1]) then return Operations.object() end
	assert(isObject(args[1]), "Object boxed primitive construction is currently unsupported")
	return args[1]
end)
builtin(Values.Math, mathStatics, objectPrototype, nil)
builtin(Values.Array, arrayStatics, functionPrototype, function(_self, _receiver, args) return (Values.Array :: any)(table.unpack(args, 1, #args)) end)
builtin(Values.Number, numberStatics, functionPrototype, function(_self, _receiver, args) return if #args == 0 then 0 else Operations.number(args[1]) end)
builtin(Symbols.Symbol, symbolStatics, functionPrototype, function(_self, _receiver, args)
	return (Symbols.Symbol :: (any) -> any)(if args[1] == nil then nil else Operations.string(args[1]))
end)
builtin(Values.String, { name = "String", length = 1, prototype = stringPrototype }, functionPrototype, function(_self, _receiver, args)
	if #args == 0 then return "" end
	return if kind(args[1]) == "symbol" then tostring(args[1]) else Operations.string(args[1])
end)
builtin(Values.Boolean, { name = "Boolean", length = 1, prototype = booleanPrototype }, functionPrototype, function(_self, _receiver, args)
	return Nulls.truthy(args[1])
end)
builtin(Regex.Constructor, { name = "RegExp", length = 2, prototype = regexPrototype }, functionPrototype, function(_self, _receiver, args)
	local pattern, flags = args[1], args[2]
	local identified = isRegex(pattern)
	if identified and flags == nil and Operations.get(pattern, "constructor") == Regex.Constructor then return pattern end
	local source = if identified then Operations.string(Operations.get(pattern, "source")) elseif pattern == nil then "" else Operations.string(pattern)
	local selectedFlags = if flags ~= nil then Operations.string(flags) elseif identified then Operations.string(Operations.get(pattern, "flags")) else ""
	return Operations.regexp(source, selectedFlags)
end)
SourceType.register(Objects, "function")
SourceType.register(functionPrototype, "function")

-- Collection storage remains owned by SourceCollections. The source view has
-- shared JS prototypes and its own data-property ledger, so implementation
-- closures never appear as enumerable instance properties.
local collectionConstructors: { [string]: any } = {
	map = Collections.Map, set = Collections.Set, weakmap = Collections.WeakMap, weakset = Collections.WeakSet,
}
local constructCollection: (any, any) -> any
local function rejectCollectionCall(_receiver: any, _arguments: any): never
	return typeError("Collection constructor requires new")
end
local collectionConstructorSchema: NativeObject = {
	properties = Collections.constructorFields,
	hasOwn = function(owner: any, key: any): boolean return Records.hasOwn(Collections.constructorFields(owner), key) end,
	get = function(owner: any, key: any, receiver: any): any return Records.readOwn(Collections.constructorFields(owner), key, receiver) end,
	ownKeys = function(owner: any): any return Records.ownKeys(Collections.constructorFields(owner)) end,
	enumerable = function(owner: any, key: any): boolean
		local desc = Records.descriptor(Collections.constructorFields(owner), key)
		return desc ~= nil and desc.enumerable == true
	end,
	getOwnPropertyDescriptor = function(owner: any, key: any): any return Operations.getOwnPropertyDescriptor(Collections.constructorFields(owner), key) end,
	prototype = function(_owner: any): any return functionPrototype end,
	call = function(_owner: any, receiver: any, arguments: any): never return rejectCollectionCall(receiver, arguments) end,
}
collectionSchema = {
	properties = Collections.properties,
	hasOwn = function(owner, key) return Records.hasOwn(Collections.properties(owner), key) end,
	get = function(owner, key, receiver) return Records.readOwn(Collections.properties(owner), key, receiver) end,
	ownKeys = function(owner) return Records.ownKeys(Collections.properties(owner)) end,
	enumerable = function(owner, key)
		local desc = Records.descriptor(Collections.properties(owner), key)
		return desc ~= nil and desc.enumerable == true
	end,
	getOwnPropertyDescriptor = function(owner, key) return Operations.getOwnPropertyDescriptor(Collections.properties(owner), key) end,
	prototype = function(owner) return collectionPrototypes[assert(Collections.kind(owner))] end,
	set = function(owner, key, value)
		local fields = Collections.properties(owner)
		assert(not table.isfrozen(owner), "TypeError: cannot assign a frozen collection property")
		assert(key ~= "__proto__" or Records.hasOwn(fields, key), "Collection prototype mutation is currently unsupported")
		assert(key ~= "size" or Collections.kind(owner) == "weakmap" or Collections.kind(owner) == "weakset" or Records.hasOwn(fields, key), "TypeError: collection size has no setter")
		Records.define(fields, key, value)
	end,
	define = function(owner, key, value)
		assert(not table.isfrozen(owner), "TypeError: cannot define a frozen collection property")
		Records.define(Collections.properties(owner), key, value)
	end,
	remove = function(owner, key)
		local fields = Collections.properties(owner)
		assert(not Records.hasOwn(fields, key) or not table.isfrozen(owner), "TypeError: cannot delete a frozen collection property")
		return Records.remove(fields, key)
	end,
}
local function collectionMethod(receiver: any, expected: string, name: string): any
	if Collections.kind(receiver) ~= expected then typeError(`{expected}.{name} requires its collection receiver`) end
	return assert(Collections.method(receiver, name), "Missing native collection implementation")
end
for collectionKind, constructor in collectionConstructors do
	local expected = collectionKind
	local fields: { [any]: any } = { constructor = constructor }
	local definitions = if expected == "set" then { { "add", 1 }, { "has", 1 }, { "delete", 1 }, { "clear", 0 } }
		elseif expected == "map" then { { "get", 1 }, { "set", 2 }, { "has", 1 }, { "delete", 1 }, { "clear", 0 } }
		elseif expected == "weakset" then { { "add", 1 }, { "has", 1 }, { "delete", 1 } }
		else { { "get", 1 }, { "set", 2 }, { "has", 1 }, { "delete", 1 } }
	for _, definition in definitions do
		local name = definition[1] :: string
		method(fields, name, definition[2] :: number, function(receiver: any, ...: any): any
			local implementation = collectionMethod(receiver, expected, name)
			if (expected == "weakset" and name == "add" or expected == "weakmap" and name == "set")
				and not Collections.canBeHeldWeakly((...)) then typeError("Weak collection keys require objects or non-registered symbols") end
			return implementation(receiver, ...)
		end)
	end
	if expected == "map" or expected == "set" then
		fields.size = true
		for _, operation in { "keys", "values", "entries" } do
			local name = operation
			method(fields, name, 0, function(receiver: any): any
				return nativeIterator(collectionMethod(receiver, expected, name)(receiver))
			end)
		end
		if expected == "set" then fields.keys = fields.values end
		fields[Symbols.Symbol.iterator] = if expected == "set" then fields.values else fields.entries
		method(fields, "forEach", 1, function(receiver: any, callback: any, thisArg: any)
			local iterate = collectionMethod(receiver, expected, "entries")
			assert(kind(callback) == "function", "TypeError: collection forEach callback is not callable")
			local cursor = iterate(receiver)
			local ok, problem = pcall(function()
				while true do
					local step = cursor.next(cursor)
					if step.done then return end
					Operations.call(callback, thisArg, packet(step.value[2], step.value[1], receiver))
				end
			end)
			cursor.close()
			if not ok then error(problem, 0) end
		end)
	end
	local parent = collectionPrototypes[expected]
	for name, value in fields do
		if name == "size" then
			local getter = Operations.registerNative(function(receiver: any): number
				collectionMethod(receiver, expected, "has")
				return receiver.size
			end, "method", "get size", 0)
			Operations.defineAccessor(parent, name, getter, nil, false, true)
		else Operations.defineDataProperty(parent, name, value, true, false, true) end
	end
	local className = if expected == "map" then "Map" elseif expected == "set" then "Set" elseif expected == "weakmap" then "WeakMap" else "WeakSet"
	Operations.defineDataProperty(parent, Symbols.Symbol.toStringTag, className, false, false, true)
	local properties = Records.adopt({}, {})
	Operations.defineDataProperty(properties, "length", 0, false, false, true)
	Operations.defineDataProperty(properties, "name", className, false, false, true)
	Operations.defineDataProperty(properties, "prototype", parent, false, false, false)
	Records.setReceiver(properties, constructor)
	Collections.bindConstructor(constructor, {
		fields = properties,
		new = function(...: any): any return constructCollection(constructor, packet(...)) end,
		instanceof = function(value: any): boolean return Operations.binary("instanceof", value, constructor) end,
		dispatch = rejectCollectionCall,
	})
	Functions.callable(constructor, properties, rejectCollectionCall)
	Operations.registerObject(constructor, collectionConstructorSchema)
end
constructCollection = function(constructor: any, arguments: any): any
	local expected = if constructor == Collections.Map then "map" elseif constructor == Collections.Set then "set"
		elseif constructor == Collections.WeakMap then "weakmap" else "weakset"
	local result = Collections.empty(constructor)
	qualify(result)
	local initial = arguments[1]
	if Nulls.isNullish(initial) then return result end
	local adder = Operations.get(result, if expected == "set" or expected == "weakset" then "add" else "set")
	assert(kind(adder) == "function", "TypeError: collection constructor adder is not callable")
	local iterator = Operations.iterable(initial)
	while true do
		local step = iterator.next(iterator)
		if step.done then return result end
		local ok, problem = pcall(function()
			if expected == "set" or expected == "weakset" then Operations.call(adder, result, packet(step.value))
			else
				assert(isObject(step.value), "TypeError: collection constructor entry is not an object")
				local key = Operations.get(step.value, 0)
				local value = Operations.get(step.value, 1)
				Operations.call(adder, result, packet(key, value))
			end
		end)
		if not ok then
			if iterator.close then pcall(iterator.close) end
			error(problem, 0)
		end
	end
end
local function constructArray(_constructor: any, arguments: any): any
	return Operations.call(Values.Array, nil, arguments)
end
local function constructObject(_constructor: any, arguments: any): any
	return Operations.call(Objects, nil, arguments)
end
local function constructRegex(_constructor: any, arguments: any): any
	local pattern, flags = arguments[1], arguments[2]
	local identified = isRegex(pattern)
	local source = if identified then Operations.string(Operations.get(pattern, "source")) elseif pattern == nil then "" else Operations.string(pattern)
	local selectedFlags = if flags ~= nil then Operations.string(flags) elseif identified then Operations.string(Operations.get(pattern, "flags")) else ""
	return Operations.regexp(source, selectedFlags)
end
function Operations.registerBuiltinConstructors(): () -> ()
	local releases: { () -> () } = {}
	local ok, problem = pcall(function()
		for _, constructor in { Collections.Map, Collections.Set, Collections.WeakMap, Collections.WeakSet } do
			table.insert(releases, Operations.registerConstructor(constructor, constructCollection))
		end
		for _, entry in { { Values.Array, constructArray }, { Objects, constructObject }, { Regex.Constructor, constructRegex } } do
			table.insert(releases, Operations.registerConstructor(entry[1], entry[2]))
		end
	end)
	if not ok then
		for _, release in releases do release() end
		error(problem, 0)
	end
	return function()
		for _, release in releases do release() end
		table.clear(releases)
	end
end
Objects.configure({ keys = objectStatics.keys, values = objectStatics.values, entries = objectStatics.entries,
	assign = objectStatics.assign, hasOwn = objectStatics.hasOwn, freeze = objectStatics.freeze })
Records.configure(Operations.get, Operations.set, Operations.call, Operations.intrinsicError)
return Operations
