--!strict
-- Intersection observation follows committed native geometry and clipping.
-- No animation-frame scan or periodic retry is used.
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
type Record = { [string]: any }
local SourceIntersection = {}

local function native(value: any): GuiObject?
	if typeof(value) == "Instance" then
		local target = value :: Instance
		if target:IsA("GuiObject") then
			return target
		end
	end
	if type(value) == "table" then
		local target = rawget(value :: { [string]: any }, "_instance")
		if typeof(target) == "Instance" then
			local instance = target :: Instance
			if instance:IsA("GuiObject") then
				return instance
			end
		end
	end
	return nil
end
local function rect(x: number, y: number, width: number, height: number): Record
	return { x = x, y = y, width = width, height = height, top = y, left = x, right = x + width, bottom = y + height }
end
local function measure(value: any): Record
	if type(value) == "table" and type(value.getBoundingClientRect) == "function" then
		local box = (value.getBoundingClientRect :: (any) -> any)(value)
		return rect(box.x or box.left, box.y or box.top, box.width, box.height)
	end
	local target = native(value)
	assert(target, "Intersection target must expose committed native geometry")
	return rect(target.AbsolutePosition.X, target.AbsolutePosition.Y, target.AbsoluteSize.X, target.AbsoluteSize.Y)
end
local function marginParts(value: string): { { value: number, percent: boolean } }
	local result = {}
	for part in value:gmatch("%S+") do
		local amount, unit = part:match("^([%+%-]?%d*%.?%d+)(px)$")
		if not amount then
			amount, unit = part:match("^([%+%-]?%d*%.?%d+)(%%)$")
		end
		assert(amount and unit, "Intersection rootMargin supports pixel or percentage lengths")
		table.insert(result, { value = tonumber(amount) :: number, percent = unit == "%" })
	end
	assert(#result >= 1 and #result <= 4, "Intersection rootMargin needs one to four lengths")
	local top = result[1]
	local right = result[2] or top
	local bottom = result[3] or top
	local left = result[4] or right
	return { top, right, bottom, left }
end

function SourceIntersection.create()
	local owned: { [() -> ()]: boolean } = {}
	local destroyed = false
	local function construct(callback: (any, any) -> (), options: any?): Record
		assert(not destroyed, "Intersection observer owner is destroyed")
		local opts: Record = if Nulls.isNullish(options) then {} else options
		local root = if Nulls.isNullish(opts.root) then nil else opts.root
		local margin = marginParts(opts.rootMargin or "0px")
		local thresholds: { number } = {}
		if type(opts.threshold) == "number" then
			table.insert(thresholds, opts.threshold)
		elseif type(opts.threshold) == "table" and not Nulls.isNull(opts.threshold) then
			for _, threshold in opts.threshold do
				table.insert(thresholds, threshold)
			end
		end
		if #thresholds == 0 then
			table.insert(thresholds, 0)
		end
		for _, threshold in thresholds do
			assert(threshold >= 0 and threshold <= 1, "Intersection threshold must be between zero and one")
		end
		table.sort(thresholds)
		local observer: Record = {}
		local targets: { [any]: Record } = {}
		local pending: { any } = {}
		local delivery: thread? = nil
		local alive = true
		local function deliver()
			if delivery then
				return
			end
			delivery = task.defer(function()
				delivery = nil
				if alive and #pending > 0 then
					local entries = pending
					pending = {}
					callback(Arrays.adopt(entries, #entries), observer)
				end
			end)
		end
		local function unobserve(a: any, b: any?)
			local target = if a == observer then b else a
			local state = targets[target]
			if state then
				targets[target] = nil
				for _, cleanup in state.cleanups do
					cleanup()
				end
				if state.reaction then
					task.cancel(state.reaction)
				end
			end
		end
		local function disconnect()
			for target in table.clone(targets) do
				unobserve(target)
			end
			if delivery then
				task.cancel(delivery)
				delivery = nil
			end
			table.clear(pending)
		end
		local function release()
			if not alive then
				return
			end
			alive = false
			disconnect()
			owned[release] = nil
		end
		owned[release] = true
		local function observe(a: any, b: any?)
			local Workspace = game:GetService("Workspace")
			assert(alive and not destroyed, "Intersection observer owner is destroyed")
			local target = if a == observer then b else a
			assert(not Nulls.isNullish(target), "Intersection target is required")
			if targets[target] then
				return
			end
			local state: Record =
				{ cleanups = {}, ratio = nil, intersecting = nil, reaction = nil, hierarchyDirty = true }
			targets[target] = state
			local function update()
				if targets[target] ~= state then
					return
				end
				local bounds = measure(target)
				local rootBounds: Record
				if root then
					rootBounds = measure(root)
				else
					local camera = Workspace.CurrentCamera
					assert(camera, "Viewport intersection observation needs the native current camera")
					rootBounds = rect(0, 0, camera.ViewportSize.X, camera.ViewportSize.Y)
				end
				local expanded = {}
				for index, part in margin do
					expanded[index] = part.value * (if part.percent then rootBounds.width / 100 else 1)
				end
				rootBounds = rect(
					rootBounds.x - expanded[4],
					rootBounds.y - expanded[1],
					rootBounds.width + expanded[2] + expanded[4],
					rootBounds.height + expanded[1] + expanded[3]
				)
				local clip = rootBounds
				local emptyClip = false
				local ancestor: Instance? = native(target)
				ancestor = if ancestor then ancestor.Parent else nil
				while ancestor do
					if ancestor:IsA("GuiObject") and (ancestor.ClipsDescendants or ancestor:IsA("ScrollingFrame")) then
						local box = measure(ancestor)
						local x, y = math.max(clip.left, box.left), math.max(clip.top, box.top)
						if math.min(clip.right, box.right) < x or math.min(clip.bottom, box.bottom) < y then
							emptyClip = true
						end
						clip = rect(
							x,
							y,
							math.max(0, math.min(clip.right, box.right) - x),
							math.max(0, math.min(clip.bottom, box.bottom) - y)
						)
					end
					ancestor = ancestor.Parent
				end
				local left, top = math.max(bounds.x, clip.x), math.max(bounds.y, clip.y)
				local right, bottom =
					math.min(bounds.x + bounds.width, clip.x + clip.width),
					math.min(bounds.y + bounds.height, clip.y + clip.height)
				local intersecting = not emptyClip and right >= left and bottom >= top
				local nativeRoot, nativeTarget = native(root), native(target)
				if
					nativeRoot
					and nativeTarget
					and nativeRoot ~= nativeTarget
					and not nativeTarget:IsDescendantOf(nativeRoot)
				then
					intersecting = false
				end
				local current: Instance? = native(target)
				while current do
					if current:IsA("GuiObject") and not current.Visible then
						intersecting = false
						break
					end
					current = current.Parent
				end
				local width, height =
					if intersecting then math.max(0, right - left) else 0,
					if intersecting then math.max(0, bottom - top) else 0
				local area = bounds.width * bounds.height
				local ratio = if area > 0 then width * height / area elseif intersecting then 1 else 0
				local changed = state.ratio == nil or intersecting ~= state.intersecting
				if not changed then
					for _, threshold in thresholds do
						if
							(state.ratio < threshold and ratio >= threshold)
							or (ratio < threshold and state.ratio >= threshold)
						then
							changed = true
							break
						end
					end
				end
				state.ratio, state.intersecting = ratio, intersecting
				if changed then
					table.insert(pending, {
						target = target,
						isIntersecting = intersecting,
						intersectionRatio = ratio,
						time = os.clock() * 1000,
						boundingClientRect = bounds,
						intersectionRect = rect(left, top, width, height),
						rootBounds = rootBounds,
					})
					deliver()
				end
			end
			local rewire: () -> () = function() end
			local function request()
				if state.reaction or targets[target] ~= state then
					return
				end
				if native(target) ~= state.nativeTarget or native(root) ~= state.nativeRoot then
					state.hierarchyDirty = true
				end
				state.reaction = task.defer(function()
					state.reaction = nil
					if targets[target] ~= state then
						return
					end
					if state.hierarchyDirty then
						state.hierarchyDirty = false
						rewire()
					end
					update()
				end)
			end
			local function connect(signal: RBXScriptSignal, hierarchy: boolean?)
				local connection = signal:Connect(function()
					if hierarchy then
						state.hierarchyDirty = true
					end
					request()
				end)
				table.insert(state.cleanups, function()
					connection:Disconnect()
				end)
			end
			rewire = function()
				for _, cleanup in state.cleanups do
					cleanup()
				end
				table.clear(state.cleanups)
				state.nativeTarget, state.nativeRoot = native(target), native(root)
				for _, value in { target, root } do
					if type(value) == "table" then
						local observers = rawget(value, "_observers")
						if type(observers) == "table" then
							(observers :: any)[request] = true
							table.insert(state.cleanups, function()
								(observers :: any)[request] = nil
							end)
						end
					end
					local node: Instance? = native(value)
					while node do
						if node:IsA("GuiObject") then
							for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible", "ClipsDescendants" } do
								connect(node:GetPropertyChangedSignal(property))
							end
							if node:IsA("ScrollingFrame") then
								connect(node:GetPropertyChangedSignal("CanvasPosition"))
							end
						end
						connect(node.AncestryChanged, true)
						node = node.Parent
					end
				end
				local camera = Workspace.CurrentCamera
				if camera then
					connect(camera:GetPropertyChangedSignal("ViewportSize"))
				end
				connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), true)
			end
			request()
		end
		observer.observe, observer.unobserve, observer.disconnect = observe, unobserve, disconnect
		observer.takeRecords = function(): any
			local result = pending
			pending = {}
			return Arrays.adopt(result, #result)
		end
		observer.root, observer.rootMargin, observer.thresholds =
			root or Nulls.value, opts.rootMargin or "0px", Arrays.adopt(thresholds, #thresholds)
		return observer
	end
	local constructor = setmetatable({ new = construct }, {
		__call = function(_self, callback: (any, any) -> (), options: any?): Record
			return construct(callback, options)
		end,
	})
	return {
		constructor = constructor,
		destroy = function()
			destroyed = true
			for release in table.clone(owned) do
				release()
			end
		end,
	}
end
return SourceIntersection
