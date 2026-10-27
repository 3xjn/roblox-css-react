--!strict
-- Progress composition follows Base UI 1.9.0. See ../LICENSE.base-ui.
-- Formatting belongs to the application; this module supplies no browser Intl.

local Html = require(script.Parent.Html)
local Composition = require(script.Parent.Composition)
local StyleObjects = require(script.Parent.StyleObjects)

type Props = Html.Props
type Status = "indeterminate" | "progressing" | "complete"
type State = { status: Status }
type ContextValue = {
	state: State,
	value: number?,
	percentage: number?,
	formatted: string,
	setLabelId: (string? | ((string?) -> string?)) -> (),
}
type Context = { Provider: any }
type Reference<T> = { current: T }
export type React = Html.React & {
	read cloneElement: Html.Factory,
	read isValidElement: (any) -> boolean,
	read createContext: (ContextValue?) -> Context,
	read useContext: (Context) -> ContextValue?,
	read useRef: <T>(T) -> Reference<T>,
	read useMemo: <T>(() -> T, { any }) -> T,
	read useState: <T>(T) -> (T, (T | ((T) -> T)) -> ()),
	read useLayoutEffect: (() -> (() -> ())?, { any }?) -> (),
}
export type FormatNumber = (number, any, Props) -> string
export type Options = { formatNumber: FormatNumber? }

local Progress = {}
local absent = table.freeze({})
local percentFormat: Props = table.freeze({ style = "percent" } :: Props)
local mapping = {
	status = function(value: any): Props
		assert(value == "indeterminate" or value == "progressing" or value == "complete", "Unknown progress status")
		return { ["data-" .. value] = "" }
	end,
}

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function declaration(property: string, text: string, kind: string, value: string): StyleObjects.Entry
	return {
		name = property,
		declaration = {
			kind = "declaration",
			property = property,
			value = text,
			tokens = { { kind = kind, value = value } },
			important = false,
			validity = "valid",
		},
	}
end

local function indicatorStyle(percentage: number?): StyleObjects.Style
	if percentage == nil then
		return { kind = "style-object", entries = {} }
	end
	local number = if percentage == 0 then "0" else string.format("%.17g", percentage)
	return {
		kind = "style-object",
		entries = {
			declaration("inset-inline-start", "0", "number", "0"),
			declaration("height", "inherit", "word", "inherit"),
			declaration("width", number .. "%", "percentage", number),
		},
	}
end

function Progress.create(react: React, element: Html.Factory?, options: Options?)
	local render = Composition.create(react, element).useRender
	local context = react.createContext(nil)
	local formatter = if options then options.formatNumber else nil
	local function owner(): ContextValue
		return assert(react.useContext(context), "Progress parts require a Progress root")
	end
	local function part(tag: string, props: Props, state: State, defaults: Props?): any
		return render({
			defaultTagName = tag,
			state = state,
			stateAttributesMapping = mapping,
			props = { defaults or {}, Html.rest(props, { "className", "style", "render" }) },
			className = props.className,
			style = props.style,
			render = props.render,
		})
	end
	local function Root(props: Props)
		local minimum = if props.min == nil then 0 else props.min
		local maximum = if props.max == nil then 100 else props.max
		local value = props.value
		local format: Props? = props.format
		local getAriaValueText: ((string, number?) -> string)? = props.getAriaValueText
		assert(format == nil or type(format) == "table", "Progress format options need a record")
		assert(type(minimum) == "number" and finite(minimum), "Progress min must be finite")
		assert(type(maximum) == "number" and finite(maximum), "Progress max must be finite")
		assert(value == nil or type(value) == "number", "Progress value must be numeric or indeterminate")
		assert(getAriaValueText == nil or type(getAriaValueText) == "function", "Progress value text needs a function")
		local status: Status = "indeterminate"
		local percentage, clamped: number? = nil, nil
		local formatted = ""
		if value ~= nil and finite(value) then
			local ratio = ((value - minimum) * 100) / (maximum - minimum)
			percentage = math.min(math.max(if ratio == ratio then ratio else 0, 0), 100)
			clamped = math.max(minimum, math.min(value, maximum))
			status = if clamped == maximum then "complete" else "progressing"
			assert(type(formatter) == "function", "Progress requires an application number-format provider")
			formatted = if format ~= nil
				then formatter(clamped, props.locale, format)
				else formatter(percentage / 100, props.locale, percentFormat)
			assert(type(formatted) == "string", "Progress number-format provider must return a string")
		end
		local state = react.useMemo(function(): State
			return { status = status }
		end, { status })
		local labelId, setLabelId = react.useState(nil :: string?)
		local contents = react.useMemo(function(): ContextValue
			return {
				state = state,
				value = value,
				percentage = percentage,
				formatted = formatted,
				setLabelId = setLabelId,
			}
		end, { state, value or absent, percentage or absent, formatted, setLabelId })
		local attributes: Props = {
			["aria-labelledby"] = labelId,
			["aria-valuemax"] = maximum,
			["aria-valuemin"] = minimum,
			["aria-valuenow"] = clamped,
			["aria-valuetext"] = if getAriaValueText
				then getAriaValueText(formatted, value)
				else (if status == "indeterminate" then "indeterminate progress" else formatted),
			role = "progressbar",
		}
		local rest = Html.rest(props, { "value", "min", "max", "format", "locale", "getAriaValueText" })
		return react.createElement(context.Provider, { value = contents }, part("div", rest, state, attributes))
	end
	local function Track(props: Props)
		return part("div", props, owner().state)
	end
	local function Indicator(props: Props)
		local current = owner()
		return part("div", props, current.state, { style = indicatorStyle(current.percentage) })
	end
	local function Label(props: Props)
		local current = owner()
		assert(props.id == nil or type(props.id) == "string", "Progress label id must be a string")
		local generated = react.useRef(nil :: string?)
		if props.id == nil and generated.current == nil then
			generated.current = "css-progress-label-" .. game:GetService("HttpService"):GenerateGUID(false)
		end
		local id = props.id or generated.current
		local setter = current.setLabelId
		react.useLayoutEffect(function()
			setter(id)
			return function()
				setter(function(previous: string?): string?
					return if previous == id then nil else previous
				end)
			end
		end, { id, setter })
		return part("span", props, current.state, { id = id, role = "presentation" })
	end
	local function Value(props: Props)
		local current = owner()
		local children = props.children
		local content = if type(children) == "function"
			then (children :: (string, number?) -> any)(
				if current.state.status == "indeterminate" then "indeterminate" else current.formatted,
				current.value
			)
			else (if current.state.status == "indeterminate" then nil else current.formatted)
		return part(
			"span",
			Html.rest(props, { "children" }),
			current.state,
			{ ["aria-hidden"] = true, children = content }
		)
	end
	return { Root = Root, Track = Track, Indicator = Indicator, Label = Label, Value = Value }
end

return Progress
