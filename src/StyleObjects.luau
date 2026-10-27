--!strict
local Css = require(script.Parent.Runtime)
export type Entry = { name: string, declaration: Css.Declaration? }
export type Style = { kind: "style-object", entries: { Entry }, properties: { [string]: Css.PropertyMetadata }? }
local StyleObjects = {}

function StyleObjects.is(value: any): boolean
	return type(value) == "table" and value.kind == "style-object"
end

local function entries(style: Style): { Entry }
	assert(StyleObjects.is(style) and type(style.entries) == "table", "Style props need compiled style-object packets")
	local count = 0
	local names: { [string]: boolean } = {}
	for index, entry in style.entries do
		assert(
			type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #style.entries,
			"Style entries require an ordered array"
		)
		assert(type(entry.name) == "string" and not names[entry.name], "Style entries require unique source names")
		names[entry.name] = true
		count += 1
	end
	assert(count == #style.entries, "Style entries require a dense array")
	return style.entries
end

function StyleObjects.toInline(style: Style): Css.InlineStyle
	local declarations: { Css.Declaration } = {}
	for _, entry in entries(style) do
		if entry.declaration then
			table.insert(declarations, entry.declaration)
		end
	end
	-- The renderer's existing inline-style snapshot validates and owns the IR.
	return { declarations = declarations, properties = style.properties }
end

function StyleObjects.merge(previous: Style?, incoming: Style): Style
	local result: { Entry } = {}
	local positions: { [string]: number } = {}
	local properties: { [string]: Css.PropertyMetadata } = {}
	local function append(style: Style)
		for _, entry in entries(style) do
			local index = positions[entry.name]
			local copy = { name = entry.name, declaration = entry.declaration }
			if index then
				result[index] = copy
			else
				table.insert(result, copy)
				positions[entry.name] = #result
			end
		end
		for name, metadata in style.properties or {} do
			assert(
				not properties[name] or Css.InlineStyle.sameMetadata(properties[name], metadata),
				"Conflicting style property metadata"
			)
			properties[name] = metadata
		end
	end
	if previous then
		append(previous)
	end
	append(incoming)
	return { kind = "style-object", entries = result, properties = properties }
end

return StyleObjects
