--!strict

-- Values stay in native numeric slots. Only length and own-presence need a
-- ledger; no undefined marker escapes a completed construction.
type State = { length: number, present: { [number]: boolean }, named: { [any]: boolean }?, order: { any }? }
local states: { [any]: State } = setmetatable({}, { __mode = "k" })
local Undefined, Hole = table.freeze({}), table.freeze({})
local Arrays = {}
local Nulls = require(script.Parent.Nulls)
local function state(value: any): State
	local result = states[value]
	assert(result, "Native source arrays need adoption with an explicit length and presence")
	return result
end
local function size(value: number): number
	assert(
		type(value) == "number" and value >= 0 and value <= 4294967295 and value % 1 == 0,
		"Invalid source array length"
	)
	return value
end
local function writable(value: any)
	assert(not table.isfrozen(value), "Cannot mutate a frozen source array")
end
local function integer(value: number): number
	assert(type(value) == "number", "Array index conversion requires a primitive number")
	return if value ~= value or value == 0 then 0 elseif value < 0 then math.ceil(value) else math.floor(value)
end
local function relative(value: number, length: number): number
	local number = integer(value)
	return if number < 0 then math.max(length + number, 0) else math.min(number, length)
end
local function truthy(value: any): boolean
	return Nulls.truthy(value)
end
local metatable = {
	__len = function(value: any): number
		return state(value).length
	end,
	__newindex = function(value: any, index: any, item: any)
		local data = state(value)
		assert(
			type(index) == "number" and index >= 1 and index <= 4294967295 and index % 1 == 0,
			"Source arrays support numeric index writes; named properties need an object provider"
		)
		rawset(value, index, item)
		data.present[index] = true
		data.length = math.max(data.length, index)
	end,
	__iter = function(value: any)
		local owner, cursor, done = value, 0, false
		return function(): (number?, any)
			if done then
				return nil, nil
			end
			cursor += 1
			if cursor > state(owner).length then
				done, owner = true, nil
				return nil, nil
			end
			return cursor, rawget(owner, cursor)
		end
	end,
}
local function attach(value: any, data: State): any
	assert(type(value) == "table" and getmetatable(value) == nil, "Source arrays require a fresh plain native table")
	assert(not table.isfrozen(value), "Frozen native arrays cannot be adopted")
	states[value] = data
	return setmetatable(value, metatable)
end
function Arrays.owns(value: any): boolean
	return states[value] ~= nil
