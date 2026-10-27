--!strict
-- Native group composition follows Base UI 1.9.0. See ../LICENSE.base-ui.
-- The existing checkbox/button binding owns input; this module owns no views.
local Html = require(script.Parent.Html)
local Composition = require(script.Parent.Composition)
local ValueState = require(script.Parent.ValueState)
local Checkbox = require(script.Parent.Checkbox)

type Props = Html.Props
export type React = Html.React & ValueState.React & {
	read cloneElement: Html.Factory,
	read isValidElement: (any) -> boolean,
	read createContext: (any) -> { Provider: any },
	read useContext: (any) -> any,
}
type Member = { token: any, value: string, id: string, disabled: boolean }
type Owner = {
	getValue: () -> { string },
	requestValue: ({ string }, any) -> boolean,
	props: Props,
	initialSubset: { string },
	status: string,
	members: { [any]: Member },
	refresh: () -> (),
	mounted: boolean,
	registryChanged: boolean,
}
type Scope = { owner: Owner, value: { string }, disabled: boolean, allValues: { string }? }

local CheckboxGroup = {}
local absent = {}
local function values(value: any): { string }
	assert(type(value) == "table", "Selection values must be an array of strings")
	local length, count = #value, 0
	for index, item in value do
		assert(
			type(index) == "number" and index >= 1 and index <= length and index % 1 == 0 and type(item) == "string",
			"Selection values must be a dense array of strings"
		)
		count += 1
	end
	assert(count == length, "Selection values must be a dense array of strings")
	return table.clone(value)
end

local function selected(value: { string }, key: string): boolean
	return table.find(value, key) ~= nil
end

local function childRequest(owner: Owner, key: string, checked: boolean, details: any)
	local value = owner.getValue()
	if checked then
		table.insert(value, key)
	else
		local index = table.find(value, key)
		if index then
			table.remove(value, index)
		end
	end
	if owner.requestValue(value, details) then
		owner.initialSubset, owner.status = table.clone(value), "mixed"
	end
end

