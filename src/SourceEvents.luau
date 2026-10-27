--!strict
-- Browser Event/EventTarget source values over the ordinary-tree dispatcher.
-- Existing host nodes attach with an explicit real path and release lease.
-- Standalone targets own their own dispatcher, so discarded target/listener
-- cycles do not become roots of a long-lived platform context.
local Native = require(script.Parent.DomEvents)
local Operations = require(script.Parent.SourceOperations)
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Symbols = require(script.Parent.SourceSymbols)
local SourceType = require(script.Parent.SourceType)

local SourceEvents = {}
local eventToken, targetToken = {}, {}
local attached: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local wrappers: { [any]: any } = setmetatable({}, { __mode = "kv" }) :: any
local constants: { [string]: number } = { NONE = 0, CAPTURING_PHASE = 1, AT_TARGET = 2, BUBBLING_PHASE = 3 }

local function packet(...: any): any return Arrays.adopt({ ... }, select("#", ...)) end
local function private(owner: any, token: any): any
	local meta = if type(owner) == "table" then getmetatable(owner) else nil
	return if type(meta) == "table" then rawget(meta, token) else nil
end
local function eventState(owner: any): any
	local value = private(owner, eventToken)
	if not value or not value.realm.active then return Operations.intrinsicError("TypeError", "Illegal or detached Event receiver") end
	return value
end
local function targetState(owner: any): any
	local value = private(owner, targetToken) or attached[owner]
	if not value or not value.realm.active or not value.active then
		return Operations.intrinsicError("TypeError", "Illegal or detached EventTarget receiver")
	end
	return value
end
local function ordinarySchema(token: any, tag: string): Operations.NativeObject
	local function state(owner: any): any
		return if token == eventToken then eventState(owner) else targetState(owner)
	end
	return {
		tag = tag,
		hasOwn = function(owner: any, key: any): boolean return Records.hasOwn(state(owner).fields, key) end,
		get = function(owner: any, key: any, receiver: any): any return Records.readOwn(state(owner).fields, key, receiver) end,
		ownKeys = function(owner: any): any return Records.ownKeys(state(owner).fields) end,
		enumerable = function(owner: any, key: any): boolean
			local descriptor = Records.descriptor(state(owner).fields, key)
			return descriptor ~= nil and descriptor.enumerable
		end,
		getOwnPropertyDescriptor = function(owner: any, key: any): any return Operations.getOwnPropertyDescriptor(state(owner).fields, key) end,
		properties = function(owner: any): any return state(owner).fields end,
		prototype = function(owner: any): any
			local current = state(owner)
			local explicit, parent = Records.getPrototype(current.fields)
			return if explicit then parent else current.prototype
		end,
	}
end
local eventSchema, targetSchema = ordinarySchema(eventToken, "Event"), ordinarySchema(targetToken, "EventTarget")
local trustedGetter = Operations.registerNative(function(owner: any): boolean
	return eventState(owner).native.isTrusted
end, "method", "get isTrusted", 0)

local function readCapture(ops: any, options: any): boolean
	if type(options) == "boolean" then return options end
	return if Nulls.isNullish(options) then false else ops.truthy(ops.get(options, "capture"))
end
local function add(target: any, kind: any, callback: any, options: any)
	local current = targetState(target)
	local ops = current.realm.ops
	local text = ops.string(kind)
	local settings: any = { capture = readCapture(ops, options) }
	if not Nulls.isNullish(options) and type(options) ~= "boolean" then
		settings.once = ops.truthy(ops.get(options, "once"))
		local passive = ops.get(options, "passive")
		settings.passive = if passive == nil then nil else ops.truthy(passive)
		local signal = ops.get(options, "signal")
		if not Nulls.isNullish(signal) then
			local resolve: ((any) -> any)? = current.realm.settings.signal
			assert(resolve, "AbortSignal listener options require the native signal brand/ABI capability")
			settings.signal = resolve(signal)
		end
	end
	current.dispatcher.listen(target, text, callback, settings)
end
local function remove(target: any, kind: any, callback: any, options: any)
	local current = targetState(target)
	local ops = current.realm.ops
	local text, capture = ops.string(kind), readCapture(ops, options)
	if Nulls.isNullish(callback) then return end
	current.dispatcher.remove(target, text, callback, capture)
