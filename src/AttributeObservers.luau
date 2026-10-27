--!strict
local Nulls = require(script.Parent.Nulls)
local Arrays = require(script.Parent.Arrays)
local DomElements = require(script.Parent.DomElements)
local AttributeObservers = {}
export type Target = {
	read snapshotAttributes: () -> { [string]: string },
	read subscribeAttributes: (() -> ()) -> () -> (),
}
export type Options = {
	attributes: boolean?,
	attributeOldValue: boolean?,
	attributeFilter: { string }?,
	subtree: boolean?,
	childList: boolean?,
	characterData: boolean?,
	characterDataOldValue: boolean?,
}
type Record = { [string]: any }
export type Observer = {
	read observe: (Target, Options) -> (),
	read disconnect: () -> (),
	read takeRecords: () -> { Record },
}

function AttributeObservers.create()
	local closed = false
	local releases: { [() -> ()]: boolean } = {}
	local function new(callback: ({ Record }, Observer) -> ()): Observer
		assert(not closed, "Attribute observer context is destroyed")
		local targets: { [Target]: () -> () } = {}
		local records: { Record } = {}
		local pending: thread? = nil
		local observer: Observer
		local function takeRecords(): { Record }
			local result = records
			records = {}
			return Arrays.adopt(result, #result)
		end
		local function enqueue(record: Record)
			table.insert(records, record)
			if not pending then
				pending = task.defer(function()
					pending = nil
					if #records > 0 then
						callback(takeRecords(), observer)
					end
				end)
			end
		end
		local function disconnect()
			if pending then
				task.cancel(pending)
				pending = nil
			end
			for _, off in targets do
				off()
			end
			table.clear(targets)
			table.clear(records)
			releases[disconnect] = nil
		end
		observer = table.freeze({
			takeRecords = takeRecords,
			disconnect = disconnect,
			observe = function(target: Target, options: Options)
				assert(not closed, "Attribute observer context is destroyed")
				assert(options.childList or options.attributes or options.characterData or options.attributeOldValue
					or options.attributeFilter or options.characterDataOldValue, "Mutation options must observe a change type")
				assert(options.attributes ~= false or not (options.attributeOldValue or options.attributeFilter), "Conflicting attribute options")
				assert(options.characterData ~= false or not options.characterDataOldValue, "Conflicting characterData options")
				if targets[target] then
					targets[target]()
					targets[target] = nil
				end
				local filter: { [string]: boolean } = {}
				local filtered = options.attributeFilter ~= nil
				if options.attributeFilter then
					for _, name in options.attributeFilter do
						filter[name] = true
					end
				end
				local oldValue = options.attributeOldValue == true
				local cleanups: { () -> () } = {}
				local watched: { [any]: boolean } = {}
				local function watch(element: any)
					if watched[element] or not (options.attributes or options.attributeOldValue or options.attributeFilter) then return end
					watched[element] = true
					local previous = element.snapshotAttributes()
					local off = element.subscribeAttributes(function()
						local current = element.snapshotAttributes()
						local names = {}
						for name in previous do names[name] = true end
						for name in current do names[name] = true end
						for name in names do
							if (not filtered or filter[name]) and previous[name] ~= current[name] then
								enqueue({ type = "attributes", target = element, attributeName = name,
									oldValue = if oldValue and previous[name] ~= nil then previous[name] else Nulls.value })
							end
						end
						previous = current
					end)
					table.insert(cleanups, off)
				end
				watch(target)
				local ok, root = pcall(DomElements.unwrap, target)
				if ok and root then
					local function parentElement(instance: Instance): any
						local parent = instance.Parent
						while parent and parent ~= root do
							local element = DomElements.fromNative(parent)
							if element then return element end
							parent = parent.Parent
						end
						return if parent == root then target else nil
					end
					if options.subtree then
						for _, instance in root:GetDescendants() do
							local element = DomElements.fromNative(instance)
							if element then watch(element) end
						end
					end
					local function changed(instance: Instance, added: boolean)
						local element = DomElements.fromNative(instance)
						if not element then return end
						local parent = parentElement(instance)
						if added and options.subtree then watch(element) end
						if options.childList and parent and (options.subtree or parent == target) then
							enqueue({ type = "childList", target = parent,
								addedNodes = Arrays.adopt(if added then { element } else {}, if added then 1 else 0),
								removedNodes = Arrays.adopt(if added then {} else { element }, if added then 0 else 1),
								previousSibling = Nulls.value, nextSibling = Nulls.value, attributeName = Nulls.value, oldValue = Nulls.value })
						end
					end
					local added = root.DescendantAdded:Connect(function(instance) changed(instance, true) end)
					local removing = root.DescendantRemoving:Connect(function(instance) changed(instance, false) end)
					table.insert(cleanups, function() added:Disconnect(); removing:Disconnect() end)
				end
				targets[target] = function() for _, off in cleanups do off() end end
				releases[disconnect] = true
			end,
		})
		return observer
	end
	return table.freeze({
		constructor = table.freeze({ new = new }),
		destroy = function()
			if closed then
				return
			end
			closed = true
			for release in table.clone(releases) do
				release()
			end
		end,
	})
end
return AttributeObservers
