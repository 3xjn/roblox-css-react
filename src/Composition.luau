--!strict
-- Prop composition follows Base UI 1.9.0. See ../LICENSE.base-ui.

local Html = require(script.Parent.Html)
local StyleObjects = require(script.Parent.StyleObjects)
type Props = Html.Props
type Input = Props | ((Props) -> Props)
type React = Html.React & {
	read cloneElement: Html.Factory,
	read isValidElement: (any) -> boolean,
}

local Composition = {}
local empty: Props = table.freeze({} :: Props)

local function record(value: any): Props
	assert(type(value) == "table", "Prop composition requires a record")
	for name in next, value do
		assert(type(name) == "string", "Prop names must be strings")
	end
	return value
end

local function event(name: string, value: any): boolean
	local third = string.byte(name, 3)
	return name:sub(1, 2) == "on" and third ~= nil and third >= 65 and third <= 90 and type(value) == "function"
end

local function chain(previous: any, incoming: (...any) -> any): (...any) -> any
	assert(previous == nil or type(previous) == "function", "Event handlers must be functions")
	if previous == nil then
		return incoming
	end
	local callback = previous :: (...any) -> any
	return function(...: any): any
		-- Native InputObjects/custom values have no DOM synthetic-event contract.
		local result = incoming(...)
		callback(...)
		return result
	end
end

local function classes(previous: any, incoming: any): any
	assert(previous == nil or type(previous) == "string", "Merged className requires strings")
	assert(incoming == nil or type(incoming) == "string", "Merged className requires strings")
	if incoming == nil or incoming == "" then
		return previous
	end
	return if previous ~= nil and previous ~= "" then incoming .. " " .. previous else incoming
end

local function mergeInto(merged: Props, input: Input?): Props
	if input == nil then
		return merged
	end
	if type(input) == "function" then
		-- A getter owns the entire result; it explicitly chains its own handlers.
		return record(input(merged))
	end
	for name, value in next, record(input) do
		if name == "className" then
			merged[name] = classes(merged[name], value)
		elseif name == "style" then
			if StyleObjects.is(value) or StyleObjects.is(merged[name]) then
				merged[name] = StyleObjects.merge(merged[name], value)
			else
				local style = if merged[name] == nil then {} else table.clone(record(merged[name]))
				for property, setting in next, record(value) do
					style[property] = setting
				end
				merged[name] = style
			end
		elseif event(name, value) then
			merged[name] = chain(merged[name], value)
		else
			merged[name] = value
		end
	end
	return merged
end

local function copy(input: Props): Props
	local result = table.clone(input)
	setmetatable(result, nil)
	return result
end

function Composition.mergeProps(...: Input?): Props
	local count = select("#", ...)
	local first = if count > 0 then select(1, ...) else nil
	local merged: Props
	if type(first) == "function" then
		merged = copy(record(first(empty)))
	else
		merged = if first == nil then {} else copy(record(first))
	end
	for index = 2, count do
		merged = mergeInto(merged, select(index, ...))
	end
	return merged
end

local function truthy(value: any): boolean
	return value ~= nil
		and value ~= false
		and value ~= ""
		and value ~= 0
		and not (type(value) == "number" and value ~= value)
end

local function stateProps(state: Props, mapping: Props?): Props
	local result: Props = {}
	for name, value in next, state do
		local custom = if mapping then rawget(mapping, name) else nil
		if custom ~= nil then
			assert(type(custom) == "function", "State attribute mappings must be functions")
			local attributes = (custom :: (any) -> Props?)(value)
			if attributes ~= nil then
				for attribute, setting in next, record(attributes) do
					result[attribute] = setting
				end
			end
		elseif value == true then
			result["data-" .. name:lower()] = ""
		elseif truthy(value) then
			assert(
				type(value) == "string" or type(value) == "number",
				"State attributes require scalar values or a custom mapping"
			)
			result["data-" .. name:lower()] = tostring(value)
		end
	end
	return result
end

local options: { [string]: boolean } = {
	defaultTagName = true,
	props = true,
	render = true,
	state = true,
	stateAttributesMapping = true,
	enabled = true,
	className = true,
	style = true,
}

function Composition.create(react: React, element: Html.Factory?)
	local createElement = element or Html.create(react)
	local function useRender(settings: Props): any
		for name in next, record(settings) do
			assert(options[name], `Render option {name} needs a platform adapter`)
		end
		assert(settings.enabled == nil or type(settings.enabled) == "boolean", "Render enabled must be boolean")
		if settings.enabled == false then
			return nil
		end
		local state = if settings.state == nil then empty else record(settings.state)
		local props = settings.props
		local resolved: Props
		if type(props) == "table" and props[1] ~= nil then
			local count = #props
			for index in next, props do
				assert(
					type(index) == "number" and index % 1 == 0 and index >= 1 and index <= count,
					"Render prop lists must be dense"
				)
			end
			resolved = Composition.mergeProps(table.unpack(props, 1, count))
		else
			resolved = Composition.mergeProps(props)
		end
		local out = stateProps(
			state,
			if settings.stateAttributesMapping == nil then nil else record(settings.stateAttributesMapping)
		)
		for name, value in next, resolved do
			out[name :: string] = value
		end
		assert(out.ref == nil, "Render refs need a platform adapter")
		local className = settings.className
		if type(className) == "function" then
			className = (className :: (Props) -> any)(state)
		end
		if className ~= nil then
			out.className = classes(out.className, className)
		end
		local style = settings.style
		if type(style) == "function" then
			style = (style :: (Props) -> any)(state)
		end
		if style ~= nil then
			out = Composition.mergeProps(out, { style = style })
		end
		local render = settings.render
		if type(render) == "function" then
			return (render :: (Props, Props) -> any)(out, state)
		end
		if render ~= nil then
			assert(react.isValidElement(render), "Render requires a React element or callback")
			assert(render.ref == nil, "Render element refs need a platform adapter")
			local external = render.props
			if type(render.type) == "string" then
				assert(
					Html.isIntrinsic(render.type),
					`HTML element {render.type} needs a native behavior or rendering adapter`
				)
				-- Html has already converted intrinsic attributes for the CSS host.
				-- Flatten them before applying the raw HTML prop merge, then convert once.
				external = table.clone(record(external))
				local attributes = external.attributes
				external.attributes = nil
				if attributes then
					for name, value in next, record(attributes) do
						external[name] = value
					end
				end
				return react.cloneElement(render, Html.toHostProps(Composition.mergeProps(out, external)))
			end
			return react.cloneElement(render, Composition.mergeProps(out, external))
		end
		local tag = settings.defaultTagName or "div"
		assert(type(tag) == "string", "Default render tag must be a string")
		return createElement(tag, out)
	end
	return { useRender = useRender, mergeProps = Composition.mergeProps }
end

return Composition
