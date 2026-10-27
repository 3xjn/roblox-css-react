--!strict
-- ECMAScript promise jobs over explicit source values/callables. State belongs
-- to the promise's private metatable; weak registries never retain their owner.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Functions = require(script.Parent.FunctionValues)
local SourceType = require(script.Parent.SourceType)
local Promise = {}
local identity: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local stateToken, fieldsToken, staticToken, functionPrototypeToken = {}, {}, {}, {}
local function stateOf(value: any): any
	assert(identity[value], "TypeError: Promise method requires a source Promise receiver")
	return (getmetatable(value) :: any)[stateToken]
end
local function packet(...: any): any return Arrays.adopt({ ... }, select("#", ...)) end
local function object(value: any): boolean
	local kind = SourceType.typeOf(value)
	return not Nulls.isNull(value) and (kind == "object" or kind == "function")
end
local function nativeInvoke(ops: any, callback: any, ...: any): any
	local arguments = packet(...)
	if type(callback) ~= "function" then return ops.call(callback, nil, arguments) end
	return Functions.invokeReference(Functions.reference(nil, function() return callback end, "free", false),
		function() return arguments end, false)
end
local function dual(name: string, arity: number, receiver: boolean, native: any, source: any): any
	local state = { native = native, source = source, properties = Records.adopt({}, {}) }
	local function value(...: any): any return state.native(...) end
	Functions.named(value, name, arity, receiver)
	Functions.source(value, state.source, state.properties)
	return value
end
local function fieldsOf(owner: any, key: any): any return (getmetatable(owner) :: any)[key] end
local instanceSchema = {
	tag = "Promise",
	hasOwn = function(owner: any, key: any): boolean return Records.hasOwn(stateOf(owner).properties, key) end,
	get = function(owner: any, key: any): any return rawget(stateOf(owner).properties, key) end,
	ownKeys = function(owner: any): any return Records.ownKeys(stateOf(owner).properties) end,
	enumerable = function(owner: any, key: any): boolean return Records.hasOwn(stateOf(owner).properties, key) end,
	prototype = function(owner: any): any return stateOf(owner).prototype end,
	set = function(owner: any, key: any, value: any)
		assert(not table.isfrozen(owner), "TypeError: Promise properties are frozen")
		assert(key ~= "__proto__", "Promise prototype mutation is unsupported")
		Records.define(stateOf(owner).properties, key, value)
	end,
	define = function(owner: any, key: any, value: any)
		assert(not table.isfrozen(owner), "TypeError: Promise properties are frozen")
		Records.define(stateOf(owner).properties, key, value)
	end,
	remove = function(owner: any, key: any): boolean
		local properties = stateOf(owner).properties
		assert(not table.isfrozen(owner) or not Records.hasOwn(properties, key), "TypeError: Promise properties are frozen")
		return Records.remove(properties, key)
	end,
}
local prototypeSchema = {
	tag = "Promise",
	hasOwn = function(owner: any, key: any): boolean return fieldsOf(owner, fieldsToken)[key] ~= nil end,
	get = function(owner: any, key: any): any return fieldsOf(owner, fieldsToken)[key] end,
	ownKeys = function(): any return packet("constructor", "then", "catch", "finally") end,
	enumerable = function(): boolean return false end,
}
local constructorSchema = {
	hasOwn = function(owner: any, key: any): boolean return fieldsOf(owner, staticToken)[key] ~= nil end,
	get = function(owner: any, key: any): any return fieldsOf(owner, staticToken)[key] end,
	ownKeys = function(): any return packet("length", "name", "prototype", "resolve", "reject", "all", "allSettled", "race", "any") end,
	enumerable = function(): boolean return false end,
	prototype = function(owner: any): any return fieldsOf(owner, functionPrototypeToken) end,
	call = function(): never error("TypeError: Promise constructor requires new", 2) end,
}
local function nativeIndex(owner: any, key: any): any
	local state = stateOf(owner)
	return if Records.hasOwn(state.properties, key) then rawget(state.properties, key) else fieldsOf(state.prototype, fieldsToken)[key]
