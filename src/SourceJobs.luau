--!strict
-- One realm FIFO. A scheduled drain owns only its callbacks, never application
-- promises, event subscriptions, timers, or external producer cancellation.
local Jobs = {}
export type Options = { schedule: ((() -> ()) -> (() -> ())?)?, onError: ((any) -> ())? }
export type Context = { enqueue: (() -> ()) -> (() -> ()), destroy: () -> () }
function Jobs.create(options: Options?): Context
	local settings: Options = if options then table.clone(options) else {}
	local closed, draining, scheduling = false, false, false
	local queue: { [number]: { callback: (() -> ())? } } = {}
	local head, tail = 1, 0
	local scheduled = false
	local cancel: (() -> ())? = nil
	local function drain()
		assert(not scheduling, "The source job scheduler must defer its drain")
		if closed then return end
		cancel, scheduled, draining = nil, false, true
		local failures = {}
		while not closed and head <= tail do
			local job = queue[head]
			queue[head], head = nil, head + 1
			local callback = job.callback
			job.callback = nil
			if callback then
				local ok, failure = pcall(callback)
				if not ok then table.insert(failures, failure) end
			end
		end
		head, tail, draining = 1, 0, false
		if settings.onError then for _, failure in failures do settings.onError(failure) end
		elseif #failures > 0 then error(failures[1], 0) end
	end
	local function enqueue(callback: () -> ()): () -> ()
		assert(not closed, "Source job queue is destroyed")
		local job = { callback = callback :: (() -> ())? }
		tail += 1
		queue[tail] = job
		if not scheduled and not draining then
			scheduled, scheduling = true, true
			if settings.schedule then cancel = settings.schedule(drain)
			else
				local thread = task.defer(drain)
				cancel = function() if coroutine.status(thread) ~= "dead" then task.cancel(thread) end end
			end
			scheduling = false
		end
		return function() job.callback = nil end
	end
	return {
		enqueue = enqueue,
		destroy = function()
			if closed then return end
			closed = true
			if cancel then cancel() end
			cancel, scheduled = nil, false
			for _, job in queue do job.callback = nil end
			table.clear(queue)
			settings.schedule, settings.onError = nil, nil
			head, tail = 1, 0
		end,
	}
end
return Jobs
