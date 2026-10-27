--!strict
-- URL percent encoding and the UTF-8 replacement decoder used by form queries.
-- https://url.spec.whatwg.org/#application/x-www-form-urlencoded
local Codec = {}
local replacement = utf8.char(0xFFFD)
function Codec.decodeUtf8(input: string): string
	local out, at = {}, 1
	while at <= #input do
		local first = string.byte(input, at)
		if first < 0x80 then table.insert(out, string.char(first)); at += 1; continue end
		local count = if first >= 0xC2 and first <= 0xDF then 2 elseif first >= 0xE0 and first <= 0xEF then 3 elseif first >= 0xF0 and first <= 0xF4 then 4 else 0
		if count == 0 then table.insert(out, replacement); at += 1; continue end
		local value = first % (if count == 2 then 0x20 elseif count == 3 then 0x10 else 8)
		local consumed, valid = 1, true
		for offset = 1, count - 1 do
			local byte = string.byte(input, at + offset)
			local low = if offset == 1 and first == 0xE0 then 0xA0 elseif offset == 1 and first == 0xF0 then 0x90 else 0x80
			local high = if offset == 1 and first == 0xED then 0x9F elseif offset == 1 and first == 0xF4 then 0x8F else 0xBF
			if byte == nil or byte < low or byte > high then valid = false; break end
			value = value * 64 + byte - 0x80; consumed += 1
		end
		table.insert(out, if valid then utf8.char(value) else replacement)
		at += consumed
	end
	return table.concat(out)
end
function Codec.decode(input: string, plus: boolean?): string
	local source = if plus then string.gsub(input, "+", " ") else input
	local bytes = string.gsub(source, "%%(%x%x)", function(pair) return string.char(tonumber(pair, 16) :: number) end)
	return Codec.decodeUtf8(bytes)
end
local function unreserved(byte: number): boolean
	return byte >= 0x41 and byte <= 0x5A or byte >= 0x61 and byte <= 0x7A or byte >= 0x30 and byte <= 0x39
end
function Codec.encode(input: string, mode: string): string
	assert(utf8.len(input), "URL strings require Unicode scalar UTF-8")
	local out = {}
	for at = 1, #input do
		local byte = string.byte(input, at)
		if mode == "form" and byte == 0x20 then table.insert(out, "+"); continue end
		local allowed: boolean
		if mode == "form" then allowed = unreserved(byte) or byte == 0x2A or byte == 0x2D or byte == 0x2E or byte == 0x5F
		else
			allowed = byte >= 0x21 and byte <= 0x7E and byte ~= 0x22 and byte ~= 0x3C and byte ~= 0x3E
			if mode == "fragment" then allowed = allowed and byte ~= 0x60
			elseif mode == "query" then allowed = allowed and byte ~= 0x23 and byte ~= 0x27
			elseif mode == "path" or mode == "userinfo" then
				allowed = allowed and byte ~= 0x23 and byte ~= 0x3F and byte ~= 0x5E and byte ~= 0x60 and byte ~= 0x7B and byte ~= 0x7D
				if mode == "userinfo" then allowed = allowed and not string.find("/:;=@[\\]|", string.char(byte), 1, true) end
			else error("Unknown URL encoding mode") end
		end
		table.insert(out, if allowed then string.char(byte) else string.format("%%%02X", byte))
	end
	return table.concat(out)
end
function Codec.parseForm(input: string): { { string } }
	local result = {}
	for field in string.gmatch(input .. "&", "(.-)&") do
		if field == "" then continue end
		local equals = string.find(field, "=", 1, true)
		local key, value = if equals then string.sub(field, 1, equals - 1) else field, if equals then string.sub(field, equals + 1) else ""
		table.insert(result, { Codec.decode(key, true), Codec.decode(value, true) })
	end
	return result
end
function Codec.serializeForm(list: { { string } }): string
	local result = {}
	for _, pair in list do table.insert(result, Codec.encode(pair[1], "form") .. "=" .. Codec.encode(pair[2], "form")) end
	return table.concat(result, "&")
end
return Codec
