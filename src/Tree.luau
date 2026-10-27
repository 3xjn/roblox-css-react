--!strict

local Css = require(script.Parent.Runtime)
local TextSegments = Css.TextSegments

export type Key = string | number
export type NodeOptions = Css.NodeOptions
-- Adapter-owned form-control semantics. This metadata does not become a CSS
-- property or alter the source tag/native representation.
export type Element = { key: Key, props: NodeOptions?, children: { Element }?, labelable: boolean? }
type Entry = { key: Key, props: NodeOptions, parent: Key?, children: { Key } }
type Record = { node: Css.Node, parent: Key?, props: NodeOptions }

local Tree = {}

local function arrayLength(elements: { Element }): number
	assert(type(elements) == "table", "CSS children must be an ordered array")
	local length = #elements
	local count = 0
	for index in elements do
		assert(
			type(index) == "number" and index >= 1 and index <= length and index % 1 == 0,
			"CSS children must be a dense ordered array"
		)
		count += 1
	end
	assert(count == length, "CSS children must be a dense ordered array")
	return length
end

local function prepare(elements: { Element }): ({ Entry }, { Key })
	local entries: { Entry } = {}
	local seen: { [Key]: boolean } = {}
	local active: { [Element]: boolean } = {}
	local function visit(children: { Element }, parent: Key?): { Key }
		local keys: { Key } = {}
		for index = 1, arrayLength(children) do
			local element = children[index]
			assert(not active[element], "CSS element tree contains a cycle")
			local key = element.key
			assert(
				type(key) == "string" or (type(key) == "number" and key == key and math.abs(key) < math.huge),
				"Invalid CSS element key"
			)
			assert(not seen[key], "CSS element keys must be unique across this surface")
			seen[key] = true
			active[element] = true
			local props: NodeOptions = element.props or {}
			local textAfter = TextSegments.copy(props.textAfter)
			if textAfter then
				assert(
					not TextSegments.validate(textAfter, if element.children then arrayLength(element.children) else 0),
					"Text segment has no element anchor"
				)
			end
			assert(
				props.nativeControl == nil or props.nativeControl == "auto" or props.nativeControl == "button",
				"Unknown native control"
			)
			local entry: Entry = {
				key = key,
				parent = parent,
				children = {},
				props = {
					tag = props.tag or "div",
					nativeControl = props.nativeControl or "auto",
					id = props.id,
					className = props.className or "",
					text = props.text or "",
					textAfter = textAfter,
					attributes = table.clone(props.attributes or {}),
					states = table.clone(props.states or {}),
					inlineStyle = if props.inlineStyle then Css.InlineStyle.copy(props.inlineStyle) else nil,
				},
			}
			table.insert(entries, entry)
			table.insert(keys, key)
			entry.children = visit(element.children or {}, key)
			active[element] = nil
		end
		return keys
	end
	local roots = visit(elements, nil)
	return entries, roots
end

local function sameMap<T>(a: { [string]: T }?, b: { [string]: T }?): boolean
	for key, value in a or {} do
		if not b or b[key] ~= value then
			return false
		end
	end
	for key in b or {} do
		if not a or a[key] == nil then
			return false
		end
	end
	return true
end

local function sameProps(a: NodeOptions, b: NodeOptions): boolean
	return a.tag == b.tag
		and a.nativeControl == b.nativeControl
		and a.id == b.id
		and a.className == b.className
		and a.text == b.text
		and TextSegments.same(a.textAfter, b.textAfter)
		and sameMap(a.attributes, b.attributes)
		and sameMap(a.states, b.states)
		and (a.inlineStyle == b.inlineStyle or Css.InlineStyle.equal(a.inlineStyle, b.inlineStyle))
end

-- Exclusive ownership of this host transfers to the controller. Validation and
-- snapshotting happen before writes; unexpected host errors are not rolled back.
function Tree.create(host: Css.Host)
	local records: { [Key]: Record } = {}
	local destroyed = false
	local committing = false
	local controller = {}
	local function release()
		if destroyed then
			return
		end
		destroyed = true
		table.clear(records)
		host:destroy()
	end
	local function apply(entries: { Entry }, roots: { Key })
		local desired: { [Key]: boolean } = {}
		for _, entry in entries do
			desired[entry.key] = true
			local previous = records[entry.key]
			-- Detach moved nodes first: an old ancestor can become a descendant.
			-- Retained children also survive deletion of their old parents.
			if previous and previous.parent ~= entry.parent then
				host:reparent(previous.node, nil)
			end
		end
		for _, entry in entries do
			local parent = if entry.parent ~= nil then records[entry.parent].node else nil
			local previous = records[entry.key]
			if not previous then
				records[entry.key] =
					{ node = host:add(entry.props, parent), parent = entry.parent, props = entry.props }
			else
				if previous.parent ~= entry.parent then
					host:reparent(previous.node, parent)
				end
				if not sameProps(previous.props, entry.props) then
					local props = entry.props
					local clearInline = previous.props.inlineStyle ~= nil and props.inlineStyle == nil
					local clearText = previous.props.textAfter ~= nil and props.textAfter == nil
					if clearInline or clearText then
						props = table.clone(props)
						if clearInline then
							props.inlineStyle = { declarations = {} }
						end
						if clearText then
							props.textAfter = {}
						end
					end
					host:update(previous.node, props)
					if previous.props.id ~= entry.props.id then
						host:setId(previous.node, entry.props.id)
					end
				end
				previous.parent = entry.parent
				previous.props = entry.props
			end
		end
		for key, record in table.clone(records) do
			if not desired[key] then
				host:remove(record.node)
				records[key] = nil
			end
		end
		for _, entry in entries do
			local children: { Css.Node } = {}
			for _, key in entry.children do
				table.insert(children, records[key].node)
			end
			host:reorder(records[entry.key].node, children)
		end
		local rootNodes: { Css.Node } = {}
		for _, key in roots do
			table.insert(rootNodes, records[key].node)
		end
		host:reorder(nil, rootNodes)
	end
	function controller.commit(elements: { Element })
		assert(not destroyed, "CSS tree controller has been destroyed")
		assert(not committing, "Reentrant CSS tree commit")
		local entries, roots = prepare(elements)
		committing = true
		local ok, failure = pcall(apply, entries, roots)
		committing = false
		if not ok then
			-- An unexpected host failure may have changed identity/parentage. Do
			-- not reuse that partial tree or claim rollback; release this surface.
			local clean, cleanupFailure = pcall(release)
			if not clean then
				error(`CSS tree commit: {tostring(failure)}; cleanup: {tostring(cleanupFailure)}`, 0)
			end
			error(failure, 0)
		end
	end
	function controller.getNode(key: Key): Css.Node?
		local record = if not destroyed then records[key] else nil
		return if record then record.node else nil
	end
	function controller.getHost(): Css.Host?
		return if not destroyed then host else nil
	end
	controller.destroy = release
	return controller
end

export type Controller = typeof(Tree.create(nil :: any))
return Tree
