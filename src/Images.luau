--!strict

local Html = require(script.Parent.Html)
local Css = require(script.Parent.Runtime)

export type Options = {
	name: string,
	getAsset: (string) -> Css.ImageData?,
}

local Images = {}
local providerAttribute = "data-css-image-provider"
local assetAttribute = "data-css-image"

-- Asset lookup/loading belongs to the caller. The bridge supplies selector
-- identity and content data; the shared renderer owns all native image views.
function Images.create(react: Html.React, options: Options)
	assert(type(options.name) == "string" and options.name ~= "", "Image provider needs a name")
	assert(type(options.getAsset) == "function", "Image provider needs getAsset")
	local name, getAsset = options.name, options.getAsset
	local function resolve(node: Css.Node): (Css.ImageData?, string?)
		if node.attributes[providerAttribute] ~= name then
			return nil, nil
		end
		local asset = node.attributes[assetAttribute]
		if not asset or asset == "" then
			return nil, "image-provider-asset-name-required"
		end
		local data = getAsset(asset)
		if not data then
			return nil, `image-provider-asset-required:{name}:{asset}`
		end
		local copied = table.clone(data)
		setmetatable(copied, nil)
		copied.natural = if data.natural then table.clone(data.natural) else nil
		return copied, nil
	end
	local function validateTag(tag: string)
		assert(type(tag) == "string" and tag:match("^[a-z][a-z0-9%-]*$"), "Image component needs a source tag")
		assert(tag ~= "button" and tag ~= "input" and tag ~= "textarea", "Image content requires a passive source tag")
	end
	local function render(asset: string, tag: string, props: Html.Props): any
		assert(type(asset) == "string" and asset ~= "", "Image asset needs a name")
		assert(props.children == nil or props.children == false, "Image components cannot contain children")
		assert(
			props[providerAttribute] == nil and props[assetAttribute] == nil,
			"Image provider attributes are owned by the adapter"
		)
		local forwarded = table.clone(props)
		forwarded.children = nil
		forwarded[providerAttribute], forwarded[assetAttribute] = name, asset
		return react.createElement(tag, Html.toHostProps(forwarded))
	end
	local function component(asset: string, tag: string): (Html.Props) -> any
		assert(type(asset) == "string" and asset ~= "", "Image asset needs a name")
		validateTag(tag)
		return function(props: Html.Props): any
			return render(asset, tag, props)
		end
	end
	local function fromAttribute(tag: string, attribute: string): (Html.Props) -> any
		validateTag(tag)
		assert(
			type(attribute) == "string" and attribute:match("^data%-%S+$"),
			"Image asset selection needs a data attribute"
		)
		assert(
			attribute ~= providerAttribute and attribute ~= assetAttribute,
			"Image provider attributes are owned by the adapter"
		)
		return function(props: Html.Props): any
			local asset = props[attribute]
			local forwarded = table.clone(props)
			forwarded[attribute] = nil
			return render(asset, tag, forwarded)
		end
	end
	return {
		component = component,
		fromAttribute = fromAttribute,
		resolve = resolve,
		inputs = { attributes = { providerAttribute, assetAttribute }, states = {} } :: Css.ImageProviderInputs,
	}
end

return Images
