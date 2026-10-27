--!strict
local Nulls = require(script.Parent.Nulls)
local Arrays = require(script.Parent.Arrays)
local RenderNodes = {}

local function normalize(value: any, parents: { [any]: boolean }?): any
	if rawequal(value, Nulls.value) then
		return false
	end
	if type(value) ~= "table" or rawget(value, "$$typeof") ~= nil then
		return value
	end
	local active = parents or {}
	assert(not active[value], "React child collections cannot contain cycles")
	active[value] = true
	local copy: any = nil
	if Arrays.owns(value) then
		local length = Arrays.length(value)
		for index = 1, length do
			local before = rawget(value, index)
			local after = normalize(before, active)
			if after == nil then
				after = false
			end
			if not rawequal(before, after) and copy == nil then
				copy = table.create(length)
				for previous = 1, index - 1 do
					copy[previous] = rawget(value, previous)
				end
			end
			if copy then
				copy[index] = after
			end
		end
	else
		for key, before in next, value do
			local after = normalize(before, active)
			if not rawequal(before, after) and copy == nil then
				copy = {}
				for sourceKey, sourceValue in next, value do
					copy[sourceKey] = sourceValue
				end
			end
			if copy then
				rawset(copy, key, after)
			end
		end
	end
	active[value] = nil
	return if copy == nil then value else copy
end
function RenderNodes.normalize(value: any): any
	return normalize(value, nil)
end
return RenderNodes
