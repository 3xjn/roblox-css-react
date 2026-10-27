--!strict
-- Runtime-local Cookie Store operations. No HTTP/account cookie access, disk
-- persistence, service workers, change-event monitors or expiration polling.
local Nulls = require(script.Parent.Nulls)
local Records = require(script.Parent.Records)
local Arrays = require(script.Parent.Arrays)
local Errors = require(script.Parent.SourceErrors)
local Numbers = require(script.Parent.SourceNumbers)
local SourceURL = require(script.Parent.SourceURL)
local CookieStore = {}
type Record = { [string]: any }
export type Options = { Promise: any, now: (() -> number)?, url: string? }
local function invalid(message: string): never
	error(Errors.TypeError(message), 3)
end
local function scalar(value: any): string
	local result: string
	if value == nil then result = "undefined"
	elseif Nulls.isNull(value) then result = "null"
	elseif type(value) == "number" then result = Numbers.toString(value)
	elseif type(value) == "boolean" then result = tostring(value)
	elseif type(value) == "string" then result = value
	else return invalid("Cookie Store strings require primitive values") end
	if not utf8.len(result) then invalid("Cookie Store strings require scalar UTF-8") end
	for _, code in utf8.codes(result) do
		if code >= 0xD800 and code <= 0xDFFF then invalid("Cookie Store strings require scalar UTF-8") end
	end
	return result
end
local function trim(value: string): string
	return (value:gsub("^[\t ]+", ""):gsub("[\t ]+$", ""))
end
local function finite(value: any, name: string): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return invalid("Cookie Store " .. name .. " requires a finite number")
	end
	return value
end
local function nullable(value: any): any
	return if Nulls.isNullish(value) then nil else value
end
local function unsafe(value: string): boolean
	for index = 1, #value do
		local byte = string.byte(value, index)
		if byte == 59 or byte == 127 or byte < 32 and byte ~= 9 then return true end
	end
	return false
