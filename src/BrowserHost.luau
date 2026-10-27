--!strict
-- Native browser API boundary. Upstream packages retain their own behavior.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Html = require(script.Parent.Html)
local Nulls = require(script.Parent.Nulls)
local Colors = require(script.Parent.Parent.Css.Colors)
local SourceObservers = require(script.Parent.SourceObservers)
local DomClasses = require(script.Parent.DomClasses)
local SourceCapabilities = require(script.Parent.SourceCapabilities)
local SourceDOMRect = require(script.Parent.SourceDOMRect)
local SourceMediaQueries = require(script.Parent.SourceMediaQueries)
local SourceCookieStore = require(script.Parent.SourceCookieStore)
local SourcePromise = require(script.Parent.SourcePromise)
export type Props = Html.Props
export type React = Html.React
export type Options = {
	element: Html.Factory?,
	flushSync: ((() -> ()) -> any)?,
	createPortal: ((any, Instance, any?) -> any)?,
	portalContainer: Instance?,
	Promise: any?,
	cookieURL: string?,
}
local BrowserHost = {}
local function noop() end
local function readField(value: any, key: string): any
	return rawget(value :: { [string]: any }, key)
end

local function unwrapInstance(target: any): Instance?
	if Nulls.isNullish(target) then
		return nil
	end
	if typeof(target) == "Instance" then
		return target
	end
	if type(target) == "table" then
		local inst = readField(target, "_instance")
		if typeof(inst) == "Instance" then
			return inst
		end
	end
	return nil
end

function BrowserHost.activeElement(_doc: any?): any
	local target = UserInputService:GetFocusedTextBox() or GuiService.SelectedObject
	return if target then Html.fromInstance(target) else Nulls.value
end

function BrowserHost.contains(parent: any, child: any): boolean
	if Nulls.isNullish(parent) or Nulls.isNullish(child) then
		return false
	end
	if rawequal(parent, child) then
		return true
	end
	local parentInst = unwrapInstance(parent)
	local childInst = unwrapInstance(child)
	if parentInst and childInst then
		return parentInst == childInst or childInst:IsDescendantOf(parentInst)
	end
	return false
end

function BrowserHost.cssSupports(property: string, value: string?): boolean
	local name, setting = property, value
	if setting == nil then
		name, setting = property:match("^%s*([%w%-]+)%s*:%s*(.-)%s*$")
	end
	if name ~= "color" or setting == nil then
		-- Only return true for a capability proven by the native evaluator.
		-- Browser scrollbar gutters and vendor engine probes stay unsupported.
		return false
	end
	local style = Html.normalizeStyle({ color = setting })
	local declaration = if style and style.entries[1] then style.entries[1].declaration else nil
	return declaration ~= nil and Colors.resolve(declaration.tokens, {}) ~= nil
end

local function field(value: any, name: string): any
	return if type(value) == "table" then (value :: any)[name] else nil
end

local function instance(value: any): Instance?
	if typeof(value) == "Instance" then
		return value
	end
	local target = field(value, "_instance")
	return if typeof(target) == "Instance" then target else nil
end

local defaults: { [string]: string } = {
	display = "block",
	overflow = "visible",
	overflowX = "visible",
	overflowY = "visible",
	direction = "ltr",
	position = "static",
	transform = "none",
	transitionDuration = "0s",
	transitionDelay = "0s",
	animationName = "none",
	paddingTop = "0px",
	paddingRight = "0px",
	paddingBottom = "0px",
	paddingLeft = "0px",
	borderTopWidth = "0px",
	borderRightWidth = "0px",
	borderBottomWidth = "0px",
	borderLeftWidth = "0px",
	marginTop = "0px",
	marginLeft = "0px",
	marginRight = "0px",
	marginBottom = "0px",
	boxSizing = "content-box",
}

