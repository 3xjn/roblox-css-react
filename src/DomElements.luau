--!strict
-- Mounted renderer targets, never structural DOM guesses. The source prototype
-- view has unbound methods; the legacy typed native view has explicit free calls.
local Nulls = require(script.Parent.Nulls)
local DomClasses = require(script.Parent.DomClasses)
local DomEvents = require(script.Parent.DomEvents)
local DomSelectors = require(script.Parent.DomSelectors)
local Detached = require(script.Parent.SourceDetachedElements)
local Properties = require(script.Parent.Properties)
local Target = require(script.Parent.Target)
local Operations = require(script.Parent.SourceOperations)
local Arrays = require(script.Parent.Arrays)
local SourceDOMRect = require(script.Parent.SourceDOMRect)
local Records = require(script.Parent.Records)
local Functions = require(script.Parent.FunctionValues)
local SourceType = require(script.Parent.SourceType)
local DomElements = {}
export type Options = { tag: string?, document: any?, window: any?, documentRoot: Instance?, animations: ((Target.Context) -> any)?, events: any?, pointer: any? }
type State = { target: GuiObject?, context: Target.Context?, options: Options?, active: boolean,
	cleanups: { [() -> ()]: boolean }, views: { [any]: boolean }, bound: { [string]: any }, properties: any,
	offSchema: (() -> ())?, offProperties: (() -> ())?, inlineStyle: any?, styleDirty: boolean?,
	detachedAttributes: { [string]: string }?, detachedInline: { [string]: { string } }?,
	checked: boolean?, checkedAttribute: boolean? }
local stateToken, styleToken, inlineToken = {}, {}, {}
local mounted: { [Instance]: any } = setmetatable({}, { __mode = "kv" }) :: any
local function stateOf(element: any): State?
	local meta = if type(element) == "table" then getmetatable(element) else nil
	return if type(meta) == "table" then rawget(meta, stateToken) :: State? else nil
end
local function live(element: any): State
	local state = stateOf(element)
	if not state then return Operations.intrinsicError("TypeError", "Illegal DOM method receiver") end
	assert(state.active and state.target and state.context, "DOM reference is not a mounted CSS target")
	return state
end
local function packet(...: any): any return Arrays.adopt({ ... }, select("#", ...)) end
local function attributes(element: any): { [string]: string }
	local current = assert(stateOf(element), "Illegal DOM object")
	if not current.active then return current.detachedAttributes or {} end
	return assert(assert(current.context).getAttributes, "This native target does not expose attributes")()
end
local function cssName(name: string): string
	if name:sub(1, 2) == "--" then return name end
	return name:gsub("([a-z0-9])([A-Z])", "%1-%2"):lower()
end
local function ensureLayout(current: State)
	local context = assert(current.context, "DOM reference is detached")
	if context.ensureLayout then
		local ready, failure = context.ensureLayout()
		assert(ready, failure or "Native synchronous layout capability is unavailable")
		current.styleDirty = false
	else
		assert(not current.styleDirty, "Inline mutation requires a native synchronous layout capability before geometry can be read")
	end
end
local function readResolved(current: State, name: string): string
	if not current.active or not current.context then return "" end
	ensureLayout(current)
	local resolve = assert(assert(current.context).getResolvedProperty, "This native target has no resolved CSS property API")
	local result, failure = resolve(name)
	assert(result ~= nil, failure or `CSS property {name} is unresolved`)
	return result
end
local function styleState(owner: any): any
	local meta = if type(owner) == "table" then getmetatable(owner) else nil
	local value: any = if type(meta) == "table" then rawget(meta, styleToken) else nil
	if not value then return Operations.intrinsicError("TypeError", "Illegal resolved-style method receiver") end
	return value
