--!strict
-- A browser API boundary, independent of any consuming package. Network-special
-- URLs and scalar UTF-8 form queries are implemented here; IDNA and other URL
-- schemes are explicit capability gaps, not successful partial parses.
local Parser = require(script.Parent.SourceURLParser)
local Codec = require(script.Parent.SourceURLCodec)
local Params = require(script.Parent.SourceURLSearchParams)
local Arrays = require(script.Parent.Arrays)
local Symbols = require(script.Parent.SourceSymbols)
local URL = {}
local token = {}
local function component(value: string): string return (string.gsub(value, "[\t\r\n]", "")) end
function URL.create(ops: any): any
	local closed = false
	local query = Params.create(ops)
	local function invalid(message: string): never return ops.intrinsicError("TypeError", message) end
	local function state(owner: any): any
		local meta: any = if type(owner) == "table" then getmetatable(owner) else nil
		if type(meta) ~= "table" or not meta[token] then return invalid("URL method requires its receiver") end
		return meta[token]
	end
	local constructor = ops.classValue("URL", nil, false, function(frame: any, args: any)
		assert(not closed, "Source URL realm is destroyed")
		if Arrays.length(args) < 1 then invalid("URL requires an input") end
		local input = ops.string(args[1])
		local base = if args[2] ~= nil then ops.string(args[2]) else nil
		local parent = if base then Parser.parse(base) else nil
		if base and not parent then invalid("Invalid URL") end
		local parsed = Parser.parse(input, parent)
		if not parsed then invalid("Invalid URL") end
		local parts = parsed :: Parser.Parts
		local owner = ops.classThis(frame)
		local current: any = { parts = parts }
		current.params = query.make(parts.query or "", function(serialized: string)
			current.parts.query = if serialized == "" then nil else serialized
		end)
		local meta = table.clone(getmetatable(owner) :: any)
		meta[token] = current
		setmetatable(owner, meta)
	end, nil, 1)
	local prototype = ops.get(constructor, "prototype")
	ops.defineDataProperty(prototype, Symbols.Symbol.toStringTag, "URL", false, false, true)
	local function replace(current: any, parts: Parser.Parts)
		current.parts = parts
		query.replace(current.params, parts.query or "")
	end
	local function property(name: string, get: (any) -> any, set: ((any, string) -> ())?, convertBeforeReceiver: boolean?)
		local getter = ops.functionValue(function(owner: any): any return get(state(owner)) end, "get " .. name, 0, "method")
		local setter = if set then ops.functionValue(function(owner: any, args: any)
			-- URL.href's legacy stringifier setter converts before its brand
			-- check; the other WebIDL attribute setters check their receiver first.
			local text = if convertBeforeReceiver then ops.string(args[1]) else nil
			local current = state(owner)
			local apply = set :: (any, string) -> ()
			apply(current, text or ops.string(args[1]))
		end, "set " .. name, 1, "method") else nil
		ops.defineAccessor(prototype, name, getter, setter, true, true)
	end
	property("href", function(current) return Parser.serialize(current.parts) end, function(current, text)
		local parsed = Parser.parse(text)
		if not parsed then invalid("Invalid URL") end
		replace(current, parsed :: Parser.Parts)
	end, true)
	property("origin", function(current) return current.parts.scheme .. "://" .. Parser.hostString(current.parts) end, nil)
	property("protocol", function(current) return current.parts.scheme .. ":" end, function(current, text)
		local scheme = string.match(component(text), "^([A-Za-z][A-Za-z0-9+.-]*):")
		if not scheme then scheme = string.match(component(text), "^([A-Za-z][A-Za-z0-9+.-]*)$") end
		if not scheme then return end
		scheme = string.lower(scheme)
		if not (Parser.ports :: any)[scheme] then return end
		current.parts.scheme = scheme
		if tonumber(current.parts.port) == (Parser.ports :: any)[scheme] then current.parts.port = "" end
	end)
	for _, key in { "username", "password" } do
		local name = key
		property(name, function(current) return current.parts[name] end, function(current, text) current.parts[name] = Codec.encode(text, "userinfo") end)
	end
	property("host", function(current) return Parser.hostString(current.parts) end, function(current, text)
		text = string.match(component(text), "^[^/\\?#]*") or ""
		local host, port = Parser.hostPort(text, current.parts.scheme, true)
		if not host then return end
		current.parts.hostname = host
		local hasPort = if string.sub(text, 1, 1) == "[" then string.find(text, "]:", 1, true) ~= nil else string.find(text, ":", 1, true) ~= nil
		-- Parsing a host setter commits its hostname before the port parser.
		-- An empty or invalid port leaves the existing port intact.
		if hasPort and port and port ~= "" then current.parts.port = port
		elseif hasPort and port == "" and string.sub(text, -1) ~= ":" then current.parts.port = "" end
	end)
	property("hostname", function(current) return current.parts.hostname end, function(current, text)
		text = string.match(component(text), "^[^/\\?#]*") or ""
		local host = Parser.host(text)
		if host then current.parts.hostname = host end
	end)
	property("port", function(current) return current.parts.port end, function(current, text)
		text = component(text)
		local digits = if text == "" then "" else string.match(text, "^[0-9]+")
		if digits == nil then return end
		local selected = Parser.port(digits, current.parts.scheme)
		if selected then current.parts.port = selected end
	end)
	property("pathname", function(current) return current.parts.path end, function(current, text)
		current.parts.path = Parser.path((string.gsub(component(text), "\\", "/")))
	end)
	property("search", function(current)
		return if current.parts.query == nil or current.parts.query == "" then "" else "?" .. current.parts.query
	end, function(current, text)
		text = component(text)
		if text == "" then current.parts.query = nil
		else current.parts.query = Codec.encode(if string.sub(text, 1, 1) == "?" then string.sub(text, 2) else text, "query") end
		query.replace(current.params, current.parts.query or "")
	end)
	property("hash", function(current)
		return if current.parts.fragment == nil or current.parts.fragment == "" then "" else "#" .. current.parts.fragment
	end, function(current, text)
		text = component(text)
		current.parts.fragment = if text == "" then nil else Codec.encode(if string.sub(text, 1, 1) == "#" then string.sub(text, 2) else text, "fragment")
	end)
	property("searchParams", function(current) return current.params end, nil)
	for _, name in { "toString", "toJSON" } do
		ops.defineDataProperty(prototype, name, ops.functionValue(function(owner: any): string return Parser.serialize(state(owner).parts) end, name, 0, "method"), true, true, true)
	end
	return {
		URL = constructor, URLSearchParams = query.Constructor,
		destroy = function() if closed then return end; closed = true; query.destroy() end,
	}
end
return URL