local function tokenText(token: any): string
	if token.kind == "function" then
		local parts = {}
		for _, child in token.children or {} do
			table.insert(parts, tokenText(child))
		end
		return tostring(token.value) .. "(" .. table.concat(parts, " ") .. ")"
	elseif token.kind == "dimension" then
		return tostring(token.value) .. tostring(token.unit)
	elseif token.kind == "percentage" then
		return tostring(token.value) .. "%"
	end
	return tostring(token.value)
end

function BrowserHost.getComputedStyle(value: any): { [string]: any }
	local context: any = field(value, "_context")
	local computed: any = if context then context.getComputedStyle() else nil
	local function property(name: string): string
		local cssName = name:gsub("([a-z0-9])([A-Z])", "%1-%2"):lower()
		local tokens: any = if computed then computed.properties[cssName] else nil
		if tokens then
			local parts = {}
			for _, token in tokens do
				table.insert(parts, tokenText(token))
			end
			return table.concat(parts, " ")
		end
		local target = instance(value)
		if target and target:IsA("GuiObject") then
			if name == "width" then
				return tostring(target.AbsoluteSize.X) .. "px"
			end
			if name == "height" then
				return tostring(target.AbsoluteSize.Y) .. "px"
			end
			if name == "display" and not target.Visible then
				return "none"
			end
		end
		local camelName = name:gsub("%-([a-z])", string.upper)
		return defaults[name] or defaults[camelName] or ""
	end
	local result: { [string]: any } = {
		getPropertyValue = function(a: any, b: any): string
			return property(if type(a) == "string" then a else b)
		end,
	}
	return setmetatable(result, {
		__index = function(_self, key: string): string
			return property(key)
		end,
	})
end

local function attachAbortSignal(options: any, cleanup: () -> ()): () -> ()
	local live = true
	local listeners: { () -> () }? = nil
	local function release()
		if not live then
			return
		end
		live = false
		if listeners then
			local index = table.find(listeners, release)
			if index then
				table.remove(listeners, index)
			end
		end
		cleanup()
	end
	if type(options) == "table" and not Nulls.isNull(options) then
		local signal = readField(options, "signal")
		if type(signal) == "table" and not Nulls.isNull(signal) then
			if readField(signal, "aborted") == true then
				release()
				return release
			end
			local signalListeners = readField(signal, "_listeners")
			if type(signalListeners) == "table" then
				listeners = signalListeners :: { () -> () }
				table.insert(listeners :: { () -> () }, release)
			end
		end
	end
	return release
end

