--!strict
local Codec = require(script.Parent.SourceURLCodec)
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Symbols = require(script.Parent.SourceSymbols)
local SourceType = require(script.Parent.SourceType)
local Functions = require(script.Parent.FunctionValues)
local Objects = require(script.Parent.SourceObjects)
local Nulls = require(script.Parent.Nulls)
local Params = {}
local token = {}
type State = { list: { { string } }, changed: ((string) -> ())? }
local function packet(...: any): any return Arrays.adopt({ ... }, select("#", ...)) end
local function object(value: any): boolean
	local kind = SourceType.typeOf(value)
	return not Nulls.isNull(value) and (kind == "object" or kind == "function")
end
function Params.create(ops: any): any
	local closed = false
	local function invalid(message: string): never return ops.intrinsicError("TypeError", message) end
	local function state(owner: any): State
		local meta: any = if type(owner) == "table" then getmetatable(owner) else nil
		if type(meta) ~= "table" or not meta[token] then return invalid("URLSearchParams method requires its receiver") end
		return meta[token]
	end
	local function notify(current: State)
		local changed = current.changed
		if changed then changed(Codec.serializeForm(current.list)) end
	end
	-- WebIDL sequence conversion closes an iterator when converting its yielded
	-- value fails. A failure from next() itself is already an abrupt iterator
	-- step and must propagate without calling that iterator's return method.
	local function sequence(input: any, convert: (any) -> any, method: any?): { any }
		local iterator = ops.iterable(input, method)
		local result = {}
		while true do
			local item = iterator.next(iterator)
			if item.done then return result end
			local ok, value = pcall(convert, item.value)
			if not ok then
				if iterator.close then pcall(iterator.close) end
				error(value, 0)
			end
			table.insert(result, value)
		end
	end
	local function parse(init: any): { { string } }
		-- Only an omitted/undefined argument takes the IDL default. The union
		-- contains no nullable or dictionary member: null converts to "null".
		if init == nil then return {} end
		if not object(init) then
			local text = ops.string(init)
			return Codec.parseForm(if string.sub(text, 1, 1) == "?" then string.sub(text, 2) else text)
		end
		local result = {}
		local iteratorMethod = ops.get(init, Symbols.Symbol.iterator)
		if not Nulls.isNullish(iteratorMethod) then
			return sequence(init, function(value: any): { string }
				if not object(value) then invalid("URLSearchParams entries require iterable pairs") end
				local pair = sequence(value, function(item: any): string return ops.string(item) end)
				if #pair ~= 2 then invalid("URLSearchParams entries require exactly two values") end
				return pair
			end, iteratorMethod)
		end
		for _, key in Objects.keys(init) do table.insert(result, { ops.string(key), ops.string(ops.get(init, key)) }) end
		local symbols = ops.call(ops.get(Objects, "getOwnPropertySymbols"), Objects, packet(init))
		for _, key in symbols do
			local desc = ops.getOwnPropertyDescriptor(init, key)
			if desc and desc.enumerable then table.insert(result, { ops.string(key), ops.string(ops.get(init, key)) }) end
		end
		return result
	end
	local constructor = ops.classValue("URLSearchParams", nil, false, function(frame: any, args: any)
		assert(not closed, "Source URL realm is destroyed")
		local owner = ops.classThis(frame)
		local meta = table.clone(getmetatable(owner) :: any)
		meta[token] = { list = parse(args[1]), changed = nil }
		setmetatable(owner, meta)
	end, nil, 0)
	local prototype = ops.get(constructor, "prototype")
	ops.defineDataProperty(prototype, Symbols.Symbol.toStringTag, "URLSearchParams", false, false, true)
	local function required(args: any, count: number)
		if Arrays.length(args) < count then invalid("Not enough arguments for URLSearchParams method") end
	end
	local function method(name: string, count: number, callback: (any, any) -> any): any
		local value = ops.functionValue(function(owner: any, args: any): any
			local current = state(owner); required(args, count)
			return callback(current, args)
		end, name, count, "method")
		ops.defineDataProperty(prototype, name, value, true, true, true)
		return value
	end
	method("append", 2, function(current: any, args: any)
		local key, value = ops.string(args[1]), ops.string(args[2])
		table.insert(current.list, { key, value }); notify(current)
		return nil
	end)
	method("delete", 1, function(current: any, args: any)
		local key = ops.string(args[1])
		local value = if args[2] ~= nil then ops.string(args[2]) else nil
		for at = #current.list, 1, -1 do
			local pair = current.list[at]
			if pair[1] == key and (value == nil or pair[2] == value) then table.remove(current.list, at) end
		end
		notify(current)
		return nil
	end)
	method("get", 1, function(current: any, args: any): any
		local key = ops.string(args[1])
		for _, pair in current.list do if pair[1] == key then return pair[2] end end
		return Nulls.value
	end)
	method("getAll", 1, function(current: any, args: any): any
		local key, result = ops.string(args[1]), Arrays.adopt({}, 0)
		for _, pair in current.list do if pair[1] == key then Arrays.push(result, pair[2]) end end
		return result
	end)
	method("has", 1, function(current: any, args: any): boolean
		local key = ops.string(args[1])
		local value = if args[2] ~= nil then ops.string(args[2]) else nil
		for _, pair in current.list do if pair[1] == key and (value == nil or pair[2] == value) then return true end end
		return false
	end)
	method("set", 2, function(current: any, args: any)
		local key, value = ops.string(args[1]), ops.string(args[2])
		local seen, at = false, 1
		while at <= #current.list do
			local pair = current.list[at]
			if pair[1] ~= key then at += 1
			elseif not seen then pair[2] = value; seen = true; at += 1
			else table.remove(current.list, at) end
		end
		if not seen then table.insert(current.list, { key, value }) end
		notify(current)
		return nil
	end)
	method("sort", 0, function(current: any)
		local decorated: { { pair: { string }, at: number } } = {}
		for at, pair in current.list do table.insert(decorated, { pair = pair, at = at }) end
		table.sort(decorated, function(a: { pair: { string }, at: number }, b: { pair: { string }, at: number })
			return if a.pair[1] == b.pair[1] then a.at < b.at else ops.binary("<", a.pair[1], b.pair[1])
		end)
		local sorted = {}
		for _, entry in decorated do table.insert(sorted, entry.pair) end
		current.list = sorted; notify(current)
		return nil
	end)
	method("toString", 0, function(current: any): string return Codec.serializeForm(current.list) end)
	local size = ops.functionValue(function(owner: any): number return #state(owner).list end, "get size", 0, "method")
	ops.defineAccessor(prototype, "size", size, nil, true, true)
	local function iterate(owner: any, mode: string): any
		local current, at = state(owner), 1
		local iterator = ops.object()
		local nextValue = ops.functionValue(function(): any
			local pair = current.list[at]
			local value: any = nil
			if pair then
				at += 1
				value = if mode == "keys" then pair[1] elseif mode == "values" then pair[2] else packet(pair[1], pair[2])
			end
			return Records.adopt({ value = value, done = pair == nil }, { "value", "done" })
		end, "next", 0, "method")
		ops.defineDataProperty(iterator, "next", nextValue, true, false, true)
		ops.defineDataProperty(iterator, Symbols.Symbol.iterator, ops.functionValue(function(receiver: any): any return receiver end, "[Symbol.iterator]", 0, "method"), true, false, true)
		ops.defineDataProperty(iterator, Symbols.Symbol.toStringTag, "URLSearchParams Iterator", false, false, true)
		return iterator
	end
	for _, name in { "keys", "values", "entries" } do
		local mode = name
		ops.defineDataProperty(prototype, name, ops.functionValue(function(owner: any): any return iterate(owner, mode) end, name, 0, "method"), true, true, true)
	end
	ops.defineDataProperty(prototype, Symbols.Symbol.iterator, ops.get(prototype, "entries"), true, true, true)
	local function each(owner: any, args: any, native: boolean)
		local current = state(owner); required(args, 1)
		local callback, thisArg = args[1], args[2]
		if SourceType.typeOf(callback) ~= "function" then invalid("URLSearchParams.forEach requires a callback") end
		local at = 1
		while at <= #current.list do
			local pair = current.list[at]
			local values = packet(pair[2], pair[1], owner)
			if native and not Functions.isSource(callback) then
				Functions.invokeReference(Functions.reference(nil, function() return callback end, "free", false), function() return values end, false)
			else ops.call(callback, thisArg, values) end
			at += 1
		end
	end
	local dual: any = { properties = Records.adopt({}, {}) }
	dual.source = function(owner: any, args: any) each(owner, args, false) end
	dual.native = function(owner: any, ...: any) each(owner, packet(...), true) end
	local function forEach(owner: any, ...: any) return dual.native(owner, ...) end
	Functions.named(forEach, "forEach", 1, true)
	Functions.source(forEach, dual.source, dual.properties)
	Records.defineDescriptor(dual.properties, "name", { kind = "data", value = "forEach", writable = false, enumerable = false, configurable = true })
	Records.defineDescriptor(dual.properties, "length", { kind = "data", value = 1, writable = false, enumerable = false, configurable = true })
	ops.defineDataProperty(prototype, "forEach", forEach, true, true, true)
	return {
		Constructor = constructor,
		make = function(text: string, changed: ((string) -> ())?): any
			local owner = ops.construct(constructor, packet(text))
			state(owner).changed = changed
			return owner
		end,
		replace = function(owner: any, text: string) state(owner).list = Codec.parseForm(text) end,
		destroy = function() closed = true end,
	}
end
return Params
