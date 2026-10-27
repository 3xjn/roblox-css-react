--!strict
local StyleObjects = require(script.Parent.StyleObjects)
local SourceType = require(script.Parent.SourceType)
local Nulls = require(script.Parent.Nulls)
local Records = require(script.Parent.Records)
local Arrays = require(script.Parent.Arrays)
local SourceElements = require(script.Parent.SourceElements)
local Operations = require(script.Parent.SourceOperations)
local Objects = require(script.Parent.SourceObjects)
local Target = require(script.Parent.Target)
local DomElements = require(script.Parent.DomElements)

export type Props = { [string]: any }
export type Factory = (any, Props?, ...any) -> any
export type React = { read createElement: Factory, read Fragment: any? }

local Html = {}
Html.typeOf, Html.typeIs = SourceType.typeOf, SourceType.typeIs

function Html.staticSvgProps(asset: any, geometry: any, ...: any): Props
	if type(asset) ~= "string" and select("#", ...) == 0 then
		local source = asset
		if Nulls.isNullish(source) or type(source) == "boolean" or type(source) == "number" then
			return Records.adopt({}, {})
		end
		assert(type(source) == "table", "Static SVG root spreads require an object")
		if Records.owns(source) then
			local snapshot = Records.adopt({}, {})
			for _, name in Records.keys(source) do
				if Records.hasOwn(source, name) then
					snapshot[name] = source[name]
				end
			end
			return snapshot
		end
		assert(getmetatable(source) == nil, "Static SVG native root props require a plain table or adopted source record")
		local keys = geometry
		if keys == nil then
			keys = {}
			for name in next, source do
				table.insert(keys, name)
			end
		end
		return Records.adopt(table.clone(source), keys)
	end
	local props = Records.adopt({}, {})
	for index = 1, select("#", ...) do
		local segment = select(index, ...)
		Objects.assign(props, segment)
	end
	if asset == nil then
		return props
	end
	assert(type(asset) == "string" and asset ~= "", "Static SVG assets require a compiled asset key")
	for name, expected in geometry do
		local actual = props[name]
		assert(
			(type(actual) == "string" or type(actual) == "number")
				and (actual == expected or tostring(actual) == tostring(expected)),
			`Static SVG root geometry override {name} requires a document renderer`
		)
	end
	local result: Props = {}
	for rawName, value in next, props do
		assert(typeof(rawName) == "string", "Static SVG root prop names must be strings")
		local name: string = rawName :: string
		if geometry[name] ~= nil then
			continue
		end
		if name == "children" then
			assert(Nulls.isNullish(value) or value == false, "Static SVG root child overrides require a document renderer")
			continue
		end
		assert(name ~= "data-css-svg-asset", "The compiled SVG asset attribute is owned by the static SVG adapter")
		assert(name ~= "ref" and not name:match("^on[A-Z]"), "Static SVG refs and events require an explicit native adapter")
		assert(
			name == "className" or name == "id" or name == "key" or name == "role" or name == "style"
				or name:match("^data%-%S+$") ~= nil or name:match("^aria%-%S+$") ~= nil,
			`Static SVG root prop {name} requires a document renderer`
		)
		result[name] = value
	end
	result["data-css-svg-asset"] = asset
	return result
end

local function sourceCopy(props: any): any
	if Nulls.isNullish(props) then
		return Records.adopt({}, {})
	end
	if Records.owns(props) then
		return Records.copy(props)
	end
	local keys = {}
	for key in next, props do
		assert(type(key) == "string", "Native source props require string keys")
		table.insert(keys, key)
	end
	return Records.adopt(table.clone(props), keys)
end
function Html.sourceInfo(element: any): any
	return SourceElements.get(element)
end
function Html.cloneElement(react: any, factory: Factory, element: any, overrides: any?, ...: any): any
	local info = Html.sourceInfo(element)
	local config = sourceCopy(overrides)
	if Nulls.isNull(config.key) then
		config.key = "null"
	end
	if not info then
		return react.cloneElement(element, config, ...)
	end
	local props = Records.copy(info.props)
	if not Nulls.isNullish(info.key) then
		props.key = info.key
	end
	if not Nulls.isNullish(info.ref) then
		props.ref = info.ref
	end
	for _, key in Records.keys(config) do
		-- React preserves a previous reserved key/ref when an override is undefined.
		if (key == "key" or key == "ref") and config[key] == nil then
			continue
		end
		props[key] = config[key]
	end
	return factory(info.tag, props, ...)
