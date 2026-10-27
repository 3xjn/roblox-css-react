--!strict

local Html = require(script.Parent.Html)
local Target = require(script.Parent.Target)
type Props = Html.Props
type Binder = (GuiObject) -> (() -> ())?
type Interaction = { hovered: boolean, pressed: boolean, focused: boolean, focusVisible: boolean, disabled: boolean }
export type ToggleOptions = {
	value: boolean?,
	defaultValue: boolean?,
	disabled: boolean?,
	readOnly: boolean?,
	onValueChange: ((boolean, InputObject, number) -> ())?,
}
export type ButtonOptions = { disabled: boolean?, onActivated: ((InputObject, number) -> ())? }
export type TextInputOptions = {
	value: string?,
	defaultValue: string?,
	disabled: boolean?,
	readOnly: boolean?,
	flushSync: ((() -> ()) -> ())?,
	onValueChange: ((string) -> ())?,
	onFocusLost: ((string, boolean, InputObject) -> ())?,
}
export type TextInputState = {
	text: string,
	focused: boolean,
	selected: boolean,
	focusVisible: boolean,
	disabled: boolean,
	readOnly: boolean,
}
export type Options = {
	flushSync: ((() -> ()) -> ())?,
	bindLabel: Target.Binder?,
	field: {
		prepare: (
			Props
		) -> { props: Props, connected: boolean, valid: boolean?, observe: (TextInputState, string) -> () },
	}?,
}
export type Bindings = {
	read useButton: ((ButtonOptions) -> (Binder, Interaction))?,
	read useToggle: ((ToggleOptions) -> (Binder, { value: boolean, interaction: Interaction }))?,
	read useTextInput: ((TextInputOptions) -> (Binder, TextInputState, string))?,
}

local Controls = {}

local function states(interaction: Interaction, disabled: boolean?): { [string]: boolean }
	-- CSS control semantics follow committed props. Native availability still
	-- gates input in the behavior binding and supplies observed interaction.
	local unavailable = disabled == true
	return {
		hover = interaction.hovered,
		active = interaction.pressed,
		focus = interaction.focused,
		["focus-visible"] = interaction.focusVisible,
		disabled = unavailable,
		enabled = not unavailable,
	}
end