end
function CookieStore.create(options: Options)
	local Promise = options.Promise
	assert(type(Promise) == "table", "Cookie Store requires a SourcePromise constructor")
	local url = SourceURL.URL.new(options.url or "https://roblox.invalid/")
	assert(url.protocol == "https:", "The in-memory Cookie Store requires a secure document URL")
	local now = options.now or function() return DateTime.now().UnixTimestampMillis end
	local cookies: { Record } = {}
	local closed = false
	local store: Record = {}
	local function operation(callback: () -> any): any
		local ok, result = pcall(function()
			if closed then invalid("Cookie Store owner is destroyed") end
			return callback()
		end)
		return if ok then Promise.resolve(result) else Promise.reject(result)
	end
	local function purge()
		local clock = now()
		for index = #cookies, 1, -1 do
			local expires = cookies[index].expires
			if expires ~= nil and expires <= clock then table.remove(cookies, index) end
		end
	end
	local function defaultPath(): string
		local path = url.pathname
		local final = path:match("^(.+)/")
		return if final and final ~= "" then final else "/"
	end
	local function keyOptions(input: Record): Record
		-- WebIDL dictionary members are read in lexicographic order.
		local domain = nullable(input.domain)
		local name = trim(scalar(input.name))
		local partitioned = Nulls.truthy(input.partitioned)
		local path = if input.path == nil then "/" else scalar(input.path)
		if domain ~= nil then
			domain = scalar(domain)
			if domain:sub(1, 1) == "." then invalid("Cookie domains cannot start with a dot") end
			if domain:lower() ~= url.hostname then
				invalid("Cookie suffix domains require a public-suffix capability; only the document host is supported")
			end
			domain = url.hostname
		end
		if path == "" then path = defaultPath() end
		if path:sub(1, 1) ~= "/" or #path > 1024 then invalid("Invalid cookie path") end
		return { domain = domain, name = name, partitioned = partitioned, path = path }
	end
	local function sameKey(left: Record, right: Record): boolean
		-- RFC storage identity includes the host-only flag as well as domain.
		return left.name == right.name and left.path == right.path
			and left.domain == right.domain and left.partitioned == right.partitioned
	end
	local function validate(key: Record, value: string)
		local name = key.name
		if unsafe(name) or unsafe(value) or name:find("=", 1, true) then invalid("Invalid cookie name or value") end
		local lower = name:lower()
		if name == "" then
			local lowerValue = value:lower()
			if value == "" or value:find("=", 1, true) or lowerValue:match("^__host%-")
				or lowerValue:match("^__http%-") or lowerValue:match("^__secure%-") then invalid("Invalid nameless cookie") end
		end
		if lower:match("^__http%-") or lower:match("^__host%-http%-") then invalid("HTTP-only cookie prefixes are unavailable to script") end
		if lower:match("^__host%-") and (key.domain ~= nil or key.path ~= "/") then invalid("Host cookie prefix requires host-only scope and root path") end
		if #name + #value > 4096 then invalid("Cookie name and value exceed 4096 UTF-8 bytes") end
	end
	local function snapshot(cookie: Record): Record
		return Records.adopt({ name = cookie.name, value = cookie.value }, { "name", "value" })
	end
	local function query(input: any): { Record }
		local name: string? = nil
		local requested: any = nil
		if type(input) == "string" then name = input
		elseif not Nulls.isNullish(input) then
			if type(input) ~= "table" then name = scalar(input)
			else
				local rawName = input.name
				if rawName ~= nil then name = scalar(rawName) end
				requested = input.url
			end
		end
		if name ~= nil then name = trim(name) end
		if requested ~= nil then
			local target = scalar(requested)
			if target:sub(1, 1) == "/" and target:sub(1, 2) ~= "//" then target = url.origin .. target end
			if SourceURL.URL.new(target).href ~= url.href then invalid("Window cookie reads require the document creation URL") end
		end
		purge()
		local result = {}
		for _, cookie in cookies do
			local path = cookie.path
			local matches = path == url.pathname or url.pathname:sub(1, #path) == path
				and (path:sub(-1) == "/" or url.pathname:sub(#path + 1, #path + 1) == "/")
			if matches and (name == nil or cookie.name == name) then table.insert(result, cookie) end
		end
		-- Cookie retrieval prefers longer paths; creation order breaks ties.
		table.sort(result, function(left: Record, right: Record)
			return if #left.path == #right.path then left.order < right.order else #left.path > #right.path
		end)
		return result
	end
	store.get = function(a: any?, b: any?): any
		local input = if a == store then b else a
		return operation(function()
			local result = query(input)
			return if result[1] then snapshot(result[1]) else Nulls.value
		end)
	end
	store.getAll = function(a: any?, b: any?): any
		local input = if a == store then b else a
		return operation(function()
			local result = {}
			for _, cookie in query(input) do table.insert(result, snapshot(cookie)) end
			return Arrays.adopt(result, #result)
		end)
	end
	local sequence = 0
	store.set = function(a: any, b: any?, c: any?): any
		local input, value = a, b
		if a == store then input, value = b, c end
		return operation(function()
			local init = if type(input) == "table" and not Nulls.isNull(input) then input
				else { name = input, value = value }
			-- Snapshot the complete dictionary before validating or mutating.
			local rawDomain, rawExpires, rawMaxAge = init.domain, init.expires, init.maxAge
			local rawName, rawPartitioned, rawPath = init.name, init.partitioned, init.path
			local rawSameSite, rawValue = init.sameSite, init.value
			if rawName == nil or rawValue == nil then invalid("Cookie name and value are required") end
			local key = keyOptions({ domain = rawDomain, name = rawName, partitioned = rawPartitioned, path = rawPath })
			local text = trim(scalar(rawValue))
			validate(key, text)
			local sameSite = if rawSameSite == nil then "strict" else scalar(rawSameSite)
			if sameSite ~= "strict" and sameSite ~= "lax" and sameSite ~= "none" then invalid("Invalid cookie sameSite") end
			local expires, maxAge = nullable(rawExpires), nullable(rawMaxAge)
			if expires ~= nil and maxAge ~= nil then invalid("Cookie expires and maxAge are mutually exclusive") end
			if expires ~= nil then expires = math.floor(finite(expires, "expires") / 1000) * 1000 end
			if maxAge ~= nil then
				local age = finite(maxAge, "maxAge")
				age = if age < 0 then math.ceil(age) else math.floor(age)
				if math.abs(age) > 9007199254740991 then invalid("Cookie maxAge requires a safe integer") end
				expires = now() + age * 1000
			end
			purge()
			local previous: number? = nil
			for index, cookie in cookies do if sameKey(cookie, key) then previous = index; break end end
			if expires ~= nil and expires <= now() then
				if previous then table.remove(cookies, previous) end
				return nil
			end
			sequence += 1
			key.order = if previous then cookies[previous].order else sequence
			key.expires, key.value, key.sameSite = expires, text, sameSite
			if previous then cookies[previous] = key else table.insert(cookies, key) end
			return nil
		end)
	end
	store.delete = function(a: any, b: any?): any
		local input = if a == store then b else a
		return operation(function()
			local init = if type(input) == "table" and not Nulls.isNull(input) then input else { name = input }
			local domain, name, partitioned, path = init.domain, init.name, init.partitioned, init.path
			if name == nil then invalid("Cookie name is required") end
			local key = keyOptions({ domain = domain, name = name, partitioned = partitioned, path = path })
			validate(key, if key.name == "" then "deleted" else "")
			purge()
			for index = #cookies, 1, -1 do if sameKey(cookies[index], key) then table.remove(cookies, index) end end
			return nil
		end)
	end
	return { cookieStore = store, destroy = function() closed = true; table.clear(cookies) end }
end
return CookieStore
