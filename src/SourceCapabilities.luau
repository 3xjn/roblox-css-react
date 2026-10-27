--!strict
-- Source APIs without Roblox equivalents enter through an explicit host
-- capability. In particular, Lua patterns are not JavaScript regular
-- expressions, and ASCII formatting is not Intl locale formatting.
local SourceCapabilities = {}
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local Collections = require(script.Parent.SourceCollections)
local SourceIntersection = require(script.Parent.SourceIntersection)
local SourceJson = require(script.Parent.SourceJson)
local SourcePromise = require(script.Parent.SourcePromise)
local SourceErrors = require(script.Parent.SourceErrors)
local SourceWeakRef = require(script.Parent.SourceWeakRef)
local SourceURL = require(script.Parent.SourceURL)
local WeakKeys = require(script.Parent.SourceWeakKeys)
export type Options = { [string]: any }
local owners: { [any]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

local symbols: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local registered: { [string]: any } = {}
local registeredKeys: { [any]: string } = setmetatable({}, { __mode = "k" }) :: any
local function symbolValue(description: any?): any
	assert(
		description == nil or type(description) == "string" or type(description) == "number",
		"Symbol description requires a primitive string or number"
	)
	local value = table.freeze(setmetatable({}, {
		__tostring = function()
			return "Symbol(" .. (if description == nil then "" else tostring(description)) .. ")"
		end,
	}))
	symbols[value] = true
	WeakKeys.registerSymbol(value, false)
	return value
end
local symbolMembers: Options = {}
local Symbol = setmetatable(symbolMembers, {
	__call = function(_self, description: any?): any
		return symbolValue(description)
	end,
})
Symbol["for"] = function(key: string): any
	assert(type(key) == "string", "Symbol.for requires a string key")
	if registered[key] == nil then
		registered[key] = symbolValue(key)
		registeredKeys[registered[key]] = key
		WeakKeys.registerSymbol(registered[key], true)
	end
	return registered[key]
end
Symbol.keyFor = function(value: any): string?
	assert(symbols[value], "Symbol.keyFor requires a Symbol")
	return registeredKeys[value]
end
Symbol.iterator = symbolValue("Symbol.iterator")
table.freeze(Symbol)

function SourceCapabilities.isSymbol(value: any): boolean
	return symbols[value] == true
end

local function eventConstructor(eventType: string, options: Options?): Options
	assert(type(eventType) == "string", "Event type must be a string")
	local settings: Options = options or ({} :: Options)
	local event: Options = {
		type = eventType,
		bubbles = settings.bubbles == true,
		cancelable = settings.cancelable == true,
		composed = settings.composed == true,
		defaultPrevented = false,
		isTrusted = false,
		eventPhase = 0,
		cancelBubble = false,
		returnValue = true,
		target = Nulls.value,
		currentTarget = Nulls.value,
		timeStamp = os.clock() * 1000,
	}
	event.preventDefault = function()
		if event.cancelable then
			event.defaultPrevented = true
			event.returnValue = false
		end
	end
	event.stopPropagation = function()
		event.cancelBubble = true
	end
	event.stopImmediatePropagation = function()
		event.cancelBubble = true
		event._immediatePropagationStopped = true
	end
	event.isDefaultPrevented = function(): boolean
		return event.defaultPrevented == true
	end
	event.isPropagationStopped = function(): boolean
		return event.cancelBubble == true
	end
	event.composedPath = function()
		-- A constructed, undispatched source event has no propagation path.
		return Arrays.adopt({}, 0)
	end
	return event
end
SourceCapabilities.createEvent = eventConstructor

local Event = setmetatable({ new = eventConstructor }, {
	__call = function(_self, eventType: string, options: Options?): Options
		return eventConstructor(eventType, options)
	end,
})

function SourceCapabilities.create(options: Options?): Options
	local supplied = options or {}
	local intersection = SourceIntersection.create()
	local promises = SourcePromise.create()
	local weakRefs = SourceWeakRef.create()
	local globals: Options = {
		Error = SourceErrors.Error,
		TypeError = SourceErrors.TypeError,
		RangeError = SourceErrors.RangeError,
		WeakRef = weakRefs.WeakRef,
		URL = SourceURL.URL,
		Event = Event,
		Map = Collections.Map,
		Set = Collections.Set,
		WeakMap = Collections.WeakMap,
		WeakSet = Collections.WeakSet,
		Symbol = Symbol,
		IntersectionObserver = intersection.constructor,
		JSON = SourceJson,
		Promise = promises.Promise,
		performance = table.freeze({
			now = function(): number
				return os.clock() * 1000
			end,
		}),
		console = table.freeze({ log = print, info = print, warn = warn, error = warn, debug = print }),
	}
	for _, name in
		{
			"RegExp",
			"Map",
			"Set",
			"WeakMap",
			"WeakSet",
			"JSON",
			"console",
			"Event",
			"Symbol",
			"Intl",
			"Promise",
			"performance",
			"IntersectionObserver",
			"Error",
			"TypeError",
			"RangeError",
			"WeakRef",
			"URL",
		}
	do
		if supplied[name] ~= nil then
			globals[name] = supplied[name]
		end
	end
	owners[globals] = function()
		intersection.destroy()
		promises.destroy()
		weakRefs.destroy()
	end
	return table.freeze(globals)
end

function SourceCapabilities.destroy(globals: Options)
	local release = owners[globals]
	owners[globals] = nil
	if release then
		release()
	end
end

return SourceCapabilities