end

-- Source cn() calls commonly contain conditional strings. Keep the compiled
-- conflict merger independent of source-value normalization.
function Html.createClassName(merge: (...string?) -> string): (...any) -> string
	return function(...: any): string
		local parts = {}
		for index = 1, select("#", ...) do
			local value = select(index, ...)
			local kind = type(value)
			if kind == "nil" or kind == "boolean" or (kind == "number" and (value == 0 or value ~= value)) then
				continue
			end
			assert(
				kind == "string",
				"Source class composition needs strings or falsy conditions; other values require normalization"
			)
			if value ~= "" then
				table.insert(parts, value)
			end
		end
		return merge(table.concat(parts, " "))
	end
end

local tags = {
	button = "inline-block",
	input = "inline-block",
	textarea = "inline-block",
	label = "inline",
	fieldset = "block",
	legend = "block",
	div = "block",
	span = "inline",
	p = "block",
	section = "block",
	main = "block",
	header = "block",
	footer = "block",
	nav = "block",
	ul = "block",
	ol = "block",
	li = "block",
	a = "inline",
	table = "table",
	caption = "block",
	thead = "table-header-group",
	tbody = "table-row-group",
	tfoot = "table-footer-group",
	tr = "table-row",
	th = "table-cell",
	td = "table-cell",
	kbd = "inline",
	h1 = "block",
	h2 = "block",
	h3 = "block",
	h4 = "block",
	h5 = "block",
	h6 = "block",
	img = "inline-block",
	form = "block",
	script = "none",
}

local function attribute(name: string, value: any): string
	local kind = type(value)
	assert(kind == "string" or kind == "boolean" or kind == "number", `HTML attribute {name} requires a scalar value`)
	assert(kind ~= "number" or (value == value and math.abs(value) < math.huge), `HTML attribute {name} must be finite`)
	return tostring(value)
end

function Html.rest(props: Props, excluded: { string }): Props
	if Records.owns(props) then
		return Records.rest(props, excluded)
	end
	local result = table.clone(props)
	setmetatable(result, nil)
	for _, name in excluded do
		result[name] = nil
	end
	return result
end

local unitlessProperties: { [string]: boolean } = {
	opacity = true,
	["z-index"] = true,
	["flex-grow"] = true,
	["flex-shrink"] = true,
	order = true,
	["line-height"] = true,
	["font-weight"] = true,
	scale = true,
}

local function toKebabCase(name: string): string
	if name:sub(1, 2) == "--" then
		return name
	end
	local converted = name:gsub("([a-z0-9])([A-Z])", "%1-%2"):lower()
	return converted
end

local parseTokens: (string) -> { any }
local function parseSingleToken(raw: string): any
	local trimmed = raw:match("^%s*(.-)%s*$") or raw
	local functionName, argument = trimmed:match("^([%a_][%w_-]*)%((.*)%)$")
	if functionName then
		return { kind = "function", value = functionName, children = parseTokens(argument) }
	end
	local numOnly = trimmed:match("^(-?%d+%.?%d*)$") or trimmed:match("^(-?%.%d+)$")
	if numOnly then
		return { kind = "number", value = numOnly }
	end
	local pct = trimmed:match("^(-?%d+%.?%d*)%%$") or trimmed:match("^(-?%.%d+)%%$")
	if pct then
		return { kind = "percentage", value = pct }
	end
	local numPart, unitPart = trimmed:match("^(-?%d+%.?%d*)([a-zA-Z]+)$")
	if not numPart then
		numPart, unitPart = trimmed:match("^(-?%.%d+)([a-zA-Z]+)$")
	end
	if numPart and unitPart then
		local unit = unitPart:lower()
		local syntaxType = if unit == "s" or unit == "ms" or unit == "deg" or unit == "rad" or unit == "grad" or unit == "turn"
			then nil
			else "length"
		return { kind = "dimension", value = numPart, unit = unit, syntaxType = syntaxType }
	end
	return { kind = "word", value = trimmed }
end

