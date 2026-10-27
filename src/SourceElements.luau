--!strict
-- Passive React-host metadata. The native element's props own this snapshot;
-- no registry roots an element through a ref callback and no binder is added.
local marker = {}
local property = "__cssSourceElement"
local SourceElements = { property = property }
function SourceElements.attach(hostProps: any, info: any)
	info.marker = marker
	hostProps[property] = info
end
function SourceElements.get(element: any): any
	if type(element) ~= "table" then
		return nil
	end
	local props = rawget(element, "props")
	local info = if type(props) == "table" then rawget(props :: any, property) else nil
	return if type(info) == "table" and rawget(info :: any, "marker") == marker then info else nil
end
return table.freeze(SourceElements)
