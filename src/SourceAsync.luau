--!strict
-- Managed source coroutines preserve lexical catch/finally across await.
-- Only opaque await requests may suspend; resumption is a Promise reaction job.
local Async = {}
function Async.create(ops: any, promises: any): any
	local closed = false
	local request = {}
	local completed = {}
	local running: { [thread]: any } = setmetatable({}, { __mode = "kv" }) :: any
	local active: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local resume: (any, boolean?, any?) -> ()
	local function retire(frame: any)
		if frame.release then (frame.release :: () -> ())(); frame.release = nil end
		if frame.thread then running[frame.thread] = nil end
		active[frame] = nil
		if frame.capability then promises.retain(frame.capability.promise, frame, nil) end
	end
	resume = function(frame: any, fulfilled: boolean?, value: any?)
		if closed or frame.cancelled then return end
		frame.release = nil
		local thread = frame.thread
		local ok, result, awaited, completionValue = coroutine.resume(thread, fulfilled, value)
		if closed or frame.cancelled then
			retire(frame)
			if coroutine.status(thread) == "suspended" then coroutine.close(thread) end
			return
		end
		if not ok then
			retire(frame)
			frame.capability.reject(ops.caught(result))
		elseif coroutine.status(thread) == "dead" then
			retire(frame)
			if result == completed then
				if awaited then frame.capability.resolve(completionValue) else frame.capability.reject(ops.caught(completionValue)) end
			else frame.capability.reject("Unsupported asynchronous coroutine completion") end
		elseif result == request then
			frame.release = promises.subscribe(awaited, function(passed: boolean, settled: any)
				resume(frame, passed, settled)
			end)
		else
			retire(frame)
			coroutine.close(thread)
			frame.capability.reject("Unsupported source async suspension outside await")
		end
	end
	local function run(body: () -> any): any
		assert(not closed, "Source async realm is destroyed")
		local capability = promises.capability()
		local frame: any = { capability = capability, cancelled = false }
		frame.thread = coroutine.create(function()
			-- Catch before crossing the host coroutine.resume boundary: some Luau
			-- embedders serialize uncaught coroutine errors, losing object identity.
			local ok, result = pcall(body)
			return completed, ok, result
		end)
		running[frame.thread], active[frame] = frame, true
		promises.retain(capability.promise, frame, frame)
		resume(frame)
		return capability.promise
	end
	return {
		asyncFunctionValue = function(callback: any, name: string, length: number, form: string): any
			assert(form == "ordinary" or form == "arrow" or form == "method", "Unknown asynchronous source function kind")
			local asyncForm = if form == "ordinary" then "asyncOrdinary" elseif form == "arrow" then "asyncArrow" else "asyncMethod"
			return ops.functionValue(function(receiver: any, args: any): any
				return run(function() return callback(receiver, args) end)
			end, name, length, asyncForm)
		end,
		awaitValue = function(value: any): any
			assert(not closed, "Source async realm is destroyed")
			local frame = running[coroutine.running()]
			assert(frame and not frame.cancelled, "Await requires this realm's managed asynchronous invocation")
			local promise = promises.resolve(value)
			local passed, result = coroutine.yield(request, promise)
			if not passed then ops.raise(result) end
			return result
		end,
		destroy = function()
			if closed then return end
			closed = true
			local current = coroutine.running()
			for frame in active do
				frame.cancelled = true
				retire(frame)
				if frame.thread ~= current and coroutine.status(frame.thread) == "suspended" then coroutine.close(frame.thread) end
			end
		end,
	}
end
return Async
