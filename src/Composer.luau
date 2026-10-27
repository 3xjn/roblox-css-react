--!strict

local Css = require(script.Parent.Runtime)
local Tree = require(script.Parent.Tree)

export type Handle = {}
export type Placement = { parent: Handle?, sourceOrder: number, props: Css.NodeOptions? }
type Entry = { parent: Handle?, sourceOrder: number, props: Css.NodeOptions }
export type Options = { onDiagnostic: ((string) -> ())? }

local Composer = {}

-- Registrations are logical data only. Native ownership begins at attach;
-- independent component layout effects coalesce into one descriptor commit.
function Composer.create(options: Options?)
	local owners = setmetatable({}, { __mode = "k" }) :: { [Handle]: number }
	local entries: { [Handle]: Entry } = {}
	local nextId = 0
	local tree: Tree.Controller? = nil
	local destroyed = false
	local scheduled = false
	local generation = 0
	local flushing = false
	local dirty = false
	local schedule: () -> ()
	local listeners: { [() -> ()]: boolean } = {}
	local composer = {}
	local function report(reason: string)
		if options and options.onDiagnostic then
			local ok, failure = pcall(options.onDiagnostic, reason)
			if not ok then
				warn(failure)
			end
		else
			warn(reason)
		end
	end
	local function notify()
		for listener in table.clone(listeners) do
			if listeners[listener] then
				local ok, failure = pcall(listener)
				if not ok then
					report(tostring(failure))
				end
			end
		end
	end
	local function assertOwned(handle: Handle)
		assert(owners[handle] ~= nil, "CSS node handle belongs to another composer")
	end
	local function describe(): { Tree.Element }
		local children: { [Handle]: { Handle } } = {}
		local roots: { Handle } = {}
		local count = 0
		for handle, entry in entries do
			count += 1
			if entry.parent then
				assert(entries[entry.parent], "CSS component parent is not registered")
				local siblings = children[entry.parent]
				if not siblings then
					siblings = {}
					children[entry.parent] = siblings
				end
				table.insert(siblings, handle)
			else
				table.insert(roots, handle)
			end
		end
		local visited = 0
		local function visit(siblings: { Handle }): { Tree.Element }
			table.sort(siblings, function(a, b)
				return entries[a].sourceOrder < entries[b].sourceOrder
			end)
			local result = {}
			local previous: number? = nil
			for _, handle in siblings do
				local entry = entries[handle]
				assert(previous ~= entry.sourceOrder, "CSS siblings need distinct sourceOrder values")
				previous = entry.sourceOrder
				visited += 1
				table.insert(result, {
					key = owners[handle],
					props = entry.props,
					children = visit(children[handle] or {}),
				})
			end
			return result
		end
		local result = visit(roots)
		assert(visited == count, "CSS component tree contains a parent cycle")
		return result
	end
	function composer.flush(): (boolean, string?)
		assert(not destroyed, "CSS composer has been destroyed")
		if flushing then
			return false, "Reentrant CSS component commit"
		end
		generation += 1
		scheduled = false
		local current = tree
		if not current then
			return false, "CSS composer has no attached host"
		end
		local ok, result = pcall(describe)
		if not ok then
			return false, tostring(result)
		end
		flushing = true
		local committed, failure = pcall(current.commit, result)
		if committed or not current.getHost() then
			notify()
		end
		flushing = false
		if dirty then
			dirty = false
			schedule()
		end
		return committed, if committed then nil else tostring(failure)
	end
	schedule = function()
		if scheduled or not tree then
			return
		end
		if flushing then
			dirty = true
			return
		end
		scheduled = true
		local version = generation
		task.defer(function()
			if destroyed or version ~= generation then
				return
			end
			local ok, failure = composer.flush()
			if not ok then
				report(failure or "CSS component commit failed")
			end
		end)
	end
	function composer.createHandle(): Handle
		assert(not destroyed, "CSS composer has been destroyed")
		nextId += 1
		assert(nextId < 2 ^ 53, "CSS component identity space exhausted")
		local handle = {}
		owners[handle] = nextId
		return handle
	end
	function composer.update(handle: Handle, placement: Placement)
		assert(not destroyed, "CSS composer has been destroyed")
		assertOwned(handle)
		if placement.parent then
			assertOwned(placement.parent)
		end
		local order = placement.sourceOrder
		assert(order == order and math.abs(order) < math.huge, "CSS sourceOrder must be finite")
		local source: Css.NodeOptions = placement.props or {}
		local props = table.clone(source)
		props.attributes = table.clone(props.attributes or {})
		props.states = table.clone(props.states or {})
		entries[handle] = { parent = placement.parent, sourceOrder = order, props = props }
		schedule()
	end
	function composer.remove(handle: Handle)
		assert(not destroyed, "CSS composer has been destroyed")
		assertOwned(handle)
		entries[handle] = nil
		schedule()
	end
	function composer.attach(host: Css.Host)
		assert(not destroyed, "CSS composer has been destroyed")
		assert(not tree, "CSS composer already owns a host")
		tree = Tree.create(host)
		schedule()
	end
	function composer.detach()
		generation += 1
		scheduled = false
		dirty = false
		local previous = tree
		tree = nil
		notify()
		if previous then
			previous.destroy()
		end
	end
	function composer.getNode(handle: Handle): Css.Node?
		if destroyed then
			return nil
		end
		assertOwned(handle)
		return if tree then tree.getNode(owners[handle]) else nil
	end
	function composer.getHost(): Css.Host?
		return if tree then tree.getHost() else nil
	end
	function composer.subscribe(listener: () -> ()): () -> ()
		assert(not destroyed, "CSS composer has been destroyed")
		listeners[listener] = true
		return function()
			listeners[listener] = nil
		end
	end
	function composer.destroy()
		if destroyed then
			return
		end
		destroyed = true
		composer.detach()
		table.clear(entries)
		table.clear(owners)
		table.clear(listeners)
	end
	return composer
end

export type Controller = typeof(Composer.create())
return Composer
