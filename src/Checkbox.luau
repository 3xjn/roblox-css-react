--!strict
-- Checkbox composition follows Base UI 1.9.0. See ../LICENSE.base-ui.
-- Native button events replace the browser's hidden input. CheckboxGroup is an
-- optional context bridge; forms, field validation and exit transitions remain separate.

local Html = require(script.Parent.Html)
local Composition = require(script.Parent.Composition)
local Controls = require(script.Parent.Controls)
local ValueState = require(script.Parent.ValueState)

type Props = Html.Props
export type State = {
	checked: boolean,
	disabled: boolean,
	readOnly: boolean,
	required: boolean,
	indeterminate: boolean,
}
export type ChangeEventDetails = {
	reason: "none",
	event: InputObject,
	isCanceled: boolean,
	isPropagationAllowed: boolean,
	cancel: () -> (),
	allowPropagation: () -> (),
}
type Context = { Provider: any }
export type React = Html.React & ValueState.React & {
	read cloneElement: Html.Factory,
	read isValidElement: (any) -> boolean,
	read createContext: (State?) -> Context,
	read useContext: (Context) -> State?,
	read useMemo: <T>(() -> T, { any }) -> T,
}

local Checkbox = {}

local function details(input: InputObject): ChangeEventDetails
	local value: ChangeEventDetails
	value = {
		reason = "none",
		event = input,
		isCanceled = false,
		isPropagationAllowed = false,
		cancel = function()
			value.isCanceled = true
		end,
		allowPropagation = function()
			value.isPropagationAllowed = true
		end,
	}
	return value
end

local function mapping(state: State): Props
	return {
		checked = function(value: any): Props
			if state.indeterminate then
				return {}
			end
			return { [if value then "data-checked" else "data-unchecked"] = "" }
		end,
	}
end

export type Preparation = { props: Props, getChecked: (() -> boolean)? }
export type Options = { group: { prepare: (Props) -> Preparation }? }

function Checkbox.create(react: React, behavior: Controls.Bindings, element: Html.Factory?, options: Options?)
	assert(type(behavior.useButton) == "function", "Checkbox requires the application's native button binding")
	local useButton = assert(behavior.useButton)
	local createElement = element or Html.create(react)
	local render = Composition.create(react, createElement).useRender
	local context = react.createContext(nil)
	local useChecked = ValueState.create(react, "Checkbox", function(value)
		assert(type(value) == "boolean", "Checkbox checked value must be boolean")
		return value
	end)
	local function Root(props: Props)
		local group = if options and options.group then options.group.prepare(props) else nil
		props = if group then group.props else props
		for _, name in { "checked", "defaultChecked", "indeterminate", "disabled", "readOnly", "required" } do
			assert(props[name] == nil or type(props[name]) == "boolean", `Checkbox {name} must be boolean`)
		end
		assert(
			props.onCheckedChange == nil or type(props.onCheckedChange) == "function",
			"Checkbox change needs a function"
		)
		assert(props.bindTarget == nil, "Checkbox owns its native interaction binding")
		assert(props.states == nil, "Checkbox owns its native interaction states")
		assert(props.labelable == nil or props.labelable == true, "Checkbox owns its label-control semantics")
		assert(
			props.nativeControl == nil or props.nativeControl == "button",
			"Checkbox requires its native button representation"
		)
		assert(props.type == nil or props.type == "button", "Checkbox form button types need a form adapter")
		for _, name in { "name", "value", "form", "uncheckedValue", "inputRef", "parent" } do
			assert(props[name] == nil, `Checkbox {name} requires a form, group or input adapter`)
		end
		assert(
			props.nativeButton == nil or type(props.nativeButton) == "boolean",
			"Checkbox nativeButton must be boolean"
		)
		local checked, requestChecked, getChecked = useChecked({
			value = props.checked,
			defaultValue = props.defaultChecked == true,
			onChange = props.onCheckedChange,
			getAccepted = if group then group.getChecked else nil,
		})
		local latest = react.useRef(props)
		react.useLayoutEffect(function()
			latest.current = props
			return nil
		end)
		local bind, interaction = useButton({
			disabled = props.disabled,
			onActivated = function(input: InputObject, _count: number)
				local current = latest.current
				if current.disabled or current.readOnly then
					return
				end
				-- Base UI excludes Enter from checkbox toggling. Native pointer,
				-- touch, Space and gamepad activation retain their button path.
				if input and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
					return
				end
				requestChecked(not getChecked(), details(input))
			end,
		})
		local state = react.useMemo(function(): State
			return {
				checked = checked,
				disabled = props.disabled == true,
				readOnly = props.readOnly == true,
				required = props.required == true,
				indeterminate = props.indeterminate == true,
			}
		end, {
			checked,
			props.disabled == true,
			props.readOnly == true,
			props.required == true,
			props.indeterminate == true,
		})
		local rest = Html.rest(props, {
			"checked",
			"defaultChecked",
			"indeterminate",
			"disabled",
			"readOnly",
			"required",
			"onCheckedChange",
			"nativeButton",
			"nativeControl",
			"labelable",
			"className",
			"style",
			"render",
		})
		local native = {
			role = "checkbox",
			type = if props.nativeButton then "button" else nil,
			["aria-checked"] = if state.indeterminate then "mixed" else tostring(checked),
			["aria-readonly"] = if state.readOnly then true else nil,
			["aria-required"] = if state.required then true else nil,
			["aria-disabled"] = if state.disabled then true else nil,
			disabled = if props.nativeButton and state.disabled then "" else nil,
			nativeControl = "button",
			labelable = true,
			bindTarget = bind,
			states = {
				hover = interaction.hovered,
				active = interaction.pressed,
				focus = interaction.focused,
				["focus-visible"] = interaction.focusVisible,
				checked = checked,
				indeterminate = state.indeterminate,
				disabled = state.disabled,
				enabled = not state.disabled,
				["read-only"] = state.readOnly or state.disabled,
				["read-write"] = not state.readOnly and not state.disabled,
				required = state.required,
				optional = not state.required,
			},
		}
		local content = render({
			defaultTagName = "span",
			state = state,
			stateAttributesMapping = mapping(state),
			props = { native, rest },
			className = props.className,
			style = props.style,
			render = props.render,
		})
		return react.createElement(context.Provider, { value = state }, content)
	end
	local function Indicator(props: Props)
		local state = assert(react.useContext(context), "Checkbox indicator requires a Checkbox root")
		assert(props.keepMounted == nil or type(props.keepMounted) == "boolean", "Checkbox keepMounted must be boolean")
		return render({
			defaultTagName = "span",
			enabled = props.keepMounted == true or state.checked or state.indeterminate,
			state = state,
			stateAttributesMapping = mapping(state),
			props = Html.rest(props, { "keepMounted", "className", "style", "render" }),
			className = props.className,
			style = props.style,
			render = props.render,
		})
	end
	return { Root = Root, Indicator = Indicator }
end

return Checkbox
