--!strict

-- Declared CSS peer dependency. Source mappings and the portable Rojo model
-- keep Css and CssReact as siblings beneath a consumer-owned container.
local Css = require(script.Parent.Parent.Css)

export type Node = Css.Node
export type ComputedStyle = Css.ComputedStyle
export type BoxGeometry = Css.BoxGeometry
export type ImageData = Css.ImageData
export type ImageProviderInputs = Css.ImageProviderInputs
export type NodeOptions = Css.NodeOptions
export type InlineStyle = Css.InlineStyle
export type Declaration = Css.Declaration
export type PropertyMetadata = Css.PropertyMetadata
export type Host = Css.Host
export type PlaybackHandle = Css.PlaybackHandle
export type Stylesheet = Css.Stylesheet
export type HostOptions = Css.HostOptions
export type RootOptions = Css.RootOptions
export type SceneKey = Css.SceneKey

return Css
