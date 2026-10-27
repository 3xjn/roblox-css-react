--!strict
-- Date values use Roblox's native timestamp and local-zone conversions.
-- DateTime's documented range (years 1400–9999) and locale-only formatting
-- are the supported bounds; arbitrary IANA zones belong to TZDate wrappers.
local DAY_MS = 86400000
local HOUR_MS = 3600000
local MINUTE_MS = 60000
local SECOND_MS = 1000
local nan = 0 / 0
local identities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

type Fields = { Year: number, Month: number, Day: number, Hour: number, Minute: number, Second: number, Millisecond: number }
local Date: any = {}
Date.__index = Date
local function integer(value: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nan end
	return if value < 0 then math.ceil(value) else math.floor(value)
end
local function constructorYear(value: any): number
	local year = integer(value)
	return if year >= 0 and year <= 99 then year + 1900 else year
end
local function timestamp(value: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nan end
	local clipped = integer(value)
	local ok = pcall(DateTime.fromUnixTimestampMillis, clipped)
	return if ok then clipped else nan
end
local function fields(self: any, localTime: boolean): Fields?
	if self.time ~= self.time then return nil end
	local ok, result = pcall(function(): any
		local dateTime = DateTime.fromUnixTimestampMillis(self.time)
		return if localTime then dateTime:ToLocalTime() else dateTime:ToUniversalTime()
	end)
	return if ok then result else nil
end
local function normalizedFields(year: number, month: number, day: number, hour: number, minute: number, second: number, millisecond: number): Fields?
	year, month, day = integer(year), integer(month), integer(day)
	hour, minute, second, millisecond = integer(hour), integer(minute), integer(second), integer(millisecond)
	if year ~= year or month ~= month or day ~= day or hour ~= hour or minute ~= minute or second ~= second or millisecond ~= millisecond then return nil end
	year += math.floor(month / 12)
	month %= 12
	if month < 0 then month += 12 end
	month += 1
	local ok, result = pcall(function(): any
		local first = DateTime.fromUniversalTime(year, month, 1, 0, 0, 0, 0).UnixTimestampMillis
		local normalized = first + (day - 1) * DAY_MS + hour * HOUR_MS + minute * MINUTE_MS + second * SECOND_MS + millisecond
		return DateTime.fromUnixTimestampMillis(normalized):ToUniversalTime()
	end)
	return if ok then result else nil
end
local function fromFields(value: Fields, localTime: boolean): number
	local ok, result = pcall(function(): number
		local dateTime = if localTime
			then DateTime.fromLocalTime(value.Year, value.Month, value.Day, value.Hour, value.Minute, value.Second, value.Millisecond)
			else DateTime.fromUniversalTime(value.Year, value.Month, value.Day, value.Hour, value.Minute, value.Second, value.Millisecond)
		return timestamp(dateTime.UnixTimestampMillis)
	end)
	return if ok then result else nan
end
local function construct(year: number, month: number, day: number, hour: number, minute: number, second: number, millisecond: number, localTime: boolean): number
	local valueFields = normalizedFields(year, month, day, hour, minute, second, millisecond)
	return if valueFields then fromFields(valueFields, localTime) else nan
end
local function make(time: number): any
	local value = setmetatable({ time = timestamp(time) }, Date)
	identities[value] = true
	return value
end
local function mutate(self: any, replace: { [string]: number }, localTime: boolean, invalidDefaults: boolean?): number
	local current = fields(self, localTime)
	if not current and not invalidDefaults then self.time = nan; return nan end
	local base: any = current or { Year = 1970, Month = 1, Day = 1, Hour = 0, Minute = 0, Second = 0, Millisecond = 0 }
	local year = replace.Year
	if year == nil then year = base.Year end
	local month = replace.Month
	if month == nil then month = base.Month end
	local day = replace.Day
	if day == nil then day = base.Day end
	local hour = replace.Hour
	if hour == nil then hour = base.Hour end
	local minute = replace.Minute
	if minute == nil then minute = base.Minute end
	local second = replace.Second
	if second == nil then second = base.Second end
	local millisecond = replace.Millisecond
	if millisecond == nil then millisecond = base.Millisecond end
	self.time = construct(year, month - 1, day, hour, minute, second, millisecond, localTime)
	return self.time
end

function Date.constructor(self: any, ...: any): any
	local args = table.pack(...)
	local count = args.n
	local first = args[1]
	if count == 0 then self.time = timestamp(DateTime.now().UnixTimestampMillis)
	elseif count == 1 and type(first) == "number" then self.time = timestamp(first)
	elseif count == 1 and type(first) == "string" then
		local ok, parsed = pcall(function(): number return DateTime.fromIsoDate(first).UnixTimestampMillis end)
		self.time = timestamp(if ok then parsed else nan)
	elseif count == 1 and type(first) == "table" and identities[first] then self.time = timestamp(first.time)
	elseif count >= 2 then
		local defaulted = function(index: number, default: any): any
			return if count >= index then args[index] else default
		end
		self.time = if args[1] == nil then nan else construct(constructorYear(args[1]), args[2], defaulted(3, 1), defaulted(4, 0), defaulted(5, 0), defaulted(6, 0), defaulted(7, 0), true)
	else self.time = nan end
	identities[self] = true
	return self
end
function Date.new(...: any): any
	local self = setmetatable({}, Date)
	return Date.constructor(self, ...)
end
function Date.now(): number return DateTime.now().UnixTimestampMillis end
function Date.UTC(...: any): number
	local args = table.pack(...)
	local count = args.n
	local defaulted = function(index: number, default: any): any
		return if count >= index then args[index] else default
	end
	return construct(constructorYear(args[1]), defaulted(2, 0), defaulted(3, 1), defaulted(4, 0), defaulted(5, 0), defaulted(6, 0), defaulted(7, 0), false)
end
function Date.parse(value: string): number
	local ok, parsed = pcall(function(): number return DateTime.fromIsoDate(value).UnixTimestampMillis end)
	return if ok then timestamp(parsed) else nan
end
function Date.instanceof(value: unknown): boolean return type(value) == "table" and identities[value] == true end
local getters = {
	getFullYear = { "Year", true }, getUTCFullYear = { "Year", false },
	getMonth = { "Month", true }, getUTCMonth = { "Month", false },
	getDate = { "Day", true }, getUTCDate = { "Day", false },
	getHours = { "Hour", true }, getUTCHours = { "Hour", false },
	getMinutes = { "Minute", true }, getUTCMinutes = { "Minute", false },
	getSeconds = { "Second", true }, getUTCSeconds = { "Second", false },
	getMilliseconds = { "Millisecond", true }, getUTCMilliseconds = { "Millisecond", false },
}
for name, descriptor in getters do
	Date[name] = function(self: any): number
		local valueFields = fields(self, descriptor[2])
		if not valueFields then return nan end
		local result = (valueFields :: any)[descriptor[1]]
		return if descriptor[1] == "Month" then result - 1 else result
	end
end
local function dayOfWeek(self: any, localTime: boolean): number
	local valueFields = fields(self, localTime)
	if not valueFields then return nan end
	local localAsUtc = DateTime.fromUniversalTime(valueFields.Year, valueFields.Month, valueFields.Day, 0, 0, 0, 0).UnixTimestampMillis
	return (math.floor(localAsUtc / DAY_MS) + 4) % 7
end
function Date.getDay(self: any): number return dayOfWeek(self, true) end
function Date.getUTCDay(self: any): number return dayOfWeek(self, false) end
function Date.getTimezoneOffset(self: any): number
	local valueFields = fields(self, true)
	if not valueFields then return nan end
	local localAsUtc = DateTime.fromUniversalTime(valueFields.Year, valueFields.Month, valueFields.Day, valueFields.Hour, valueFields.Minute, valueFields.Second, valueFields.Millisecond).UnixTimestampMillis
	return (self.time - localAsUtc) / MINUTE_MS
end
function Date.getTime(self: any): number return self.time end
function Date.valueOf(self: any): number return self.time end
function Date.setTime(self: any, value: number): number self.time = timestamp(value); return self.time end
local setterSpecs = {
	setFullYear = { "Year", true, true }, setUTCFullYear = { "Year", false, true },
	setMonth = { "Month", true }, setUTCMonth = { "Month", false },
	setDate = { "Day", true }, setUTCDate = { "Day", false },
	setHours = { "Hour", true }, setUTCHours = { "Hour", false },
	setMinutes = { "Minute", true }, setUTCMinutes = { "Minute", false },
	setSeconds = { "Second", true }, setUTCSeconds = { "Second", false },
	setMilliseconds = { "Millisecond", true }, setUTCMilliseconds = { "Millisecond", false },
}
local function setParts(self: any, member: string, localTime: boolean, invalidDefaults: boolean?, ...: any): number
	local values = table.pack(...)
	if values.n == 0 then self.time = nan; return nan end
	local current = fields(self, localTime)
	if not current and not invalidDefaults then self.time = nan; return nan end
	local base: any = current or { Year = 1970, Month = 1, Day = 1, Hour = 0, Minute = 0, Second = 0, Millisecond = 0 }
	local replacement: any = {}
	local index = 1
	local offset = if member == "Year" then 0 elseif member == "Month" then 1 elseif member == "Day" then 2 elseif member == "Hour" then 3 elseif member == "Minute" then 4 elseif member == "Second" then 5 else 6
	local maxArguments = if member == "Year" or member == "Month" then 2 elseif member == "Hour" then 4 elseif member == "Minute" then 3 elseif member == "Second" then 2 else 1
	local keys = { "Year", "Month", "Day", "Hour", "Minute", "Second", "Millisecond" }
	for keyIndex, key in keys do
		if keyIndex - 1 < offset then replacement[key] = base[key] end
	end
	local provided: { [string]: boolean } = {}
	for valueIndex = 1, math.min(values.n, maxArguments) do
		local key = keys[offset + valueIndex]
		if key then
			local value = values[valueIndex]
			replacement[key] = if key == "Month" and type(value) == "number" then value + 1 else value
			provided[key] = true
		end
	end
	for keyIndex, key in keys do
		if not provided[key] then replacement[key] = base[key] end
	end
	local zeroBasedMonth = if replacement.Month == nil then nan else replacement.Month - 1
	self.time = construct(replacement.Year, zeroBasedMonth, replacement.Day, replacement.Hour,
		replacement.Minute, replacement.Second, replacement.Millisecond, localTime)
	return self.time
end
for name, spec in setterSpecs do
	Date[name] = function(self: any, ...: any): number
		local member, localTime, invalidDefaults = spec[1], spec[2], spec[3]
		return setParts(self, member, localTime, invalidDefaults, ...)
	end
end
local function nativeDateTime(self: any, localTime: boolean): any?
	if self.time ~= self.time then return nil end
	local ok, dateTime = pcall(DateTime.fromUnixTimestampMillis, self.time)
	if not ok then return nil end
	return dateTime
end
function Date.toISOString(self: any): string
	local dateTime = nativeDateTime(self, false)
	assert(dateTime, "Invalid time value")
	local value = dateTime:ToUniversalTime()
	return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", value.Year, value.Month, value.Day, value.Hour, value.Minute, value.Second, value.Millisecond)
end
function Date.toJSON(self: any): string? return if self.time ~= self.time then nil else Date.toISOString(self) end
function Date.toUTCString(self: any): string
	local dateTime = nativeDateTime(self, false)
	if not dateTime then return "Invalid Date" end
	local value = dateTime:ToUniversalTime()
	local weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
	local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
	return string.format("%s, %02d %s %04d %02d:%02d:%02d GMT", weekdays[dayOfWeek(self, false) + 1], value.Day, months[value.Month], value.Year, value.Hour, value.Minute, value.Second)
end
function Date.toLocaleString(self: any, locale: string?): string
	local dateTime = nativeDateTime(self, true)
	return if dateTime then dateTime:FormatLocalTime("LLLL", locale or "en-us") else "Invalid Date"
end
function Date.toLocaleDateString(self: any, locale: string?): string
	local dateTime = nativeDateTime(self, true)
	return if dateTime then dateTime:FormatLocalTime("LL", locale or "en-us") else "Invalid Date"
end
function Date.toLocaleTimeString(self: any, locale: string?): string
	local dateTime = nativeDateTime(self, true)
	return if dateTime then dateTime:FormatLocalTime("LTS", locale or "en-us") else "Invalid Date"
end
function Date.toString(self: any): string
	local dateTime = nativeDateTime(self, true)
	if not dateTime then return "Invalid Date" end
	local value = dateTime:ToLocalTime()
	local weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
	local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
	local offset = Date.getTimezoneOffset(self)
	local sign = if offset > 0 then "-" else "+"
	local minutes = math.abs(offset)
	local offsetHour = math.floor(minutes / 60)
	local offsetMinute = minutes % 60
	return string.format("%s %s %02d %04d %02d:%02d:%02d GMT%s%02d%02d", weekdays[dayOfWeek(self, true) + 1], months[value.Month], value.Day, value.Year, value.Hour, value.Minute, value.Second, sign, offsetHour, offsetMinute)
end
Date.prototype = Date
Date.__call = function(_self: any): string return Date.toString(Date.new()) end
Date.__tostring = Date.toString
return { Date = setmetatable(Date, { __call = Date.__call }) }
