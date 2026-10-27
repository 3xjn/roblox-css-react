--!strict
-- Event dispatch over an embedding-owned ordinary tree. The embedding supplies
-- real target ancestry and releases targets when their native ownership ends.
-- No DOM tree, input stream, default action or shadow retargeting is invented.
local Arrays = require(script.Parent.Arrays)
local Functions = require(script.Parent.FunctionValues)
local Nulls = require(script.Parent.Nulls)
local Properties = require(script.Parent.Properties)
local SourceType = require(script.Parent.SourceType)

type Info = {
	kind: string,
	bubbles: boolean,
	cancelable: boolean,
	composed: boolean,
	timestamp: number,
	target: any,
	current: any,
	phase: number,
	canceled: boolean,
	stopped: boolean,
	immediate: boolean,
	passive: boolean,
	dispatching: boolean,
	path: { any },
	extra: { [string]: any },
	extraPresent: { [string]: boolean },
}
type Listener = {
	callback: any,
	capture: boolean,
	once: boolean,
	passive: boolean,
	removed: boolean,
	release: () -> (),
}
type Signal = {
	read aborted: boolean,
	read addEventListener: (string, () -> (), { once: boolean? }?) -> (),
	read removeEventListener: (string, () -> ()) -> (),
}
export type ListenerOptions = { capture: boolean?, once: boolean?, passive: boolean?, signal: Signal? }
export type Init = { bubbles: boolean?, cancelable: boolean?, composed: boolean? }
export type Options = {
	read path: (any, boolean) -> { any },
	read reportError: ((any) -> ())?,
	read defaultPassive: ((any, string) -> boolean)?,
	-- A source-language host supplies its checked callback/object invocation ABI.
	-- Native callers keep the existing FunctionValues boundary by default.
	read invoke: ((any, any, any) -> any)?,
}
local DomEvents = {}
-- The event's private metatable owns its state. This weak identity map does not
-- root arbitrary event.expandos -> event cycles through a registry value.
local identities: { [any]: Info } = setmetatable({}, { __mode = "kv" })
local methods: { [string]: any } = {}
local constants: { [string]: number } = { NONE = 0, CAPTURING_PHASE = 1, AT_TARGET = 2, BUBBLING_PHASE = 3 }
local fields: { [string]: boolean } = {
	type = true,
	target = true,
	srcElement = true,
	currentTarget = true,
	eventPhase = true,
	bubbles = true,
	cancelable = true,
	composed = true,
	defaultPrevented = true,
	cancelBubble = true,
	returnValue = true,
	timeStamp = true,
	isTrusted = true,
	constructor = true,
}
local function fail(name: string, message: string): never
	local value = table.freeze(setmetatable({ name = name, message = message, stack = debug.traceback(message, 2) }, {
		__tostring = function()
			return name .. ": " .. message
		end,
	}))
	error(value, 0)
end
local function state(value: any): Info
	local info = identities[value]
	if not info then
		fail("TypeError", "Illegal Event receiver")
	end
	return assert(info)
end
local function cancel(info: Info)
	if info.cancelable and not info.passive then
		info.canceled = true
	end