local function createDocumentAndWindow()
	local docListeners: { [string]: { (any) -> () } } = {}
	local docConnections: { [string]: RBXScriptConnection } = {}
	local winListeners: { [string]: { (any) -> () } } = {}
	local winConnections: { [string]: RBXScriptConnection } = {}

	local doc: { [string]: any } = {}
	local win: { [string]: any } = {}
	local function clearWindowSignal(eventType: string)
		local connection = winConnections[eventType]
		if connection then
			connection:Disconnect()
			winConnections[eventType] = nil
		end
		if eventType == "resize" and winConnections.resizeViewport then
			(winConnections.resizeViewport :: RBXScriptConnection):Disconnect()
			winConnections.resizeViewport = nil
		end
	end
	local function emitWindow(eventType: string)
		local event = SourceCapabilities.createEvent(eventType)
		event.target, event.currentTarget, event.isTrusted = win, win, true
		for _, callback in table.clone(winListeners[eventType] or {}) do
			callback(event)
		end
	end
	local function ensureDocSignal(eventType: string)
		if docConnections[eventType] or (eventType ~= "pointerup" and eventType ~= "pointercancel") then
			return
		end
		docConnections[eventType] = UserInputService.InputEnded:Connect(function(input: InputObject)
			local inputType = input.UserInputType
			if
				inputType ~= Enum.UserInputType.Touch
				and inputType ~= Enum.UserInputType.MouseButton1
				and inputType ~= Enum.UserInputType.MouseButton2
				and inputType ~= Enum.UserInputType.MouseButton3
			then
				return
			end
			local canceled = input.UserInputState == Enum.UserInputState.Cancel
			if canceled ~= (eventType == "pointercancel") then
				return
			end
			local event =
				SourceCapabilities.createEvent(eventType, { bubbles = true, cancelable = true, composed = true })
			local fields: Props = {
				type = eventType,
				target = doc,
				currentTarget = doc,
				nativeInput = input,
				pointerId = Html.getPointerId(input),
				pointerType = if inputType == Enum.UserInputType.Touch then "touch" else "mouse",
				button = if inputType == Enum.UserInputType.MouseButton2
					then 2
					elseif inputType == Enum.UserInputType.MouseButton3 then 1
					else 0,
				clientX = input.Position.X,
				clientY = input.Position.Y,
				isTrusted = true,
			}
			for name, value in fields do
				event[name] = value
			end
			for _, callback in table.clone(docListeners[eventType] or {}) do
				callback(event)
			end
		end)
	end

	local function addDocListener(a: any, b: any, c: any, d: any): () -> ()
		local eventType: string = if a == doc then b else a
		local listener: (any) -> () = if a == doc then c else b
		local options: any = if a == doc then d else c
		if type(eventType) ~= "string" or type(listener) ~= "function" then
			return noop
		end
		local list = docListeners[eventType]
		if not list then
			list = {}
			docListeners[eventType] = list
		end
		if not table.find(list, listener) then
			table.insert(list, listener)
		end
		ensureDocSignal(eventType)
		local function cleanup()
			local current = docListeners[eventType]
			if current then
				local idx = table.find(current, listener)
				if idx then
					table.remove(current, idx)
				end
				if #current == 0 and docConnections[eventType] then
					docConnections[eventType]:Disconnect()
					docConnections[eventType] = nil
				end
			end
		end
		return attachAbortSignal(options, cleanup)
	end

	local function removeDocListener(a: any, b: any, c: any)
		local eventType: string = if a == doc then b else a
		local listener: (any) -> () = if a == doc then c else b
		if type(eventType) ~= "string" or type(listener) ~= "function" then
			return
		end
		local list = docListeners[eventType]
		if list then
			local idx = table.find(list, listener)
			if idx then
				table.remove(list, idx)
			end
			if #list == 0 and docConnections[eventType] then
				docConnections[eventType]:Disconnect()
				docConnections[eventType] = nil
			end
		end
	end

	local function ensureWinSignal(eventType: string)
		if winConnections[eventType] then
			return
		end
		if eventType == "blur" then
			winConnections.blur = UserInputService.WindowFocusReleased:Connect(function()
				emitWindow("blur")
			end)
		elseif eventType == "focus" then
			winConnections.focus = UserInputService.WindowFocused:Connect(function()
				emitWindow("focus")
			end)
		elseif eventType == "resize" then
			local workspace = game:GetService("Workspace")
			local initial = true
			local function bindCamera()
				if winConnections.resizeViewport then
					winConnections.resizeViewport:Disconnect()
					winConnections.resizeViewport = nil
				end
				local camera = workspace.CurrentCamera
				if camera then
					winConnections.resizeViewport = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
						emitWindow("resize")
					end)
				end
				if not initial then
					emitWindow("resize")
				end
			end
			winConnections.resize = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
			bindCamera()
			initial = false
		end
	end

	local function addWinListener(a: any, b: any, c: any, d: any): () -> ()
		local eventType: string = if a == win then b else a
		local listener: (any) -> () = if a == win then c else b
		local options: any = if a == win then d else c
		if type(eventType) ~= "string" or type(listener) ~= "function" then
			return noop
		end
		ensureWinSignal(eventType)
		local list = winListeners[eventType]
		if not list then
			list = {}
			winListeners[eventType] = list
		end
		if not table.find(list, listener) then
			table.insert(list, listener)
		end
		local function cleanup()
			local current = winListeners[eventType]
			if current then
				local idx = table.find(current, listener)
				if idx then
					table.remove(current, idx)
				end
			end
			if current and #current == 0 and winConnections[eventType] then
				clearWindowSignal(eventType)
			end
		end
		return attachAbortSignal(options, cleanup)
	end

	local function removeWinListener(a: any, b: any, c: any)
		local eventType: string = if a == win then b else a
		local listener: (any) -> () = if a == win then c else b
		if type(eventType) ~= "string" or type(listener) ~= "function" then
			return
		end
		local list = winListeners[eventType]
		if list then
			local idx = table.find(list, listener)
			if idx then
				table.remove(list, idx)
			end
			if #list == 0 and winConnections[eventType] then
				clearWindowSignal(eventType)
			end
		end
	end

	doc.addEventListener = addDocListener
	doc.removeEventListener = removeDocListener
	doc.contains = function(a: any, b: any): boolean
		local node = if a == doc then b else a
		if node == doc or node == doc.body or node == doc.documentElement then
			return true
		end
		if type(node) == "table" and node.ownerDocument == doc and node.isConnected then
			return true
		end
		return BrowserHost.contains(doc.body, node)
	end
	doc.createElement = function(a: any, b: any)
		local name = if a == doc then b else a
		assert(type(name) == "string", "Element tag name must be a string")
		local tagName: string = name
		local element = if tagName:lower() == "script" then Html.createScriptProxy() else Html.createDomProxy()
		element.nodeName, element.tagName = string.upper(tagName), string.upper(tagName)
		local kind = if tagName:lower() == "textarea" then "textarea" elseif tagName:lower() == "form" then "form"
			elseif tagName:lower() == "br" then "br" else "html"
		DomClasses.register(element, kind)
		element.ownerDocument = doc
		return element
	end
	doc.createTextNode = function(a: any, b: any?): any
		local value = DomClasses.Text.new(if a == doc then b else a)
		value.ownerDocument = doc
		return value
	end
	doc.body = Html.createDomProxy()
	doc.documentElement = Html.createDomProxy()
	rawset(doc.body, "_isDocumentRoot", true)
	rawset(doc.documentElement, "_isDocumentRoot", true)
	doc.nodeType = 9
	doc.nodeName = "#document"
	DomClasses.register(doc, "document")
	doc.body.nodeName = "BODY"
	doc.body.tagName = "BODY"
	doc.body.ownerDocument = doc
	doc.documentElement.nodeName = "HTML"
	doc.documentElement.tagName = "HTML"
	doc.documentElement.ownerDocument = doc
	doc.body.parentNode = doc.documentElement
	doc.documentElement.parentNode = doc
	doc.defaultView = win
	setmetatable(doc, {
		__has = function(self: any, key: any): boolean
			return key == "activeElement" or rawget(self, key) ~= nil
		end,
		__index = function(_self, key: any): any
			if key == "activeElement" then
				return BrowserHost.activeElement(doc)
			end
			return nil
		end,
	})

	win.document = doc
	win.addEventListener = addWinListener
	win.removeEventListener = removeWinListener
	win.getComputedStyle = BrowserHost.getComputedStyle
	setmetatable(win, {
		__has = function(self: any, key: any): boolean
			return key == "innerWidth" or key == "innerHeight" or rawget(self, key) ~= nil
		end,
		__index = function(_self, key: any): any
			if key == "innerWidth" or key == "innerHeight" then
				local camera = game:GetService("Workspace").CurrentCamera
				return if camera
					then (if key == "innerWidth" then camera.ViewportSize.X else camera.ViewportSize.Y)
					else 0
			end
			return nil
		end,
	})
	local mediaQueries = SourceMediaQueries.create({
		readEnvironment = function()
			local preferred = UserInputService.PreferredInput
			local features: { [string]: string } = {}
			if preferred == Enum.PreferredInput.KeyboardAndMouse then
				features.pointer = if UserInputService.MouseEnabled then "fine" else "none"
				features.hover = if UserInputService.MouseEnabled then "hover" else "none"
			elseif preferred == Enum.PreferredInput.Touch then
				features.pointer = if UserInputService.TouchEnabled then "coarse" else "none"
				features.hover = "none"
			elseif preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
				features.pointer, features.hover = "none", "none"
			end
			return {
				viewportWidth = win.innerWidth,
				viewportHeight = win.innerHeight,
				mediaType = "screen",
				features = features,
			}
		end,
		subscribe = function(changed: () -> ())
			local releaseResize = addWinListener("resize", changed)
			local connections = {}
			for _, property in { "PreferredInput", "MouseEnabled", "TouchEnabled" } do
				table.insert(connections, UserInputService:GetPropertyChangedSignal(property):Connect(changed))
			end
			return function()
				releaseResize()
				for _, connection in connections do
					connection:Disconnect()
				end
			end
		end,
		reportError = warn,
	})
	win.matchMedia = function(a: any, b: any?): any
		return mediaQueries.matchMedia(if a == win then b else a)
	end

	local function destroy()
		mediaQueries.destroy()
		for _, conn in docConnections do
			conn:Disconnect()
		end
		table.clear(docConnections)
		for _, conn in winConnections do
			conn:Disconnect()
		end
		table.clear(winConnections)
		table.clear(winListeners)
		table.clear(docListeners)
	end

	return doc, win, destroy
