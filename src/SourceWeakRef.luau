--!strict
-- Native weak values with one-shot job retention. The retention boundary is
-- Roblox task.defer, not a claim about browser microtask/GC scheduling.
local Errors = require(script.Parent.SourceErrors)
local WeakKeys = require(script.Parent.SourceWeakKeys)
local SourceWeakRef = {}
local identities: { [any]: { holder: { any }, keep: (any) -> () } } = setmetatable({}, { __mode = "k" }) :: any
function SourceWeakRef.create()
	local closed = false
	local kept: { [any]: boolean } = {}
	local pending: thread? = nil
	local function keep(value: any)
		assert(not closed, "WeakRef owner is destroyed")
		if value == nil then
			return
		end
		kept[value] = true
		if not pending then
			pending = task.defer(function()
				pending = nil
				table.clear(kept)
			end)
		end
	end
	local function construct(value: any): any
		if not WeakKeys.canBeHeldWeakly(value) then
			error(Errors.TypeError("WeakRef target must be an object"), 2)
		end
		keep(value)
		local holder: { any } = setmetatable({ value }, { __mode = "v" }) :: any
		local reference = {
			deref = function(self: any): any
				local storage = identities[self]
				if not storage then
					error(Errors.TypeError("WeakRef method called with an incompatible receiver"), 2)
				end
				local observed = storage.holder[1]
				storage.keep(observed)
				return observed
			end,
		}
		identities[reference] = { holder = holder, keep = keep }
		return reference
	end
	local constructor = table.freeze(setmetatable({
		new = construct,
		instanceof = function(value: any): boolean
			return type(value) == "table" and identities[value] ~= nil
		end,
	}, {
		__call = function(): never
			error(Errors.TypeError("Constructor WeakRef requires 'new'"), 2)
		end,
	}))
	return {
		WeakRef = constructor,
		destroy = function()
			if closed then
				return
			end
			closed = true
			if pending then
				task.cancel(pending)
				pending = nil
			end
			table.clear(kept)
		end,
	}
end
return SourceWeakRef