end
methods.preventDefault = Functions.named(function(self: any)
	cancel(state(self))
end, "preventDefault", 0, true)
methods.stopPropagation = Functions.named(function(self: any)
	state(self).stopped = true
end, "stopPropagation", 0, true)
methods.stopImmediatePropagation = Functions.named(function(self: any)
	local info = state(self)
	info.immediate, info.stopped = true, true
end, "stopImmediatePropagation", 0, true)
methods.composedPath = Functions.named(function(self: any): { any }
	local path = state(self).path
	return Arrays.adopt(table.clone(path), #path)
end, "composedPath", 0, true)
local Event: any

function DomEvents.create(kind: string, init: Init?, timestamp: number?): any
	assert(type(kind) == "string", "Native Event type must be a string")
	local options: Init = if Nulls.isNullish(init) then {} else assert(init)
	local time = timestamp or os.clock() * 1000
	assert(time == time and math.abs(time) < math.huge, "Native Event timestamp must be finite")
	local info: Info = {
		kind = kind,
		bubbles = Nulls.truthy(options.bubbles),
		cancelable = Nulls.truthy(options.cancelable),
		composed = Nulls.truthy(options.composed),
		timestamp = time,
		target = Nulls.value,
		current = Nulls.value,
		phase = 0,
		canceled = false,
		stopped = false,
		immediate = false,
		passive = false,
		dispatching = false,
		path = {},
		extra = {},
		extraPresent = {},
	}
	local event: any = setmetatable({}, {
		__metatable = "Event",
		__index = function(_self: any, key: string): any
			if key == "type" then
				return info.kind
			end
			if key == "target" or key == "srcElement" then
				return info.target
			end
			if key == "currentTarget" then
				return info.current
			end
			if key == "eventPhase" then
				return info.phase
			end
			if key == "bubbles" then
				return info.bubbles
			end
			if key == "cancelable" then
				return info.cancelable
			end
			if key == "composed" then
				return info.composed
			end
			if key == "defaultPrevented" then
				return info.canceled
			end
			if key == "cancelBubble" then
				return info.stopped
			end
			if key == "returnValue" then
				return not info.canceled
			end
			if key == "timeStamp" then
				return info.timestamp
			end
			if key == "isTrusted" then
				return false
			end
			if info.extraPresent[key] then
				return info.extra[key]
			end
			if key == "constructor" then
				return Event
			end
			return methods[key] or constants[key]
		end,
		__newindex = function(_self: any, key: string, value: any)
			if key == "cancelBubble" then
				if Nulls.truthy(value) then
					info.stopped = true
				end
			elseif key == "returnValue" then
				if not Nulls.truthy(value) then
					cancel(info)
				end
			elseif fields[key] or constants[key] then
				fail("TypeError", "Event property is read-only: " .. tostring(key))
			else
				info.extra[key] = value
				info.extraPresent[key] = true
			end
		end,
	})
	identities[event] = info
	local weakState = setmetatable({ value = info }, { __mode = "v" })
	Properties.register(event, function(key: any): boolean
		local current = weakState.value
		return fields[key] == true
			or constants[key] ~= nil
			or methods[key] ~= nil
			or (current ~= nil and current.extraPresent[key] == true)
	end)
	return event
end
Event = {
	new = DomEvents.create,
	name = "Event",
	length = 1,
	prototype = methods,
	instanceof = function(value: any): boolean
		return identities[value] ~= nil
	end,
}
for key, value in constants do
	Event[key] = value
end
SourceType.register(Event, "function")
DomEvents.Event = table.freeze(Event)
-- Internal producer query lets a source host raise its genuine realm-owned
-- DOMException before entering a forbidden reentrant native dispatch.
function DomEvents.isDispatching(event: any): boolean
	return state(event).dispatching
end

local function invoke(callback: any, target: any, event: any): any
	local receiver, fn = target, callback
	local mode: "free" | "method" = "free"
	if SourceType.typeOf(callback) ~= "function" then
		receiver, fn, mode = callback, callback.handleEvent, "method"
	end
	return Functions.invokeReference(
		Functions.reference(receiver, function()
			return fn
		end, mode, false),
		function()
			return Arrays.adopt({ event }, 1)
		end,
		false
	)
end

function DomEvents.createDispatcher(options: Options)
	assert(type(options.path) == "function", "Event dispatch requires the real target path")
	local buckets: { [any]: { [string]: { Listener } } } = {}
	local closed, count = false, 0
	local report = options.reportError or function(failure: any)
		warn(failure)
	end
	local invokeListener = options.invoke or invoke
	local function listen(target: any, kind: string, callback: any, settings: (ListenerOptions | boolean)?): () -> ()
		assert(not closed, "Event dispatcher is destroyed")
		assert(not Nulls.isNullish(target), "Event listeners require an owned target")
		assert(type(kind) == "string", "Event listener type must be a string")
		if Nulls.isNullish(callback) then
			return function() end
		end
		local callbackKind = SourceType.typeOf(callback)
		if callbackKind ~= "function" and callbackKind ~= "object" then
			fail("TypeError", "Event listeners require a callback or handleEvent object")
		end
		local config: ListenerOptions = if type(settings) == "boolean"
			then { capture = settings }
			elseif Nulls.isNullish(settings) then {}
			else assert(settings)
		local capture, signal = Nulls.truthy(config.capture), config.signal
		if Nulls.isNullish(signal) then
			signal = nil
		end
		if signal and signal.aborted then
			return function() end
		end
		local types = buckets[target]
		if not types then
			types = {}
			buckets[target] = types
		end
		local listeners = types[kind]
		if not listeners then
			listeners = {}
			types[kind] = listeners
		end
		for _, entry in listeners do
			if entry.callback == callback and entry.capture == capture then
				return entry.release
			end
		end
		local passive = if config.passive ~= nil
			then Nulls.truthy(config.passive)
			elseif options.defaultPassive then options.defaultPassive(target, kind)
			else false
		local entry: Listener = {
			callback = callback,
			capture = capture,
			once = Nulls.truthy(config.once),
			passive = passive,
			removed = false,
			release = function() end,
		}
		local abort: (() -> ())? = nil
		local function release()
			if entry.removed then
				return
			end
			entry.removed = true
			count -= 1
			local index = table.find(listeners, entry)
			if index then
				table.remove(listeners, index)
			end
			if #listeners == 0 then
				types[kind] = nil
			end
			if next(types) == nil then
				buckets[target] = nil
			end
			if signal and abort then
				signal.removeEventListener("abort", abort)
				abort = nil
			end
		end
		entry.release = release
		table.insert(listeners, entry)
		count += 1
		if signal then
			abort = release
			signal.addEventListener("abort", release, { once = true })
		end
		return release
	end
	local function releaseTarget(target: any)
		local types = buckets[target]
		if types then
			for _, listeners in table.clone(types) do
				for _, entry in table.clone(listeners) do
					entry.release()
				end
			end
		end
	end
	local function visit(event: any, info: Info, target: any, phase: number, capture: boolean)
		if info.stopped then
			return
		end
		info.current, info.phase = target, phase
		local types = buckets[target]
		local listeners = types and types[info.kind]
		for _, entry in if listeners then table.clone(listeners) else {} do
			if not entry.removed and entry.capture == capture then
				if entry.once then
					entry.release()
				end
				info.passive = entry.passive
				local ok, failure = pcall(invokeListener, entry.callback, target, event)
				info.passive = false
				if not ok then
					-- Reporting is not another listener and must not interrupt dispatch.
					local reported, reportFailure = pcall(function(): boolean
						report(failure)
						return true
					end)
					if not reported then
						warn(reportFailure)
					end
				end
				if info.immediate then
					break
				end
			end
		end
	end
	local function dispatch(target: any, event: any): boolean
		assert(not closed, "Event dispatcher is destroyed")
		local info = state(event)
		if info.dispatching then
			fail("InvalidStateError", "An Event cannot be dispatched while it is dispatching")
		end
		local path = table.clone(options.path(target, info.composed))
		assert(#path > 0 and path[1] == target, "Event path must begin at the actual target")
		local seen = {}
		for _, item in path do
			assert(not Nulls.isNullish(item) and not seen[item], "Event paths require unique non-null targets")
			seen[item] = true
		end
		info.dispatching, info.target, info.path = true, target, path
		local ok, failure = pcall(function()
			for index = #path, 2, -1 do
				visit(event, info, path[index], 1, true)
			end
			visit(event, info, target, 2, true)
			visit(event, info, target, 2, false)
			if info.bubbles then
				for index = 2, #path do
					visit(event, info, path[index], 3, false)
				end
			end
		end)
		info.current, info.phase, info.path = Nulls.value, 0, {}
		info.dispatching, info.stopped, info.immediate, info.passive = false, false, false, false
		if not ok then
			error(failure, 0)
		end
		return not info.canceled
	end
	return {
		listen = listen,
		remove = function(target: any, kind: string, callback: any, capture: boolean?)
			local types = buckets[target]
			for _, entry in table.clone((types and types[kind]) or {}) do
				if entry.callback == callback and entry.capture == (capture == true) then
					entry.release()
					break
				end
			end
		end,
		dispatch = dispatch,
		releaseTarget = releaseTarget,
		listenerCount = function(): number
			return count
		end,
		destroy = function()
			if closed then
				return
			end
			closed = true
			for target in table.clone(buckets) do
				releaseTarget(target)
			end
		end,
	}
end
return DomEvents