end
local function dispatch(target: any, event: any): boolean
	local current = targetState(target)
	local native = eventState(event).native
	if Native.isDispatching(native) then
		local constructor: ((string, string) -> any)? = current.realm.settings.domException
		assert(constructor, "Invalid dispatch state requires the genuine DOMException capability")
		return current.realm.ops.raise(constructor("An Event cannot be dispatched while it is dispatching", "InvalidStateError"))
	end
	return current.dispatcher.dispatch(target, native)
end

function SourceEvents.create(ops: any, options: any?): any
	local realm: any = { ops = ops, settings = options or {}, active = true }
	local events: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local targets: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local external: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local eventPrototype: any = nil
	local targetPrototype: any = nil
	local Event: any = nil
	local EventTarget: any = nil
	local function open() assert(realm.active, "Source Event/EventTarget context is destroyed") end
	local function wrap(native: any, prototype: any?): any
		open()
		assert(Native.Event.instanceof(native), "A source event requires a genuine native Event")
		local previous = wrappers[native]
		if previous then eventState(previous); return previous end
		local state: any = { realm = realm, native = native, fields = ops.object(), prototype = prototype or eventPrototype }
		local value: any = {}
		setmetatable(value, { [eventToken] = state,
			__index = function(self: any, key: any): any return ops.get(self, key) end,
			__newindex = function(self: any, key: any, child: any) ops.set(self, key, child) end })
		Records.setReceiver(state.fields, value)
		ops.defineAccessor(state.fields, "isTrusted", trustedGetter, nil, true, false)
		state.release = ops.registerObject(value, eventSchema)
		wrappers[native], events[value] = value, true
		return value
	end
	local function invoke(callback: any, target: any, native: any): any
		local source = wrap(native)
		if SourceType.typeOf(callback) == "function" then return ops.call(callback, target, packet(source)) end
		return ops.call(ops.get(callback, "handleEvent"), callback, packet(source))
	end
	local function newDispatcher(path: any): any
		return Native.createDispatcher({ path = path, reportError = realm.settings.reportError, invoke = invoke })
	end
	local function actualPath(target: any, composed: boolean): { any }
		local current = targetState(target)
		local path = current.path(target, composed)
		for _, item in path do
			local member = targetState(item)
			assert(member.realm == realm, "Event path crosses an unregistered source context")
		end
		return path
	end
	local shared = newDispatcher(actualPath)
	Event = ops.classValue("Event", nil, false, function(frame: any, args: any): any
		open()
		if #args < 1 then return ops.intrinsicError("TypeError", "Event requires an event type") end
		local kind, init = ops.string(args[1]), args[2]
		local normalized = {}
		if not Nulls.isNullish(init) then
			for _, key in { "bubbles", "cancelable", "composed" } do normalized[key] = ops.truthy(ops.get(init, key)) end
		end
		local parent = ops.get(ops.classNewTarget(frame), "prototype")
		return wrap(Native.create(kind, normalized), if SourceType.typeOf(parent) == "object" then parent else eventPrototype)
	end, nil, 1)
	eventPrototype = ops.get(Event, "prototype")
	ops.defineDataProperty(eventPrototype, Symbols.Symbol.toStringTag, "Event", false, false, true)
	local function getter(name: string, callback: any, setter: any?)
		ops.defineAccessor(eventPrototype, name, ops.registerNative(callback, "method", "get " .. name, 0),
			if setter then ops.registerNative(setter, "method", "set " .. name, 1) else nil, true, true)
	end
	for _, name in { "type", "target", "srcElement", "currentTarget", "eventPhase", "bubbles", "cancelable", "composed", "defaultPrevented", "timeStamp" } do
		getter(name, function(owner: any): any return eventState(owner).native[name] end, nil)
	end
	for _, name in { "cancelBubble", "returnValue" } do
		getter(name, function(owner: any): any return eventState(owner).native[name] end,
			function(owner: any, value: any) eventState(owner).native[name] = ops.truthy(value) end)
	end
	for _, name in { "preventDefault", "stopPropagation", "stopImmediatePropagation", "composedPath" } do
		ops.defineDataProperty(eventPrototype, name, ops.registerNative(function(owner: any): any
			local native = eventState(owner).native
			return native[name](native)
		end, "method", name, 0), true, true, true)
	end
	for name, value in constants do
		ops.defineDataProperty(Event, name, value, false, true, false)
		ops.defineDataProperty(eventPrototype, name, value, false, true, false)
	end
	local PointerEvent = ops.classValue("PointerEvent", Event, true, function(frame: any, args: any): any
		open()
		if #args < 1 then return ops.intrinsicError("TypeError", "PointerEvent requires an event type") end
		local kind, init = ops.string(args[1]), args[2]
		local normalized = {}
		if not Nulls.isNullish(init) then
			for _, key in { "bubbles", "cancelable", "composed" } do normalized[key] = ops.truthy(ops.get(init, key)) end
		end
		local prototype = ops.get(ops.classNewTarget(frame), "prototype")
		local value = wrap(Native.create(kind, normalized), if SourceType.typeOf(prototype) == "object" then prototype else eventPrototype)
		for key, default in { detail = 0, button = 0, buttons = 0, clientX = 0, clientY = 0,
			pointerId = 0, pointerType = "", shiftKey = false, ctrlKey = false, altKey = false, metaKey = false } do
			local supplied = if Nulls.isNullish(init) then nil else ops.get(init, key)
			ops.set(value, key, if supplied == nil then default else supplied)
		end
		return value
	end, nil, 1)
	EventTarget = ops.classValue("EventTarget", nil, false, function(frame: any): any
		open()
		local prototype = ops.get(ops.classNewTarget(frame), "prototype")
		local state: any = { realm = realm, fields = ops.object(), prototype = if SourceType.typeOf(prototype) == "object" then prototype else targetPrototype, active = true }
		local value: any = {}
		setmetatable(value, { [targetToken] = state,
			__index = function(self: any, key: any): any return ops.get(self, key) end,
			__newindex = function(self: any, key: any, child: any) ops.set(self, key, child) end })
		Records.setReceiver(state.fields, value)
		state.release = ops.registerObject(value, targetSchema)
		state.dispatcher = newDispatcher(function(target: any): { any } return { target } end)
		targets[value] = true
		return value
	end, nil, 0)
	targetPrototype = ops.get(EventTarget, "prototype")
	ops.defineDataProperty(targetPrototype, Symbols.Symbol.toStringTag, "EventTarget", false, false, true)
	local callbacks: { [string]: any } = { addEventListener = add, removeEventListener = remove, dispatchEvent = dispatch }
	for name, callback in callbacks do
		local required = if name == "dispatchEvent" then 1 else 2
		ops.defineDataProperty(targetPrototype, name, ops.registerNative(function(owner: any, ...: any): any
			if select("#", ...) < required then return ops.intrinsicError("TypeError", name .. " has missing required arguments") end
			return (callback :: any)(owner, ...)
		end, "method", name, required), true, true, true)
	end
	local function attach(target: any, path: any): () -> ()
		open()
		assert(SourceType.typeOf(target) == "object" and not attached[target] and not private(target, targetToken), "EventTarget is already attached or invalid")
		assert(type(path) == "function", "Host targets require an explicit event path")
		local state: any = { realm = realm, active = true, dispatcher = shared, path = path }
		attached[target], external[target] = state, true
		local owner: any = target
		return function()
			if not owner then return end
			shared.releaseTarget(owner)
			if attached[owner] == state then attached[owner] = nil end
			external[owner] = nil
			state.active, state.path = false, nil
			owner = nil
		end
	end
	return {
		Event = Event, PointerEvent = PointerEvent, EventTarget = EventTarget, attach = attach,
		addEventListener = add, removeEventListener = remove, dispatchEvent = dispatch,
		adoptEvent = wrap,
		listenerCount = function(): number
			local count = shared.listenerCount()
			for target in targets do count += targetState(target).dispatcher.listenerCount() end
			return count
		end,
		destroy = function()
			if not realm.active then return end
			shared.destroy()
			for target in targets do
				local state = targetState(target)
				state.dispatcher.destroy()
				state.active = false
				state.release()
			end
			for target in external do attached[target] = nil end
			for event in events do local state = eventState(event); state.release() end
			realm.active = false
			table.clear(targets); table.clear(events); table.clear(external)
		end,
	}
end
return SourceEvents
