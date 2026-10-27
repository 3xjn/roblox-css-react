--!strict
-- Network-special URL state. Unsupported host/protocol capabilities fail before
-- returning a misleading record. See https://url.spec.whatwg.org/#url-parsing.
local Codec = require(script.Parent.SourceURLCodec)
local Parser = {}
export type Parts = { scheme: string, username: string, password: string, hostname: string, port: string,
	path: string, query: string?, fragment: string? }
Parser.ports = { http = 80, https = 443, ftp = 21, ws = 80, wss = 443 }
local function split(value: string, separator: string): { string }
	local result, at = {}, 1
	while true do
		local found = string.find(value, separator, at, true)
		table.insert(result, string.sub(value, at, if found then found - 1 else #value))
		if not found then return result end
		at = found + #separator
	end
end
local function ipv4Number(value: string): number?
	if value == "" then return nil end
	local base = 10
	if string.sub(value, 1, 2) == "0x" then base, value = 16, string.sub(value, 3)
	elseif #value > 1 and string.sub(value, 1, 1) == "0" then base, value = 8, string.sub(value, 2) end
	if value == "" then return 0 end
	local allowed = if base == 16 then "^[0-9a-f]+$" elseif base == 8 then "^[0-7]+$" else "^[0-9]+$"
	return if string.match(value, allowed) then tonumber(value, base) else nil
end
local function ipv4(host: string): (string?, boolean)
	local pieces = split(host, ".")
	if #pieces > 1 and pieces[#pieces] == "" then table.remove(pieces) end
	local last = pieces[#pieces]
	if not string.match(last, "^[0-9]+$") and ipv4Number(last) == nil then return host, false end
	if #pieces > 4 then return nil, true end
	local number = 0
	for at, piece in pieces do
		local value = ipv4Number(piece)
		if value == nil or (at < #pieces and value > 255) or at == #pieces and value >= 256 ^ (5 - #pieces) then return nil, true end
		number += value * (if at == #pieces then 1 else 256 ^ (4 - at))
	end
	local bytes = {}
	for power = 3, 0, -1 do table.insert(bytes, tostring(math.floor(number / 256 ^ power) % 256)) end
	return table.concat(bytes, "."), true
end
local function ipv6(input: string): string?
	if string.find(input, ".", 1, true) then
		local boundary = string.match(input, "^.*():")
		if not boundary then return nil end
		local tail = split(string.sub(input, boundary + 1), ".")
		if #tail ~= 4 then return nil end
		local bytes = {}
		for _, part in tail do
			if not string.match(part, "^[0-9]+$") or #part > 1 and string.sub(part, 1, 1) == "0" then return nil end
			local value = tonumber(part) :: number
			if value > 255 then return nil end
			table.insert(bytes, value)
		end
		input = string.sub(input, 1, boundary) .. string.format("%x:%x", bytes[1] * 256 + bytes[2], bytes[3] * 256 + bytes[4])
	end
	local compressed = string.find(input, "::", 1, true)
	if compressed and string.find(input, "::", compressed + 2, true) then return nil end
	local left = if compressed then string.sub(input, 1, compressed - 1) else input
	local right = if compressed then string.sub(input, compressed + 2) else ""
	local function groups(value: string): { number }?
		if value == "" then return {} end
		local result = {}
		for _, part in split(value, ":") do
			if #part == 0 or #part > 4 or not string.match(part, "^%x+$") then return nil end
			table.insert(result, tonumber(part, 16) :: number)
		end
		return result
	end
	local a, b = groups(left), groups(right)
	if not a or not b or (if compressed then #a + #b >= 8 else #a ~= 8) then return nil end
	local values = table.clone(a)
	if compressed then for _ = 1, 8 - #a - #b do table.insert(values, 0) end end
	for _, value in b do table.insert(values, value) end
	local best, size, at = 0, 1, 1
	while at <= 8 do
		if values[at] ~= 0 then at += 1; continue end
		local finish = at
		while finish <= 8 and values[finish] == 0 do finish += 1 end
		if finish - at > size then best, size = at, finish - at end
		at = finish
	end
	local strings = {}
	for _, value in values do table.insert(strings, string.format("%x", value)) end
	if best == 0 then return "[" .. table.concat(strings, ":") .. "]" end
	return "[" .. table.concat(strings, ":", 1, best - 1) .. "::" .. table.concat(strings, ":", best + size, 8) .. "]"
end
function Parser.host(input: string): string?
	if string.sub(input, 1, 1) == "[" then
		if string.sub(input, -1) ~= "]" then return nil end
		return ipv6(string.sub(input, 2, -2))
	end
	local host = Codec.decode(input)
	if string.find(host, "[\128-\255]") then error("Unsupported URL capability: internationalized hosts require IDNA", 0) end
	if host == "" then return nil end
	for at = 1, #host do
		local byte = string.byte(host, at)
		if byte <= 0x20 or byte == 0x7F or string.find("#/:<>?@[\\]^|%", string.char(byte), 1, true) then return nil end
	end
	local result = ipv4(string.lower(host))
	return result
end
function Parser.port(input: string, scheme: string): string?
	if input == "" then return "" end
	if not string.match(input, "^[0-9]+$") then return nil end
	local number = tonumber(input) :: number
	if number > 65535 then return nil end
	return if number == (Parser.ports :: any)[scheme] then "" else tostring(number)
end
function Parser.hostPort(input: string, scheme: string, partialPort: boolean?): (string?, string?)
	local host: string = input
	local port: string = ""
	if string.sub(input, 1, 1) == "[" then
		local closing = string.find(input, "]", 1, true)
		if not closing then return nil, nil end
		host = string.sub(input, 1, closing)
		local rest = string.sub(input, closing + 1)
		if rest ~= "" then
			if string.sub(rest, 1, 1) ~= ":" then return nil, nil end
			port = string.sub(rest :: string, 2)
		end
	else
		local boundary = string.find(input, ":", 1, true)
		if boundary then host, port = string.sub(input, 1, boundary - 1), string.sub(input, boundary + 1) end
	end
	if partialPort and port ~= "" then
		local digits = string.match(port :: string, "^[0-9]+")
		if not digits then return Parser.host(host), nil end
		port = digits
	end
	local parsedHost = Parser.host(host)
	local parsedPort = Parser.port(port :: string, scheme)
	return parsedHost, parsedPort
end
function Parser.path(input: string): string
	if string.sub(input, 1, 1) ~= "/" then input = "/" .. input end
	local segments, result = split(string.sub(input, 2), "/"), {}
	for index, segment in segments do
		local dot = string.gsub(string.lower(segment), "%%2e", ".")
		if dot == "." then
			if index == #segments then table.insert(result, "") end
		elseif dot == ".." then
			if #result > 0 then table.remove(result) end
			if index == #segments then table.insert(result, "") end
		else table.insert(result, Codec.encode(segment, "path")) end
	end
	return "/" .. table.concat(result, "/")
end
function Parser.clean(input: string): string
	local value = string.gsub(input, "^[%z\1-\32]+", "")
	value = string.gsub(value, "[%z\1-\32]+$", "")
	return (string.gsub(value, "[\t\r\n]", ""))
end
function Parser.parse(input: string, base: Parts?): Parts?
	local value = Parser.clean(input)
	local scheme, rest = string.match(value, "^([A-Za-z][A-Za-z0-9+.-]*):(.*)$")
	if scheme then
		scheme = string.lower(scheme)
		if not (Parser.ports :: any)[scheme] then error("Unsupported URL capability: network-special protocols only", 0) end
	end
	local afterScheme = rest or ""
	local relative = not scheme or base ~= nil and scheme == base.scheme and string.sub(afterScheme, 1, 2) ~= "//" and string.sub(afterScheme, 1, 2) ~= "\\\\"
	if not scheme and not base then return nil end
	local selected = scheme or (base :: Parts).scheme
	local body: string = if scheme then afterScheme else value
	local hash = string.find(body, "#", 1, true)
	local fragment = if hash then Codec.encode(string.sub(body, hash + 1), "fragment") else nil
	body = if hash then string.sub(body, 1, hash - 1) else body
	local question = string.find(body, "?", 1, true)
	local query = if question then Codec.encode(string.sub(body, question + 1), "query") else nil
	body = if question then string.sub(body, 1, question - 1) else body
	body = string.gsub(body, "\\", "/")
	local authority = not relative or string.sub(body, 1, 2) == "//"
	if authority then
		body = string.gsub(body, "^/+", "")
		local boundary = string.find(body, "/", 1, true)
		local site = if boundary then string.sub(body, 1, boundary - 1) else body
		local path = if boundary then string.sub(body, boundary) else "/"
		local userinfo = string.match(site, "^.*()@")
		local username, password = "", ""
		if userinfo then
			local user = string.sub(site, 1, userinfo - 1)
			site = string.sub(site, userinfo + 1)
			local colon = string.find(user, ":", 1, true)
			username = Codec.encode(if colon then string.sub(user, 1, colon - 1) else user, "userinfo")
			password = if colon then Codec.encode(string.sub(user, colon + 1), "userinfo") else ""
		end
		local host, port = Parser.hostPort(site, selected)
		if not host or not port then return nil end
		return { scheme = selected, username = username, password = password, hostname = host, port = port,
			path = Parser.path(path), query = query, fragment = fragment }
	end
	local result = table.clone(base :: Parts)
	result.fragment = fragment
	if body ~= "" then
		result.path = Parser.path(if string.sub(body, 1, 1) == "/" then body else (string.match(result.path, "^(.*)/") or "") .. "/" .. body)
		result.query = query
	elseif question then result.query = query end
	return result
end
function Parser.hostString(value: Parts): string
	return value.hostname .. (if value.port == "" then "" else ":" .. value.port)
end
function Parser.serialize(value: Parts): string
	local user = if value.username ~= "" or value.password ~= "" then value.username .. (if value.password ~= "" then ":" .. value.password else "") .. "@" else ""
	return value.scheme .. "://" .. user .. Parser.hostString(value) .. value.path
		.. (if value.query ~= nil then "?" .. value.query else "") .. (if value.fragment ~= nil then "#" .. value.fragment else "")
end
return Parser
