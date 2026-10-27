--!strict
-- Millisecond, zero-argument one-shot callbacks for source-built modules.
-- Roblox owns scheduling. The context owns only its numeric handle mapping.
local Timers = {}
export type Context = {
	setTimeout: (() -> (), number) -> number,
	clearTimeout: (number) -> (),
	now: () -> number,
	destroy: () -> (),
}
function Timers.create(): Context
	local nextId, closed = 0, false
	local pending: { [number]: thread } = {}
	local function clearTimeout(id: number)
		local scheduled = pending[id]
		pending[id] = nil
		if scheduled then
			task.cancel(scheduled)
		end
	end
	return {
		setTimeout = function(callback: () -> (), milliseconds: number): number
			assert(not closed, "Timer context is destroyed")
			assert(milliseconds == milliseconds and math.abs(milliseconds) < math.huge, "Timer delay must be finite")
			assert(nextId < 9007199254740991, "Timer handle range exhausted")
			nextId += 1
			local id = nextId
			pending[id] = task.delay(math.max(0, milliseconds) / 1000, function()
				if not pending[id] then
					return
				end
				-- A callback may clear/restart/destroy its owner or yield. It is no
				-- longer a pending timeout before any application code runs.
				pending[id] = nil
				callback()
			end)
			return id
		end,
		clearTimeout = clearTimeout,
		now = function(): number
			return DateTime.now().UnixTimestampMillis
		end,
		destroy = function()
			if closed then
				return
			end
			closed = true
			for id in pending do
				clearTimeout(id)
			end
		end,
	}
end
return Timers
