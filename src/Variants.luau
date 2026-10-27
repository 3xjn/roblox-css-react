--!strict
-- Selection semantics derived from class-variance-authority 0.7.1.
-- Copyright 2022 Joe Bell. Apache-2.0; see ../LICENSE.cva.

export type Scalar = { kind: string, value: any? }
export type Metadata = {
	version: number,
	base: string,
	axes: { { name: string, choices: { { key: string, classes: string, numberKey: number? } } } },
	defaults: { { name: string, value: Scalar } },
	compounds: { { conditions: { { name: string, values: { Scalar }, array: boolean } }, classes: string } },
}
type Axis = { name: string, choices: { [string]: string }, numbers: { [number]: string } }
type Condition = { name: string, values: { { value: any?, nan: boolean } }, array: boolean }
local None = table.freeze({})
local Variants = { None = None }

local function dense(values: { any })
	local count = 0
	for index in values do
		assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #values, "Variant lists must be dense arrays")
		count += 1
	end
	assert(count == #values, "Variant lists must be dense arrays")
end

local function decode(value: Scalar): any
	if value.kind == "undefined" then return nil end
	if value.kind == "null" then return None end
	if value.kind == "nan" then return 0 / 0 end
	if value.kind == "positive-infinity" then return math.huge end
	if value.kind == "negative-infinity" then return -math.huge end
	if value.kind == "number" then
		assert(type(value.value) == "number" and value.value == value.value and math.abs(value.value) < math.huge, "Invalid finite variant number")
	elseif value.kind == "boolean" then
		assert(type(value.value) == "boolean", "Invalid variant boolean")
	elseif value.kind == "string" then
		assert(type(value.value) == "string", "Invalid variant string")
	else
		error("Unsupported variant scalar")
	end
	return value.value
end

local function extra(value: any): string?
	if value == nil or value == None or type(value) == "boolean" then return nil end
	if type(value) == "number" and (value == 0 or value ~= value) then return nil end
	assert(type(value) == "string", "Runtime class/className props require strings; normalize class arrays/objects at the boundary")
	return if value ~= "" then value else nil
end

local function key(value: any): any
	if type(value) == "boolean" then return tostring(value) end
	if value == 0 then return "0" end
	assert(value == nil or value == None or type(value) == "string" or type(value) == "number", "Variant values require scalars or Variants.None")
	return value
end

function Variants.create(metadata: Metadata): ({ [string]: any }?) -> string
	assert(metadata.version == 1 and type(metadata.base) == "string", "Unsupported variant metadata")
	dense(metadata.axes)
	dense(metadata.defaults)
	dense(metadata.compounds)
	local base = metadata.base
	local defaults: { [string]: any } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in metadata.defaults do
		assert(type(entry.name) == "string" and not seen[entry.name], "Invalid duplicate variant default")
		seen[entry.name] = true
		defaults[entry.name] = decode(entry.value)
	end
	local axes: { Axis } = {}
	table.clear(seen)
	for _, entry in metadata.axes do
		assert(type(entry.name) == "string" and not seen[entry.name], "Invalid duplicate variant axis")
		seen[entry.name] = true
		dense(entry.choices)
		local axis: Axis = { name = entry.name, choices = {}, numbers = {} }
		for _, choice in entry.choices do
			assert(type(choice.key) == "string" and type(choice.classes) == "string" and axis.choices[choice.key] == nil, "Invalid duplicate variant choice")
			axis.choices[choice.key] = choice.classes
			if choice.numberKey ~= nil then
				local number = choice.numberKey
				assert(type(number) == "number" and number == number and math.abs(number) < math.huge and axis.numbers[number] == nil, "Invalid numeric variant key")
				axis.numbers[number] = choice.classes
			end
		end
		table.insert(axes, axis)
	end
	local compounds: { { conditions: { Condition }, classes: string } } = {}
	for _, entry in metadata.compounds do
		assert(type(entry.classes) == "string", "Invalid compound classes")
		dense(entry.conditions)
		local conditions: { Condition } = {}
		for _, condition in entry.conditions do
			assert(type(condition.name) == "string" and type(condition.array) == "boolean", "Invalid compound condition")
			dense(condition.values)
			assert(condition.array or #condition.values == 1, "Scalar compound condition requires one value")
			local values: { { value: any?, nan: boolean } } = {}
			for _, value in condition.values do
				table.insert(values, { value = decode(value), nan = value.kind == "nan" })
			end
			table.insert(conditions, { name = condition.name, array = condition.array, values = values })
		end
		table.insert(compounds, { conditions = conditions, classes = entry.classes })
	end
	return function(props: { [string]: any }?): string
		assert(props == nil or type(props) == "table", "Variant props must be a record")
		local values = props or {}
		local result: { string } = {}
		local function append(classes: string?)
			if classes and classes ~= "" then table.insert(result, classes) end
		end
		append(base)
		for _, axis in axes do
			local value = values[axis.name]
			if value == None then continue end
			value = key(value)
			if value == nil or value == "" or (type(value) == "number" and value ~= value) then
				value = key(defaults[axis.name])
			end
			local classes
			if value == nil then classes = axis.choices.undefined
			elseif value == None then classes = axis.choices["null"]
			elseif value == math.huge then classes = axis.choices.Infinity
			elseif value == -math.huge then classes = axis.choices["-Infinity"]
			elseif type(value) == "number" then
				classes = if value ~= value then axis.choices.NaN else axis.numbers[value]
			else classes = axis.choices[value] end
			append(classes)
		end
		for _, compound in compounds do
			local matches = true
			for _, condition in compound.conditions do
				local actual = rawget(values, condition.name)
				if actual == nil then actual = defaults[condition.name] end
				local matched = false
				for _, expected in condition.values do
					if actual == expected.value or (condition.array and type(actual) == "number" and actual ~= actual and expected.nan) then
						matched = true
						break
					end
				end
				if not matched then
					matches = false
					break
				end
			end
			if matches then append(compound.classes) end
		end
		append(extra(values.class))
		append(extra(values.className))
		return table.concat(result, " ")
	end
end

return Variants
