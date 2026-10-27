--!strict
local Css = require(script.Parent.Runtime)
local Target = require(script.Parent.Target)
local Arrays = require(script.Parent.Arrays)
local Properties = require(script.Parent.Properties)
local Records = require(script.Parent.Records)
local WebAnimations = {}

-- The caller supplies the Promise implementation already used by its emitted
-- roblox-ts code. No second Promise implementation or renderer is created.
type CancelHook = (() -> ()) -> ()
type PromiseConstructor = { read new: (((any) -> (), (any) -> (), CancelHook?) -> ()) -> any }
export type Animation = {
	read finished: any,
	read pending: boolean,
	read playState: "idle" | "running" | "paused" | "finished",
	read effect: { read getTiming: () -> { duration: number, delay: number, iterations: number } },
}
export type Element = {
	read getAnimations: ({ subtree: boolean? }?) -> { Animation },
	read hasAttribute: (string) -> boolean,
	read snapshotAttributes: () -> { [string]: string },
	read subscribeAttributes: (() -> ()) -> () -> (),
}
export type SourceAnimation = Animation
export type SourceElement = Element

local function create(promises: PromiseConstructor, qualify: ((any, string) -> ())?)
	assert(type(promises.new) == "function", "A native Promise constructor is required")
	local closed = false
	local cache: { [Css.PlaybackHandle]: Animation } = setmetatable({}, { __mode = "kv" })
	local pending: { [() -> ()]: boolean } = {}
	local function wrap(handles: { Css.PlaybackHandle }): { Animation }
		if closed then
			return Arrays.adopt({}, 0)
		end
		local result = {}
		for _, handle in handles do
			local animation = cache[handle]
			if not animation then
				local finished: any = nil
				local effect = {
					getTiming = function()
						local timing = handle.timing()
						local result = {
							duration = timing.duration * 1000,
							delay = timing.delay * 1000,
							iterations = timing.iterations,
						}
						if qualify then (qualify :: (any, string) -> ())(result, "timing") end
						return result
					end,
				}
				if qualify then (qualify :: (any, string) -> ())(effect, "effect") end
				table.freeze(effect)
				animation = table.freeze(setmetatable({}, {
					__index = function(_self, key): any
						if key == "pending" then
							return false
						end
						if key == "effect" then
							return effect
						end
						if key == "playState" then
							local state = handle.state()
							return if state == "canceled" then "idle" else state
						end
						if key == "finished" then
							if finished == nil then
								finished = promises.new(function(resolve, reject, onCancel)
									if closed then
										reject("CSS animation observer destroyed")
										return
									end
									local done = false
									local off: (() -> ())? = nil
									local dispose: () -> ()
									local function stop()
										pending[dispose] = nil
										if off then local release = off; off = nil; release() end
									end
									dispose = function()
										if done then return end
										done = true
										stop()
										reject("CSS animation observer destroyed")
									end
									pending[dispose] = true
									local success, subscription = pcall(handle.subscribe, function(outcome)
										if done then return end
										done = true
										stop()
										if outcome == "finished" then
											resolve(animation)
										else
											reject("CSS playback canceled")
										end
									end)
									if not success then done = true; stop(); error(subscription, 0) end
									if done then subscription() else off = subscription end
									if onCancel then onCancel(function()
										if done then return end
										done = true
										stop()
									end) end
								end)
							end
							return finished
						end
						return nil
					end,
				})) :: Animation
				cache[handle] = animation
				if qualify then (qualify :: (any, string) -> ())(animation, "animation") end
				Properties.register(animation, function(key)
					return key == "finished" or key == "pending" or key == "playState" or key == "effect"
				end)
			end
			table.insert(result, animation)
		end
		return Arrays.adopt(result, #result)
	end
	return table.freeze({
		wrap = wrap,
		target = function(context: Target.Context): Element
			local playbacks, attributes =
				assert(context.getPlaybacks, "Target cannot observe CSS playback"),
				assert(context.getAttributes, "Target cannot read attributes")
			return table.freeze({
				snapshotAttributes = attributes,
				subscribeAttributes = function(callback: () -> ())
					return context.subscribeScene(function(_revision)
						callback()
					end)
				end,
				getAnimations = function(options: { subtree: boolean? }?): { Animation }
					return wrap(playbacks(options and options.subtree))
				end,
				hasAttribute = function(name: string): boolean
					return attributes()[name] ~= nil
				end,
			})
		end,
		destroy = function()
			if closed then
				return
			end
			closed = true
			for dispose in table.clone(pending) do
				dispose()
			end
			table.clear(cache)
		end,
	})
end
function WebAnimations.create(promises: PromiseConstructor)
	return create(promises, nil)
end

-- Source schemas describe the actual read-only playback projection, not the
-- native implementation closures. Animation/effect members live on shared
-- source prototypes; timing is a fresh ordinary source dictionary.
local animationIdentities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local effectIdentities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local sourcePrototypeToken = {}
local animationFields = { finished = true, pending = true, playState = true, effect = true }
local animationPrototypeSchema = {
	hasOwn = function(_owner: any, key: any): boolean return animationFields[key] == true end,
	get = function(_owner: any, key: any, receiver: any): any
		assert(animationIdentities[receiver], "TypeError: Animation getter requires a playback observer")
		return receiver[key]
	end,
	ownKeys = function(): any return Arrays.adopt({ "finished", "pending", "playState", "effect" }, 4) end,
	enumerable = function(): boolean return true end,
}
local animationSchema = {
	tag = "Animation",
	hasOwn = function(): boolean return false end,
	get = function(): never error("Animation fields are inherited playback observations", 2) end,
	ownKeys = function(): any return Arrays.adopt({}, 0) end,
	enumerable = function(): boolean return false end,
	prototype = function(owner: any): any return (getmetatable(owner) :: any)[sourcePrototypeToken] end,
}
local effectPrototypeFieldsToken = {}
local effectPrototypeSchema = {
	hasOwn = function(_owner: any, key: any): boolean return key == "getTiming" end,
	get = function(owner: any): any return (getmetatable(owner) :: any)[effectPrototypeFieldsToken] end,
	ownKeys = function(): any return Arrays.adopt({ "getTiming" }, 1) end,
	enumerable = function(): boolean return true end,
}
local effectSchema = {
	tag = "AnimationEffect",
	hasOwn = function(): boolean return false end,
	get = function(): never error("AnimationEffect fields are inherited native observations", 2) end,
	ownKeys = function(): any return Arrays.adopt({}, 0) end,
	enumerable = function(): boolean return false end,
	prototype = function(owner: any): any return (getmetatable(owner) :: any)[sourcePrototypeToken] end,
}
function WebAnimations.createSource(ops: any, promises: any)
	local animationPrototype: any = {}
	local effectPrototype: any = {}
	ops.registerObject(animationPrototype, animationPrototypeSchema)
	local getTiming = ops.registerNative(function(receiver: any): any
		assert(effectIdentities[receiver], "TypeError: AnimationEffect.getTiming requires its native effect")
		return receiver.getTiming()
	end, "method", "getTiming", 0)
	setmetatable(effectPrototype, { [effectPrototypeFieldsToken] = getTiming })
	ops.registerObject(effectPrototype, effectPrototypeSchema)
	local context = create({ new = promises.Promise.new }, function(value: any, kind: string)
		if kind == "timing" then Records.adopt(value, { "duration", "delay", "iterations" })
		elseif kind == "effect" then
			effectIdentities[value] = true
			setmetatable(value, { [sourcePrototypeToken] = effectPrototype })
			ops.registerObject(value, effectSchema)
		else
			animationIdentities[value] = true
			local metadata = getmetatable(value) :: any
			metadata[sourcePrototypeToken] = animationPrototype
			ops.registerObject(value, animationSchema)
		end
	end)
	return table.freeze({ wrap = context.wrap, target = function(target: Target.Context): SourceElement
		local value = context.target(target)
		ops.registerNamespace(value, "AnimationElement")
		return value
	end, destroy = context.destroy })
end
return WebAnimations