end

function BrowserHost.addEventListener(target: any, eventType: string, listener: (any) -> (), options: any?): () -> ()
	if Nulls.isNullish(target) or type(listener) ~= "function" then
		return noop
	end
	if type(target) == "table" and type(readField(target, "addEventListener")) == "function" then
		local cleanup = readField(target, "addEventListener")(target, eventType, listener, options)
		local remove = if type(cleanup) == "function"
			then cleanup
			else function()
				local rem = readField(target, "removeEventListener")
				if type(rem) == "function" then
					(rem :: (any, string, (any) -> (), any?) -> ())(target, eventType, listener, options)
				end
			end
		return attachAbortSignal(options, remove)
	end
	return noop
end

local AbortController = {}
function AbortController.new()
	local signal = {
		aborted = false,
		_listeners = {} :: { () -> () },
	}
	local signalApi = signal :: any
	signalApi.addEventListener = function(a: any, b: any, c: any)
		local eventType, listener = if a == signal then b else a, if a == signal then c else b
		if eventType == "abort" and type(listener) == "function" and not table.find(signal._listeners, listener) then
			table.insert(signal._listeners, listener)
		end
	end
	signalApi.removeEventListener = function(a: any, b: any, c: any)
		local eventType, listener = if a == signal then b else a, if a == signal then c else b
		if eventType == "abort" then
			local index = table.find(signal._listeners, listener)
			if index then
				table.remove(signal._listeners, index)
			end
		end
	end
	local controller: { [string]: any } = {
		signal = signal,
	}
	controller.abort = function()
		if signal.aborted then
			return
		end
		signal.aborted = true
		for _, fn in table.clone(signal._listeners) do
			fn()
		end
		table.clear(signal._listeners)
	end
	return controller