end
local stylePrototype = Operations.object()
local stylePrototypes: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local propertyValue = Operations.registerNative(function(self: any, ...: any): string
	local current = styleState(self)
	if select("#", ...) == 0 then return Operations.intrinsicError("TypeError", "getPropertyValue requires a property name") end
	return readResolved(current.target, cssName(Operations.string((...))))
end, "method", "getPropertyValue", 1)
Operations.defineDataProperty(stylePrototype, "getPropertyValue", propertyValue, true, true, true)
local styleSchema: Operations.NativeObject = {
	tag = "CSSStyleDeclaration",
	hasOwn = function(owner: any, _key: any): boolean
		local current = styleState(owner)
		if type(_key) == "string" and _key ~= "then" and tonumber(_key) == nil and not Operations.binary("in", _key, current.prototype) then
			error(`Resolved CSS named property {_key} requires a native query provider`, 2)
		end
		-- Indexed CSS declaration slots cannot be reflected without a complete
		-- native declaration enumeration. Named supported reads use prototype accessors.
		if type(_key) == "string" and tonumber(_key) ~= nil then error("Resolved CSS indexed declaration slots are not implemented", 2) end
		return false
	end,
	get = function(): never error("Resolved-style own slots are not qualified", 2) end,
	prototype = function(owner: any): any return styleState(owner).prototype end,
	ownKeys = function(): never error("Resolved CSS declaration enumeration is not implemented", 2) end,
	enumerable = function(): never error("Resolved CSS declaration enumeration is not implemented", 2) end,
	getOwnPropertyDescriptor = function(): never error("Resolved CSS declaration own-slot reflection is not implemented", 2) end,
	set = function(_owner: any, _key: any, _value: any): () Operations.intrinsicError("TypeError", "Computed style is read-only") end,
}
function DomElements.computedStyle(element: any, pseudoElement: any?): any
	local target = live(element)
	assert(Nulls.isNullish(pseudoElement) or pseudoElement == "", "Pseudo-element resolved styles require a native provider")
	local value: any = {}
	local names = if target.context and target.context.getResolvedPropertyNames then target.context.getResolvedPropertyNames() else nil
	local prototype = stylePrototype
	if names then
		prototype = stylePrototypes[names]
		if not prototype then
			prototype = Operations.object(stylePrototype)
			for _, name in names do
				assert(type(name) == "string", "Resolved CSS provider names require strings")
				local property = name
				local function accessor(exposed: string)
					local read = Operations.registerNative(function(self: any): string return readResolved(styleState(self).target, property) end,
						"method", "get " .. exposed, 0)
					Operations.defineAccessor(prototype, exposed, read, nil, true, true)
				end
				accessor(property)
				local camel = if property:sub(1, 2) == "--" then property else property:gsub("%-([a-z])", string.upper)
				if camel ~= property then accessor(camel) end
			end
			stylePrototypes[names] = prototype
		end
	end
	local current: any = { target = target, prototype = prototype }
	current.nativeGet = Operations.registerNative(function(...: any): string return propertyValue(value, ...) end, "free", "getPropertyValue", 1)
	setmetatable(value, { [styleToken] = current, __index = function(self: any, key: any): any
		local info = styleState(self)
		if key == "getPropertyValue" then return info.nativeGet end
		assert(type(key) == "string", "Resolved CSS property requires a string name")
		return readResolved(info.target, cssName(key))
	end, __newindex = function(): never return Operations.intrinsicError("TypeError", "Computed style is read-only") end })
	current.offSchema = Operations.registerObject(value, styleSchema)
	target.views[value] = true
	return value
end
local inlineBase = Operations.object()
local inlinePrototypes: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local inlineMethods: { [string]: any } = {}
local function inlineState(owner: any): any
	local meta = if type(owner)=="table" then getmetatable(owner) else nil
	local value: any = if type(meta)=="table" then rawget(meta,inlineToken) else nil
	if not value then return Operations.intrinsicError("TypeError","Illegal inline-style receiver") end
	return value
end
local function inlineRead(owner: any,name: string): (string,string)
	local target = inlineState(owner).target
	if not target.active or not target.context then
		local entry = (target.detachedInline or {})[name]
		return if entry then entry[1] else "", if entry then entry[2] else ""
	end
	return assert(target.context.getInlineProperty,"Native inline declaration reads are unavailable")(name)
end
local function inlineWrite(owner: any,name: string,value: string,priority: string)
	local current=inlineState(owner).target
	if not current.active or not current.context then
		current.detachedInline = current.detachedInline or {}
		current.detachedInline[name] = if value == "" then nil else {value, priority}
		return
	end
	local context = current.context
	local read = assert(context.getInlineProperty,"Native inline declaration reads are unavailable")
	local beforeValue, beforePriority = read(name)
	assert(context.setInlineProperty,"Native inline declaration mutation is unavailable")(name,value,priority)
	local afterValue, afterPriority = read(name)
	if beforeValue ~= afterValue or beforePriority ~= afterPriority then
		current.styleDirty=true
	end
end
local function cssValue(value: any): string return if Nulls.isNull(value) then "" else Operations.string(value) end
local function inlineMethod(name: string,length: number,callback: any)
	local invoke=Operations.registerNative(function(self: any,...: any): any
		inlineState(self)
		if select("#",...)<length then return Operations.intrinsicError("TypeError",name.." has missing required arguments") end
		return callback(self,...)
	end,"method",name,length)
	inlineMethods[name]=invoke
	Operations.defineDataProperty(inlineBase,name,invoke,true,true,true)
