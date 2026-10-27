--!strict

local Tree = require(script.Tree)
local Css = require(script.Runtime)
local Target = require(script.Target)
local Composer = require(script.Composer)
local Renderer = require(script.Renderer)
local Html = require(script.Html)

export type Element = Tree.Element
export type Key = Tree.Key
export type NodeOptions = Tree.NodeOptions
export type Ref<T> = { current: T }
export type TargetBinder = Target.Binder
export type ImageTargetBinder = Target.ImageBinder
export type NodeHandle = Composer.Handle
export type NodePlacement = Composer.Placement
export type RootController = Composer.Controller
export type Renderer = Renderer.Renderer
export type RendererRoot = Renderer.Root
type TargetSubscription<B> = {
	host: Css.Host,
	key: Tree.Key,
	node: Css.Node,
	bind: B,
	watch: (Css.Host, Css.SceneKey, B) -> () -> (),
	dispose: () -> (),
}
export type Controller = {
	commit: ({ Tree.Element }) -> (),
	getNode: (Tree.Key) -> Css.Node?,
	getHost: () -> Css.Host?,
	destroy: () -> (),
}
export type React = {
	read useRef: <T>(T) -> Ref<T>,
	read useLayoutEffect: (() -> (() -> ())?, { unknown }?) -> (),
}

local Bindings = {}

-- Inject the application's React instance. No second React copy,
-- executor asset loader, reconciliation fork or native widget tree is bundled.
function Bindings.createBindings(react: React)
	local function useCssRoot(
		target: GuiObject,
		stylesheet: Css.Stylesheet,
		options: Css.HostOptions
	): Composer.Controller
		local reference = react.useRef(nil :: Composer.Controller?)
		if not reference.current then
			-- This allocation is data only; native objects are owned by the effect.
			reference.current = Composer.create()
		end
		local controller = reference.current :: Composer.Controller
		react.useLayoutEffect(function()
			controller.attach(Css.createHost(target, stylesheet, options))
			return controller.detach
		end, { target, stylesheet, options })
		return controller
	end
	local function useCssNode(controller: Composer.Controller, placement: Composer.Placement): Composer.Handle
		local reference = react.useRef(setmetatable({}, { __mode = "k" }) :: { [Composer.Controller]: Composer.Handle })
		local handle = reference.current[controller]
		if not handle then
			handle = controller.createHandle()
			reference.current[controller] = handle
		end
		react.useLayoutEffect(function()
			controller.update(handle, placement)
			return nil
		end)
		react.useLayoutEffect(function()
			return function()
				controller.remove(handle)
			end
		end, { controller, handle })
		return handle
	end
	local function useNodeTarget(controller: Composer.Controller, handle: Composer.Handle, bind: Target.Binder?)
		react.useLayoutEffect(function()
			local host: Css.Host? = nil
			local node: Css.Node? = nil
			local dispose: (() -> ())? = nil
			local function clear()
				host, node = nil, nil
				local previous = dispose
				dispose = nil
				if previous then
					previous()
				end
			end
			local function refresh()
				local currentHost, currentNode = controller.getHost(), controller.getNode(handle)
				if currentHost == host and currentNode == node then
					return
				end
				clear()
				if currentHost and currentNode and bind then
					host, node = currentHost, currentNode
					local ok, nextDispose = pcall(Target.watch, currentHost, currentNode, bind)
					if not ok then
						clear()
						error(nextDispose, 0)
					end
					if host == currentHost and node == currentNode then
						dispose = nextDispose
					else
						nextDispose()
					end
				end
			end
			local unsubscribe = controller.subscribe(refresh)
			local ok, failure = pcall(refresh)
			if not ok then
				unsubscribe()
				clear()
				error(failure, 0)
			end
			return function()
				unsubscribe()
				clear()
			end
		end, { controller, handle, bind or false })
	end
	local function useCssTree(
		target: GuiObject,
		stylesheet: Css.Stylesheet,
		options: Css.HostOptions,
		elements: { Tree.Element }
	): Ref<Controller?>
		local reference = react.useRef(nil :: Controller?)
		react.useLayoutEffect(function()
			local controller = Tree.create(Css.createHost(target, stylesheet, options))
			reference.current = controller
			return function()
				if reference.current == controller then
					reference.current = nil
				end
				controller.destroy()
			end
		end, { target, stylesheet, options })
		-- Run after every committed render: mutable render inputs are snapshotted
		-- by Tree before host writes, without relying on table identity for updates.
		react.useLayoutEffect(function()
			local controller = reference.current
			if controller then
				controller.commit(elements)
			end
			return nil
		end)
		return reference
	end
	local function useTarget<B>(
		reference: Ref<Controller?>,
		key: Tree.Key,
		bind: B?,
		watch: (Css.Host, Css.SceneKey, B) -> () -> ()
	)
		local subscription = react.useRef(nil :: TargetSubscription<B>?)
		react.useLayoutEffect(function()
			local controller = reference.current
			local host = if controller then controller.getHost() else nil
			local node = if controller then controller.getNode(key) else nil
			local previous = subscription.current
			if
				previous
				and (
					previous.host ~= host
					or previous.key ~= key
					or previous.node ~= node
					or previous.bind ~= bind
					or previous.watch ~= watch
				)
			then
				subscription.current = nil
				previous.dispose()
				previous = nil
			end
			if host and node and bind and not previous then
				subscription.current = {
					host = host,
					key = key,
					node = node,
					bind = bind,
					watch = watch,
					dispose = watch(host, node, bind),
				}
			end
			return nil
		end)
		react.useLayoutEffect(function()
			return function()
				local previous = subscription.current
				subscription.current = nil
				if previous then
					previous.dispose()
				end
			end
		end, {})
	end
	local function useNativeTarget(reference: Ref<Controller?>, key: Tree.Key, bind: Target.Binder?)
		useTarget(reference, key, bind, Target.watch)
	end
	local function useImageTarget(reference: Ref<Controller?>, key: Tree.Key, bind: Target.ImageBinder?)
		useTarget(reference, key, bind, Target.watchImage)
	end
	return {
		useCssTree = useCssTree,
		useNativeTarget = useNativeTarget,
		useImageTarget = useImageTarget,
		useCssRoot = useCssRoot,
		useCssNode = useCssNode,
		useNodeTarget = useNodeTarget,
	}
end

return {
	createElementFactory = Html.create,
	createRenderer = Renderer.create,
	createBindings = Bindings.createBindings,
	createTree = Tree.create,
	watchTarget = Target.watch,
	watchImageTarget = Target.watchImage,
}