end
function Arrays.keys(value: any): any
	local indexes = {}
	for index in state(value).present do
		table.insert(indexes, index)
	end
	table.sort(indexes)
	local result = {}
	for position, index in indexes do
		result[position] = string.format("%.0f", index - 1)
	end
	local data = state(value)
	for _, name in data.order or {} do
		if type(name) == "string" and data.named and data.named[name] then table.insert(result, name) end
	end
	return Arrays.adopt(result, #result)
end
function Arrays.set(value: any, index: number, item: any): any
	local data = state(value)
	assert(index >= 0 and index < 4294967295 and index % 1 == 0, "Invalid source array index")
	writable(value)
	rawset(value, index + 1, item)
	data.present[index + 1] = true
	data.length = math.max(data.length, index + 1)
	return item
end
function Arrays.hasProperty(value: any, key: any): boolean
	local data = state(value)
	return data.named ~= nil and data.named[key] == true
end
function Arrays.defineProperty(value: any, key: any, item: any): any
	local data = state(value)
	writable(value)
	assert(key ~= "length", "Array length needs its dedicated mutation API")
	if not data.named then data.named, data.order = {}, {} end
	if not (data.named :: any)[key] then table.insert(data.order :: any, key) end
	(data.named :: any)[key] = true
	rawset(value, key, item)
	return item
end
function Arrays.removeProperty(value: any, key: any): boolean
	local data = state(value)
	writable(value)
	if data.named and data.named[key] then
		data.named[key] = nil
		local position = table.find(data.order :: any, key)
		if position then table.remove(data.order :: any, position) end
		rawset(value, key, nil)
	end
	return true
end
function Arrays.ownKeys(value: any): any
	local data = state(value)
	local keys, numericCount = Arrays.keys(value), 0
	for _ in data.present do numericCount += 1 end
	local result = Arrays.adopt({}, 0)
	for position = 1, numericCount do Arrays.push(result, keys[position]) end
	Arrays.push(result, "length")
	for position = numericCount + 1, #keys do Arrays.push(result, keys[position]) end
	for _, name in data.order or {} do
		if type(name) ~= "string" and data.named and data.named[name] then Arrays.push(result, name) end
	end
	return result
end
function Arrays.adopt(value: any, length: number, present: { number }?): any
	local data: State = { length = size(length), present = {} }
	if present then
		for _, index in present do
			assert(
				index % 1 == 0 and index >= 0 and index < length and not data.present[index + 1],
				"Invalid or duplicate source slot"
			)
			data.present[index + 1] = true
		end
	else
		for index = 1, length do
			data.present[index] = true
		end
	end
	for index in value do
		assert(
			type(index) == "number" and index >= 1 and index <= length and index % 1 == 0 and data.present[index],
			"Native array fields disagree with declared slots"
		)
	end
	return attach(value, data)
end
function Arrays.literal(value: any, length: number, holes: { number }?): any
	if holes then
		for _, index in holes do
			assert(
				index >= 0 and index < length and index % 1 == 0 and rawget(value, index + 1) == nil,
				"Invalid literal hole"
			)
		end
	end
	local result = Arrays.adopt(value, length)
	if holes then
		local data = state(result)
		for _, index in holes do
			data.present[index + 1] = nil
		end
	end
	return result
end
function Arrays.rest(callback: (any) -> any): any
	return function(...: any): any
		return callback(Arrays.adopt({ ... }, select("#", ...)))
	end
end
local function forward(resolve: () -> any, optional: boolean): any
	return function(...: any): any
		local callback = resolve()
		if optional and callback == nil then
			return nil
		end
		return callback(...)
	end
end
function Arrays.forward(): any
	return forward
end
function Arrays.call(callback: any, args: any): any
	return callback(table.unpack(args, 1, state(args).length))
end
function Arrays.callOptional(callback: any, args: any): any
	return if callback ~= nil then Arrays.call(callback, args) else nil
end
function Arrays.callOptionalLazy(callback: any, args: () -> any): any
	return if callback ~= nil then Arrays.call(callback, args()) else nil
end
function Arrays.slot(value: any): any
	return if value == nil then Undefined else value
end
function Arrays.hole(): any
	return Hole
end
function Arrays.spread(value: any): any
	local length = state(value).length
	local result = table.create(length)
	for index = 1, length do
		result[index] = Arrays.slot(rawget(value, index))
	end
	return result
end
function Arrays.finish(value: any): any
	local length = #value
	local data: State = { length = length, present = {} }
	for index = 1, length do
		local item = rawget(value, index)
		if not rawequal(item, Hole) then
			data.present[index] = true
		end
		if rawequal(item, Hole) or rawequal(item, Undefined) then
			rawset(value, index, nil)
		end
	end
	return attach(value, data)
end
function Arrays.length(value: any): number
	return state(value).length
end
function Arrays.values(value: any): any
	state(value)
	local owner, cursor = value, 0
	return {
		next = function(): { done: boolean, value: any? }
			if owner and cursor < state(owner).length then
				cursor += 1
				return { done = false, value = rawget(owner, cursor) }
			end
			owner = nil
			return { done = true }
		end,
	}
end
function Arrays.has(value: any, index: number): boolean
	return state(value).present[index + 1] == true
end
function Arrays.remove(value: any, index: number): boolean
	local data = state(value)
	writable(value)
	assert(
		index >= 0 and index < 4294967295 and index % 1 == 0,
		"Named array property deletion needs an object provider"
	)
	if data.present[index + 1] then
		rawset(value, index + 1, nil)
		data.present[index + 1] = nil
	end
	return true
end
function Arrays.setLength(value: any, length: number): number
	local data = state(value)
	size(length)
	writable(value)
	if length < data.length then
		for index in data.present do
			if index > length then
				rawset(value, index, nil)
				data.present[index] = nil
			end
		end
	end
	data.length = length
	return length
end
function Arrays.map(value: any, callback: any): any
	local data = state(value)
	local result, output = {}, { length = data.length, present = {} } :: State
	for index = 1, output.length do
		if data.present[index] then
			result[index] = callback(rawget(value, index), index - 1, value)
			output.present[index] = true
		end
	end
	return attach(result, output)
end
function Arrays.filter(value: any, callback: any): any
	local data = state(value)
	local result, count = {}, 0
	for index = 1, data.length do
		if data.present[index] then
			local item = rawget(value, index)
			if truthy(callback(item, index - 1, value)) then
				count += 1
				result[count] = item
			end
		end
	end
	return Arrays.adopt(result, count)
end
local function visit(value: any, callback: any, mode: string): boolean
	local data = state(value)
	for index = 1, data.length do
		if data.present[index] then
			local result = callback(rawget(value, index), index - 1, value)
			if mode == "some" and truthy(result) then
				return true
			end
			if mode == "every" and not truthy(result) then
				return false
			end
		end
	end
	return mode == "every"
end
function Arrays.forEach(value: any, callback: any)
	visit(value, callback, "each")
end
function Arrays.some(value: any, callback: any): boolean
	return visit(value, callback, "some")
end
function Arrays.every(value: any, callback: any): boolean
	return visit(value, callback, "every")
end
function Arrays.findIndex(value: any, callback: any): number
	local length = state(value).length
	for index = 1, length do
		if truthy(callback(rawget(value, index), index - 1, value)) then
			return index - 1
		end
	end
	return -1
end
function Arrays.find(value: any, callback: any): any
	local length = state(value).length
	for index = 1, length do
		local item = rawget(value, index)
		if truthy(callback(item, index - 1, value)) then
			return item
		end
	end
	return nil
end
function Arrays.slice(value: any, first: number?, last: number?): any
	local data = state(value)
	local start = relative(first or 0, data.length)
	local stop = relative(if last == nil then data.length else last, data.length)
	local output: State = { length = math.max(0, stop - start), present = {} }
	local result = {}
	for index = 1, output.length do
		if data.present[start + index] then
			output.present[index] = true
			result[index] = rawget(value, start + index)
		end
	end
	return attach(result, output)
end
function Arrays.concat(value: any, ...: any): any
	local result = Arrays.adopt({}, 0)
	local function append(item: any)
		if Arrays.owns(item) then
			local source, target = state(item), state(result)
			local offset = target.length
			target.length = size(offset + source.length)
			for index = 1, source.length do
				if source.present[index] then
					rawset(result, offset + index, rawget(item, index))
					target.present[offset + index] = true
				end
			end
		else Arrays.push(result, item) end
	end
	state(value)
	append(value)
	for index = 1, select("#", ...) do append((select(index, ...))) end
	return result
end
local function reduce(value: any, callback: any, right: boolean, ...: any): any
	local data = state(value)
	assert(type(callback) == "function", "Array reduce requires a callback")
	local visit = callback :: (any, any, number, any) -> any
	local accumulator = ...
	local initialized = select("#", ...) > 0
	local length = data.length
	local first, last, step = if right then length else 1, if right then 1 else length, if right then -1 else 1
	for index = first, last, step do
		if data.present[index] then
			if initialized then accumulator = visit(accumulator, rawget(value, index), index - 1, value)
			else accumulator, initialized = rawget(value, index), true end
		end
	end
	assert(initialized, "Reduce of empty array with no initial value")
	return accumulator
end
function Arrays.reduce(value: any, callback: any, ...: any): any return reduce(value, callback, false, ...) end
function Arrays.reduceRight(value: any, callback: any, ...: any): any return reduce(value, callback, true, ...) end
function Arrays.flatMap(value: any, callback: any): any
	local data = state(value)
	local length = data.length
	local result = Arrays.adopt({}, 0)
	for index = 1, length do
		if data.present[index] then
			local item = callback(rawget(value, index), index - 1, value)
			if Arrays.owns(item) then
				local child = state(item)
				for childIndex = 1, child.length do
					if child.present[childIndex] then Arrays.push(result, rawget(item, childIndex)) end
				end
			else Arrays.push(result, item) end
		end
	end
	return result
end
function Arrays.reverse(value: any): any
	local data = state(value)
	writable(value)
	for lower = 1, math.floor(data.length / 2) do
		local upper = data.length - lower + 1
		local item, present = rawget(value, lower), data.present[lower]
		rawset(value, lower, rawget(value, upper))
		data.present[lower] = data.present[upper]
		rawset(value, upper, item)
		data.present[upper] = present
	end
	return value
end
function Arrays.fill(value: any, item: any, first: number?, finish: number?): any
	local data = state(value)
	writable(value)
	local start = relative(first or 0, data.length)
	local stop = if finish == nil then data.length else relative(finish, data.length)
	for index = start + 1, stop do
		rawset(value, index, item)
		data.present[index] = true
	end
	return value
end
function Arrays.push(value: any, ...: any): number
	local data = state(value)
	writable(value)
	local count = select("#", ...)
	size(data.length + count)
	for offset = 1, count do
		local index = data.length + offset
		rawset(value, index, (select(offset, ...)))
		data.present[index] = true
	end
	data.length += count
	return data.length
end
function Arrays.pop(value: any): any
	local data = state(value)
	writable(value)
	local index = data.length
	if index == 0 then
		return nil
	end
	local item = rawget(value, index)
	rawset(value, index, nil)
	data.present[index], data.length = nil, index - 1
	return item
end
function Arrays.splice(value: any, ...: any): any
	local data, argc = state(value), select("#", ...)
	writable(value)
	local first, deleteCount = ...
	local start = relative(if first == nil then 0 else first, data.length)
	local count = if argc == 0
		then 0
		elseif argc == 1 then data.length - start
		else math.clamp(integer(deleteCount or 0), 0, data.length - start)
	local inserted = math.max(0, argc - 2)
	local length = size(data.length - count + inserted)
	local removed = Arrays.slice(value, start, start + count)
	if inserted < count then
		for index = start + count + 1, data.length do
			local target = index - count + inserted
			rawset(value, target, rawget(value, index))
			data.present[target] = data.present[index]
		end
		for index = length + 1, data.length do
			rawset(value, index, nil)
			data.present[index] = nil
		end
	elseif inserted > count then
		for index = data.length, start + count + 1, -1 do
			local target = index - count + inserted
			rawset(value, target, rawget(value, index))
			data.present[target] = data.present[index]
		end
	end
	for offset = 1, inserted do
		local target = start + offset
		rawset(value, target, (select(offset + 2, ...)))
		data.present[target] = true
	end
	data.length = length
	return removed
end
function Arrays.shift(value: any): any
	local first = rawget(value, 1)
	Arrays.splice(value, 0, 1)
	return first
end
function Arrays.unshift(value: any, ...: any): number
	Arrays.splice(value, 0, 0, ...)
	return state(value).length
end
function Arrays.pushItems(value: any, items: any): number
	return Arrays.push(value, table.unpack(items, 1, state(items).length))
end
function Arrays.unshiftItems(value: any, items: any): number
	return Arrays.unshift(value, table.unpack(items, 1, state(items).length))
end
function Arrays.spliceArgs(value: any, args: any): any
	return Arrays.splice(value, table.unpack(args, 1, state(args).length))
end
local function search(value: any, item: any, from: number?, includes: boolean): number
	local data = state(value)
	local start = integer(from or 0)
	if start < 0 then
		start = math.max(data.length + start, 0)
	end
	for index = start + 1, data.length do
		if includes or data.present[index] then
			local current = rawget(value, index)
			if
				rawequal(current, item)
				or includes
					and type(item) == "number"
					and item ~= item
					and type(current) == "number"
					and current ~= current
			then
				return index - 1
			end
		end
	end
	return -1
end
function Arrays.includes(value: any, item: any, from: number?): boolean
	return search(value, item, from, true) >= 0
end
function Arrays.indexOf(value: any, item: any, from: number?): number
	return search(value, item, from, false)
end
function Arrays.at(value: any, index: number): any
	local length = state(value).length
	local position = integer(index)
	if position < 0 then
		position += length
	end
	return if position >= 0 and position < length then rawget(value, position + 1) else nil
end
function Arrays.join(value: any, separator: string?): string
	local length, parts = state(value).length, {}
	for index = 1, length do
		local item = rawget(value, index)
		if item == nil or Nulls.isNull(item) then
			parts[index] = ""
		elseif type(item) == "string" or type(item) == "boolean" then
			parts[index] = tostring(item)
		elseif type(item) == "number" then
			if item ~= item then
				parts[index] = "NaN"
			elseif item == math.huge then
				parts[index] = "Infinity"
			elseif item == -math.huge then
				parts[index] = "-Infinity"
			else
				assert(
					item % 1 == 0 and math.abs(item) <= 9007199254740991,
					"Numeric join needs JavaScript NumberToString outside safe integers"
				)
				parts[index] = if item == 0 then "0" else string.format("%.0f", item)
			end
		else
			error("Array join object coercion needs a source primitive-conversion provider", 2)
		end
	end
	return table.concat(parts, separator or ",")
end

return Arrays