end
inlineMethod("getPropertyValue",1,function(self: any,name: any): string local value=inlineRead(self,Operations.string(name));return value end)
inlineMethod("getPropertyPriority",1,function(self: any,name: any): string local _,priority=inlineRead(self,Operations.string(name));return priority end)
inlineMethod("setProperty",2,function(self: any,name: any,value: any,priority: any)
	local key,text,importance=Operations.string(name),cssValue(value),if Nulls.isNullish(priority) then "" else Operations.string(priority)
	inlineWrite(self,key,text,importance)
end)
inlineMethod("removeProperty",1,function(self: any,name: any): string
	local key=Operations.string(name)
	local previous=inlineRead(self,key)
	inlineWrite(self,key,"","")
	return previous
end)
local inlineSchema: Operations.NativeObject = {
	tag="CSSStyleDeclaration",
	hasOwn=function(owner: any,key: any): boolean
		local current=inlineState(owner)
		if type(key)=="string" and key~="then" and not Operations.binary("in",key,current.prototype) then
			error(`Inline CSS named property {key} requires a native capability`,2)
		end
		return false
	end,
	get=function(): never error("Inline CSS own-slot reflection is not implemented",2) end,
	prototype=function(owner: any): any return inlineState(owner).prototype end,
	ownKeys=function(): never error("Inline CSS declaration enumeration is not implemented",2) end,
	enumerable=function(): never error("Inline CSS declaration enumeration is not implemented",2) end,
	getOwnPropertyDescriptor=function(): never error("Inline CSS own-slot reflection is not implemented",2) end,
	set=function(owner: any,key: any,value: any)
		local current=inlineState(owner)
		local name=current.names[key]
		assert(name,`Inline CSS property {tostring(key)} requires a native mutation capability`)
		inlineWrite(owner,name,cssValue(value),"")
	end,
}
local function inlineStyle(element: any): any
	local target=live(element)
	if target.inlineStyle then return target.inlineStyle end
	local context=assert(target.context)
	assert(context.getInlineProperty and context.setInlineProperty and context.getInlinePropertyNames,
		"Inline style needs the native CSS declaration capability")
	local names=context.getInlinePropertyNames()
	local cached=inlinePrototypes[names]
	if not cached then
		local prototype,mapping=Operations.object(inlineBase),{}
		for _,name in names do
			local property=name
			local function accessor(alias: string)
				mapping[alias]=property
				local get=Operations.registerNative(function(self: any): string local value=inlineRead(self,property);return value end,"method","get "..alias,0)
				local set=Operations.registerNative(function(self: any,value: any) inlineState(self);inlineWrite(self,property,cssValue(value),"") end,"method","set "..alias,1)
				Operations.defineAccessor(prototype,alias,get,set,true,true)
			end
			accessor(property)
			local camel=property:gsub("%-([a-z])",string.upper)
			if camel~=property then accessor(camel) end
		end
		cached={prototype=prototype,names=mapping};inlinePrototypes[names]=cached
	end
	local value: any={}
	local current: any={target=target,prototype=cached.prototype,names=cached.names,bound={}}
	setmetatable(value,{[inlineToken]=current,__index=function(self: any,key: any): any
		local info=inlineState(self)
		if inlineMethods[key] then
			if not info.bound[key] then info.bound[key]=Operations.registerNative(function(...: any): any return inlineMethods[key](self,...) end,"free",key,Functions.length(inlineMethods[key])) end
			return info.bound[key]
		end
		local name=info.names[key]
		assert(name,`Inline CSS named property {tostring(key)} requires a native capability`)
		local text=inlineRead(self,name);return text
	end,__newindex=function(self: any,key: any,item: any) (inlineSchema.set :: any)(self,key,item) end})
	current.offSchema=Operations.registerObject(value,inlineSchema)
	target.inlineStyle=value;target.views[value]=true
	return value
end
function DomElements.unwrap(element: any): GuiObject
	if typeof(element) == "Instance" and (element :: Instance):IsA("GuiObject") then return element :: GuiObject end
	return assert(live(element).target)
end
function DomElements.fromNative(target: Instance?): any
	return if target then mounted[target] else nil
end
-- React host handlers participate in the same dispatch as DOM listeners.
function DomElements.bindClick(element: any, callback: (any) -> ()): (() -> ())?
	return DomElements.bindEvent(element, "click", callback)
end
function DomElements.bindEvent(element: any, kind: string, callback: (any) -> ()): (() -> ())?
	local events = assert(live(element).options).events
	if not events then return nil end
	local listener = Operations.registerNative(function(event: any) callback(event) end, "free", kind, 1)
	events.addEventListener(element, kind, listener, false)
	return function() events.removeEventListener(element, kind, listener, false) end
end
function DomElements.beginPointer(element: any, input: InputObject)
	local pointer = assert(live(element).options).pointer
	if pointer then pointer.begin(element, input) end
end
local methods: { [string]: any } = {}
local getters: { [string]: any } = {}
local unsupported: { [any]: boolean } = {}
local function method(kind: DomClasses.Kind, name: string, length: number, callback: any)
	local invoke = Operations.registerNative(function(self: any, ...: any): any
		if name == "removeEventListener" then
			local current = stateOf(self)
			if current and not current.active then return nil end
		end
		local detached = stateOf(self)
		local detachedAttribute = name == "getAttribute" or name == "hasAttribute" or name == "setAttribute" or name == "removeAttribute"
		if kind ~= "node" and not (detached and not detached.active and detachedAttribute) and name ~= "getAnimations" and name ~= "getClientRects" and name ~= "getBoundingClientRect" then live(self) elseif not DomClasses.kind(self) then return Operations.intrinsicError("TypeError", "Illegal Node receiver") end
		if select("#", ...) < length then return Operations.intrinsicError("TypeError", name .. " has missing required arguments") end
		return callback(self, ...)
	end, "method", name, length)
	methods[name] = invoke
	Operations.defineDataProperty(DomClasses.prototype(kind), name, invoke, true, true, true)