end
setmetatable(AbortController, {
	__call = function()
		return AbortController.new()
	end,
})

function BrowserHost.create(react: React, options: Options?)
	local opts: Options = options or {}
	local ownedPromises = if opts.Promise == nil then SourcePromise.create() else nil
	local cookieOwner = SourceCookieStore.create({
		Promise = if ownedPromises then ownedPromises.Promise else opts.Promise,
		url = opts.cookieURL,
	})
	local doc, win, destroyDocument = createDocumentAndWindow()
	local observers = SourceObservers.create()
	local nextSourceId = 0
	local nativeUseState = field(react, "useState")
	local nativeUseEffect = field(react, "useEffect")
	local nativeUseId = field(react, "useId")
	local nativeUseSyncExternalStore = field(react, "useSyncExternalStore")
	local reactHooks = {
		useId = if type(nativeUseId) == "function" then nativeUseId else function(): string
			assert(type(nativeUseState) == "function", "Native React useState is required to provide useId")
			local state = (nativeUseState :: (any) -> (string, any))(function(): string
				nextSourceId += 1
				return ":rbx-source-" .. tostring(nextSourceId) .. ":"
			end)
			return state
		end,
		useSyncExternalStore = if type(nativeUseSyncExternalStore) == "function" then nativeUseSyncExternalStore else function(
			subscribe: (()->()) -> (() -> ()),
			getSnapshot: () -> any,
			_getServerSnapshot: (() -> any)?
		): any
			assert(type(nativeUseState) == "function" and type(nativeUseEffect) == "function",
				"Native React useState and useEffect are required to provide useSyncExternalStore")
			local snapshot, setSnapshot = (nativeUseState :: (any) -> (any, (any) -> ()))(getSnapshot())
			local useEffect = nativeUseEffect :: (any, any) -> ()
			useEffect(function()
				local active = true
				local function checkForUpdates()
					if active then
						setSnapshot(getSnapshot())
					end
				end
				local unsubscribe = subscribe(checkForUpdates)
				checkForUpdates()
				return function()
					active = false
					if type(unsubscribe) == "function" then
						unsubscribe()
					end
				end
			end, { subscribe, getSnapshot })
			return snapshot
		end,
	}
	if opts.portalContainer and opts.portalContainer:IsA("GuiObject") then
		rawset(doc.body, "_instance", opts.portalContainer)
		rawset(doc.documentElement, "_instance", opts.portalContainer)
	end
	local element = opts.element or Html.create(react, nil, { document = doc, window = win })
	local function flushSync(callback: () -> ()): any
		return if opts.flushSync then opts.flushSync(callback) else callback()
	end
	local function createPortal(children: any, container: any, key: any?): any
		local destination = unwrapInstance(container) or opts.portalContainer
		assert(destination, "Native portal rendering needs an Instance destination or portalContainer")
		assert(opts.createPortal, "Supply the application's native reconciler createPortal callback")
		return (opts.createPortal :: (any, Instance, any?) -> any)(children, destination, key)
	end
	local dom = { flushSync = flushSync, createPortal = createPortal }
	local globals = {
		DOMRect = SourceDOMRect.DOMRect,
		DOMRectReadOnly = SourceDOMRect.DOMRectReadOnly,
		Node = DomClasses.Node,
		Element = DomClasses.Element,
		HTMLElement = DomClasses.HTMLElement,
		ShadowRoot = DomClasses.ShadowRoot,
		Text = DomClasses.Text,
		HTMLTextAreaElement = DomClasses.HTMLTextAreaElement,
		HTMLFormElement = DomClasses.HTMLFormElement,
		HTMLBRElement = DomClasses.HTMLBRElement,
		cookieStore = cookieOwner.cookieStore,
		ResizeObserver = observers.ResizeObserver,
		MutationObserver = observers.MutationObserver,
		AbortController = AbortController,
		document = doc,
		window = win,
		getComputedStyle = BrowserHost.getComputedStyle,
		navigator = {
			userAgent = "Roblox",
			platform = "",
			maxTouchPoints = if UserInputService.TouchEnabled then 1 else 0,
		},
		CSS = { supports = BrowserHost.cssSupports },
	}
	for name, value in globals :: any do
		win[name] = value
	end
	local closed = false
	return {
		element = element,
		reactHooks = reactHooks,
		globals = globals,
		ownerDocument = function()
			return doc
		end,
		ownerWindow = function()
			return win
		end,
		getComputedStyle = BrowserHost.getComputedStyle,
		bindings = {
			["react-dom"] = { flushSync = flushSync, createPortal = createPortal, ["*"] = dom, default = dom },
		},
		destroy = function()
			if closed then
				return
			end
			closed = true
			cookieOwner.destroy()
			if ownedPromises then ownedPromises.destroy() end
			observers.destroy()
			destroyDocument()
		end,
	}
end
return BrowserHost