-- Behavior comes from the existing primitives package. This adapter only maps
-- its platform props/state onto the CSS renderer; it owns no visual classes.
function Controls.create(react: Html.React, behavior: Bindings, options: Options?)
	assert(type(behavior) == "table", "Controls require the application's native behavior bindings")
	local function Label(props: Props)
		local bind = if options then options.bindLabel else nil
		assert(type(bind) == "function", "Label requires the application's native label binding")
		assert(props.htmlFor == nil or type(props.htmlFor) == "string", "Label htmlFor must be a string")
		local host = Html.toHostProps(Html.rest(props, { "htmlFor" }))
		local attributes = host.attributes or {}
		attributes["for"] = props.htmlFor
		host.attributes = attributes
		host.bindTarget = bind
		return react.createElement("label", host)
	end
	local function Button(props: Props)
		local useButton = behavior.useButton
		assert(type(useButton) == "function", "Button requires the application's native button binding")
		assert(props.disabled == nil or type(props.disabled) == "boolean", "Button disabled must be boolean")
		assert(
			props.onActivated == nil or type(props.onActivated) == "function",
			"Button onActivated must be a function"
		)
		assert(props.type == nil or props.type == "button", "Button form types need a form adapter")
		assert(props.text == nil or type(props.text) == "string", "Button text must be a string")
		assert(props.text == nil or props.children == nil, "Button accepts text or children, not both")
		local bind, interaction = useButton({ disabled = props.disabled, onActivated = props.onActivated })
		local forwarded = Html.rest(props, { "disabled", "onActivated", "type", "text" })
		if props.text ~= nil then
			forwarded.children = props.text
		end
		local host = Html.toHostProps(forwarded)
		local attributes = host.attributes or {}
		attributes.disabled = if props.disabled then "" else nil
		attributes.type = "button"
		host.attributes = attributes
		host.states = states(interaction, props.disabled)
		host.bindTarget = bind
		return react.createElement("button", host)
	end
	local function Toggle(props: Props)
		local useToggle = behavior.useToggle
		assert(type(useToggle) == "function", "Toggle requires the application's native toggle binding")
		for _, name in { "pressed", "defaultPressed", "disabled", "readOnly" } do
			assert(props[name] == nil or type(props[name]) == "boolean", `Toggle {name} must be boolean`)
		end
		assert(
			props.onPressedChange == nil or type(props.onPressedChange) == "function",
			"Toggle onPressedChange must be a function"
		)
		assert(props.type == nil or props.type == "button", "Toggle form button types need a form adapter")
		assert(props.text == nil or type(props.text) == "string", "Toggle text must be a string")
		assert(props.text == nil or props.children == nil, "Toggle accepts text or children, not both")
		local bind, state = useToggle({
			value = props.pressed,
			defaultValue = props.defaultPressed,
			disabled = props.disabled,
			readOnly = props.readOnly,
			onValueChange = props.onPressedChange,
		})
		local forwarded =
			Html.rest(props, { "pressed", "defaultPressed", "disabled", "readOnly", "onPressedChange", "type", "text" })
		if props.text ~= nil then
			forwarded.children = props.text
		end
		local host = Html.toHostProps(forwarded)
		local attributes = host.attributes or {}
		attributes["data-pressed"] = if state.value then "" else nil
		attributes["aria-pressed"] = tostring(state.value)
		attributes.disabled = if props.disabled then "" else nil
		attributes.type = "button"
		host.attributes = attributes
		host.states = states(state.interaction, props.disabled)
		host.bindTarget = bind
		return react.createElement("button", host)
	end
	local function Input(props: Props)
		local field = if options and options.field then options.field.prepare(props) else nil
		props = if field then field.props else props
		local useTextInput = behavior.useTextInput
		assert(type(useTextInput) == "function", "Input requires the application's native text input binding")
		for _, name in { "value", "defaultValue", "placeholder" } do
			assert(props[name] == nil or type(props[name]) == "string", `Input {name} must be a string`)
		end
		for _, name in { "disabled", "readOnly", "required" } do
			assert(props[name] == nil or type(props[name]) == "boolean", `Input {name} must be boolean`)
		end
		for _, name in { "onValueChange", "onFocusLost" } do
			assert(props[name] == nil or type(props[name]) == "function", `Input {name} must be a function`)
		end
		assert(
			props.type == nil or props.type == "text" or props.type == "search",
			"Input type needs a native editor adapter"
		)
		assert(props.size == nil, "Input character-count sizing needs an intrinsic width provider")
		for _, name in { "required", "minLength", "maxLength", "pattern", "min", "max", "step" } do
			assert(
				props[name] == nil or props[name] == false or (field and field.connected),
				`Input {name} requires a field constraint adapter`
			)
		end
		assert(props.children == nil or props.children == false, "Input cannot contain children")
		local bind, state, accepted = useTextInput({
			value = props.value,
			defaultValue = props.defaultValue,
			disabled = props.disabled,
			readOnly = props.readOnly,
			flushSync = if options then options.flushSync else nil,
			onValueChange = props.onValueChange,
			onFocusLost = props.onFocusLost,
		})
		local host = Html.toHostProps(Html.rest(props, {
			"value",
			"defaultValue",
			"placeholder",
			"type",
			"size",
			"disabled",
			"readOnly",
			"onValueChange",
			"onFocusLost",
			"required",
			"name",
			"minLength",
			"maxLength",
			"pattern",
			"min",
			"max",
			"step",
		}))
		if field then
			-- A controlled edit request may be rejected or rewritten. Only the
			-- application's committed value participates in field state.
			field.observe(state, if props.value ~= nil then props.value else accepted)
		end
		local disabled, readOnly = props.disabled == true, props.readOnly == true
		local attributes = host.attributes or {}
		attributes.type = props.type or "text"
		attributes.value = props.value
		attributes["default-value"] = accepted
		attributes.placeholder = props.placeholder
		attributes.disabled = if disabled then "" else nil
		attributes.readonly = if readOnly then "" else nil
		attributes.required = if props.required then "" else nil
		for _, name in { "name", "minLength", "maxLength", "pattern", "min", "max", "step" } do
			local value = props[name]
			if value ~= nil then
				assert(type(value) == "string" or type(value) == "number", `Input {name} requires a scalar`)
				attributes[string.lower(name)] = tostring(value)
			end
		end
		host.attributes = attributes
		host.states = {
			focus = state.focused,
			["focus-visible"] = state.focusVisible,
			disabled = disabled,
			enabled = not disabled,
			["read-only"] = readOnly or disabled,
			["read-write"] = not readOnly and not disabled,
			["placeholder-shown"] = props.placeholder ~= nil and state.text == "",
			required = props.required == true,
			optional = props.required ~= true,
		}
		host.bindTarget = bind
		if field and field.connected then
			host.states.valid = field.valid == true
			host.states.invalid = field.valid == false
		end
		return react.createElement("input", host)
	end
	return { Button = Button, Toggle = Toggle, Input = Input, Label = Label }
end

return Controls
