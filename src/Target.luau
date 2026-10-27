--!strict

local Css = require(script.Parent.Runtime)
export type Context = {
	getNode: (() -> Css.Node?)?,
	getNodeTarget: ((Css.Node) -> GuiObject?)?,
	resolveLabelControl: () -> GuiObject?,
	getComputedStyle: () -> Css.ComputedStyle?,
	getLayoutBox: () -> Css.BoxGeometry?,
	ensureLayout: (() -> (boolean, string?))?,
	getInlineProperty: ((string) -> (string, string))?,
	getInlinePropertyNames: (() -> { string })?,
	setInlineProperty: ((string, string, string?) -> ())?,
	getResolvedProperty: ((string) -> (string?, string?))?,
	getResolvedPropertyNames: (() -> { string })?,
	setAttribute: ((string, string?) -> ())?,
	setState: ((string, boolean) -> ())?,
	getPlaybacks: ((boolean?) -> { Css.PlaybackHandle })?,
	getAttributes: (() -> { [string]: string })?,
	subscribeScene: ((number) -> ()) -> () -> (),
}
export type Binder = (GuiObject, Context?) -> (() -> ())?
export type ImageBinder = (ImageLabel) -> (() -> ())?

local Target = {}
-- HTML binders can update their committed state without replacing the native
-- target. Ordinary binders retain the existing teardown semantics.
local updates: any = setmetatable({}, { __mode = "k" })
function Target.registerUpdate(bind: Binder, descriptor: any)
	updates[bind] = descriptor
end
function Target.update(previous: Binder, nextBind: Binder): boolean
	local old, new = updates[previous], updates[nextBind]
	if not old or not new or old.tag ~= new.tag or old.createTarget ~= new.createTarget
		or old.previousBind ~= new.previousBind or old.textInput ~= new.textInput then
		return false
	end
	old.update(new)
	return true
end

-- Observe only committed native targets. A key can survive while its native
-- representation changes; no reference is looked up during React render.
local function watchResolved(
	host: Css.Host,
	key: Css.SceneKey,
	bind: Binder,
	resolve: (Css.Host, Css.SceneKey) -> GuiObject?
): () -> ()
	local closed = false
	local current: GuiObject? = nil
	local cleanup: (() -> ())? = nil
	local destroying: RBXScriptConnection? = nil
	local unsubscribe: (() -> ())? = nil
	local function clear()
		current = nil
		if destroying then
			destroying:Disconnect()
			destroying = nil
		end
		local previous = cleanup
		cleanup = nil
		if previous then
			previous()
		end
	end
	local function release()
		if closed then
			return
		end
		closed = true
		if unsubscribe then
			unsubscribe()
			unsubscribe = nil
		end
		clear()
	end
	local function replace(target: GuiObject?)
		if target == current then
			return
		end
		clear()
		if closed or not target then
			return
		end
		current = target
		destroying = target.Destroying:Connect(function()
			local ok, failure = pcall(clear)
			if not ok then
				release()
				error(failure, 0)
			end
		end)
		local nextCleanup = bind(target)
		-- Setup may synchronously destroy its target/host. Do not retain newly
		-- returned resources after that destruction or a reentrant replacement.
		if current == target and not closed then
			cleanup = nextCleanup
		elseif nextCleanup then
			nextCleanup()
		end
	end
	local function refresh()
		if closed then
			return
		end
		local ok, failure = pcall(function()
			replace(resolve(host, key))
		end)
		if not ok then
			local clean, cleanupFailure = pcall(release)
			if not clean then
				error(`Target binding: {tostring(failure)}; cleanup: {tostring(cleanupFailure)}`, 0)
			end
			error(failure, 0)
		end
	end
	local ok, failure = pcall(function()
		unsubscribe = host:subscribeScene(refresh)
		refresh()
	end)
	if not ok then
		local clean, cleanupFailure = pcall(release)
		if not clean then
			error(`Target subscription: {tostring(failure)}; cleanup: {tostring(cleanupFailure)}`, 0)
		end
		error(failure, 0)
	end
	return release
end

function Target.watch(host: Css.Host, key: Css.SceneKey, bind: Binder): () -> ()
	return watchResolved(host, key, bind, function(current, selected)
		return current:getGuiObject(selected)
	end)
end

function Target.watchWithContext(host: Css.Host, key: Css.SceneKey, bind: Binder, context: Context): () -> ()
	return Target.watch(host, key, function(target)
		return bind(target, context)
	end)
end

function Target.watchImage(host: Css.Host, key: Css.SceneKey, bind: ImageBinder): () -> ()
	return watchResolved(host, key, function(target)
		if target:IsA("ImageLabel") then
			return bind(target)
		end
		return nil
	end, function(current, selected)
		return current:getImageLabel(selected)
	end)
end

return Target
