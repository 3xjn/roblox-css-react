--!strict

local Css = require(script.Parent.Runtime)
local Host = require(script.Parent.ReconcilerHost)
local RendererRoot = require(script.Parent.RendererRoot)
local Html = require(script.Parent.Html)

-- The consumer supplies this ModuleScript at runtime; its export is validated
-- below. Static source mapping cannot resolve a newly cloned initializer.
local loadReconciler: (ModuleScript) -> any = require :: any

export type Root = {
	render: (any) -> (),
	unmount: () -> (),
}
export type Renderer = {
	flushSync: (() -> ()) -> (),
	createRoot: (GuiObject, Css.Stylesheet, Css.HostOptions, ((string) -> ())?) -> Root,
	destroy: () -> (),
}
type Entry = {
	target: GuiObject,
	root: RendererRoot.Root,
	closed: boolean,
	unavailable: boolean,
	connections: { RBXScriptConnection },
}

-- Exclusive ownership applies across renderer factories from this package.
-- The caller must also avoid independently mounting a CSS host on this target.
local targets = setmetatable({}, { __mode = "k" }) :: { [GuiObject]: boolean }
local destroyedTargets = setmetatable({}, { __mode = "k" }) :: { [GuiObject]: boolean }
local Renderer = {}

function Renderer.create(source: ModuleScript): Renderer
	assert(source:IsA("ModuleScript") and source.Parent, "CSS renderer needs a parented reconciler ModuleScript")
	assert(source:FindFirstChild("ReactFiberHostConfig"), "Expected a React Luau reconciler initializer")
	assert(source.Archivable, "CSS reconciler initializer must be archivable")
	for _, descendant in source:GetDescendants() do
		assert(descendant.Archivable, "CSS reconciler descendants must be archivable")
	end
	-- Sibling placement preserves upstream relative peer imports. Never require
	-- and reconfigure the source, rename it, or alter any of its descendants.
	local isolated = assert(source:Clone(), "Could not clone CSS reconciler initializer") :: ModuleScript
	isolated.Name = `CssReconciler_{game:GetService("HttpService"):GenerateGUID(false)}`
	isolated.Parent = source.Parent
	local initialized, result = pcall(function()
		local initialize = loadReconciler(isolated)
		assert(type(initialize) == "function", "Expected a React Luau reconciler initializer function")
		local reconciler = (initialize :: ({ [string]: any }) -> any)(Host.createConfig())
		for _, name in { "createContainer", "updateContainer", "flushSync", "flushPassiveEffects" } do
			assert(type(reconciler[name]) == "function", `CSS reconciler requires {name}`)
		end
		return reconciler
	end)
	if not initialized then
		isolated:Destroy()
		error(result, 0)
	end
	local reconciler = result :: RendererRoot.Reconciler
	local entries: { Entry } = {}
	local closed = false
	local busy = false
	local pending: { [Entry]: () -> () } = {}
	local renderer: Renderer = {} :: Renderer
	local function forget(entry: Entry)
		entry.closed = true
		pending[entry] = nil
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		table.clear(entry.connections)
		targets[entry.target] = nil
		local index = table.find(entries, entry)
		if index then
			table.remove(entries, index)
		end
	end
	local function drain()
		local work = pending
		pending = {}
		for entry, cleanup in work do
			if not entry.closed then
				local ok, failure = pcall(cleanup)
				if not ok then
					warn(`CSS destroyed target cleanup: {tostring(failure)}`)
				end
			end
		end
	end
	local function operation(callback: () -> ())
		assert(not closed, "CSS renderer has been destroyed")
		assert(not busy, "CSS renderer operations cannot run during render or effects")
		busy = true
		local ok, failure = pcall(callback)
		busy = false
		drain()
		if not ok then
			error(failure, 0)
		end
	end
	function renderer.createRoot(
		target: GuiObject,
		stylesheet: Css.Stylesheet,
		options: Css.HostOptions,
		onDiagnostic: ((string) -> ())?
	): Root
		assert(not closed, "CSS renderer has been destroyed")
		assert(not busy, "CSS renderer operations cannot run during render or effects")
		assert(target:IsA("GuiObject"), "CSS root target must be a GuiObject")
		assert(not destroyedTargets[target], "CSS root target was destroyed")
		assert(not targets[target], "CSS root target already belongs to a renderer")
		targets[target] = true
		local host: Css.Host? = nil
		busy = true
		local created, root = pcall(function()
			local settings = table.clone(options)
			local styles = table.clone(options.styles or ({} :: Css.RootOptions))
			local displayDefaults = Html.getDisplayDefaults()
			for tag, value in styles.displayDefaults or {} do
				displayDefaults[tag] = value
			end
			styles.displayDefaults = displayDefaults
			settings.styles = styles
			host = Css.createHost(target, stylesheet, settings)
			return RendererRoot.create(reconciler, host :: Css.Host, onDiagnostic)
		end)
		busy = false
		drain()
		if not created then
			targets[target] = nil
			if host then
				local cleaned, failure = pcall(function()
					(host :: Css.Host):destroy()
				end)
				if not cleaned then
					error(`CSS root creation: {tostring(root)}; cleanup: {tostring(failure)}`, 0)
				end
			end
			error(root, 0)
		end
		local entry: Entry = { target = target, root = root, closed = false, unavailable = false, connections = {} }
		table.insert(entries, entry)
		local public: Root = {} :: Root
		function public.render(element: any)
			assert(not entry.closed, "CSS renderer root is unmounted")
			assert(not entry.unavailable, "CSS renderer target has been destroyed")
			operation(function()
				local ok, failure = pcall(entry.root.render, element)
				if not entry.root.getContainer() then
					forget(entry)
				end
				if not ok then
					error(failure, 0)
				end
			end)
		end
		function public.unmount()
			if entry.closed then
				return
			end
			operation(function()
				local ok, failure = pcall(entry.root.unmount)
				if not entry.root.getContainer() then
					forget(entry)
				end
				if not ok then
					error(failure, 0)
				end
			end)
		end
		local function destroyed(targetGone: boolean)
			if targetGone then
				destroyedTargets[target] = true
			end
			if entry.closed or entry.unavailable then
				return
			end
			entry.unavailable = true
			local container = entry.root.getContainer()
			if container then
				container.releasing = true
			end
			-- One deferred reaction coalesces ancestor/target/host destruction and
			-- avoids entering React while a native Destroying callback is running.
			task.defer(function()
				if entry.closed then
					return
				end
				pending[entry] = public.unmount
				if not busy then
					drain()
				end
			end)
		end
		table.insert(
			entry.connections,
			target.Destroying:Connect(function()
				destroyed(true)
			end)
		)
		table.insert(
			entry.connections,
			(host :: Css.Host).mount.Destroying:Connect(function()
				destroyed(false)
			end)
		)
		return public
	end
	function renderer.destroy()
		if closed then
			return
		end
		assert(not busy, "CSS renderer cannot be destroyed during render or effects")
		closed = true
		local failures: { string } = {}
		for index = #entries, 1, -1 do
			local entry = entries[index]
			local ok, failure = pcall(entry.root.unmount)
			forget(entry)
			if not ok then
				table.insert(failures, tostring(failure))
			end
		end
		isolated:Destroy()
		if #failures > 0 then
			error(`CSS renderer cleanup: {table.concat(failures, "; ")}`, 0)
		end
	end
	function renderer.flushSync(callback: () -> ())
		operation(function()
			reconciler.flushSync(callback)
		end)
	end
	return renderer
end

return Renderer
