--!strict
-- Native observer ownership shared by document/window contexts.
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local DomElements = require(script.Parent.DomElements)
type Record = { [string]: any }
local SourceObservers = {}
local function native(value: any): GuiObject?
	if typeof(value) == "Instance" then
		local target = value :: Instance
		if target:IsA("GuiObject") then
			return target
		end
	end
	if type(value) == "table" then
		local ok, mounted = pcall(DomElements.unwrap, value)
		if ok then return mounted end
		local inst = rawget(value :: { [string]: any }, "_instance")
		if typeof(inst) == "Instance" then
			local instance = inst :: Instance
			if instance:IsA("GuiObject") then
				return instance
			end
		end
	end
	return nil
end
function SourceObservers.create()
	local releases: { [() -> ()]: boolean } = {}
	local destroyed = false
	local function resize(callback: (any, any) -> ()): Record
		local observer: Record = {}
		local observed: { [any]: Record } = {}
		local function unobserve(a: any, b: any?)
			local target = if a == observer then b else a
			local state = observed[target]
			if not state then
				return
			end
			observed[target] = nil
			for _, cleanup in state.cleanups do
				cleanup()
			end
			if state.pending then
				task.cancel(state.pending)
			end
		end
		local function disconnect()
			for target in table.clone(observed) do
				unobserve(target)
			end
		end
		local function release()
			disconnect()
			releases[release] = nil
		end
		releases[release] = true
		local function observe(a: any, b: any?, c: any?)
			assert(not destroyed, "Observer owner is destroyed")
			local target = if a == observer then b else a
			local options = if a == observer then c else b
			assert(not Nulls.isNullish(target), "Resize target required")
			if observed[target] then
				unobserve(target)
			end
			local box = if type(options) == "table" then options.box else nil
			assert(
				box == nil or box == "content-box" or box == "border-box" or box == "device-pixel-content-box",
				"Unsupported resize box"
			)
			local state: Record = { cleanups = {}, width = nil, height = nil, pending = nil }
			observed[target] = state
			local request: () -> ()
			table.insert(state.cleanups, function()
				if state.connection then
					(state.connection :: RBXScriptConnection):Disconnect()
					state.connection = nil
				end
			end)
			local function check()
				state.pending = nil
				if observed[target] ~= state then
					return
				end
				local inst = native(target)
				if inst ~= state.instance then
					if state.connection then
						(state.connection :: RBXScriptConnection):Disconnect()
						state.connection = nil
					end
					state.instance = inst
					if inst then
						state.connection = inst:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
							request()
						end)
					end
				end
				local bounds: Record
				if type(target) == "table" and type(target.getBoundingClientRect) == "function" then
					bounds = (target.getBoundingClientRect :: (any) -> any)(target)
				elseif inst then
					bounds = { x = 0, y = 0, width = inst.AbsoluteSize.X, height = inst.AbsoluteSize.Y }
				else
					return
				end
				local context = if type(target) == "table" then rawget(target, "_context") else nil
				local layout = if context then (context :: any).getLayoutBox() else nil
				local width, height =
					if layout then layout.contentWidth else bounds.width,
					if layout then layout.contentHeight else bounds.height
				local selectedWidth, selectedHeight =
					if box == "border-box" then bounds.width else width,
					if box == "border-box" then bounds.height else height
				if state.width == selectedWidth and state.height == selectedHeight then
					return
				end
				state.width, state.height = selectedWidth, selectedHeight
				local content = { inlineSize = width, blockSize = height }
				local border = { inlineSize = bounds.width, blockSize = bounds.height }
				callback(
					Arrays.adopt({
						{
							target = target,
							contentRect = {
								x = 0,
								y = 0,
								left = 0,
								top = 0,
								right = width,
								bottom = height,
								width = width,
								height = height,
							},
							contentBoxSize = Arrays.adopt({ content }, 1),
							borderBoxSize = Arrays.adopt({ border }, 1),
							devicePixelContentBoxSize = Arrays.adopt({ content }, 1),
						},
					}, 1),
					observer
				)
			end
			request = function()
				if not state.pending then
					state.pending = task.defer(check)
				end
			end
			if type(target) == "table" and type(rawget(target, "_observers")) == "table" then
				local hooks = rawget(target, "_observers") :: any
				hooks[request] = true
				table.insert(state.cleanups, function()
					hooks[request] = nil
				end)
			end
			request()
		end
		observer.observe, observer.unobserve, observer.disconnect = observe, unobserve, disconnect
		return observer
	end
	local function mutation(callback: (any, any) -> ()): Record
		local observer: Record = {}
		local observed: { [any]: () -> () } = {}
		local records: { any } = {}
		local scheduled: thread? = nil
		local function takeRecords(): any
			local result = records
			records = {}
			return Arrays.adopt(result, #result)
		end
		local function disconnect()
			for target, cleanup in table.clone(observed) do
				observed[target] = nil
				cleanup()
			end
			if scheduled then
				task.cancel(scheduled)
				scheduled = nil
			end
			table.clear(records)
		end
		local function release()
			disconnect()
			releases[release] = nil
		end
		releases[release] = true
		local function observe(a: any, b: any?, c: any?)
			assert(not destroyed, "Observer owner is destroyed")
			local target = if a == observer then b else a
			local options: Record = (if a == observer then c else b) or {}
			assert(type(target) == "table", "Mutation target must be a native DOM proxy")
			assert(
				options.attributes
					or options.childList
					or options.characterData
					or options.attributeFilter
					or options.attributeOldValue
					or options.characterDataOldValue,
				"Mutation options must observe a change type"
			)
			if observed[target] then
				observed[target]()
			end
			local hooks = rawget(target, "_mutationObservers") :: any
			assert(type(hooks) == "table", "Mutation target must belong to the native browser boundary")
			local function receive(record: Record)
				if record.target ~= target and not options.subtree then
					return
				end
				if record.type == "attributes" then
					if not (options.attributes or options.attributeFilter or options.attributeOldValue) then
						return
					end
					if options.attributeFilter and not table.find(options.attributeFilter, record.attributeName) then
						return
					end
				elseif record.type == "childList" and not options.childList then
					return
				elseif
					record.type == "characterData" and not (options.characterData or options.characterDataOldValue)
				then
					return
				end
				local entry = table.clone(record)
				if record.type == "attributes" and not options.attributeOldValue then
					entry.oldValue = Nulls.value
				end
				if record.type == "characterData" and not options.characterDataOldValue then
					entry.oldValue = Nulls.value
				end
				table.insert(records, entry)
				if not scheduled then
					scheduled = task.defer(function()
						scheduled = nil
						if #records > 0 then
							callback(takeRecords(), observer)
						end
					end)
				end
			end
			hooks[receive] = true
			observed[target] = function()
				hooks[receive] = nil
			end
		end
		observer.observe, observer.disconnect, observer.takeRecords = observe, disconnect, takeRecords
		return observer
	end
	local function constructor(factory: (any) -> Record): any
		return setmetatable({ new = factory }, {
			__call = function(_self, callback: any)
				return factory(callback)
			end,
		})
	end
	return {
		ResizeObserver = constructor(resize),
		MutationObserver = constructor(mutation),
		destroy = function()
			destroyed = true
			for release in table.clone(releases) do
				release()
			end
		end,
	}
end
return SourceObservers
