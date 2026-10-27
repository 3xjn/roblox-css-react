--!strict
-- A renderer-owned document/window pair backed by an explicit native root.
-- Membership follows that root, including while it is detached from DataModel.
-- Detached body children provide DOM container identity, not native geometry.
local Operations = require(script.Parent.SourceOperations)
local DomClasses = require(script.Parent.DomClasses)
local DomElements = require(script.Parent.DomElements)
local Detached = require(script.Parent.SourceDetachedElements)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Symbols = require(script.Parent.SourceSymbols)
local SourceEvents = require(script.Parent.SourceEvents)
local DomEvents = require(script.Parent.DomEvents)
local Abort = require(script.Parent.Abort)
local SourceDocument = {}
export type Context = {
	document: any,
	window: any,
	destroy: () -> (),
	installGlobals: ({ [string]: any }) -> (),
	bindRoot: (Instance) -> (),
	events: any,
	pointer: any,
}
local token = {}
type State = {
	active: boolean,
	root: Instance?,
	document: any,
	window: any,
	documentData: any,
	windowData: any,
	releases: { () -> () },
	destroying: RBXScriptConnection?,
	onDestroy: (() -> ())?,
}
local function data(owner: any): any
	local meta: any = if type(owner) == "table" then getmetatable(owner) else nil
	local value: any = if type(meta) == "table" then rawget(meta, token) else nil
	if not value or not value.state or not value.state.active then
		return Operations.intrinsicError("TypeError", "Document/window capability is detached")
	end
	return value
end
local function documentState(owner: any): State
	local value = data(owner)
	if value.kind ~= "document" then
		return Operations.intrinsicError("TypeError", "Document method requires its receiver")
	end
	return value.state
end
local function readNode(owner: any, key: string): any
	local current = documentState(owner)
	if key == "nodeType" then
		return 9
	end
	if key == "nodeName" then
		return "#document"
	end
	if key == "ownerDocument" then
		return Nulls.value
	end
	if key == "isConnected" then
		return current.active
	end
	return Operations.intrinsicError("TypeError", "Document Node API requires a native implementation: " .. key)
end
local function contains(owner: any, other: any): boolean
	local current = documentState(owner)
	if other == owner then
		return true
	end
	if Detached.is(other) then
		return DomClasses.contains(Operations.get(owner, "body"), other)
	end
	local kind = DomClasses.kind(other)
	if kind == "document" then
		return false
	end
	if kind ~= "element" and kind ~= "html" then
		return Operations.intrinsicError("TypeError", "Document membership requires a mounted renderer node")
	end
	if Operations.get(other, "ownerDocument") ~= owner then
		return false
	end
	local native, root = DomElements.unwrap(other), current.root
	return root ~= nil and (native == root or native:IsDescendantOf(root))
end
DomClasses.registerImplementation("document", { read = readNode, contains = contains })
local documentPrototype = DomClasses.prototype("document")
Operations.defineAccessor(
	documentPrototype,
	"defaultView",
	Operations.functionValue(function(owner: any): any
		return documentState(owner).window
	end, "get defaultView", 0, "method"),
	nil,
	true,
	true
)

