--!strict

local Tree = require(script.Parent.Tree)

local LabelAssociation = {}
local labelable =
	{ button = true, input = true, meter = true, output = true, progress = true, select = true, textarea = true }

local function accepts(element: Tree.Element): boolean
	local props: Tree.NodeOptions = element.props or {}
	local tag = props.tag or "div"
	return (labelable[tag] == true or element.labelable == true)
		and not (tag == "input" and props.attributes and (props.attributes.type or ""):lower() == "hidden")
end

local function find(elements: { Tree.Element }, predicate: (Tree.Element) -> boolean): Tree.Element?
	for _, element in elements do
		if predicate(element) then
			return element
		end
		local descendant = find(element.children or {}, predicate)
		if descendant then
			return descendant
		end
	end
	return nil
end

-- Resolve only on activation, against the renderer's committed tree. Native
-- ancestry is a paint detail and does not establish document association.
function LabelAssociation.resolve(elements: { Tree.Element }, key: Tree.Key): Tree.Key?
	local label = find(elements, function(element)
		return element.key == key
	end)
	if not label or not label.props or label.props.tag ~= "label" then
		return nil
	end
	local attributes = label.props.attributes
	local id = if attributes then attributes["for"] else nil
	local control: Tree.Element?
	if id ~= nil then
		if id == "" then
			return nil
		end
		-- A non-labelable first duplicate ID blocks a later labelable match.
		control = find(elements, function(element)
			return element.props ~= nil and element.props.id == id
		end)
	else
		control = find(label.children or {}, accepts)
	end
	return if control and accepts(control) then control.key else nil
end

return LabelAssociation