end
local function getter(kind: DomClasses.Kind, name: string, callback: any)
	local invoke = Operations.registerNative(function(self: any): any
		local state = stateOf(self)
		if name == "style" and state and not state.active and state.inlineStyle then return state.inlineStyle end
		if kind ~= "node" and not ({ offsetParent=true, offsetTop=true, offsetLeft=true, offsetWidth=true, offsetHeight=true, clientTop=true, clientLeft=true, clientWidth=true, clientHeight=true, scrollTop=true, scrollLeft=true, scrollWidth=true, scrollHeight=true, assignedSlot=true })[name] then live(self) end
		return callback(self)
	end, "method", "get " .. name, 0)
	getters[name] = invoke
	Operations.defineAccessor(DomClasses.prototype(kind), name, invoke, nil, true, true)
end
local function readNode(self: any, key: string): any
	local state = stateOf(self)
	if key == "isConnected" and state and not state.active then return false end
	local current = live(self)
	if key == "nodeType" then return 1 end
	if key == "nodeName" then return string.upper(assert(current.options).tag or "div") end
	if key == "ownerDocument" then return assert(assert(current.options).document, "This DOM target has no supplied ownerDocument") end
	if key == "isConnected" then
		local native, root = assert(current.target), assert(current.options).documentRoot
		return if root then native == root or native:IsDescendantOf(root) else native:IsDescendantOf(game)
	end
	error("Unsupported Node field: " .. key, 2)
end
local function nativeContains(self: any, native: GuiObject): boolean
	local owner = assert(live(self).target)
	return native == owner or native:IsDescendantOf(owner)
end
local function containsNode(self: any, other: any): boolean
	local current = stateOf(self)
	if current and not current.active then return self == other end
	live(self)
	if DomClasses.kind(other) == "document" then return false end
	local otherState = stateOf(other)
	if not otherState then return false end
	if not otherState.active or not otherState.target then return false end
	return nativeContains(self, assert(otherState.target))
end
DomClasses.registerImplementation("html", { read = readNode, contains = containsNode })
for _, name in { "nodeType", "nodeName", "ownerDocument", "isConnected" } do
	getter("node", name, function(self: any): any return DomClasses.readNode(self, name) end)
end
getter("html", "style", inlineStyle)
local function inputChecked(self: any): (State, boolean)
	local current = live(self)
	local attrs = attributes(self)
	assert(string.lower(assert(current.options).tag or "") == "input" and string.lower(attrs.type or "") == "checkbox",
		"DOM checked requires a checkbox input")
	local fromAttribute = attrs.checked ~= nil
	if current.checked == nil or current.checkedAttribute ~= fromAttribute then
		current.checked, current.checkedAttribute = fromAttribute, fromAttribute
	end
	return current, current.checked == true
end
do
	local get = Operations.registerNative(function(self: any): boolean local _, value = inputChecked(self); return value end,
		"method", "get checked", 0)
	local set = Operations.registerNative(function(self: any, value: any)
		local current = inputChecked(self)
		current.checked = Operations.truthy(value)
	end, "method", "set checked", 1)
	getters.checked = get
	Operations.defineAccessor(DomClasses.prototype("html"), "checked", get, set, true, true)
end
do
	local function textBox(self: any): TextBox
		local current = live(self)
		local tag = string.lower(assert(current.options).tag or "")
		local target = assert(current.target)
		assert((tag == "input" or tag == "textarea") and target:IsA("TextBox"), "DOM value requires a native text input")
		return target :: TextBox
	end
	local get = Operations.registerNative(function(self: any): string return textBox(self).Text end, "method", "get value", 0)
	local set = Operations.registerNative(function(self: any, value: any) textBox(self).Text = Operations.string(value) end, "method", "set value", 1)
	getters.value = get
	Operations.defineAccessor(DomClasses.prototype("html"), "value", get, set, true, true)
	method("html", "setSelectionRange", 2, function(self: any, startValue: any, endValue: any, direction: any)
		local box = textBox(self)
		local text = box.Text
		local function nativeOffset(raw: any): number
			local number = Operations.number(raw)
			if number ~= number or number < 0 then number = 0 end
			local wanted = math.floor(number)
			local units = 0
			for byte, codepoint in utf8.codes(text) do
				if units >= wanted then return byte end
				local nextUnits = units + (if codepoint > 0xFFFF then 2 else 1)
				if wanted < nextUnits then return byte end
				units = nextUnits
			end
			return #text + 1
		end
		local first, last = nativeOffset(startValue), nativeOffset(endValue)
		if last < first then first = last end
		local backwards = not Nulls.isNullish(direction) and Operations.string(direction) == "backward"
		box.CursorPosition = if backwards then first else last
		box.SelectionStart = if first == last then -1 elseif backwards then last else first
	end)
end
for _, name in { "parentNode", "parentElement" } do
	getter("element", name, function(self: any): any
		local current = live(self)
		local ancestor = assert(current.target).Parent
		while ancestor do
			local element = mounted[ancestor]
			local state = if element then stateOf(element) else nil
			if state and state.active and state.options and state.options.events == assert(current.options).events then return element end
			ancestor = ancestor.Parent
		end
		if name == "parentNode" and current.options and current.options.documentRoot and current.options.document
			and assert(current.target):IsDescendantOf(current.options.documentRoot) then return current.options.document end
		return Nulls.value
	end)
