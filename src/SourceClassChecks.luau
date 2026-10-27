--!strict
-- RuntimeLib.instanceof from installed roblox-ts 3.0.0, MIT; see
-- LICENSE.roblox-ts and node_modules/roblox-ts/include/RuntimeLib.lua:111.
-- This preserves its custom static hook and ordinary class-metatable path.
local SourceClassChecks = {}
function SourceClassChecks.instanceOf(obj: any, class: any): boolean
	if type(class) == "table" and type(class.instanceof) == "function" then
		local predicate: any = class.instanceof
		return predicate(obj)
	end
	if type(obj) == "table" then
		local current: any = getmetatable(obj)
		while current ~= nil do
			if current == class then
				return true
			end
			local mt: any = getmetatable(current)
			if mt then
				current = mt.__index
			else
				current = nil
			end
		end
	end
	return false
end
return SourceClassChecks
