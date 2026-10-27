--!strict
-- Native frame requests, not a recurring listener or a scene/change scan.
-- A context owns its handles and at most one pending PreRender subscription.
local Frames = {}
export type Callback = (number) -> ()
export type Context = {
	requestAnimationFrame: (Callback) -> number,
	cancelAnimationFrame: (number) -> (),
	destroy: () -> (),
}
function Frames.create(): Context
	local runService = game:GetService("RunService")
	assert(runService:IsClient(), "Animation frame contexts require a client render loop")
	local event = runService.PreRender
	local origin, nextId, count, closed = os.clock(), 0, 0, false
	local pending: { [number]: Callback } = {}
	local order: { number } = {}
	local scheduled: RBXScriptConnection? = nil
	local function cancelAnimationFrame(id: number)
		if not pending[id] then
			return
		end
		pending[id] = nil
		count -= 1
		if count == 0 then
			if scheduled then
				scheduled:Disconnect()
				scheduled = nil
			end
			table.clear(order)
		end
	end
	local function tick()
		scheduled = nil
		local batch = order
		order = {}
		local timestamp = (os.clock() - origin) * 1000
		for _, id in batch do
			local callback = pending[id]
			if callback then
				pending[id] = nil
				count -= 1
				-- Native task dispatch isolates errors/yields between callbacks.
				-- Requests made here join the next native frame, not this batch.
				task.spawn(callback, timestamp)
			end
		end
	end
	return {
		requestAnimationFrame = function(callback: Callback): number
			assert(not closed, "Frame context is destroyed")
			assert(type(callback) == "function", "Frame callbacks must be functions")
			assert(nextId < 9007199254740991, "Frame handle range exhausted")
			nextId += 1
			local id = nextId
			pending[id] = callback
			count += 1
			table.insert(order, id)
			if not scheduled then
				scheduled = event:Once(tick)
			end
			return id
		end,
		cancelAnimationFrame = cancelAnimationFrame,
		destroy = function()
			if closed then
				return
			end
			closed = true
			if scheduled then
				scheduled:Disconnect()
				scheduled = nil
			end
			table.clear(order)
			table.clear(pending)
			count = 0
		end,
	}
end
return Frames
