--!nocheck
-- Detached document elements used as browser-managed portal containers.
local Operations = require(script.Parent.SourceOperations)
local DomClasses = require(script.Parent.DomClasses)
local Nulls = require(script.Parent.Nulls)
local nodes = setmetatable({}, { __mode = 'k' })
local function state(node) return assert(nodes[node], 'Invalid detached element') end
local function contains(node, other)
 local cursor = other
 while nodes[cursor] do
  if cursor == node then return true end
  cursor = state(cursor).parent
 end
 return false
end
DomClasses.registerImplementation('element', {
 read = function(node, key)
  local s = state(node)
  if key == 'nodeType' then return 1 end
  if key == 'nodeName' then return s.tag end
  if key == 'ownerDocument' then return s.document end
  if key == 'isConnected' then return contains(s.body, node) end
  error('Unsupported detached node field: ' .. key)
 end,
 contains = contains,
})
local M = {}
function M.create(document, tag, body)
 local node = Operations.object(DomClasses.prototype('element'))
 local s = { document = document, tag = string.upper(tag), parent = nil, children = {}, attributes = {}, body = body }
 nodes[node] = s
 if not body then s.body = node end
 DomClasses.register(node, 'element')
 local function field(name, value) Operations.defineDataProperty(node, name, value, true, true, true) end
 local function method(name, fn, count) field(name, Operations.registerNative(fn, 'method', name, count)) end
 local function parent(n) return state(n).parent or Nulls.value end
 Operations.defineAccessor(node, 'parentNode', Operations.registerNative(parent, 'method', 'get parentNode', 0), nil, true, true)
 field('tagName', s.tag)
 method('appendChild', function(self, child)
  local target, item = state(self), state(child)
  assert(self ~= child and not contains(child, self), 'Cannot create a DOM cycle')
  if item.parent then local siblings = state(item.parent).children; table.remove(siblings, assert(table.find(siblings, child))) end
  item.parent = self; table.insert(target.children, child); return child
 end, 1)
 method('removeChild', function(self, child)
  local children = state(self).children
  local index = assert(table.find(children, child), 'Node is not a child')
  table.remove(children, index); state(child).parent = nil; return child
 end, 1)
 method('remove', function(self) local p = state(self).parent; if p then Operations.call(Operations.get(p, 'removeChild'), p, Operations.array({self}, 1)) end end, 0)
 method('setAttribute', function(self, name, value) state(self).attributes[Operations.string(name)] = Operations.string(value) end, 2)
 method('getAttribute', function(self, name) return state(self).attributes[Operations.string(name)] or Nulls.value end, 1)
 method('hasAttribute', function(self, name) return state(self).attributes[Operations.string(name)] ~= nil end, 1)
 method('removeAttribute', function(self, name) state(self).attributes[Operations.string(name)] = nil end, 1)
 method('querySelector', function(self, selector)
  local text = Operations.string(selector)
  local attr = text:match('^%[([%w_%-]+)%]$')
  local id = text:match('^#([%w_%-]+)$')
  assert(attr or id or text:match('^[%a][%w_%-]*$'), 'Unsupported detached element selector')
  local function search(n)
   for _, child in state(n).children do
    local item = state(child)
    if (attr and item.attributes[attr] ~= nil) or (id and item.attributes.id == id) or (not attr and not id and item.tag:lower() == text:lower()) then return child end
    local found = search(child); if found then return found end
   end
  end
  return search(self) or Nulls.value
 end, 1)
 return node
end
function M.is(node) return nodes[node] ~= nil end
function M.compareOrder(a, b)
 local function path(node)
  local result = {}
  while node do table.insert(result, 1, node); node = state(node).parent end
  return result
 end
 local left, right = path(a), path(b)
 if left[1] ~= right[1] then return 1 end
 local i = 1
 while left[i] == right[i] do i += 1 end
 local siblings = state(left[i - 1]).children
 return if table.find(siblings, left[i]) < table.find(siblings, right[i]) then 4 else 2
end
return M
