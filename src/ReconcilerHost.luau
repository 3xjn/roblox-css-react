--!strict

local Css = require(script.Parent.Runtime)
local Tree = require(script.Parent.Tree)
local Target = require(script.Parent.Target)
local StyleObjects = require(script.Parent.StyleObjects)
local LabelAssociation = require(script.Parent.LabelAssociation)
local SourceElements = require(script.Parent.SourceElements)

export type Props = {
	[string]: unknown,
	nativeControl: ("auto" | "button")?,
	labelable: boolean?,
	id: string?,
	className: string?,
	attributes: { [string]: string }?,
	states: { [string]: boolean }?,
	text: string?,
	inlineStyle: Css.InlineStyle?,
	style: StyleObjects.Style?,
	children: unknown,
	bindTarget: Target.Binder?,
}
export type Container = {
	kind: "root",
	children: { Node },
	elements: { Tree.Element },
	controller: Tree.Controller,
	nextId: number,
	closed: boolean,
	releasing: boolean,
	committing: boolean,
	dirty: boolean,
	bindings: { [number]: { bind: Target.Binder, dispose: () -> () } },
	onDiagnostic: ((string) -> ())?,
}
export type Node = {
	kind: "element" | "text",
	key: number,
	owner: Container,
	parent: (Container | Node)?,
	children: { Node },
	props: Css.NodeOptions,
	value: string?,
	bindTarget: Target.Binder?,
	labelable: boolean,
}
type Parent = Container | Node
type Update = { props: Css.NodeOptions, bindTarget: Target.Binder?, labelable: boolean }

local Host = {}
local allowed: { [string]: boolean } = {
	nativeControl = true,
	labelable = true,
	id = true,
	className = true,
	attributes = true,
	states = true,
	text = true,
	children = true,
	bindTarget = true,
	inlineStyle = true,
	style = true,
}
allowed[SourceElements.property] = true
local function validate(props: Props)
	for name in props do
		assert(allowed[name], `CSS renderer host prop needs an adapter: {tostring(name)}`)
	end
	assert(props.bindTarget == nil or type(props.bindTarget) == "function", "bindTarget must be a function")
	assert(props.labelable == nil or type(props.labelable) == "boolean", "labelable must be boolean")
	assert(
		props.nativeControl == nil or props.nativeControl == "auto" or props.nativeControl == "button",
		"Unknown native control"
	)
	assert(props.style == nil or props.inlineStyle == nil, "Use style or inlineStyle on one host, not both")
	if type(props.children) == "string" or type(props.children) == "number" then
		assert(props.text == nil, "CSS renderer cannot combine text prop and text children")
	end
end

local function content(props: Props): string
	local text = props.text or ""
	if type(props.children) == "string" or type(props.children) == "number" then
		text = tostring(props.children)
	end
	return text
end

local function snapshot(tag: string, props: Props): Css.NodeOptions
	validate(props)
	local inlineStyle = if props.style then StyleObjects.toInline(props.style) else props.inlineStyle
	return {
		tag = tag,
		nativeControl = props.nativeControl or "auto",
		id = props.id,
		className = props.className or "",
		attributes = table.clone(props.attributes or {}),
		states = table.clone(props.states or {}),
		text = content(props),
		inlineStyle = if inlineStyle then Css.InlineStyle.copy(inlineStyle) else nil,
	}
end

local function sameMap<T>(a: { [string]: T }?, b: { [string]: T }?): boolean
	if a then
		for name, value in a do
			if not b or b[name] ~= value then
				return false
			end
		end
	end
	if b then
		for name in b do
			if not a or a[name] == nil then
				return false
			end
		end
	end
	return true
end

