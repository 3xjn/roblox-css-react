--!strict
-- Native field composition follows Base UI 1.9.0. See ../LICENSE.base-ui.
-- The application supplies its independent field model and input bindings.

local Html = require(script.Parent.Html)
local Composition = require(script.Parent.Composition)

type Props = Html.Props
type Cancel = () -> ()
type Validation = { errors: { string }, flags: { [string]: boolean }? }
type State = { disabled: boolean, touched: boolean, dirty: boolean, valid: boolean?, filled: boolean, focused: boolean }
type Snapshot = { state: State, value: string, initialValue: string, errors: { string }, flags: { [string]: boolean } }
type Model = {
	getSnapshot: () -> Snapshot?,
	configure: (Props) -> (),
	setValue: (string) -> (),
	setFocused: (boolean) -> (),
	validate: () -> (),
	reset: (string?) -> (),
	subscribe: ((Snapshot) -> ()) -> Cancel,
	destroy: () -> (),
}
type Context = { Provider: any }
type Reference<T> = { current: T }
export type React = Html.React & {
	read cloneElement: Html.Factory,
	read isValidElement: (any) -> boolean,
	read createContext: (any) -> Context,
	read useContext: (Context) -> any,
	read useRef: <T>(T) -> Reference<T>,
	read useMemo: <T>(() -> T, { any }) -> T,
	read useState: <T>(T) -> (T, (T | ((T) -> T)) -> ()),
	read useLayoutEffect: (() -> (() -> ())?, { any }?) -> (),
}
export type ModelFactory = (string?, Props?) -> Model
export type Options = {
	getFormValues: (() -> Props)?,
	runValidation: (((string, Props) -> any, string, Props, (any) -> ()) -> Cancel?)?,
	constraints: ((Props, string) -> Validation)?,
	renderErrors: (({ string }) -> any)?,
}
type Owner = {
	model: Model,
	props: Props,
	control: Props?,
	token: any,
	id: string,
	controlId: string,
	messages: { { token: any, id: string } },
	labelId: string?,
	refresh: () -> (),
	runner: (string, (Validation) -> ()) -> Cancel?,
}
type Scope = { owner: Owner, snapshot: Snapshot, props: Props, runner: (string, (Validation) -> ()) -> Cancel? }

local Field = {}
local absent = table.freeze({})
local emptyValues: Props = table.freeze({} :: Props)
local mapping = {
	valid = function(value: any): Props
		return { [if value then "data-valid" else "data-invalid"] = "" }
	end,
}

local function schedule(milliseconds: number, callback: () -> ()): Cancel
	local active = true
	local thread = task.delay(milliseconds / 1000, function()
		if active then
			active = false
			callback()
		end
	end)
	return function()
		if active then
			active = false
			pcall(task.cancel, thread)
		end
	end
end

local function messages(result: any): { string }
	if result == nil or result == "" then
		return {}
	end
	if type(result) == "string" then
		return { result }
	end
	assert(type(result) == "table", "Field validator must return a message, message array or nil")
	local output = {}
	for key in result do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #result,
			"Asynchronous field validation requires a provider; messages must be a dense array"
		)
	end
	for index = 1, #result do
		assert(type(result[index]) == "string", "Field validation messages must be strings")
		if result[index] ~= "" then
			table.insert(output, result[index])
		end
	end
	return output
end