end
getter("element", "tagName", function(self: any): string return string.upper(assert(live(self).options).tag or "div") end)
method("element", "matches", 1, function(self: any, selector: any): boolean
	local node = assert(assert(live(self).context).getNode, "DOM selector matching requires a CSS node")()
	return DomSelectors.matches(Operations.string(selector), assert(node, "DOM selector node is detached"))
end)
method("element", "querySelector", 1, function(self: any, selector: any): any
	local text = Operations.string(selector)
	local context = assert(live(self).context)
	local root = assert(assert(context.getNode, "DOM selector lookup requires a CSS node")())
	local resolve = assert(context.getNodeTarget, "DOM selector lookup requires native targets")
	local function find(node: any): any
		for _, child in node.children do
			if DomSelectors.matches(text, child) then
				local target = resolve(child)
				return (if target then mounted[target] else nil) or Nulls.value
			end
			local found = find(child)
			if not Nulls.isNullish(found) then return found end
		end
		return Nulls.value
	end
	return find(root)
end)
method("element", "closest", 1, function(self: any, selector: any): any
	local text = Operations.string(selector)
	local context = assert(live(self).context)
	local node = assert(assert(context.getNode, "DOM selector matching requires a CSS node")())
	local current = node
	while current do
		if DomSelectors.matches(text, current) then
			if current == node then return self end
			local target = assert(context.getNodeTarget, "DOM ancestor lookup requires a native target")(current)
			return (if target then mounted[target] else nil) or Nulls.value
		end
		current = current.parent
	end
	return Nulls.value
end)
local function geometryState(self: any): State?
 local current = stateOf(self)
 if not current or not current.active or not current.target or not current.context then return nil end
 local root = if current.options then current.options.documentRoot else nil
 if root and current.target ~= root and not current.target:IsDescendantOf(root) then return nil end
 return current
end
local function border(current: State, side: string): number
 local context = assert(current.context)
 if not context.getResolvedProperty then return 0 end
 local value = context.getResolvedProperty("border-" .. side .. "-width")
 return if value then (tonumber(value:match("^%s*([%+%-]?[%d%.]+)")) or 0) else 0
end
local function offsetParent(self: any): any
 local current = geometryState(self)
 if not current then return Nulls.value end
 local context = assert(current.context)
 ensureLayout(current)
 if context.getResolvedProperty and context.getResolvedProperty("position") == "fixed" then return Nulls.value end
 local ancestor = assert(current.target).Parent
 while ancestor do
  local element = mounted[ancestor]
  local info = if element then stateOf(element) else nil
  if info and info.active and info.options and current.options and info.options.events == current.options.events then return element end
  ancestor = ancestor.Parent
 end
 return if current.options and current.options.document then Operations.get(current.options.document, "body") else Nulls.value
end
getter("html", "offsetParent", offsetParent)
getter("element", "assignedSlot", function(): any return Nulls.value end)
for _, name in { "offsetTop", "offsetLeft", "offsetWidth", "offsetHeight", "clientTop", "clientLeft", "clientWidth", "clientHeight", "scrollTop", "scrollLeft", "scrollWidth", "scrollHeight" } do
 local function read(self: any): number
  local current = geometryState(self)
  if not current then return 0 end
  ensureLayout(current)
  local target = assert(current.target)
  if name == "offsetTop" or name == "offsetLeft" then
   local parent = offsetParent(self)
   local parentState = stateOf(parent)
   local position = if parentState and parentState.target then parentState.target.AbsolutePosition else Vector2.zero
   return if name == "offsetTop" then target.AbsolutePosition.Y - position.Y else target.AbsolutePosition.X - position.X
  end
  if name == "clientTop" then return border(current, "top") end
  if name == "clientLeft" then return border(current, "left") end
  if name == "scrollTop" or name == "scrollLeft" then
   if not target:IsA("ScrollingFrame") then return 0 end
   return if name == "scrollTop" then target.CanvasPosition.Y else target.CanvasPosition.X
  end
  local horizontal = name == "offsetWidth" or name == "clientWidth" or name == "scrollWidth"
  local size = if horizontal then target.AbsoluteSize.X else target.AbsoluteSize.Y
  if name == "clientWidth" then return math.max(0, size - border(current, "left") - border(current, "right")) end
  if name == "clientHeight" then return math.max(0, size - border(current, "top") - border(current, "bottom")) end
  if (name == "scrollWidth" or name == "scrollHeight") and target:IsA("ScrollingFrame") then
   return if horizontal then target.AbsoluteCanvasSize.X else target.AbsoluteCanvasSize.Y
  end
  return size
 end
 local kind: DomClasses.Kind = if name:sub(1, 6) == "offset" then "html" else "element"
 if name == "scrollTop" or name == "scrollLeft" then
  local get = Operations.registerNative(read, "method", "get " .. name, 0)
  local set = Operations.registerNative(function(self: any, value: any)
   local current = geometryState(self)
   if not current then return end
   local target = assert(current.target)
   if target:IsA("ScrollingFrame") then
    local number = tonumber(value) or 0
    target.CanvasPosition = if name == "scrollTop" then Vector2.new(target.CanvasPosition.X, number) else Vector2.new(number, target.CanvasPosition.Y)
   end
  end, "method", "set " .. name, 1)
  getters[name] = get
  Operations.defineAccessor(DomClasses.prototype(kind), name, get, set, true, true)
 else getter(kind, name, read) end