local function prepareUpdate(node: Node, tag: string, props: Props): Update?
	validate(props)
	local previous = node.props
	-- Inline packets still pass through the owning validator/copy. The common
	-- class-only path compares the owned scalar/map snapshot without allocating
	-- a second snapshot for every unchanged host on an application render.
	local nextProps = if props.style or props.inlineStyle or previous.inlineStyle then snapshot(tag, props) else nil
	if
		previous.tag == tag
		and previous.nativeControl == (props.nativeControl or "auto")
		and previous.id == props.id
		and previous.className == (props.className or "")
		and previous.text == content(props)
		and node.bindTarget == props.bindTarget
		and node.labelable == (props.labelable == true)
		and sameMap(previous.attributes, props.attributes)
		and sameMap(previous.states, props.states)
		and (not nextProps or Css.InlineStyle.equal(previous.inlineStyle, nextProps.inlineStyle))
	then
		return nil
	end
	return {
		props = nextProps or snapshot(tag, props),
		bindTarget = props.bindTarget,
		labelable = props.labelable == true,
	}
end

local function owner(parent: Parent): Container
	return if parent.kind == "root" then parent else parent.owner
end

local function detach(child: Node)
	local parent = child.parent
	if parent then
		local index = table.find(parent.children, child)
		assert(index, "CSS renderer child is missing from its parent")
		table.remove(parent.children, index)
		child.parent = nil
		owner(parent).dirty = true
	end
end

local function insert(parent: Parent, child: Node, before: Node?)
	local root = owner(parent)
	assert(not root.closed, "CSS renderer root is closed")
	assert(parent.kind ~= "text", "CSS text nodes cannot contain children")
	assert(child.owner == root, "Cross-root CSS mutations require portal support")
	local ancestor: Parent? = parent
	while ancestor do
		assert(ancestor ~= child, "CSS renderer parent cycle")
		ancestor = if ancestor.kind == "root" then nil else ancestor.parent
	end
	if before == child then
		return
	end
	if before then
		assert(before.parent == parent, "CSS insertion anchor belongs to another parent")
	end
	detach(child)
	local index = if before then table.find(parent.children, before) else #parent.children + 1
	table.insert(parent.children, assert(index), child)
	child.parent = parent
	root.dirty = true
end

