--!strict

local Css = require(script.Parent.Runtime)
local Host = require(script.Parent.ReconcilerHost)

-- This internal boundary accepts an already isolated/configured reconciler.
-- Provisioning must never initialize the consumer's native reconciler again.
export type Reconciler = {
	createContainer: (Host.Container, number, boolean, any) -> any,
	updateContainer: (any, any, any, (() -> ())?) -> any,
	flushSync: (() -> ()) -> any,
	flushPassiveEffects: () -> boolean,
}
export type Root = {
	render: (any) -> (),
	unmount: () -> (),
	getContainer: () -> Host.Container?,
}

local RendererRoot = {}

-- Ownership of host transfers after argument validation. This legacy root is
-- deliberately synchronous; calls from React render/effects are unsupported.
function RendererRoot.create(reconciler: Reconciler, host: Css.Host, onDiagnostic: ((string) -> ())?): Root
	for _, name in { "createContainer", "updateContainer", "flushSync", "flushPassiveEffects" } do
		assert(type((reconciler :: any)[name]) == "function", `CSS renderer requires reconciler.{name}`)
	end
	local container = Host.createContainer(host, onDiagnostic)
	local created, fiber = pcall(reconciler.createContainer, container, 0, false, nil)
	if not created then
		local cleaned, failure = pcall(Host.destroy, container)
		if not cleaned then
			error(`CSS root creation: {tostring(fiber)}; cleanup: {tostring(failure)}`, 0)
		end
		error(fiber, 0)
	end
	local closed = false
	local busy = false
	local root: Root = {} :: Root
	local function release(): { string }
		closed = true
		container.releasing = true
		local failures: { string } = {}
		local function attempt(callback: () -> ())
			local ok, failure = pcall(callback)
			if not ok then
				table.insert(failures, tostring(failure))
			end
		end
		-- Attempt every release even when a component cleanup throws. Passive
		-- effects are drained by the upstream API, not a retry/polling loop.
		attempt(function()
			reconciler.flushSync(function()
				reconciler.updateContainer(nil, fiber, nil, nil)
			end)
		end)
		attempt(function()
			reconciler.flushPassiveEffects()
		end)
		attempt(function()
			Host.destroy(container)
		end)
		fiber = nil
		return failures
	end
	function root.render(element: any)
		assert(not closed, "CSS renderer root is unmounted")
		assert(not busy, "CSS root operations cannot run inside another root operation")
		busy = true
		local ok, failure = pcall(function()
			reconciler.flushSync(function()
				reconciler.updateContainer(element, fiber, nil, nil)
			end)
		end)
		if not ok then
			local failures = release()
			busy = false
			if #failures > 0 then
				error(`CSS root render: {tostring(failure)}; cleanup: {table.concat(failures, "; ")}`, 0)
			end
			error(failure, 0)
		end
		busy = false
	end
	function root.unmount()
		if closed then
			return
		end
		assert(not busy, "CSS root operations cannot run inside another root operation")
		busy = true
		local failures = release()
		busy = false
		if #failures > 0 then
			error(`CSS root cleanup: {table.concat(failures, "; ")}`, 0)
		end
	end
	function root.getContainer(): Host.Container?
		return if closed then nil else container
	end
	return root
end

return RendererRoot