-- Split only at the current nesting level. Whitespace and commas inside a
-- function or quoted string belong to that token, not the surrounding value.
parseTokens = function(source: string): { any }
	local result = {}
	local start, depth, quote, escaped = 1, 0, nil, false
	local function emit(last: number)
		if last >= start then table.insert(result, parseSingleToken(source:sub(start, last))) end
	end
	local i = 1
	while i <= #source do
		local char = source:sub(i, i)
		if quote then
			if escaped then escaped = false
			elseif char == "\\" then escaped = true
			elseif char == quote then quote = nil end
		elseif char == '"' or char == "'" then quote = char
		elseif char == "(" then depth += 1
		elseif char == ")" then depth -= 1
		elseif depth == 0 and (char:match("%s") or char == ",") then
			emit(i - 1)
			if char == "," then
				table.insert(result, { kind = "div", value = "," })
			else
				local first = i
				while i < #source and source:sub(i + 1, i + 1):match("%s") do i += 1 end
				table.insert(result, { kind = "space", value = source:sub(first, i) })
			end
			start = i + 1
		end
		i += 1
	end
	emit(#source)
	return result
end

function Html.normalizeStyle(value: any): StyleObjects.Style?
	if Nulls.isNullish(value) or value == false then
		return nil
	end
	if StyleObjects.is(value) then
		return value
	end
	if type(value) ~= "table" then
		return nil
	end
	local entries: { StyleObjects.Entry } = {}
	local keys = if Records.owns(value) then Records.keys(value) else nil
	local function addProp(rawName: any, setting: any)
		if type(rawName) ~= "string" then
			return
		end
		local name = toKebabCase(rawName)
		local isCustom = name:sub(1, 2) == "--"
		local validity: any = if isCustom then "deferred" else "valid"
		if Nulls.isNullish(setting) or setting == false or setting == "" then
			table.insert(entries, { name = name, declaration = nil })
		elseif type(setting) == "number" then
			if setting == setting and math.abs(setting) < math.huge then
				local text = string.format("%.17g", setting)
				local usePx = not isCustom and not unitlessProperties[name] and setting ~= 0
				local token: any = if usePx
					then { kind = "dimension", value = text, unit = "px", syntaxType = "length" }
					else { kind = "number", value = text }
				table.insert(entries, {
					name = name,
					declaration = {
						kind = "declaration",
						property = name,
						value = if usePx then text .. "px" else text,
						tokens = { token },
						important = false,
						validity = validity,
					},
				})
			end
		elseif type(setting) == "string" then
			local trimmed = setting:match("^%s*(.-)%s*$") or setting
			if trimmed ~= "" then
				table.insert(entries, {
					name = name,
					declaration = {
						kind = "declaration",
						property = name,
						value = trimmed,
						tokens = parseTokens(trimmed),
						important = false,
						validity = validity,
					},
				})
			end
		end
	end
	if keys then
		for _, k in keys do
			addProp(k, Operations.get(value, k))
		end
	else
		for k, v in next, value do
			addProp(k, v)
		end
	end
	return { kind = "style-object", entries = entries }
end

local scalarAttributes: { [string]: boolean } = {
	href = true,
	target = true,
	rel = true,
	type = true,
	placeholder = true,
	value = true,
	defaultValue = true,
	name = true,
	min = true,
	max = true,
	step = true,
	rows = true,
	cols = true,
	autoComplete = true,
	inputMode = true,
	pattern = true,
	alt = true,
	src = true,
	colSpan = true,
	rowSpan = true,
	scope = true,
	dir = true,
	title = true,
	nonce = true,
	maxLength = true,
	minLength = true,
	size = true,
	wrap = true,
	form = true,
	width = true,
	height = true,
	loading = true,
	decoding = true,
	fetchPriority = true,
	crossOrigin = true,
	referrerPolicy = true,
	sizes = true,
	srcSet = true,
	contentEditable = true,
	spellCheck = true,
	draggable = true,
	translate = true,
	enterKeyHint = true,
	autoCapitalize = true,
	autoCorrect = true,
}

local booleanAttributes: { [string]: boolean } = {
	disabled = true,
	readOnly = true,
	required = true,
	checked = true,
	defaultChecked = true,
	hidden = true,
	inert = true,
	multiple = true,
	autoFocus = true,
}

function Html.toHostProps(props: Props?, tag: string?, environment: Props?): Props
	local host: Props = {}
	local attributes: { [string]: string } = {}
	local eventHandlers: { [string]: any } = {}
	local nativeControl = if props and props.nativeControl
		then props.nativeControl
		elseif tag == "button" or tag == "a" then "button"
		elseif tag == "input" or tag == "textarea" then "auto"
		else nil
	if tag == "button" or tag == "a" then
		host.nativeControl = nativeControl
		if tag == "button" then host.labelable = true end
	elseif tag == "input" or tag == "textarea" then
		host.nativeControl = nativeControl
		host.labelable = true
	end
	assert(nativeControl == nil or nativeControl == "auto" or nativeControl == "button", "Unknown native control")
	for name, value in next, props or {} do
		assert(type(name) == "string", "HTML prop names must be strings")
		if name == "key" and Nulls.isNull(value) then
			host.key = "null"
		elseif Nulls.isNullish(value)
			or name == "suppressHydrationWarning"
			or name == "suppressContentEditableWarning"
			or name == "dangerouslySetInnerHTML"
		then
			-- Source React ignores nullish attribute/prop values and SSR hydration flags.
			continue
		elseif name == "ref" and environment and environment.createTarget then
			-- The target binder below owns source ref assignment and cleanup.
		elseif name == "tabIndex" then
			assert(type(value) == "number" and value % 1 == 0, "tabIndex requires an integer")
			attributes.tabindex = tostring(value)
		elseif name == "nativeControl" then
			host.nativeControl = nativeControl
		elseif nativeControl ~= nil and name == "labelable" then
			assert(type(value) == "boolean", "labelable must be boolean")
			host.labelable = value
		elseif nativeControl ~= nil and name == "bindTarget" then
			assert(type(value) == "function", "bindTarget must be a function")
			host.bindTarget = value
		elseif nativeControl ~= nil and name == "states" then
			assert(type(value) == "table", "Control states must be a record")
			local states = {}
			for state, active in value do
				assert(type(state) == "string" and type(active) == "boolean", "Control states require named booleans")
				states[state] = active
			end
			host.states = states
		elseif booleanAttributes[name] then
			if value == true then
				attributes[name:lower()] = ""
			end
		elseif scalarAttributes[name] then
			if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
				attributes[name:lower()] = attribute(name, value)
			end
		elseif name == "className" or name == "id" then
			assert(type(value) == "string", `HTML {name} must be a string`)
			host[name] = value
		elseif name == "children" or name == "key" then
			host[name] = value
		elseif name == "htmlFor" then
			assert(type(value) == "string", "HTML htmlFor must be a string")
			attributes["for"] = value
		elseif name == "style" then
			local normalized = Html.normalizeStyle(value)
			if normalized then
				host.style = normalized
			end
		elseif name == "role" or name:match("^data%-%S+$") or name:match("^aria%-%S+$") then
			if value ~= false then
				attributes[name] = attribute(name, value)
			end
		elseif name:match("^on[A-Z]") then
			eventHandlers[name] = value
		else
			error(`HTML prop {name} needs a host adapter`, 2)
		end
	end
	if next(attributes) then
		host.attributes = attributes
	end
	local ref = if props then props.ref else nil
	local hasEvents = next(eventHandlers) ~= nil
	local inputType = if props and type(props.type) == "string" then string.lower(props.type) else "text"
	local textInput = tag == "textarea" or (tag == "input" and (inputType == "text" or inputType == "search"
		or inputType == "email" or inputType == "tel" or inputType == "url" or inputType == "number"))
	if not Nulls.isNullish(ref) or hasEvents or ((tag == "button" or tag == "a") and environment and environment.bindSourceButton)
		or (textInput and environment and environment.bindSourceTextInput) then
		local previousBind: ((GuiObject, any) -> (() -> ())?)? = host.bindTarget
		local createTarget = if environment and type(environment.createTarget) == "function"
			then environment.createTarget :: (GuiObject, any, string?) -> any
			else nil
		local boundary: any = nil
		local sourceButton: any = nil
		local sourceInput: any = nil
		local buttonDisabled = props ~= nil and props.disabled == true
		local inputReadOnly = props ~= nil and props.readOnly == true
		local controlledValue = if props then props.value else nil
		local wasFocused = false
		local refreshPointerConnections: (() -> ())? = nil
		local function assign(value: any)
			if Nulls.isNullish(ref) then
				return
			end
			if type(ref) == "function" then
				(ref :: (any) -> ())(value)
			else
				assert(type(ref) == "table", "A source ref must be a callback or ref object")
				ref.current = value
			end
		end
		local function callHandler(fn: any, evt: any)
			if fn == nil or Nulls.isNullish(fn) then
				return
			end
			if environment and environment.sourceElements then
				Operations.call(fn, nil, Arrays.adopt({ evt }, 1))
			else
				(fn :: (any) -> ())(evt)
			end
		end
		host.bindTarget = function(target: GuiObject, context: any)
			local previousCleanup = if previousBind then previousBind(target, context) else nil
			local connections: { RBXScriptConnection } = {}
			local releaseClick: (() -> ())? = nil
			local releaseInput: (() -> ())? = nil
			local releaseChange: (() -> ())? = nil
			local releasePointerDown: (() -> ())? = nil
			local ok, reason = pcall(function()
				if createTarget and context then
					boundary = createTarget(target, context, tag)
					assign(boundary.element)
					releaseClick = DomElements.bindClick(boundary.element, function(evt: any)
						callHandler(eventHandlers.onClick, evt)
					end)
					releasePointerDown = DomElements.bindEvent(boundary.element, "pointerdown", function(evt: any)
						callHandler(eventHandlers.onPointerDown, evt)
					end)
					if tag == "input" or tag == "textarea" then
						releaseInput = DomElements.bindEvent(boundary.element, "input", function(evt: any)
							callHandler(eventHandlers.onInput, evt)
						end)
						releaseChange = DomElements.bindEvent(boundary.element, "change", function(evt: any)
							callHandler(eventHandlers.onChange, evt)
						end)
					end
				end
				do
					local domElem = if boundary then boundary.element else Nulls.value
					local function makeEvt(evtType: string, x: number?, y: number?, pointerType: string?)
						local evt: any = {}
						evt.type = evtType
						evt.target = domElem
						evt.currentTarget = domElem
						evt.relatedTarget = Nulls.value
						evt.button = 0
						evt.buttons = 1
						evt.detail = 1
						evt.clientX = x or 0
						evt.clientY = y or 0
						evt.pointerId = 1
						evt.pointerType = pointerType or "mouse"
						evt.isTrusted = true
						evt.shiftKey = false
						evt.ctrlKey = false
						evt.altKey = false
						evt.metaKey = false
						evt.defaultPrevented = false
						evt.preventDefault = Operations.registerNative(function()
							evt.defaultPrevented = true
						end, "free", "preventDefault", 0)
						evt.stopPropagation = Operations.registerNative(function() end, "free", "stopPropagation", 0)
						evt.stopImmediatePropagation = Operations.registerNative(function() end, "free", "stopImmediatePropagation", 0)
						if environment and environment.pointerEvent then
							local native = Operations.construct(environment.pointerEvent, Arrays.adopt({ evtType, Records.adopt({
								button = evt.button, buttons = evt.buttons, detail = evt.detail, clientX = evt.clientX, clientY = evt.clientY,
								pointerId = evt.pointerId, pointerType = evt.pointerType, shiftKey = evt.shiftKey, ctrlKey = evt.ctrlKey,
								altKey = evt.altKey, metaKey = evt.metaKey,
							}, {
								"button", "buttons", "detail", "clientX", "clientY", "pointerId", "pointerType",
								"shiftKey", "ctrlKey", "altKey", "metaKey",
							}) }, 2))
							Operations.defineDataProperty(native, "target", domElem, true, true, true)
							Operations.defineDataProperty(native, "currentTarget", domElem, true, true, true)
							evt.nativeEvent = native
						else
							evt.nativeEvent = evt
						end
						return Records.adopt(evt, {
							"type", "target", "currentTarget", "relatedTarget",
							"button", "buttons", "detail", "clientX", "clientY",
							"pointerId", "pointerType", "isTrusted",
							"shiftKey", "ctrlKey", "altKey", "metaKey",
							"defaultPrevented", "preventDefault", "stopPropagation", "stopImmediatePropagation",
							"nativeEvent",
						})
					end
					local enterConnection: RBXScriptConnection? = nil
					local leaveConnection: RBXScriptConnection? = nil
					local moveConnection: RBXScriptConnection? = nil
					local function wanted(name: string): boolean
						return not Nulls.isNullish(eventHandlers[name])
					end
					refreshPointerConnections = function()
						local enter = wanted("onMouseEnter") or wanted("onPointerEnter")
						local leave = wanted("onMouseLeave") or wanted("onPointerLeave")
						local move = wanted("onMouseMove") or wanted("onPointerMove")
						if enter and not enterConnection then
							enterConnection = target.MouseEnter:Connect(function(x, y)
								callHandler(eventHandlers.onPointerEnter, makeEvt("pointerenter", x, y))
								callHandler(eventHandlers.onMouseEnter, makeEvt("mouseenter", x, y))
							end)
						elseif not enter and enterConnection then enterConnection:Disconnect(); enterConnection = nil end
						if leave and not leaveConnection then
							leaveConnection = target.MouseLeave:Connect(function(x, y)
								callHandler(eventHandlers.onPointerLeave, makeEvt("pointerleave", x, y))
								callHandler(eventHandlers.onMouseLeave, makeEvt("mouseleave", x, y))
							end)
						elseif not leave and leaveConnection then leaveConnection:Disconnect(); leaveConnection = nil end
						if move and not moveConnection then
							moveConnection = target.InputChanged:Connect(function(input: InputObject)
								if input.UserInputType == Enum.UserInputType.MouseMovement then
									local pos = input.Position
									callHandler(eventHandlers.onPointerMove, makeEvt("pointermove", pos.X, pos.Y))
									callHandler(eventHandlers.onMouseMove, makeEvt("mousemove", pos.X, pos.Y))
								end
							end)
						elseif not move and moveConnection then moveConnection:Disconnect(); moveConnection = nil end
					end
					refreshPointerConnections()
					table.insert(connections, { Disconnect = function()
						refreshPointerConnections = nil
						if enterConnection then enterConnection:Disconnect() end
						if leaveConnection then leaveConnection:Disconnect() end
						if moveConnection then moveConnection:Disconnect() end
					end } :: any)
					table.insert(connections, target.InputBegan:Connect(function(input: InputObject)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local pos = input.Position
							local pointerType = if input.UserInputType == Enum.UserInputType.Touch then "touch" else "mouse"
							if boundary and not Nulls.isNullish(eventHandlers.onPointerDown) then DomElements.beginPointer(boundary.element, input) end
							callHandler(eventHandlers.onPointerDown, makeEvt("pointerdown", pos.X, pos.Y, pointerType))
							callHandler(eventHandlers.onMouseDown, makeEvt("mousedown", pos.X, pos.Y))
							if not target:IsA("GuiButton") then
								callHandler(eventHandlers.onClick, makeEvt("click", pos.X, pos.Y))
							end
						end
					end))
					table.insert(connections, target.InputEnded:Connect(function(input: InputObject)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local pos = input.Position
							local pointerType = if input.UserInputType == Enum.UserInputType.Touch then "touch" else "mouse"
							callHandler(eventHandlers.onPointerUp, makeEvt("pointerup", pos.X, pos.Y, pointerType))
							callHandler(eventHandlers.onMouseUp, makeEvt("mouseup", pos.X, pos.Y))
						end
					end))
					if target:IsA("GuiButton") and (tag == "button" or tag == "a") and not previousBind and environment and environment.bindSourceButton then
						sourceButton = environment.bindSourceButton(target, {
							disabled = buttonDisabled,
							onState = function(state: any)
								if context and context.setState then
									context.setState("hover", state.hovered)
									context.setState("active", state.pressed)
									context.setState("focus", state.focused)
									context.setState("focus-visible", state.focusVisible)
								end
								if state.focused ~= wasFocused then
									wasFocused = state.focused
									callHandler(if wasFocused then eventHandlers.onFocus else eventHandlers.onBlur, makeEvt(if wasFocused then "focus" else "blur"))
								end
							end,
							onActivated = function(input: InputObject)
								local pos = input.Position or Vector3.zero
								callHandler(eventHandlers.onClick, makeEvt("click", pos.X, pos.Y))
							end,
						})
					elseif target:IsA("GuiButton") then
						table.insert(connections, target.Activated:Connect(function(input: InputObject)
							local pos = input.Position
							callHandler(eventHandlers.onClick, makeEvt("click", pos.X, pos.Y))
						end))
					end
					if textInput and target:IsA("TextBox") and not previousBind and environment and environment.bindSourceTextInput then
						sourceInput = environment.bindSourceTextInput(target, {
							disabled = buttonDisabled,
							readOnly = inputReadOnly,
							onState = function(state: any)
								if context and context.setState then
									context.setState("focus", state.focused)
									context.setState("focus-visible", state.focusVisible)
								end
								if state.focused ~= wasFocused then
									wasFocused = state.focused
									callHandler(if wasFocused then eventHandlers.onFocus else eventHandlers.onBlur, makeEvt(if wasFocused then "focus" else "blur"))
								end
							end,
							onTextChanged = function(value: string)
								if controlledValue ~= nil and tostring(controlledValue) == value then return end
								callHandler(eventHandlers.onInput, makeEvt("input"))
								callHandler(eventHandlers.onChange, makeEvt("change"))
							end,
						})
					end
				end
			end)
			if not ok then
				if sourceButton then sourceButton.destroy(); sourceButton = nil end
				if sourceInput then sourceInput.destroy(); sourceInput = nil end
				if releaseClick then releaseClick() end
				if releaseInput then releaseInput() end
				if releaseChange then releaseChange() end
				if releasePointerDown then releasePointerDown() end
				for _, conn in connections do
					conn:Disconnect()
				end
				if boundary then
					boundary.release()
					boundary = nil
				end
				if previousCleanup then
					previousCleanup()
				end
				error(reason, 0)
			end
			return function()
				if sourceButton then sourceButton.destroy(); sourceButton = nil end
				if sourceInput then sourceInput.destroy(); sourceInput = nil end
				if releaseClick then releaseClick() end
				if releaseInput then releaseInput() end
				if releaseChange then releaseChange() end
				if releasePointerDown then releasePointerDown() end
				for _, conn in connections do
					conn:Disconnect()
				end
				local assigned, failure = pcall(assign, Nulls.value)
				if boundary then
					boundary.release()
					boundary = nil
				end
				if previousCleanup then
					previousCleanup()
				end
				if not assigned then
					error(failure, 0)
				end
			end
		end
		local descriptor: any = {
			tag = tag, createTarget = createTarget, previousBind = previousBind,
			ref = ref, handlers = eventHandlers, disabled = buttonDisabled, readOnly = inputReadOnly, value = controlledValue,
			textInput = textInput,
		}
		descriptor.update = function(nextDescriptor: any)
			eventHandlers = nextDescriptor.handlers
			buttonDisabled = nextDescriptor.disabled
			if sourceButton then sourceButton.setDisabled(buttonDisabled) end
			inputReadOnly, controlledValue = nextDescriptor.readOnly, nextDescriptor.value
			if sourceInput then sourceInput.setDisabled(buttonDisabled); sourceInput.setReadOnly(inputReadOnly) end
			if refreshPointerConnections then refreshPointerConnections() end
			if ref ~= nextDescriptor.ref then
				if boundary then assign(Nulls.value) end
				ref = nextDescriptor.ref
				if boundary then assign(boundary.element) end
			end
		end
		Target.registerUpdate(host.bindTarget, descriptor)
	end
	return host
end

function Html.isIntrinsic(tag: string): boolean
	return tags[tag] ~= nil
end

-- The supported HTML subset's display defaults, independent of author CSS.
-- Consumers can override this copy through RootOptions.displayDefaults.
function Html.getDisplayDefaults(): { [string]: string }
	local defaults = table.clone(tags)
	-- This display default does not bypass the required native label adapter.
	defaults.label = "inline"
	return defaults
end

function Html.create(react: React, components: { [string]: any }?, environment: Props?): Factory
	local function normalize(value: any, parents: { [any]: boolean }?): any
		if value == nil or Nulls.isNull(value) then
			return false
		end
		if type(value) ~= "table" or rawget(value, "$$typeof") ~= nil then
			return value
		end
		assert(react.Fragment ~= nil, "Child collections require the application's React.Fragment")
		local active = parents or {}
		assert(not active[value], "React child collections cannot contain cycles")
		active[value] = true
		local children = {}
		for key, child in next, value do
			children[key] = normalize(child, active)
		end
		active[value] = nil
		-- React Luau assigns stable keys to nested tables. A virtual fragment
		-- shields the caller's collection from that metadata write, retaining
		-- keyed children and nested-array order without a native layout wrapper.
		return react.createElement(react.Fragment, { children = children })
	end
	local function hostElement(tag: any, props: Props?, ...: any): any
		local count = select("#", ...)
		if count == 0 then
			if props and Nulls.isNull(props.children) then
				props = table.clone(props)
				assert(props).children = false
			end
			if props and type(props.children) == "table" and rawget(props.children :: Props, "$$typeof") == nil then
				props = table.clone(props)
				props.children = normalize(props.children, nil)
			end
			return react.createElement(tag, props)
		end
		for index = 1, count do
			local child = select(index, ...)
			if child == nil or (type(child) == "table" and rawget(child, "$$typeof") == nil) then
				local children = table.pack(...)
				for offset = index, count do
					children[offset] = normalize(children[offset], nil)
				end
				return react.createElement(tag, props, table.unpack(children, 1, count))
			end
		end
		return react.createElement(tag, props, ...)
	end
	local function intrinsic(tag: string, props: Props?, ...: any): any
		if tag == "script" then
			assert(select("#", ...) == 0, "Script children are unsupported")
			if props then
				assert(Nulls.isNullish(props.src) and Nulls.isNullish(props.children), "Executable scripts are unsupported")
				local html = props.dangerouslySetInnerHTML
				if not Nulls.isNullish(html) then
					assert(type(html) == "table" and html.__html == "", "Executable scripts are unsupported")
				end
			end
		end
		local info: any = nil
		if environment and environment.sourceElements then
			local copied = sourceCopy(props)
			local count = select("#", ...)
			if count == 1 then
				copied.children = (...)
			elseif count > 1 then
				copied.children = Arrays.adopt({ ... }, count)
			end
			info = {
				tag = tag,
				props = Records.rest(copied, { "key", "ref" }),
				key = if copied.key == nil then Nulls.value else copied.key,
				ref = if Nulls.isNullish(copied.ref) then Nulls.value else copied.ref,
			}
			-- Use the copied own string properties for the native host, just as
			-- React's config processing ignores inherited and symbol properties.
			props = copied
		end
		local hostProps = Html.toHostProps(props, tag, environment)
		if info then
			SourceElements.attach(hostProps, info)
		end
		return hostElement(tag, hostProps, ...)
	end
	return function(tag: any, props: Props?, ...: any): any
		if props and props.key ~= nil then
			local key = props.key
			assert(
				Nulls.isNull(key) or type(key) == "string" or type(key) == "number",
				"Source keys require strings or numbers"
			)
			if Nulls.isNull(key) or type(key) == "number" or rawget(props, "key") == nil then
				props = sourceCopy(props)
				assert(props).key = if Nulls.isNull(key) then "null" else Records.keyString(key)
			end
		end
		if props and props.ref ~= nil and rawget(props, "ref") == nil then
			local ref = props.ref
			props = sourceCopy(props)
			assert(props).ref = ref
		end
		if react.Fragment ~= nil and tag == react.Fragment then
			return hostElement(tag, props, ...)
		end
		if type(tag) ~= "string" then
			return react.createElement(tag, props, ...)
		end
		if props and props.nativeControl ~= nil then
			-- An explicit adapter already owns the binding. Bypass a consumer's
			-- tag component map so it cannot install a second interaction scope.
			assert(Html.isIntrinsic(tag) or tag == "button", `HTML element {tag} needs a rendering adapter`)
			return intrinsic(tag, props, ...)
		end
		local component = if components then components[tag] else nil
		if component ~= nil then
			assert(
				type(component) == "function" or type(component) == "table",
				`HTML element {tag} requires a component binding`
			)
			return react.createElement(component, props, ...)
		end
		assert(Html.isIntrinsic(tag), `HTML element {tag} needs a native behavior or rendering adapter`)
		return intrinsic(tag, props, ...)
	end
end

function Html.createSeparator(element: Factory): (Props) -> any
	return function(props: Props): any
		local orientation = props.orientation or "horizontal"
		assert(orientation == "horizontal" or orientation == "vertical", "Unknown separator orientation")
		local forwarded = table.clone(props)
		forwarded.orientation = nil
		forwarded["data-orientation"] = orientation
		forwarded["aria-orientation"] = orientation
		forwarded.role = props.role or "separator"
		return element("div", forwarded)
	end
end

return Html