local function describe(nodes: { Node }, bindings: { [number]: Target.Binder }): ({ Tree.Element }, boolean)
	local result = {}
	local hasLabels = false
	for _, node in nodes do
		assert(node.kind == "element", "CSS renderer document roots must be elements")
		local props = table.clone(node.props)
		if node.bindTarget then
			bindings[node.key] = node.bindTarget
			hasLabels = hasLabels or props.tag == "label"
		end
		local text: { string } = {}
		local textAfter: { [number]: string }? = nil
		local elements: { Node } = {}
		for _, child in node.children do
			if child.kind == "text" then
				if #elements == 0 then
					table.insert(text, child.value or "")
				else
					textAfter = textAfter or {}
					textAfter[#elements] = (textAfter[#elements] or "") .. (child.value or "")
				end
			else
				table.insert(elements, child)
			end
		end
		-- Text segments retain their positions without becoming selector siblings.
		props.textAfter = textAfter
		if #text > 0 then
			assert(props.text == nil or props.text == "", "CSS text children conflict with leading text")
			props.text = table.concat(text)
		end
		local children, childLabels = describe(elements, bindings)
		hasLabels = hasLabels or childLabels
		table.insert(
			result,
			{ key = node.key, props = props, children = children, labelable = if node.labelable then true else nil }
		)
	end
	return result, hasLabels
end

function Host.createContainer(host: Css.Host, onDiagnostic: ((string) -> ())?): Container
	return {
		kind = "root",
		children = {},
		elements = {},
		controller = Tree.create(host),
		nextId = 0,
		closed = false,
		releasing = false,
		committing = false,
		dirty = true,
		bindings = {},
		onDiagnostic = onDiagnostic,
	}
end

local function releaseBindings(container: Container, desired: { [number]: Target.Binder }): { string }
	local failures = {}
	for key, binding in table.clone(container.bindings) do
		local nextBind = desired[key]
		if nextBind and nextBind ~= binding.bind and Target.update(binding.bind, nextBind) then
			continue
		end
		if nextBind ~= binding.bind then
			container.bindings[key] = nil
			local ok, failure = pcall(binding.dispose)
			if not ok then
				table.insert(failures, tostring(failure))
			end
		end
	end
	return failures
end

function Host.commit(container: Container): (boolean, string?)
	assert(not container.closed, "CSS renderer root is closed")
	-- React still removes its logical children/effects during disposal. Native
	-- resources are released after those effects, without painting an empty scene
	-- into a host which may already have been destroyed externally.
	if container.releasing then
		return true, nil
	end
	assert(not container.committing, "Reentrant CSS renderer commit")
	if not container.dirty then
		return true, nil
	end
	container.committing = true
	-- Binding callbacks can schedule another render. Clear before doing work so
	-- a mutation made during this commit remains dirty for its own commit.
	container.dirty = false
	local desired: { [number]: Target.Binder } = {}
	local ok, result, hasLabels = pcall(describe, container.children, desired)
	if ok then
		local elements = result :: { Tree.Element }
		ok, result = pcall(function()
			local failures = releaseBindings(container, desired)
			assert(#failures == 0, table.concat(failures, "; "))
			container.controller.commit(elements)
			-- Unrelated roots retain no association snapshot. Label roots reuse the
			-- description already prepared for this commit, without another walk.
			container.elements = if hasLabels then elements else {}
			local host = assert(container.controller.getHost())
			for key in desired do
				if not container.bindings[key] then
					local node = container.controller.getNode(key)
					if node and not host:getGuiObject(node) then
						host:flushSync()
						break
					end
				end
			end
			for key, bind in desired do
				if not container.bindings[key] and not container.closed and not container.releasing then
					local binding = { bind = bind, dispose = function() end }
					container.bindings[key] = binding
					local node = assert(container.controller.getNode(key))
					local context: Target.Context = {
						getNode = function()
							return if container.closed or container.releasing then nil else node
						end,
						getNodeTarget = function(candidate)
							return if container.closed or container.releasing then nil else host:getGuiObject(candidate)
						end,
						resolveLabelControl = function()
							return nil
						end,
						getComputedStyle = function()
							return if container.closed or container.releasing then nil else host:getComputedStyle(node)
						end,
						getLayoutBox = function()
							return if container.closed or container.releasing then nil else host:getLayoutBox(node)
						end,
						ensureLayout = function()
							if container.closed or container.releasing then return false, "CSS target is detached" end
							return host:flushSync()
						end,
						getInlinePropertyNames = function()
							assert(not container.closed and not container.releasing, "CSS target is detached")
							return Css.InlineStyle.mutableProperties
						end,
						getInlineProperty = function(name)
							assert(not container.closed and not container.releasing, "CSS target is detached")
							return host:getInlineProperty(node, name)
						end,
						setInlineProperty = function(name, value, priority)
							assert(not container.closed and not container.releasing, "CSS target is detached")
							host:setInlineProperty(node, name, value, priority)
						end,
						getResolvedProperty = function(name)
							if container.closed or container.releasing then
								return nil, "CSS target is detached"
							end
							return host:getResolvedProperty(node, name)
						end,
						getResolvedPropertyNames = function()
							assert(not container.closed and not container.releasing, "CSS target is detached")
							return Css.resolvedPropertyNames
						end,
						setAttribute = function(name, value)
							assert(not container.closed and not container.releasing, "CSS target is detached")
							host:setAttribute(node, name, value)
						end,
						setState = function(name, active)
							if not container.closed and not container.releasing then host:setState(node, name, active) end
						end,
						getPlaybacks = function(subtree)
							return if container.closed or container.releasing
								then {}
								else host:getPlaybacks(node, subtree)
						end,
						getAttributes = function()
							return if container.closed or container.releasing then {} else table.clone(node.attributes)
						end,
						subscribeScene = function(listener)
							return host:subscribeScene(listener)
						end,
					}
					if node.tag == "label" then
						context.resolveLabelControl = function(): GuiObject?
							if container.closed or container.releasing then
								return nil
							end
							local selected = LabelAssociation.resolve(container.elements, key)
							local control = if selected then container.controller.getNode(selected) else nil
							return if control then host:getGuiObject(control) else nil
						end
					end
					local dispose = Target.watchWithContext(host, node, bind, context)
					if container.closed or container.bindings[key] ~= binding then
						dispose()
					else
						binding.dispose = dispose
					end
				end
			end
		end)
	end
	container.committing = false
	if not ok then
		container.dirty = true
		local reason = tostring(result)
		if container.onDiagnostic then
			container.onDiagnostic(reason)
		else
			warn(reason)
		end
		return false, reason
	end
	return true, nil
end

function Host.destroy(container: Container)
	if container.closed then
		return
	end
	container.closed = true
	local failures = releaseBindings(container, {})
	local ok, failure = pcall(container.controller.destroy)
	table.clear(container.children)
	container.elements = {}
	if not ok then
		table.insert(failures, tostring(failure))
	end
	assert(#failures == 0, table.concat(failures, "; "))
end

-- Configuration is the untyped boundary expected by React Luau's initializer.
-- Configure only an independently provisioned reconciler instance.
function Host.createConfig(): { [string]: any }
	local function create(tag: string?, props: Props?, container: Container, text: string?): Node
		assert(not container.closed, "CSS renderer root is closed")
		container.nextId += 1
		assert(container.nextId < 2 ^ 53, "CSS renderer identity space exhausted")
		return {
			kind = if tag then "element" else "text",
			key = container.nextId,
			owner = container,
			parent = nil,
			children = {},
			props = if tag and props then snapshot(tag, props) else {},
			value = text,
			bindTarget = if props then props.bindTarget else nil,
			labelable = props ~= nil and props.labelable == true,
		}
	end
	local function remove(parent: Parent, child: Node)
		assert(child.parent == parent, "CSS removal parent mismatch")
		detach(child)
	end
	local config: { [string]: any } = {
		isPrimaryRenderer = false,
		warnsIfNotActing = true,
		supportsMutation = true,
		supportsPersistence = false,
		supportsHydration = false,
		noTimeout = -1,
		scheduleTimeout = function(callback: () -> (), milliseconds: number)
			return task.delay(milliseconds / 1000, callback)
		end,
		cancelTimeout = function(handle: thread)
			task.cancel(handle)
		end,
		getRootHostContext = function()
			return {}
		end,
		getChildHostContext = function(context: {})
			return context
		end,
		getPublicInstance = function(node: Node)
			return node
		end,
		prepareForCommit = function()
			return nil
		end,
		resetAfterCommit = function(container: Container)
			Host.commit(container)
		end,
		beforeActiveInstanceBlur = function() end,
		afterActiveInstanceBlur = function() end,
		createInstance = function(tag: string, props: Props, container: Container)
			return create(tag, props, container, nil)
		end,
		createTextInstance = function(text: string, container: Container)
			return create(nil, nil, container, text)
		end,
		appendInitialChild = insert,
		appendChild = insert,
		appendChildToContainer = insert,
		insertBefore = insert,
		insertInContainerBefore = insert,
		removeChild = remove,
		removeChildFromContainer = remove,
		finalizeInitialChildren = function()
			return false
		end,
		prepareUpdate = function(node: Node, tag: string, _old: Props, props: Props)
			return prepareUpdate(node, tag, props)
		end,
		commitMount = function() end,
		commitUpdate = function(node: Node, payload: Update)
			node.props = payload.props
			node.bindTarget = payload.bindTarget
			node.labelable = payload.labelable
			node.owner.dirty = true
		end,
		shouldSetTextContent = function(_tag: string, props: Props)
			return type(props.children) == "string" or type(props.children) == "number"
		end,
		resetTextContent = function(node: Node)
			node.props.text = ""
			node.owner.dirty = true
		end,
		commitTextUpdate = function(node: Node, _old: string, text: string)
			node.value = text
			node.owner.dirty = true
		end,
		clearContainer = function(container: Container)
			if #container.children > 0 then
				container.dirty = true
			end
			for _, child in container.children do
				child.parent = nil
			end
			table.clear(container.children)
			return false
		end,
	}
	for _, name in
		{
			"preparePortalMount",
			"hideInstance",
			"hideTextInstance",
			"unhideInstance",
			"unhideTextInstance",
			"cloneInstance",
			"createContainerChildSet",
			"appendChildToContainerChildSet",
			"finalizeContainerChildren",
			"replaceContainerChildren",
			"cloneHiddenInstance",
			"cloneHiddenTextInstance",
		}
	do
		config[name] = function()
			error(`CSS reconciler capability is not implemented: {name}`, 0)
		end
	end
	return config
end

return Host