end
method("element", "getClientRects", 0, function(self: any): any
 if not geometryState(self) then return Arrays.adopt({}, 0) end
 return Arrays.adopt({ methods.getBoundingClientRect(self) }, 1)
end)
method("element", "getBoundingClientRect", 0, function(self: any): any
	local current = geometryState(self)
	if not current then return SourceDOMRect.DOMRect.new(0, 0, 0, 0) end
	ensureLayout(current)
	local target = assert(current.target)
	local box = assert(assert(current.context).getLayoutBox(), "CSS target has no committed layout box")
	return SourceDOMRect.DOMRect.new(target.AbsolutePosition.X, target.AbsolutePosition.Y, box.width, box.height)
end)
method("element", "getAttribute", 1, function(self: any, name: any): any
	local value = attributes(self)[string.lower(Operations.string(name))]
	return if value == nil then Nulls.value else value
end)
method("element", "hasAttribute", 1, function(self: any, name: any): boolean return attributes(self)[string.lower(Operations.string(name))] ~= nil end)
method("element", "setAttribute", 2, function(self: any, name: any, value: any)
	local key, text = string.lower(Operations.string(name)), Operations.string(value)
	assert(key:match("^[%a_:][%w_.:%-]*$"), "Native setAttribute currently requires a valid ASCII XML name; Unicode names and DOMException faults are unqualified")
	local current = assert(stateOf(self))
	if not current.active then
		current.detachedAttributes = current.detachedAttributes or {}
		current.detachedAttributes[key] = text
	else
		assert(assert(current.context).setAttribute, "This target has no attribute mutation API")(key, text)
	end
end)
method("element", "removeAttribute", 1, function(self: any, name: any)
	local current = assert(stateOf(self))
	local key = string.lower(Operations.string(name))
	if not current.active then
		if current.detachedAttributes then current.detachedAttributes[key] = nil end
	else
		assert(assert(current.context).setAttribute, "This target has no attribute mutation API")(key, nil)
	end
end)
method("element", "getAnimations", 0, function(self: any, options: any): any
	local state = stateOf(self)
	if state and not state.active then return Arrays.adopt({}, 0) end
	local current = live(self)
	ensureLayout(current)
	local provider = assert(assert(current.options).animations, "Supply the native CSS animation boundary")
	local subtree = if Nulls.isNullish(options) then false else Operations.truthy(Operations.get(options, "subtree"))
	return provider(assert(current.context)).getAnimations({ subtree = subtree })
end)
method("node", "contains", 1, function(self: any, other: any): boolean return DomClasses.contains(self, other) end)
method("node", "compareDocumentPosition", 1, function(self: any, other: any): number
	if not DomClasses.kind(other) then return Operations.intrinsicError("TypeError", "compareDocumentPosition requires a Node") end
	if self == other then return 0 end
	if DomClasses.contains(other, self) then return 10 end
	if DomClasses.contains(self, other) then return 20 end
	if Detached.is(self) and Detached.is(other) then return Detached.compareOrder(self, other) end
	local a, b = stateOf(self), stateOf(other)
	if not a or not b then return 1 end
	if not a.options or not b.options or not a.options.document or a.options.document ~= b.options.document
		or not a.options.documentRoot or a.options.documentRoot ~= b.options.documentRoot then return 1 end
	local root = a.options.documentRoot
	if not (a.target == root or assert(a.target):IsDescendantOf(root))
		or not (b.target == root or assert(b.target):IsDescendantOf(root)) then return 1 end
	local function path(target: Instance): { Instance }
		local result: { Instance } = {}
		local cursor: Instance? = target
		while cursor do table.insert(result, 1, cursor); cursor = cursor.Parent end
		return result
	end
	local left, right = path(assert(live(self).target)), path(assert(live(other).target))
	if left[1] ~= right[1] then return 1 end
	local i = 1
	while left[i] == right[i] do i += 1 end
	local siblings = left[i - 1]:GetChildren()
	return if assert(table.find(siblings, left[i])) < assert(table.find(siblings, right[i])) then 4 else 2
end)
method("node", "getRootNode", 0, function(self: any): any
	if DomClasses.kind(self) == "document" then return self end
	if Detached.is(self) then
		local node = self
		while true do
			local parent = Operations.get(node, "parentNode")
			if Nulls.isNullish(parent) then return node end
			node = parent
		end
	end
	local current = live(self)
	local root = assert(current.options).documentRoot
	local target = assert(current.target)
	if root and (target == root or target:IsDescendantOf(root)) and current.options.document then
		return current.options.document
	end
	return self
end)
for _, name in { "setPointerCapture", "releasePointerCapture", "hasPointerCapture" } do
	method("element", name, 1, function(self: any, id: any): any
		local pointer = assert(assert(live(self).options).pointer, "Pointer capture requires a native document")
		if name == "setPointerCapture" then pointer.capture(self, id); return nil end
		if name == "releasePointerCapture" then pointer.release(self, id); return nil end
		return pointer.has(self, id)
	end)
