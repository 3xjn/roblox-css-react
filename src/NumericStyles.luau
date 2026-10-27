--!strict
local Css = require(script.Parent.Runtime)
local StyleObjects = require(script.Parent.StyleObjects)
type Range = { minimum: number?, maximum: number?, integer: boolean? }
type Slot = {
	entry: number,
	argument: number,
	pixels: boolean,
	unit: string?,
	domain: { zero: boolean, ranges: { Range } },
}
export type Template = {
	kind: "numeric-style",
	base: StyleObjects.Style,
	arity: number,
	slots: { Slot },
	keys: { number }?,
}
export type Value = number | boolean | string | nil
local NumericStyles = {}

local function array(value: any): number
	assert(type(value) == "table", "Numeric style needs an ordered array")
	local count = 0
	for index in value do
		assert(
			type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #value,
			"Numeric style needs an ordered array"
		)
		count += 1
	end
	assert(count == #value, "Numeric style needs a dense array")
	return count
end

local function freeze(value: any)
	if type(value) ~= "table" or table.isfrozen(value) then
		return
	end
	for _, child in value do
		freeze(child)
	end
	table.freeze(value)
end

function NumericStyles.create(template: Template): (...Value) -> StyleObjects.Style
	assert(
		template.kind == "numeric-style" and template.arity >= 0 and template.arity % 1 == 0,
		"Invalid numeric style template"
	)
	local snapshot = assert(Css.InlineStyle.copy(StyleObjects.toInline(template.base)))
	local base: { StyleObjects.Entry } = {}
	local declarationIndex = 0
	for _, entry in template.base.entries do
		local declaration: Css.Declaration? = nil
		if entry.declaration then
			declarationIndex += 1
			declaration = snapshot.declarations[declarationIndex]
		end
		table.insert(base, { name = entry.name, declaration = declaration })
	end
	local slots: { Slot } = {}
	local occupied: { [number]: boolean } = {}
	local arguments: { [number]: boolean } = {}
	array(template.slots)
	for _, slot in template.slots do
		assert(
			slot.entry % 1 == 0 and base[slot.entry] and base[slot.entry].declaration and not occupied[slot.entry],
			"Invalid numeric style entry"
		)
		assert(
			slot.argument % 1 == 0 and slot.argument >= 1 and slot.argument <= template.arity,
			"Invalid numeric style argument"
		)
		assert(type(slot.pixels) == "boolean" and type(slot.domain.zero) == "boolean", "Invalid numeric style mode")
		if slot.unit ~= nil then
			local tokens = assert(base[slot.entry].declaration).tokens
			local token = tokens[1]
			assert(
				type(slot.unit) == "string" and #tokens == 1 and token,
				"Explicit style units need one numeric token"
			)
			assert(
				if slot.unit == ""
					then token.kind == "number"
					elseif slot.unit == "%" then token.kind == "percentage"
					else token.kind == "dimension" and string.lower(token.unit or "") == string.lower(slot.unit),
				"Style unit disagrees with its compiled token"
			)
		end
		local ranges: { Range } = {}
		array(slot.domain.ranges)
		for _, range in slot.domain.ranges do
			for _, limit in { range.minimum, range.maximum } do
				assert(
					type(limit) == "number" and limit == limit and math.abs(limit) < math.huge,
					"Invalid numeric style range"
				)
			end
			assert(range.integer == nil or type(range.integer) == "boolean", "Invalid numeric integer mode")
			assert((range.minimum or -math.huge) <= (range.maximum or math.huge), "Reversed numeric style range")
			table.insert(ranges, { minimum = range.minimum, maximum = range.maximum, integer = range.integer })
		end
		occupied[slot.entry] = true
		arguments[slot.argument] = true
		table.insert(slots, {
			entry = slot.entry,
			argument = slot.argument,
			pixels = slot.pixels,
			unit = slot.unit,
			domain = { zero = slot.domain.zero, ranges = ranges },
		})
	end
	local keys: { number } = {}
	local checked: { [number]: boolean } = {}
	if template.keys then
		array(template.keys)
		for _, argument in template.keys do
			assert(
				argument % 1 == 0
					and argument >= 1
					and argument <= template.arity
					and not arguments[argument]
					and not checked[argument],
				"Invalid computed style key argument"
			)
			checked[argument] = true
			table.insert(keys, argument)
		end
	end
	freeze(base)
	freeze(snapshot.properties)
	local arity = template.arity
	return function(...: Value): StyleObjects.Style
		assert(select("#", ...) == arity, "Numeric style argument count changed")
		for _, argument in keys do
			assert(select(argument, ...) == true, "Computed style key disagrees with its source declaration")
		end
		local entries: { StyleObjects.Entry } = {}
		for _, entry in base do
			table.insert(entries, { name = entry.name, declaration = entry.declaration })
		end
		for _, slot in slots do
			local value = select(slot.argument, ...)
			local entry = entries[slot.entry]
			if value == nil or type(value) == "boolean" or value == "" then
				entry.declaration = nil
			else
				assert(
					type(value) == "number" and value == value and math.abs(value) < math.huge,
					"Numeric style needs a finite number or a clear value"
				)
				local number = value :: number
				local valid = number == 0 and slot.domain.zero
				if number ~= 0 then
					for _, range in slot.domain.ranges do
						if
							number >= (range.minimum or -math.huge)
							and number <= (range.maximum or math.huge)
							and (not range.integer or (number % 1 == 0 and math.abs(number) < 1e21))
						then
							valid = true
							break
						end
					end
				end
				-- CSS integer tokens cannot contain exponents. React's numeric
				-- string conversion uses decimal form for integral values < 1e21.
				local text = if number == 0
					then "0"
					elseif number % 1 == 0 and math.abs(number) < 1e21 then string.format("%.0f", number)
					else string.format("%.17g", number)
				local pixels = slot.pixels and number ~= 0
				local declaration = table.clone(assert(base[slot.entry].declaration))
				declaration.value = text .. (if slot.unit ~= nil then slot.unit elseif pixels then "px" else "")
				if slot.unit ~= nil then
					local token = table.clone(assert(base[slot.entry].declaration).tokens[1])
					token.value = text
					declaration.tokens = { token }
				else
					declaration.tokens = {
						{
							kind = if pixels then "dimension" else "number",
							value = text,
							unit = if pixels then "px" else nil,
							syntaxType = if pixels then "length" else nil,
						},
					}
				end
				declaration.validity = if not valid
					then "invalid"
					elseif string.sub(declaration.property, 1, 2) == "--" then "deferred"
					else "valid"
				entry.declaration = declaration
			end
		end
		return { kind = "style-object", entries = entries, properties = snapshot.properties }
	end
end

return NumericStyles
