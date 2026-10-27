--!strict
-- React host event values backed by an actual DOM-boundary event. This module
-- owns no input detection, component behavior, DOM tree or default action.
local Records = require(script.Parent.Records)
local Functions = require(script.Parent.FunctionValues)
local Nulls = require(script.Parent.Nulls)

type State = { prevented: boolean, stopped: boolean }
local states: { [any]: State } = setmetatable({}, { __mode = "kv" })
local prototype: any = Records.adopt({}, {})
local function state(value: any): State
	return assert(states[value], "Illegal synthetic event receiver")
end
prototype.preventDefault = Functions.named(function(self: any)
	local current = state(self)
	self.defaultPrevented = true
	self.nativeEvent:preventDefault()
	current.prevented = true
end, "preventDefault", 0, true)
prototype.stopPropagation = Functions.named(function(self: any)
	self.nativeEvent:stopPropagation()
	state(self).stopped = true
end, "stopPropagation", 0, true)
prototype.persist = Functions.named(function(_self: any) end, "persist", 0, true)
prototype.isPersistent = Functions.named(function(_self: any): boolean
	return true
end, "isPersistent", 0, true)
local SyntheticEvents = {}
function SyntheticEvents.create(nativeEvent: any): any
	assert(type(nativeEvent) == "table", "Synthetic events require a native boundary event")
	local current = { prevented = nativeEvent.defaultPrevented == true, stopped = false }
	local event: any = Records.adopt(
		{
			nativeEvent = nativeEvent,
			type = nativeEvent.type,
			target = nativeEvent.target,
			currentTarget = Nulls.value,
			bubbles = nativeEvent.bubbles,
			cancelable = nativeEvent.cancelable,
			eventPhase = nativeEvent.eventPhase,
			isTrusted = nativeEvent.isTrusted,
			timeStamp = nativeEvent.timeStamp,
			defaultPrevented = nativeEvent.defaultPrevented,
			isDefaultPrevented = Functions.named(function(): boolean
				return current.prevented
			end, "", 0, false),
			isPropagationStopped = Functions.named(function(): boolean
				return current.stopped
			end, "", 0, false),
		},
		{
			"nativeEvent",
			"type",
			"target",
			"currentTarget",
			"bubbles",
			"cancelable",
			"eventPhase",
			"isTrusted",
			"timeStamp",
			"defaultPrevented",
			"isDefaultPrevented",
			"isPropagationStopped",
		}
	)
	Records.setPrototype(event, prototype)
	states[event] = current
	return event
end
-- A discrete host dispatch sets currentTarget only for the handler invocation.
-- Unpooled events retain their other fields, including after a callback throws.
function SyntheticEvents.invoke(callback: (any) -> (), event: any, currentTarget: any)
	state(event)
	event.currentTarget = currentTarget
	local ok, failure = pcall(function(): boolean
		callback(event)
		return true
	end)
	event.currentTarget = Nulls.value
	if not ok then
		error(failure, 0)
	end
end
return SyntheticEvents
