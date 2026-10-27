--!strict
-- Enumerable own data operations shared by client and headless source graphs.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Functions = require(script.Parent.FunctionValues)
local Nulls = require(script.Parent.Nulls)
local Objects = {}
-- A stateless intrinsic route lets native authored TypeScript reach the same
-- explicit object schemas as compiled JS. The canonical Object identity stays
-- unchanged, and these callbacks must not retain any per-owner user values.
local routing: any = nil
function Objects.configure(routes: any)
	assert(routing==nil or routing==routes,"Object intrinsic routes are already initialized")
	routing=routes
end
local function read(value: any, key: string): any
	if type(value) == "function" then return Functions.getProperty(value, key) end
	if Arrays.owns(value) then
		local index = if type(key) == "string" then tonumber(key) else nil
		if index and index >= 0 and index < 4294967295 and index % 1 == 0 and tostring(index) == key then return rawget(value, index + 1) end
		return rawget(value, key)
	end
	return value[key]
end
function Objects.is(left: any, right: any): boolean
	if type(left) == "number" and type(right) == "number" then
		if left ~= left and right ~= right then return true end
		if left == 0 and right == 0 then return 1 / left == 1 / right end
	end
	return rawequal(left, right)
end
function Objects.hasOwn(value: any, key: any): boolean
	if routing then return (routing :: any).hasOwn(value,key) end
	return if type(value) == "function" then Functions.hasOwn(value, key) else Records.hasOwn(value, key)
end
function Objects.freeze(value: any): any
	if routing then return (routing :: any).freeze(value) end
	assert(type(value) == "table", "Object.freeze requires a native source data table")
	return if table.isfrozen(value) then value else table.freeze(value)
end
function Objects.keys(value: any): any
	if routing then return (routing :: any).keys(value) end
	return if type(value) == "function" then Functions.keys(value) else Records.keys(value)
end
function Objects.values(value: any): any
	if routing then return (routing :: any).values(value) end
	local keys = Objects.keys(value)
	local result = Arrays.adopt({}, 0)
	for _, key in keys do Arrays.push(result, read(value, key)) end
	return result
end
function Objects.entries(value: any): any
	if routing then return (routing :: any).entries(value) end
	local keys = Objects.keys(value)
	local result = Arrays.adopt({}, 0)
	for _, key in keys do Arrays.push(result, Arrays.adopt({key, read(value, key)}, 2)) end
	return result
end
function Objects.assign(target: any, ...: any): any
	if routing then return (routing :: any).assign(target,...) end
	assert(Records.owns(target) or type(target) == "function", "Object.assign target requires a source record or function")
	for position = 1, select("#", ...) do
		local source = select(position, ...)
		if not Nulls.isNullish(source) then
			for _, key in Objects.keys(source) do
				local value = read(source, key)
				if type(target) == "function" then Functions.setProperty(target, key, value) else target[key] = value end
			end
		end
	end
	return target
end
return table.freeze(Objects)