local windowPrototype = Operations.object()
Operations.defineDataProperty(windowPrototype, Symbols.Symbol.toStringTag, "Window", false, false, true)
local schema: Operations.NativeObject = {
	hasOwn = function(owner: any, key: any): boolean
		return Records.hasOwn(data(owner).fields, key)
	end,
	get = function(owner: any, key: any, receiver: any): any
		return Records.readOwn(data(owner).fields, key, receiver)
	end,
	ownKeys = function(owner: any): any
		return Records.ownKeys(data(owner).fields)
	end,
	enumerable = function(owner: any, key: any): boolean
		local descriptor = Records.descriptor(data(owner).fields, key)
		return descriptor ~= nil and descriptor.enumerable
	end,
	getOwnPropertyDescriptor = function(owner: any, key: any): any
		return Operations.getOwnPropertyDescriptor(data(owner).fields, key)
	end,
	properties = function(owner: any): any
		return data(owner).fields
	end,
	prototype = function(owner: any): any
		local current = data(owner)
		local explicit, parent = Records.getPrototype(current.fields)
		return if explicit then parent elseif current.kind == "document" then documentPrototype else windowPrototype
	end,
}
function SourceDocument.create(root: Instance?, computedStyle: (any) -> any, onDestroy: (() -> ())?): Context
	assert(root == nil or typeof(root) == "Instance", "A document requires a native membership root")
	local current: State = {
		active = true,
		root = root,
		document = nil,
		window = nil,
		documentData = nil,
		windowData = nil,
		releases = {},
		destroying = nil,
		onDestroy = onDestroy,
	}
	local function owner(kind: string): any
		local value: any = {}
		local fields = Records.adopt({}, {})
		local private = { state = current, kind = kind, fields = fields }
		setmetatable(value, {
			[token] = private,
			__index = function(self: any, key: any): any
				-- Trusted native creation validates nodeType before installing the
				-- class brand. Source reads still use the shared Node prototype.
				if kind == "document" and key == "nodeType" then
					return readNode(self, key)
				end
				return Operations.get(self, key)
			end,
			__newindex = function(self: any, key: any, child: any)
				Operations.set(self, key, child)
			end,
		})
		Records.setReceiver(fields, value)
		table.insert(current.releases, Operations.registerObject(value, schema))
		return value, private
	end
	local function destroy()
		if not current.active then
			return
		end
		current.active = false
		if current.destroying then
			current.destroying:Disconnect()
			current.destroying = nil
		end
		local callback = current.onDestroy
		current.onDestroy = nil
		local callbackOk: boolean = true
		local callbackFailure: any = nil
		if callback then
			callbackOk, callbackFailure = pcall(callback)
		end
		for _, release in current.releases do
			release()
		end
		table.clear(current.releases)
		for _, private in { current.documentData, current.windowData } do
			if private then
				private.state, private.fields = nil, nil
			end
		end
		current.root, current.document, current.window = nil, nil, nil
		current.documentData, current.windowData = nil, nil
		if not callbackOk then
			error(callbackFailure, 0)
		end
	end
	local events: any = nil
	local pointerOwner: any = nil
	local pointerOrigin: any = nil
	local pointerInput: InputObject? = nil
	local pointerId: number? = nil
	local pointerCaptured = false
	local pointerConnections: { RBXScriptConnection } = {}
	local function stopPointer()
		for _, connection in pointerConnections do connection:Disconnect() end
		table.clear(pointerConnections)
		pointerOwner, pointerOrigin, pointerInput, pointerId, pointerCaptured = nil, nil, nil, nil, false
	end
	local pointer: any = {}
	function pointer.begin(owner: any, input: InputObject)
		stopPointer()
		pointerOwner, pointerOrigin, pointerInput, pointerId = owner, owner, input, 1
		local touch = input.UserInputType == Enum.UserInputType.Touch
		local service = game:GetService("UserInputService")
		local function send(kind: string, source: InputObject)
			if not pointerOwner or not events then return end
			local event = events.adoptEvent(DomEvents.create(kind, { bubbles = true, cancelable = true, composed = true }))
			local position = source.Position
			for key, value in { pointerId = 1, pointerType = if touch then "touch" else "mouse",
				button = 0, buttons = if kind == "pointerup" then 0 else 1,
				clientX = position.X, clientY = position.Y, shiftKey = false, ctrlKey = false, altKey = false, metaKey = false } do
				Operations.set(event, key, value)
			end
			Operations.set(event, "nativeEvent", event)
			events.dispatchEvent(pointerOwner, event)
		end
		table.insert(pointerConnections, service.InputChanged:Connect(function(changed: InputObject)
			if (touch and changed == pointerInput) or (not touch and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				send("pointermove", changed)
			end
		end))
		table.insert(pointerConnections, service.InputEnded:Connect(function(ended: InputObject)
			if (touch and ended == pointerInput) or (not touch and ended.UserInputType == Enum.UserInputType.MouseButton1) then
				local ok, failure = pcall(send, "pointerup", ended)
				stopPointer()
				if not ok then error(failure, 0) end
			end
		end))
	end
	function pointer.capture(owner: any, id: any)
		assert(pointerOwner ~= nil and id == pointerId, "Pointer capture requires an active pointer")
		pointerOwner, pointerCaptured = owner, true
	end
	function pointer.has(owner: any, id: any): boolean return pointerCaptured and pointerOwner == owner and pointerId == id end
	function pointer.release(owner: any, id: any)
		if pointer.has(owner, id) then pointerOwner, pointerCaptured = pointerOrigin, false end
	end
	function pointer.releaseOwner(owner: any)
		if pointerOwner == owner or pointerOrigin == owner then stopPointer() end
	end
	local ok, failure = pcall(function()
		current.document, current.documentData = owner("document")
		DomClasses.register(current.document, "document")
		local body = Detached.create(current.document, "body", nil)
		Operations.defineDataProperty(current.documentData.fields, "body", body, false, true, true)
  local documentElement = Detached.create(current.document, "html", nil)
  Operations.defineDataProperty(current.documentData.fields, "documentElement", documentElement, false, true, true)
  local function viewport(): Vector2
   local native = current.root
   if native and native:IsA("GuiObject") then return native.AbsoluteSize end
   local camera = workspace.CurrentCamera
   return if camera then camera.ViewportSize else Vector2.zero
  end
  for _, element in { body, documentElement } do
   for _, name in { "clientWidth", "clientHeight", "scrollWidth", "scrollHeight", "clientTop", "clientLeft", "scrollTop", "scrollLeft", "offsetWidth", "offsetHeight", "offsetTop", "offsetLeft" } do
    local get = Operations.registerNative(function(): number
     if name == "clientWidth" or name == "scrollWidth" or name == "offsetWidth" then return viewport().X end
     if name == "clientHeight" or name == "scrollHeight" or name == "offsetHeight" then return viewport().Y end
     return 0
    end, "method", "get " .. name, 0)
    local set = if name == "scrollTop" or name == "scrollLeft" then Operations.registerNative(function() end, "method", "set " .. name, 1) else nil
    Operations.defineAccessor(element, name, get, set, true, true)
   end
  end

		Operations.defineAccessor(current.documentData.fields, "activeElement", Operations.registerNative(function(): any
			local focused = game:GetService("UserInputService"):GetFocusedTextBox() or game:GetService("GuiService").SelectedObject
			local root = current.root
			if focused and root and (focused == root or focused:IsDescendantOf(root)) then
				return DomElements.fromNative(focused) or body
			end
			return body
		end, "method", "get activeElement", 0), nil, true, true)
		Operations.defineDataProperty(current.documentData.fields, "createElement", Operations.registerNative(function(_self: any, tag: any): any
			return Detached.create(current.document, Operations.string(tag), body)
		end, "method", "createElement", 1), true, true, true)
		Operations.defineDataProperty(current.documentData.fields, "querySelector", Operations.registerNative(function(_self: any, selector: any): any
			if Operations.string(selector):lower() == "body" then return body end
			return Operations.call(Operations.get(body, "querySelector"), body, Operations.array({ selector }, 1))
		end, "method", "querySelector", 1), true, true, true)
		current.window, current.windowData = owner("window")
		events = SourceEvents.create(Operations, { signal = Abort.resolveSignal })
		for _, target in { current.document, current.window } do
			table.insert(current.releases, events.attach(target, function(value: any): { any } return { value } end))
			local targetFields = if target == current.document then current.documentData.fields else current.windowData.fields
			for _, name in { "addEventListener", "removeEventListener", "dispatchEvent" } do
				local callback = events[name]
				Operations.defineDataProperty(targetFields, name, Operations.registerNative(callback, "method", name, if name == "dispatchEvent" then 1 else 2), true, false, true)
			end
		end
		table.insert(current.releases, stopPointer)
		table.insert(current.releases, events.destroy)
		local fields = current.windowData.fields
  for _, name in { "innerWidth", "innerHeight", "pageXOffset", "pageYOffset", "scrollX", "scrollY" } do
   Operations.defineAccessor(fields, name, Operations.registerNative(function(): number
    if name == "innerWidth" then return viewport().X end
    if name == "innerHeight" then return viewport().Y end
    return 0
   end, "method", "get " .. name, 0), nil, true, true)
  end
  Operations.defineDataProperty(fields, "visualViewport", Nulls.value, false, true, true)

		local capabilities: { [string]: any } = {
			Node = DomClasses.Node,
			Element = DomClasses.Element,
			HTMLElement = DomClasses.HTMLElement,
			Document = DomClasses.Document,
			ShadowRoot = DomClasses.ShadowRoot,
			getComputedStyle = computedStyle,
		}
		for name, value in capabilities do
			Operations.defineDataProperty(fields, name, value, true, true, true)
		end
		local identities: { [string]: any } =
			{ document = current.document, window = current.window, self = current.window, globalThis = current.window }
		for name, value in identities do
			Operations.defineDataProperty(fields, name, value, false, true, true)
		end
		if root then current.destroying = root.Destroying:Connect(destroy) end
	end)
	if not ok then
		pcall(destroy)
		error(failure, 0)
	end
	local installed = false
	return {
		document = current.document,
		window = current.window,
		events = events,
		pointer = pointer,
		destroy = destroy,
		bindRoot = function(nextRoot: Instance)
			assert(current.active and typeof(nextRoot) == "Instance", "A document requires a live native membership root")
			if current.destroying then current.destroying:Disconnect() end
			current.root = nextRoot
			current.destroying = nextRoot.Destroying:Connect(destroy)
		end,
		installGlobals = function(globals: { [string]: any })
			assert(current.active and not installed, "Document globals are detached or already installed")
			installed = true
			local fields = current.windowData.fields
			for name, value in globals do
				if not Records.hasOwn(fields, name) then
					Operations.defineDataProperty(fields, name, value, true, true, true)
				end
			end
		end,
	}
end
return SourceDocument