end
for _, name in { "addEventListener", "removeEventListener", "dispatchEvent" } do
	method("element", name, if name == "dispatchEvent" then 1 else 2, function(self: any, ...: any): any
		local current = live(self)
		local events = assert(assert(current.options).events, "DOM element requires an event context")
		local event = (...)
		local attrs = attributes(self)
		if name ~= "dispatchEvent" or Operations.get(event, "type") ~= "click"
			or string.lower(assert(current.options).tag or "") ~= "input" or string.lower(attrs.type or "") ~= "checkbox" or attrs.disabled ~= nil then
			return events[name](self, ...)
		end
		local _, previous = inputChecked(self)
		current.checked = not previous
		local accepted = events.dispatchEvent(self, event)
		if not accepted then current.checked = previous; return false end
		for _, kind in { "input", "change" } do
			local change = events.adoptEvent(DomEvents.create(kind, { bubbles = true }))
			Operations.set(change, "nativeEvent", change)
			events.dispatchEvent(self, change)
		end
		return true
	end)
end
local clicking: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
method("html", "click", 0, function(self: any)
	local current = live(self)
	local tag = string.lower(assert(current.options).tag or "")
	if (tag == "button" or tag == "input" or tag == "select" or tag == "textarea") and attributes(self).disabled ~= nil then return end
	if clicking[self] then return end
	local events = assert(current.options.events, "DOM element requires an event context")
	local event = events.adoptEvent(DomEvents.create("click", { bubbles = true, cancelable = true, composed = true }))
	for key, value in { button = 0, buttons = 0, detail = 0, clientX = 0, clientY = 0, nativeEvent = event } do
		Operations.set(event, key, value)
	end
	clicking[self] = true
	local ok, failure = pcall(methods.dispatchEvent, self, event)
	clicking[self] = nil
	if not ok then error(failure, 0) end
end)
method("html", "focus", 0, function(self: any, options: any)
	local preventScroll = false
	local focusVisible: boolean? = nil
	if not Nulls.isNullish(options) then
		preventScroll = Operations.truthy(Operations.get(options, "preventScroll"))
		local requested = Operations.get(options, "focusVisible")
		if not Nulls.isNullish(requested) then focusVisible = Operations.truthy(requested) end
	end
	local native = assert(live(self).target)
	local scrollPositions: { { target: ScrollingFrame, position: Vector2 } } = {}
	if preventScroll then
		local ancestor = native.Parent
		while ancestor do
			if ancestor:IsA("ScrollingFrame") then
				table.insert(scrollPositions, { target = ancestor, position = ancestor.CanvasPosition })
			end
			ancestor = ancestor.Parent
		end
	end
	if native:IsA("TextBox") then native:CaptureFocus()
	elseif native.Selectable then game:GetService("GuiService").SelectedObject = native end
	local context = live(self).context
	if focusVisible ~= nil and context and context.setState then context.setState("focus-visible", focusVisible) end
	for _, item in scrollPositions do
		if item.target.Parent then item.target.CanvasPosition = item.position end
	end
end)
method("html", "blur", 0, function(self: any)
	local native = assert(live(self).target)
	if native:IsA("TextBox") then native:ReleaseFocus() else
		local gui = game:GetService("GuiService")
		if gui.SelectedObject == native then gui.SelectedObject = nil end
	end
end)
-- Renderer extensions retain their existing explicit native contracts.
method("html", "snapshotAttributes", 0, function(self: any): any
	local values, keys = attributes(self), {}
	for key in values do table.insert(keys, key) end
	table.sort(keys)
	return Records.adopt(values, keys)
end)
method("html", "subscribeAttributes", 1, function(self: any, callback: any): any
	if SourceType.typeOf(callback) ~= "function" then return Operations.intrinsicError("TypeError", "Attribute subscription requires a callback") end
	local current = live(self)
	local box: any = { callback = callback, owner = current }
	local release: () -> ()
	release = function()
		if not box.owner then return end
		local owner, off = box.owner, box.off
		box.owner, box.callback, box.off = nil, nil, nil
		owner.cleanups[release] = nil
		if off then off() end
	end
	current.cleanups[release] = true
	local ok, off = pcall(assert(current.context).subscribeScene, function(_revision: number)
		local fn = box.callback
		if fn then Functions.invokeReference({ value = fn, owner = nil, mode = "free" }, function() return packet() end, false, 0) end
	end)
	if not ok then release(); error(off, 0) end
	if box.owner then box.off = off else off() end
	return Operations.registerNative(release, "free", "unsubscribeAttributes", 0)
end)
local instanceSchema: Operations.NativeObject = {
	tag = "HTMLElement",
	hasOwn = function(owner: any, key: any): boolean
		local current = assert(stateOf(owner), "Illegal DOM object")
		if unsupported[key] then error(`DOM API {tostring(key)} requires a native implementation`, 2) end
		return Records.hasOwn(current.properties, key)
	end,
	get = function(owner: any, key: any, receiver: any): any return Records.readOwn(assert(stateOf(owner)).properties, key, receiver) end,
	properties = function(owner: any): any return assert(stateOf(owner)).properties end,
	prototype = function(owner: any): any
		local explicit, parent = Records.getPrototype(assert(stateOf(owner)).properties)
		return if explicit then parent else DomClasses.prototype("html")
	end,
	ownKeys = function(owner: any): any return Records.ownKeys(live(owner).properties) end,
	enumerable = function(owner: any, key: any): boolean local desc = Records.descriptor(live(owner).properties, key); return desc ~= nil and desc.enumerable end,
	getOwnPropertyDescriptor = function(owner: any, key: any): any return Operations.getOwnPropertyDescriptor(live(owner).properties, key) end,
}
local function nativeOptions(value: any): any
	if Nulls.isNullish(value) or Records.owns(value) then return value end
	assert(type(value) == "table", "Native DOM method options require a typed dictionary")
	local copied, keys = {}, {}
	for key, item in next, value do
		assert(type(key) == "string", "Native DOM option names require strings")
		copied[key] = item
		table.insert(keys, key)
	end
	return Records.adopt(copied, keys)