local function parentRequest(owner: Owner, allValues: { string }, details: any)
	local disabled: { [string]: boolean } = {}
	for _, member in owner.members do
		if disabled[member.value] == nil then
			disabled[member.value] = true
		end
		if not member.disabled then
			disabled[member.value] = false
		end
	end
	local all, none = {}, {}
	for _, key in allValues do
		local wasChecked = selected(owner.initialSubset, key)
		if disabled[key] and wasChecked then
			table.insert(none, key)
		end
		if not disabled[key] or wasChecked then
			table.insert(all, key)
		end
	end
	if #owner.initialSubset == #all or #owner.initialSubset == 0 then
		owner.requestValue(if #owner.getValue() == #all then none else all, details)
		return
	end
	local nextStatus, proposal = "mixed", owner.initialSubset
	if owner.status == "mixed" then
		nextStatus, proposal = "on", all
	elseif owner.status == "on" then
		nextStatus, proposal = "off", none
	end
	if owner.requestValue(proposal, details) then
		owner.status = nextStatus
	end
end

function CheckboxGroup.create(react: React, element: Html.Factory?)
	local render = Composition.create(react, element or Html.create(react)).useRender
	local context = react.createContext(nil)
	local useValue = ValueState.create(react, "CheckboxGroup", values)
	local function Root(props: Props)
		assert(props.disabled == nil or type(props.disabled) == "boolean", "CheckboxGroup disabled must be boolean")
		assert(
			props.onValueChange == nil or type(props.onValueChange) == "function",
			"CheckboxGroup change needs a function"
		)
		for _, name in { "name", "form", "required", "validate", "actionsRef" } do
			assert(props[name] == nil, `CheckboxGroup {name} needs a field/form adapter`)
		end
		local value, request, current = useValue({
			value = props.value,
			defaultValue = if props.defaultValue ~= nil then props.defaultValue else {},
			onChange = props.onValueChange,
		})
		local allValues = if props.allValues ~= nil then values(props.allValues) else nil
		local ownerRef = react.useRef(nil :: Owner?)
		local _, refresh = react.useState(0)
		if not ownerRef.current then
			local created = {} :: Owner
			created = {
				getValue = current,
				requestValue = request,
				props = props,
				initialSubset = table.clone(value),
				status = "mixed",
				members = {},
				mounted = false,
				registryChanged = false,
				refresh = function()
					if created.mounted then
						refresh(function(previous: number)
							return previous + 1
						end)
					else
						created.registryChanged = true
					end
				end,
			}
			ownerRef.current = created
		end
		local owner = assert(ownerRef.current)
		react.useLayoutEffect(function()
			owner.mounted = true
			if owner.registryChanged then
				owner.registryChanged = false
				owner.refresh()
			end
			return function()
				owner.mounted = false
			end
		end, {})
		react.useLayoutEffect(function()
			owner.props = props
			return nil
		end)
		local state =
			{ disabled = props.disabled == true, touched = false, dirty = false, filled = false, focused = false }
		local content = render({
			defaultTagName = "div",
			state = state,
			props = {
				{ role = "group" },
				Html.rest(props, {
					"value",
					"defaultValue",
					"onValueChange",
					"allValues",
					"disabled",
					"className",
					"style",
					"render",
				}),
			},
			className = props.className,
			style = props.style,
			render = props.render,
		})
		return react.createElement(
			context.Provider,
			{ value = { owner = owner, value = value, disabled = state.disabled, allValues = allValues } },
			content
		)
	end
	local function prepare(props: Props): Checkbox.Preparation
		local current: Scope? = react.useContext(context)
		assert(props.disabled == nil or type(props.disabled) == "boolean", "Checkbox disabled must be boolean")
		assert(
			props.onCheckedChange == nil or type(props.onCheckedChange) == "function",
			"Checkbox change needs a function"
		)
		local reference = react.useRef(nil :: { token: any, id: string }?)
		if current and not reference.current then
			reference.current =
				{ token = {}, id = "css-checkbox-" .. game:GetService("HttpService"):GenerateGUID(false) }
		end
		local key: string? = props.value
		assert(key == nil or type(key) == "string", "Checkbox group values must be strings")
		assert(props.parent == nil or type(props.parent) == "boolean", "Checkbox parent must be boolean")
		local parent = props.parent == true
		local owner = current and current.owner
		local disabled = props.disabled == true or (current ~= nil and current.disabled)
		assert(props.id == nil or type(props.id) == "string", "Checkbox id must be a string")
		local id: string = props.id or (reference.current and reference.current.id) or ""
		local token = if reference.current then reference.current.token else absent
		local tracksParent = current ~= nil and current.allValues ~= nil
		react.useLayoutEffect(function(): (() -> ())?
			if not owner or key == nil or parent or not tracksParent then
				return nil
			end
			local currentOwner = owner
			currentOwner.members[token] = { token = token, value = assert(key), id = id, disabled = disabled }
			currentOwner.refresh()
			return function()
				currentOwner.members[token] = nil
				currentOwner.refresh()
			end
		end, { owner or absent, key or absent, parent, disabled, id, tracksParent })
		if not current then
			assert(not parent, "Parent checkbox requires a CheckboxGroup with allValues")
			return { props = if props.parent == false then Html.rest(props, { "parent" }) else props }
		end
		local out = table.clone(props)
		out.disabled, out.value, out.parent = disabled, nil, nil
		if key == nil and not parent then
			return { props = out }
		end
		local group = current
		local groupOwner = assert(owner)
		if parent then
			local all = assert(group.allValues, "Parent checkbox requires allValues")
			out.checked = #group.value == #all
			out.indeterminate = (#group.value ~= #all and #group.value > 0) or props.indeterminate == true
			out["data-parent"] = ""
			local ids = {}
			for _, value in all do
				local matching = {}
				for _, member in groupOwner.members do
					if member.value == value then
						table.insert(matching, member.id)
					end
				end
				table.sort(matching)
				for _, childId in matching do
					table.insert(ids, childId)
				end
			end
			out["aria-controls"] = if #ids > 0 then table.concat(ids, " ") else nil
		else
			out.checked = selected(group.value, assert(key))
			out.id = id
		end
		out.onCheckedChange = function(checked: boolean, details: any)
			if props.onCheckedChange then
				(props.onCheckedChange :: any)(checked, details)
			end
			if details.isCanceled or groupOwner.props.disabled then
				return
			end
			if parent then
				parentRequest(groupOwner, values(assert(groupOwner.props.allValues)), details)
			else
				childRequest(groupOwner, assert(key), checked, details)
			end
		end
		return {
			props = out,
			getChecked = function()
				if parent then
					return #groupOwner.getValue() == #values(assert(groupOwner.props.allValues))
				end
				return selected(groupOwner.getValue(), assert(key))
			end,
		}
	end
	return { Root = Root, control = { prepare = prepare } }
end

return CheckboxGroup