end
function Promise.create(ops: any, jobs: any): any
	local closed = false
	local owned: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local token = {}
	local constructor: any = {}
	local prototype: any = {}
	local releases: { () -> () } = {}
	local callbacks: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local fields: any = { constructor = constructor }
	local createCapability: () -> any
	local adopt: (any, any) -> ()
	local thenValue: (any, any, any) -> any
	local resolveValue: (any) -> any
	local rejectValue: (any) -> any
	local function alive() assert(not closed, "Source Promise realm is destroyed") end
	local function ownedCallback(callback: any, name: string, length: number): any
		local state: any = { callback = callback }
		callbacks[state] = true
		return ops.functionValue(function(receiver: any, args: any): any
			if closed or not state.callback then return nil end
			return (state.callback :: (any, any) -> any)(receiver, args)
		end, name, length, "arrow")
	end
	local function errorValue(name: string, message: string): any
		-- Error prototype construction is a separate native capability. These
		-- rejection fields are source data; no native Error identity is guessed.
		return Records.adopt({ name = name, message = message }, { "name", "message" })
	end
	local function unlink(state: any, handler: any)
		if handler.previous then handler.previous.following = handler.following else state.head = handler.following end
		if handler.following then handler.following.previous = handler.previous else state.tail = handler.previous end
		handler.previous, handler.following = nil, nil
	end
	local function dispatch(state: any, handler: any)
		if not handler.active or closed then return end
		handler.cancel = jobs.enqueue(function()
			handler.cancel = nil
			if closed or not handler.active then return end
			handler.active = false
			local callback = handler.callback
			handler.callback = nil
			callback(state.status == "fulfilled", state.value)
		end)
	end
	local function subscribe(value: any, callback: (boolean, any) -> ()): () -> ()
		alive()
		local state = stateOf(value)
		assert(state.realm == token, "Cross-realm native Promise subscription requires adoption")
		local handler: any = { active = true, callback = callback, previous = nil, following = nil, cancel = nil }
		if state.status == "pending" then
			handler.previous = state.tail
			if state.tail then state.tail.following = handler else state.head = handler end
			state.tail = handler
		else dispatch(state, handler) end
		return function()
			if not handler.active then return end
			handler.active = false
			if state.status == "pending" then unlink(state, handler) end
			if handler.cancel then (handler.cancel :: () -> ())(); handler.cancel = nil end
			handler.callback = nil
		end
	end
	local function settle(state: any, status: string, value: any)
		if closed or state.status ~= "pending" then return end
		state.status, state.value = status, value
		table.clear(state.anchors)
		local handler = state.head
		state.head, state.tail = nil, nil
		while handler do
			local following = handler.following
			handler.previous, handler.following = nil, nil
			dispatch(state, handler)
			handler = following
		end
	end
	adopt = function(state: any, value: any)
		if closed or state.status ~= "pending" then return end
		if value == state.promise then settle(state, "rejected", errorValue("TypeError", "A promise cannot resolve to itself")); return end
		if object(value) then
			local ok, thenMethod = pcall(ops.get, value, "then")
			if not ok then settle(state, "rejected", ops.caught(thenMethod)); return end
			if SourceType.typeOf(thenMethod) == "function" then
				jobs.enqueue(function()
					if closed or state.status ~= "pending" then return end
					local called = false
					local resolve = ownedCallback(function(_receiver: any, args: any)
						if called then return end
						called = true
						adopt(state, args[1])
					end, "resolve", 1)
					local reject = ownedCallback(function(_receiver: any, args: any)
						if called then return end
						called = true
						settle(state, "rejected", args[1])
					end, "reject", 1)
					local success, failure = pcall(ops.call, thenMethod, value, packet(resolve, reject))
					if not success and not called then called = true; settle(state, "rejected", ops.caught(failure)) end
				end)
				return
			end
		end
		settle(state, "fulfilled", value)
	end
	createCapability = function(): any
		alive()
		local value: any = {}
		local state: any = { promise = value, realm = token, prototype = prototype, status = "pending", value = nil, locked = false,
			head = nil, tail = nil, anchors = {}, properties = Records.adopt({}, {}) }
		identity[value], owned[value] = true, true
		setmetatable(value, { [stateToken] = state, __index = nativeIndex })
		ops.registerObject(value, instanceSchema)
		local resolve = ownedCallback(function(_receiver: any, args: any)
			if closed or state.locked then return end
			state.locked = true
			adopt(state, args[1])
		end, "resolve", 1)
		local reject = ownedCallback(function(_receiver: any, args: any)
			if closed or state.locked then return end
			state.locked = true
			settle(state, "rejected", args[1])
		end, "reject", 1)
		return { promise = value, resolve = resolve, reject = reject }
	end
	resolveValue = function(value: any): any
		alive()
		if identity[value] and ops.get(value, "constructor") == constructor then return value end
		local capability = createCapability()
		capability.resolve(value)
		return capability.promise
	end
	rejectValue = function(reason: any): any local capability = createCapability(); capability.reject(reason); return capability.promise end
	thenValue = function(value: any, fulfilled: any, rejected: any): any
		alive()
		local state = stateOf(value)
		assert(state.realm == token, "Borrowed cross-realm Promise methods are unsupported")
		local selected = ops.get(value, "constructor")
		assert(selected == nil or selected == constructor, "Custom Promise constructors/species are unsupported")
		local capability = createCapability()
		subscribe(value, function(ok: boolean, result: any)
			local callback = if ok then fulfilled else rejected
			if SourceType.typeOf(callback) ~= "function" then
				if ok then capability.resolve(result) else capability.reject(result) end
				return
			end
			local success, returned = pcall(ops.call, callback, nil, packet(result))
			if success then capability.resolve(returned) else capability.reject(ops.caught(returned)) end
		end)
		return capability.promise
	end
	local function nativeCallback(value: any): any
		if SourceType.typeOf(value) ~= "function" then return value end
		return ownedCallback(function(_receiver: any, args: any): any
			return nativeInvoke(ops, value, table.unpack(args, 1, Arrays.length(args)))
		end, "native callback", 1)
	end
	local function method(name: string, arity: number, source: (any, any, any) -> any)
		local callback = dual(name, arity, true, function(receiver: any, first: any, second: any): any
			return source(receiver, nativeCallback(first), nativeCallback(second))
		end, function(receiver: any, args: any): any return source(receiver, args[1], args[2]) end)
		fields[name] = callback
	end
	method("then", 2, thenValue)
	method("catch", 1, function(value: any, rejected: any): any
		return ops.call(ops.get(value, "then"), value, packet(nil, rejected))
	end)
	method("finally", 1, function(value: any, callback: any): any
		alive()
		if SourceType.typeOf(callback) ~= "function" then return ops.call(ops.get(value, "then"), value, packet(callback, callback)) end
		local function finish(ok: boolean): any
			return ownedCallback(function(_self: any, args: any): any
				local result = args[1]
				local returned = ops.call(callback, nil, packet())
				return thenValue(resolveValue(returned), ownedCallback(function(): any
					if ok then return result end
					return ops.raise(result)
				end, "finally continuation", 0), nil)
			end, "finally handler", 1)
		end
		return ops.call(ops.get(value, "then"), value, packet(finish(true), finish(false)))
	end)
	setmetatable(prototype, { [fieldsToken] = fields })
	local releasePrototype = ops.registerObject(prototype, prototypeSchema)
	table.insert(releases, releasePrototype)
	local function construct(executor: any, native: boolean): any
		alive()
		assert(SourceType.typeOf(executor) == "function", "TypeError: Promise executor must be callable")
		local capability = createCapability()
		local ok, failure
		if native then ok, failure = pcall(nativeInvoke, ops, executor, capability.resolve, capability.reject)
		else ok, failure = pcall(ops.call, executor, nil, packet(capability.resolve, capability.reject)) end
		if not ok then capability.reject(ops.caught(failure)) end
		return capability.promise
	end
	constructor.new = function(executor: any): any return construct(executor, true) end
	local static: any = { name = "Promise", length = 1, prototype = prototype, resolve = resolveValue, reject = rejectValue }
	local function aggregate(input: any, mode: string): any
		local capability = createCapability()
		local ok, failure = pcall(function()
			local iterator = ops.iterable(input)
			local results, remaining, count = Arrays.adopt({}, 0), 1, 0
			local function finish()
				if remaining ~= 0 then return end
				if mode == "any" then
					local error = errorValue("AggregateError", "All promises were rejected")
					Records.define(error, "errors", results)
					capability.reject(error)
				elseif mode ~= "race" then capability.resolve(results) end
			end
			while true do
				local step = iterator.next(iterator)
				if step.done then break end
				local index = count
				count, remaining = count + 1, remaining + 1
				Arrays.push(results, nil)
				local success, problem = pcall(function()
					local called = false
					local function settled(passed: boolean, value: any)
						if mode == "race" then if passed then capability.resolve(value) else capability.reject(value) end; return end
						if passed and mode == "any" then capability.resolve(value); return end
						if not passed and mode == "all" then capability.reject(value); return end
						if called then return end
						called = true
						local item = value
						if mode == "allSettled" then
							item = if passed then Records.adopt({ status = "fulfilled", value = value }, { "status", "value" })
								else Records.adopt({ status = "rejected", reason = value }, { "status", "reason" })
						end
						Arrays.set(results, index, item)
						remaining -= 1
						finish()
					end
					local nextPromise = resolveValue(step.value)
					ops.call(ops.get(nextPromise, "then"), nextPromise, packet(
						ownedCallback(function(_receiver: any, args: any) settled(true, args[1]) end, "aggregate fulfilled", 1),
						ownedCallback(function(_receiver: any, args: any) settled(false, args[1]) end, "aggregate rejected", 1)))
				end)
				if not success then if iterator.close then pcall(iterator.close) end; error(problem, 0) end
			end
			remaining -= 1
			finish()
		end)
		if not ok then capability.reject(ops.caught(failure)) end
		return capability.promise
	end
	for _, name in { "all", "allSettled", "race", "any" } do
		local mode = name
		local callback = function(input: any): any return aggregate(input, mode) end
		static[name] = callback
	end
	SourceType.register(constructor, "function")
	for _, name in { "resolve", "reject", "all", "allSettled", "race", "any" } do
		local implementation = static[name]
		local callback = dual(name, 1, false, implementation, function(receiver: any, args: any): any
			assert(receiver == constructor, "Generic Promise static constructors are unsupported")
			return implementation(args[1])
		end)
		constructor[name], static[name] = callback, callback
	end
	local function functionPrototypeProbe() end
	setmetatable(constructor, { [staticToken] = static, [functionPrototypeToken] = ops.get(functionPrototypeProbe, "__proto__") })
	local releaseObject: () -> () = ops.registerObject(constructor, constructorSchema)
	local releaseConstructor: () -> () = ops.registerConstructor(constructor, function(_constructor: any, args: any): any return construct(args[1], false) end)
	table.insert(releases, releaseObject)
	table.insert(releases, releaseConstructor)
	return {
		Promise = constructor, resolve = resolveValue, reject = rejectValue, capability = createCapability, subscribe = subscribe,
		retain = function(value: any, key: any, retained: any) stateOf(value).anchors[key] = retained end,
		destroy = function()
			if closed then return end
			closed = true
			for state in callbacks do state.callback = nil end
			table.clear(callbacks)
			for value in owned do
				local state = stateOf(value)
				local handler = state.head
				while handler do local following = handler.following; handler.callback, handler.active = nil, false; handler.previous, handler.following = nil, nil; handler = following end
				state.head, state.tail, state.value, state.promise, state.status = nil, nil, nil, nil, "destroyed"
				table.clear(state.anchors)
			end
			for _, release in releases do release() end
			table.clear(releases)
		end,
	}
end
return Promise