end
function DomElements.create(target: GuiObject, context: Target.Context, options: Options?): any
	assert(target:IsA("GuiObject"), "A DOM target must be a native GuiObject")
	local current: State = { target = target, context = context, options = options or {}, active = true,
		cleanups = {}, views = setmetatable({}, { __mode = "k" }), bound = {}, properties = Operations.object() }
	local element: any = {}
	setmetatable(element, { [stateToken] = current, __index = function(self: any, key: any): any
		local info = assert(stateOf(self), "Illegal DOM object")
		if getters[key] then return getters[key](self) end
		if methods[key] then
			if not info.bound[key] then
				info.bound[key] = Operations.registerNative(function(...: any): any
					if key == "contains" then
						local other = (...)
						if typeof(other) == "Instance" then
							local native = other :: Instance
							if native:IsA("GuiObject") then return nativeContains(self, native) end
						end
					end
					if key == "focus" or key == "getAnimations" or key == "addEventListener" or key == "removeEventListener" then
						local args = packet(...)
						local index = if key == "addEventListener" or key == "removeEventListener" then 3 else 1
						if Arrays.length(args) >= index and type(args[index]) ~= "boolean" then args[index] = nativeOptions(args[index]) end
						return methods[key](self, table.unpack(args, 1, Arrays.length(args)))
					end
					return methods[key](self, ...)
				end, "free", key, Functions.length(methods[key]))
			end
			return info.bound[key]
		end
		if Records.hasOwn(info.properties, key) then return Operations.get(info.properties, key) end
		error(`DOM API {tostring(key)} requires a native implementation`, 2)
	end, __newindex = function(): never error("Raw native DOM property mutation is unsupported; use source descriptors", 2) end })
	DomClasses.register(element, "html")
	mounted[target] = element
	if current.options and current.options.pointer then
		local pointer = current.options.pointer
		current.cleanups[function() pointer.releaseOwner(element) end] = true
	end
	if current.options and current.options.events then
		local detach = current.options.events.attach(element, function(owner: any): { any }
			local result = { owner }
			local native = target.Parent
			while native do
				local ancestor = mounted[native]
				local ancestorState = if ancestor then stateOf(ancestor) else nil
				if ancestorState and ancestorState.active and ancestorState.options and ancestorState.options.events == current.options.events then
					table.insert(result, ancestor)
				end
				native = native.Parent
			end
			local root = current.options.documentRoot
			if root and (target == root or target:IsDescendantOf(root)) and current.options.document then
				table.insert(result, current.options.document)
				if current.options.window then table.insert(result, current.options.window) end
			end
			return result
		end)
		current.cleanups[detach] = true
	end
	Records.setReceiver(current.properties, element)
	current.offSchema = Operations.registerObject(element, instanceSchema)
	local weakOwner: any = setmetatable({ value = element }, { __mode = "v" })
	current.offProperties = Properties.register(element, function(key: any): boolean
		local owner = weakOwner.value
		assert(owner, "DOM property owner was collected")
		return Operations.binary("in", key, owner)
	end)
	local function release()
		if not current.active then return end
		if mounted[target] == element then mounted[target] = nil end
		local context = current.context
		if context and context.getAttributes then
			local ok, snapshot = pcall(context.getAttributes)
			if ok then current.detachedAttributes = snapshot end
		end
		if context and context.getInlinePropertyNames and context.getInlineProperty then
			pcall(function()
			current.detachedInline = {}
			for _, name in context.getInlinePropertyNames() do
				local value, priority = context.getInlineProperty(name)
				if value ~= "" then current.detachedInline[name] = {value, priority} end
			end
			end)
		end
		current.active = false
		local failed, failure = false, nil
		local function cleanup(callback: () -> ())
			local ok, problem = pcall(callback)
			if not ok and not failed then failed, failure = true, problem end
		end
		for off in table.clone(current.cleanups) do cleanup(off) end
		-- Retained CSS declaration views remain usable after detachment.
		table.clear(current.views)
		-- A detached DOM node can still be referenced by scheduled source callbacks.
		-- Keep its weakly held source schema for the lifetime of that object.
		current.offSchema = nil
		if current.offProperties then cleanup(current.offProperties); current.offProperties = nil end
		current.active = false
		current.target, current.context, current.options = nil, nil, nil
		table.clear(current.bound)
		if failed then error(failure, 0) end
	end
	return { element = element, release = release }
end
return DomElements