function Field.create(react: React, createModel: ModelFactory, element: Html.Factory?, options: Options?)
	assert(type(createModel) == "function", "Field requires the application's field model factory")
	local createElement = element or Html.create(react)
	local render = Composition.create(react, createElement).useRender
	local context, itemContext = react.createContext(nil), react.createContext(false)
	local settings: Options = options or {}
	local function scope(): Scope
		return assert(react.useContext(context), "Field parts require a Field root")
	end
	local function configure(owner: Owner, committedProps: Props?, runner: ((string, (Validation) -> ()) -> Cancel?)?)
		if committedProps then
			owner.props = committedProps
		end
		if runner then
			owner.runner = runner
		end
		local props, control: Props = owner.props, owner.control or {}
		owner.model.configure({
			disabled = props.disabled,
			invalid = props.invalid,
			dirty = props.dirty,
			touched = props.touched,
			readOnly = control.readOnly == true or control.disabled == true,
			validationMode = props.validationMode,
			validationDebounceTime = props.validationDebounceTime,
			runValidation = owner.runner,
			schedule = schedule,
		})
	end
	local function part(tag: string, props: Props, state: State, defaults: Props?, enabled: boolean?): any
		return render({
			defaultTagName = tag,
			state = state,
			stateAttributesMapping = mapping,
			props = { defaults or {}, Html.rest(props, { "className", "style", "render" }) },
			className = props.className,
			style = props.style,
			render = props.render,
			enabled = enabled,
		})
	end
	local function localState(current: Scope): State
		local disabled = react.useContext(itemContext) == true
		if not disabled then
			return current.snapshot.state
		end
		local state = table.clone(current.snapshot.state)
		state.disabled = true
		return state
	end
	local function Root(props: Props)
		for _, name in { "disabled", "invalid", "dirty", "touched" } do
			assert(props[name] == nil or type(props[name]) == "boolean", `Field {name} must be boolean`)
		end
		assert(props.name == nil or type(props.name) == "string", "Field name must be a string")
		assert(props.validate == nil or type(props.validate) == "function", "Field validate must be a function")
		assert(
			props.actionsRef == nil or type(props.actionsRef) == "table",
			"Field actionsRef requires a native ref object"
		)
		local reference = react.useRef(nil :: Owner?)
		local _, setVersion = react.useState(0)
		if not reference.current then
			local id = "css-field-" .. game:GetService("HttpService"):GenerateGUID(false)
			reference.current = {
				model = createModel(""),
				props = props,
				id = id,
				controlId = id .. "-control",
				messages = {},
				token = nil,
				control = nil,
				labelId = nil,
				refresh = function()
					local current = reference.current
					if current and current.model.getSnapshot() then
						setVersion(function(previous: number)
							return previous + 1
						end)
					end
				end,
				runner = function()
					return nil
				end,
			}
		end
		local owner = reference.current :: Owner
		local runner = react.useMemo(function()
			return function(value: string, finish: (Validation) -> ()): Cancel?
				local control: Props = owner.control or {}
				local constraints: Validation = if settings.constraints
					then settings.constraints(control, value)
					else { errors = {}, flags = { valueMissing = control.required == true and value == "" } }
				local function complete(result: any)
					local errors = messages(result)
					local flags: { [string]: boolean } = table.clone(constraints.flags or ({} :: { [string]: boolean }))
					flags.customError = flags.customError == true or #errors > 0
					for _, message in constraints.errors do
						table.insert(errors, message)
					end
					finish({ errors = errors, flags = flags })
				end
				local validator: ((string, Props) -> any)? = props.validate
				if validator == nil then
					complete(nil)
					return nil
				end
				local values = if settings.getFormValues then settings.getFormValues() else emptyValues
				if settings.runValidation then
					return settings.runValidation(validator, value, values, complete)
				end
				complete(validator(value, values))
				return nil
			end
		end, { props.validate or absent })
		local snapshot, setSnapshot = react.useState(owner.model.getSnapshot() :: Snapshot)
		react.useLayoutEffect(function()
			local release = owner.model.subscribe(setSnapshot)
			setSnapshot(owner.model.getSnapshot() :: Snapshot)
			return function()
				release()
				owner.model.destroy()
			end
		end, { owner })
		react.useLayoutEffect(function()
			owner.props, owner.runner = props, runner
			configure(owner)
			return nil
		end)
		local actions = react.useMemo(function()
			return { validate = owner.model.validate }
		end, { owner })
		react.useLayoutEffect(function()
			local ref = props.actionsRef
			if not ref then
				return nil
			end
			ref.current = actions
			return function()
				if ref.current == actions then
					ref.current = nil
				end
			end
		end, { props.actionsRef or absent, actions })
		local rest = Html.rest(props, {
			"name",
			"disabled",
			"invalid",
			"dirty",
			"touched",
			"validate",
			"validationMode",
			"validationDebounceTime",
			"actionsRef",
		})
		return react.createElement(
			context.Provider,
			{ value = { owner = owner, snapshot = snapshot, props = props, runner = runner } },
			part("div", rest, snapshot.state)
		)
	end
	local function Item(props: Props)
		local current = scope()
		local inherited = react.useContext(itemContext) == true
		assert(props.disabled == nil or type(props.disabled) == "boolean", "Field Item disabled must be boolean")
		local state = table.clone(current.snapshot.state)
		state.disabled = state.disabled or inherited or props.disabled == true
		return react.createElement(
			itemContext.Provider,
			{ value = inherited or props.disabled == true },
			part("div", Html.rest(props, { "disabled" }), state)
		)
	end
	local function metadata(current: Scope, props: Props, kind: string, enabled: boolean): string
		assert(props.id == nil or type(props.id) == "string", "Field part id must be a string")
		local token = react.useRef({})
		local id = react.useRef(nil :: string?)
		if id.current == nil then
			id.current = "css-field-" .. kind .. "-" .. game:GetService("HttpService"):GenerateGUID(false)
		end
		local value, owner = props.id or id.current, current.owner
		react.useLayoutEffect(function()
			if not enabled then
				return nil
			end
			if kind == "label" then
				assert(
					owner.labelId == nil or owner.labelId == value,
					"Multiple field labels require a label-association provider"
				)
				owner.labelId = value
			else
				table.insert(owner.messages, { token = token.current, id = value })
			end
			owner.refresh()
			return function()
				if kind == "label" then
					if owner.labelId == value then
						owner.labelId = nil
					end
				else
					for index = #owner.messages, 1, -1 do
						if owner.messages[index].token == token.current then
							table.remove(owner.messages, index)
						end
					end
				end
				owner.refresh()
			end
		end, { owner, value, enabled })
		return value
	end
	local function Label(props: Props)
		local current = scope()
		local state = localState(current)
		assert(
			props.nativeLabel == nil or props.nativeLabel == true,
			"Non-native Field labels require a label provider"
		)
		local id = metadata(current, props, "label", true)
		return part("label", Html.rest(props, { "nativeLabel" }), state, { id = id, htmlFor = current.owner.controlId })
	end
	local function Description(props: Props)
		local current = scope()
		local state = localState(current)
		local id = metadata(current, props, "description", true)
		return part("p", props, state, { id = id })
	end
	local function Error(props: Props)
		local current = scope()
		local state, snapshot = localState(current), current.snapshot
		local match = props.match
		assert(match == nil or type(match) == "boolean" or type(match) == "string", "Unknown Field Error match")
		local enabled = match == true
			or (
				not state.disabled
				and (
					if type(match) == "string"
						then (if match == "valid" then state.valid == true else snapshot.flags[match] == true)
						else state.valid == false
				)
			)
		local id = metadata(current, props, "error", enabled)
		local content = props.children
		if content == nil and #snapshot.errors > 0 then
			assert(
				#snapshot.errors == 1 or settings.renderErrors ~= nil,
				"Multiple default errors require a message renderer"
			)
			content = if settings.renderErrors then settings.renderErrors(snapshot.errors) else snapshot.errors[1]
		end
		return part("div", Html.rest(props, { "match" }), state, { id = id, children = content }, enabled)
	end
	local function Validity(props: Props)
		local snapshot = scope().snapshot
		local children = props.children
		assert(type(children) == "function", "Field Validity requires a render-function child")
		local public = react.useMemo(function()
			local flags: Props = table.clone(snapshot.flags)
			flags.valid = snapshot.state.valid
			return {
				validity = flags,
				errors = snapshot.errors,
				error = snapshot.errors[1] or "",
				value = snapshot.value,
				initialValue = snapshot.initialValue,
			}
		end, {
			snapshot.flags,
			snapshot.errors,
			if snapshot.state.valid == nil then absent else snapshot.state.valid,
			snapshot.value,
			snapshot.initialValue,
		})
		return react.createElement(react.Fragment, nil, (children :: (any) -> any)(public))
	end
	local function Control(props: Props)
		local current = scope()
		return part("input", props, localState(current))
	end
	local function prepare(props: Props)
		local current: Scope? = react.useContext(context)
		local itemDisabled = react.useContext(itemContext) == true
		local token = react.useRef({})
		local owner = if current then current.owner else nil
		local out = props
		if owner and current then
			for _, name in { "minLength", "maxLength", "pattern", "min", "max", "step" } do
				assert(
					props[name] == nil or settings.constraints ~= nil,
					`Field {name} requires a native constraint provider`
				)
			end
			assert(props.required == nil or type(props.required) == "boolean", "Field control required must be boolean")
			out = table.clone(props)
			out.id = props.id or owner.id .. "-control"
			out.name = current.props.name or props.name
			out.disabled = current.props.disabled == true or itemDisabled or props.disabled == true
			out["aria-invalid"] = if current.snapshot.state.valid == false then true else nil
			out["aria-labelledby"] = owner.labelId
			local ids = {}
			for _, message in owner.messages do
				table.insert(ids, message.id)
			end
			out["aria-describedby"] = if #ids > 0 then table.concat(ids, " ") else nil
		end
		react.useLayoutEffect(function()
			if not owner then
				return nil
			end
			local boundOwner: Owner = owner
			assert(
				owner.token == nil or owner.token == token.current,
				"Multiple field controls require a group adapter"
			)
			owner.token, owner.control, owner.controlId = token.current, out, out.id
			owner.model.reset(out.value or out.defaultValue or "")
			configure(owner, current and current.props, current and current.runner)
			owner.refresh()
			return function()
				if boundOwner.token == token.current then
					boundOwner.token, boundOwner.control = nil, nil
					boundOwner.controlId = boundOwner.id .. "-control"
					if boundOwner.model.getSnapshot() then
						boundOwner.model.reset("")
						boundOwner.refresh()
					end
				end
			end
		end, { owner or absent, token.current })
		local function observe(state: { focused: boolean }, accepted: string)
			react.useLayoutEffect(function()
				if owner and current then
					owner.control = out
					if owner.controlId ~= out.id then
						owner.controlId = out.id
						owner.refresh()
					end
					-- Child layout effects run before their provider's layout effect.
					-- Read this committed context, not the previous root's options.
					configure(owner, current.props, current.runner)
					owner.model.setValue(accepted)
					owner.model.setFocused(state.focused)
				end
				return nil
			end)
		end
		return {
			props = out,
			observe = observe,
			connected = owner ~= nil,
			valid = if current then current.snapshot.state.valid else nil,
		}
	end
	return {
		parts = {
			Root = Root,
			Item = Item,
			Label = Label,
			Description = Description,
			Error = Error,
			Control = Control,
			Validity = Validity,
		},
		control = { prepare = prepare },
	}
end

return Field
