--!strict
-- Bounded window.matchMedia surface. The embedding host owns real viewport
-- observations; this module only evaluates queries when the host notifies it.
local Conditions = require(script.Parent.Parent.Css.Conditions)
local Nulls = require(script.Parent.Nulls)
local SourceCapabilities = require(script.Parent.SourceCapabilities)
local Functions = require(script.Parent.FunctionValues)
local Arrays = require(script.Parent.Arrays)

type Record = { [string]: any }
type Environment = { viewportWidth: number?, viewportHeight: number?, mediaType: string?, features: Record? }
type AbortSignalLike = {
	aborted: boolean?,
	addEventListener: any,
	removeEventListener: any,
}
type Options = {
	readEnvironment: () -> Environment,
	subscribe: (() -> ()) -> () -> (),
	reportError: ((string) -> ())?,
}

local SourceMediaQueries = {}
local supported =
	{ width = true, height = true, ["aspect-ratio"] = true, orientation = true, pointer = true, hover = true }

local function trim(value: string): string
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitTop(value: string, separator: string): { string }
	local result, depth, start = {}, 0, 1
	local i = 1
	while i <= #value do
		local c = value:sub(i, i)
		if c == "(" then
			depth += 1
		elseif c == ")" then
			depth -= 1
		end
		if depth == 0 and value:sub(i, i + #separator - 1):lower() == separator then
			table.insert(result, trim(value:sub(start, i - 1)))
			i += #separator
			start = i
		else
			i += 1
		end
	end
	if #result > 0 then
		table.insert(result, trim(value:sub(start)))
	end
	return result
end

local function numberToken(value: string): Record
	local numeric, unit = value:match("^([+-]?[%d%.]+)([%a%%]*)$")
	assert(numeric ~= nil, "Invalid media query numeric value: " .. value)
	assert(tonumber(numeric) ~= nil, "Invalid media query numeric value: " .. value)
	unit = (unit or ""):lower()
	if unit == "" then
		return { kind = "number", value = numeric }
	end
	assert(
		unit == "px"
			or unit == "em"
			or unit == "rem"
			or unit == "vw"
			or unit == "vh"
			or unit == "in"
			or unit == "cm"
			or unit == "mm"
			or unit == "pt"
			or unit == "pc",
		"Unsupported media query unit: " .. (unit :: string)
	)
	return { kind = "dimension", value = numeric, unit = unit :: string }
end

local function featureValueToken(name: string, value: string): Record
	if name == "aspect-ratio" then
		local left, right = value:match("^([%d%.]+)%s*/%s*([%d%.]+)$")
		local leftNumber, rightNumber = tonumber(left), tonumber(right)
		if leftNumber and rightNumber and rightNumber ~= 0 then
			return { kind = "number", value = tostring(leftNumber / rightNumber) }
		end
	end
	return numberToken(value)
end

local function featureExpression(body: string): Record
	body = trim(body)
	local name, value = body:match("^([%w%-]+)%s*:%s*(.-)%s*$")
	if name then
		local validName, validValue = (name :: string):lower(), value :: string
		local baseName = validName:gsub("^min%-", ""):gsub("^max%-", "")
		assert(supported[baseName], "Unsupported media feature: " .. validName)
		local tokens: { Record }
		if baseName == "aspect-ratio" then
			tokens = { featureValueToken(baseName, validValue) }
		elseif baseName == "orientation" or baseName == "pointer" or baseName == "hover" then
			tokens = { { kind = "word", value = validValue:lower() } }
		else
			tokens = { numberToken(validValue) }
		end
		return { kind = "feature", name = validName, tokens = tokens } :: Record
	end
	local rangeValues, comparisons = {}, {}
	local cursor, index = 1, 1
	while index <= #body do
		local current = body:sub(index, index)
		local nextTwo = body:sub(index, index + 1)
		local operator = if nextTwo == "<=" or nextTwo == ">="
			then nextTwo
			elseif current == "<" or current == ">" or current == "=" then current
			else nil
		if operator then
			table.insert(rangeValues, trim(body:sub(cursor, index - 1)))
			table.insert(comparisons, operator)
			index += #operator
			cursor = index
		else
			index += 1
		end
	end
	if #comparisons > 0 then
		table.insert(rangeValues, trim(body:sub(cursor)))
		assert(#rangeValues == #comparisons + 1 and #comparisons <= 2, "Unsupported media range syntax")
		local featureIndex, featureName = nil, nil
		for operandIndex, operand in rangeValues do
			if supported[operand:lower()] then
				assert(featureIndex == nil, "Media range must contain one feature")
				featureIndex, featureName = operandIndex, operand:lower()
			end
		end
		assert(featureIndex ~= nil and featureName ~= nil, "Media range requires one supported feature")
		if #comparisons == 2 then
			assert(featureIndex == 2, "A two-sided media range requires the feature between its bounds")
			local first, second = comparisons[1], comparisons[2]
			assert(
				(first == "<" or first == "<=") and (second == "<" or second == "<=")
					or (first == ">" or first == ">=") and (second == ">" or second == ">="),
				"Media range comparisons must have one direction"
			)
		end
		local rangeOperands = {}
		for operandIndex, operand in rangeValues do
			table.insert(
				rangeOperands,
				if operandIndex == featureIndex
					then { kind = "feature", name = featureName }
					else { kind = "value", tokens = { featureValueToken(featureName, operand) } }
			)
		end
		return { kind = "range", rangeOperands = rangeOperands, comparisons = comparisons }
	end
	local bare = body:lower()
	assert(supported[bare], "Unsupported media feature: " .. bare)
	return { kind = "feature", name = bare }
end

local parse: (string) -> Record
parse = function(source: string): Record
	source = trim(source)
	if source == "" then
		return { kind = "media-type", name = "all" }
	end
	local list = splitTop(source, ",")
	if #list > 1 then
		local operands = {}
		for _, item in list do
			table.insert(operands, parse(item))
		end
		return { kind = "or", operands = operands }
	end
	local lower = source:lower()
	if lower:sub(1, 4) == "not " then
		return { kind = "not", operand = parse(trim(source:sub(5))) }
	end
	for _, operator in { " or ", " and " } do
		local parts = splitTop(lower, operator)
		if #parts > 1 then
			local operands = {}
			for _, item in parts do
				table.insert(operands, parse(item))
			end
			return { kind = trim(operator) == "or" and "or" or "and", operands = operands }
		end
	end
	if source:sub(1, 1) == "(" and source:sub(-1) == ")" then
		local inside = source:sub(2, -2)
		if inside:sub(1, 1) == "(" or #splitTop(inside, " and ") > 1 or #splitTop(inside, " or ") > 1 then
			return parse(inside)
		end
		if
			inside:find(":", 1, true)
			or inside:find("<", 1, true)
			or inside:find(">", 1, true)
			or inside:find("=", 1, true)
			or supported[trim(inside):lower()]
		then
			return featureExpression(inside)
		end
		return parse(inside)
	end
	local mediaType = lower
	assert(mediaType == "all" or mediaType == "screen" or mediaType == "print", "Unsupported media type: " .. mediaType)
	return { kind = "media-type", name = mediaType }
end

local function checkCapabilities(expression: Record, environment: Environment)
	if expression.kind == "feature" then
		local rawName: string = (expression.name :: string?) or ""
		local name = rawName:gsub("^min%-", ""):gsub("^max%-", "")
		if name == "pointer" or name == "hover" then
			assert(environment.features and environment.features[name] ~= nil, "Media capability unavailable: " .. name)
		end
	elseif expression.kind == "and" or expression.kind == "or" then
		for _, operand in expression.operands do
			checkCapabilities(operand, environment)
		end
	elseif expression.kind == "not" then
		checkCapabilities(expression.operand, environment)
	end
end

function SourceMediaQueries.create(optionsValue: any)
	assert(not Nulls.isNullish(optionsValue) and type(optionsValue) == "table", "Media query options required")
	local options = optionsValue :: Options
	assert(
		type(options.readEnvironment) == "function" and type(options.subscribe) == "function",
		"readEnvironment and subscribe are required"
	)
	local owner: Record = {}
	local activeQueries: { [any]: Record } = {}
	local cleanup: (() -> ())? = nil
	local destroyed = false
	local dispatching: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local updateSubscription: () -> ()
	local function report(message: string)
		local reporter = options.reportError
		if type(reporter) == "function" then
			pcall(reporter, message)
		end
	end
	local function readMatch(state: Record, environment: Environment): boolean
		checkCapabilities(state.expression, environment)
		local value = Conditions.match(
			{ name = "media", params = state.media, tokens = {}, expression = state.expression },
			environment :: any,
			nil,
			{} :: any
		)
		assert(value ~= nil, "Media query requires an unavailable environment capability: " .. state.media)
		return value
	end
	local function removeActive(query: any, state: Record)
		if #state.listeners == 0 then
			activeQueries[query] = nil
		end
	end
	local function removeEntry(query: any, state: Record, entry: Record)
		local index = table.find(state.listeners, entry)
		if index then
			table.remove(state.listeners, index)
		end
		local signalCleanup = entry.cleanupSignal
		if type(signalCleanup) == "function" then
			(signalCleanup :: () -> ())()
		end
		if state.onchangeEntry == entry then
			state.onchangeEntry = nil
			state.onchange = nil
		end
		removeActive(query, state)
		updateSubscription()
	end
	local function dispatch(query: any, state: Record, event: Record): boolean
		assert(type(event.type) == "string", "dispatchEvent requires an Event")
		assert(event.type == "change", "MediaQueryList only supports change events")
		assert(dispatching[event] ~= true, "Event is already being dispatched")
		dispatching[event] = true
		event.target = query
		event.currentTarget = query
		event.eventPhase = 2
		event.cancelBubble = false
		event._immediatePropagationStopped = false
		local snapshot = table.clone(state.listeners) :: { Record }
		for _, entry in snapshot do
			if destroyed then
				break
			end
			if event._immediatePropagationStopped then
				break
			end
			if table.find(state.listeners, entry) then
				if entry.once then
					removeEntry(query, state, entry)
				end
				local ok, reason = pcall(function()
					local functionListener = type(entry.listener) == "function"
					local receiver = if functionListener then query else entry.listener
					local reference = Functions.reference(receiver, function(object: any)
						return if functionListener then entry.listener else object.handleEvent
					end, if functionListener then "free" else "method", false)
					-- Source descriptors retain JavaScript this. Unregistered native
					-- callbacks use the free-function/method ABI in the declaration.
					Functions.invokeReference(reference, function()
						return Arrays.adopt({ event }, 1)
					end, false)
				end)
				if not ok then
					report(tostring(reason))
				end
			end
		end
		event.currentTarget = Nulls.value
		event.eventPhase = 0
		event._immediatePropagationStopped = false
		dispatching[event] = nil
		return event.defaultPrevented ~= true
	end
	local function refresh()
		if destroyed then
			return
		end
		local environment = options.readEnvironment()
		for query, state in table.clone(activeQueries) do
			if destroyed then
				break
			end
			local ok, value = pcall(readMatch, state, environment)
			if not ok then
				report(tostring(value))
				continue
			end
			if value ~= state.lastNotified then
				state.lastNotified = value
				local event = SourceCapabilities.createEvent("change") :: Record
				event.matches, event.media = value, state.media
				event.isTrusted = true
				local dispatched = pcall(dispatch, query, state, event)
				if not dispatched then
					report("MediaQueryList change dispatch failed")
				end
				removeActive(query, state)
			end
		end
		updateSubscription()
	end
	updateSubscription = function()
		local active = next(activeQueries) ~= nil
		if active and not cleanup then
			cleanup = options.subscribe(refresh)
		elseif not active and cleanup then
			cleanup()
			cleanup = nil
		end
	end
	owner.matchMedia = function(a: any, b: any?): any
		assert(not destroyed, "Media query owner is destroyed")
		local mediaValue = if a == owner then b else a
		assert(type(mediaValue) == "string", "matchMedia accepts a query string")
		local media = mediaValue
		local expression = parse(media)
		local state: Record = {
			media = media,
			expression = expression,
			lastNotified = nil,
			listeners = {},
			onchange = nil,
			onchangeEntry = nil,
		}
		local query: Record = {}
		local function setting(value: any): Record
			return if type(value) == "table" then value else { capture = value == true }
		end
		local function removeListenerEntry(entry: Record)
			removeEntry(query, state, entry)
		end
		local function add(listener: any, listenerOptions: any?)
			assert(not destroyed, "Media query owner is destroyed")
			if Nulls.isNullish(listener) then
				return
			end
			assert(
				type(listener) == "function" or type(listener) == "table",
				"Media listener requires a callback object"
			)
			local config = setting(listenerOptions)
			local capture = config.capture == true
			for _, existing in state.listeners do
				if existing.listener == listener and existing.capture == capture then
					return
				end
			end
			local signal: AbortSignalLike? = nil
			if config.signal ~= nil then
				assert(type(config.signal) == "table", "AbortSignal must be an object")
				signal = config.signal :: AbortSignalLike
				if signal.aborted then
					return
				end
				assert(type(signal.addEventListener) == "function", "Unsupported AbortSignal")
			end
			local wasInactive = #state.listeners == 0
			local entry: Record = { listener = listener, capture = capture, once = config.once == true }
			table.insert(state.listeners, entry)
			if signal then
				local abortSignal = signal
				local abortHandler = function()
					removeListenerEntry(entry)
				end
				entry.cleanupSignal = function()
					local removeAbortListener = abortSignal.removeEventListener :: any
					if type(removeAbortListener) == "function" then
						(removeAbortListener :: any)(abortSignal, "abort", abortHandler)
					end
					entry.cleanupSignal = nil
				end
				local addAbortListener = abortSignal.addEventListener :: any
				(addAbortListener :: any)(abortSignal, "abort", abortHandler, { once = true })
				if abortSignal.aborted then
					removeListenerEntry(entry)
					return
				end
			end
			if wasInactive then
				state.lastNotified = readMatch(state, options.readEnvironment())
			end
			activeQueries[query] = state
			updateSubscription()
		end
		local function remove(listener: any, capture: boolean)
			local snapshot = table.clone(state.listeners) :: { Record }
			for _, entry in snapshot do
				if not entry.onchange and entry.listener == listener and entry.capture == capture then
					removeListenerEntry(entry)
					return
				end
			end
		end
		query.addEventListener = function(a: any, b: any, c: any?, d: any?)
			local eventType, listener, listenerOptions = a, b, c
			if a == query then
				eventType, listener, listenerOptions = b, c, d
			end
			assert(eventType == "change", "MediaQueryList only supports change listeners")
			add(listener, listenerOptions)
		end
		query.removeEventListener = function(a: any, b: any, c: any?, d: any?)
			local eventType, listener, listenerOptions = a, b, c
			if a == query then
				eventType, listener, listenerOptions = b, c, d
			end
			assert(eventType == "change", "MediaQueryList only supports change listeners")
			remove(listener, setting(listenerOptions).capture == true)
		end
		query.addListener = function(a: any, b: any?)
			add(if a == query then b else a, nil)
		end
		query.removeListener = function(a: any, b: any?)
			remove(if a == query then b else a, false)
		end
		query.dispatchEvent = function(a: any, b: any?)
			local event = if a == query then b else a
			assert(type(event) == "table", "dispatchEvent requires an Event")
			return dispatch(query, state, event)
		end
		setmetatable(query, {
			__index = function(_, key): any
				if key == "matches" then
					return readMatch(state, options.readEnvironment())
				elseif key == "media" then
					return media
				elseif key == "onchange" then
					return state.onchange or Nulls.value
				end
				return nil
			end,
			__newindex = function(_, key, value)
				if key == "onchange" then
					assert(destroyed == false or Nulls.isNullish(value), "Media query owner is destroyed")
					local callback = if Nulls.isNullish(value) then nil else value
					assert(callback == nil or type(callback) == "function", "onchange must be a function or null")
					if callback == nil then
						state.onchange = nil
						if state.onchangeEntry then
							removeListenerEntry(state.onchangeEntry)
						end
					elseif state.onchangeEntry then
						state.onchange = callback
						state.onchangeEntry.listener = callback
					else
						local wasInactive = #state.listeners == 0
						if wasInactive then
							state.lastNotified = readMatch(state, options.readEnvironment())
						end
						local entry = { listener = callback, capture = false, once = false, onchange = true }
						state.onchange, state.onchangeEntry = callback, entry
						table.insert(state.listeners, entry)
						activeQueries[query] = state
						updateSubscription()
					end
				else
					if type(key) == "string" then
						rawset(query :: any, key, value)
					end
				end
			end,
			__has = function(_, key)
				return key == "matches" or key == "media" or key == "onchange"
			end,
		})
		return query
	end
	function owner.destroy()
		if destroyed then
			return
		end
		destroyed = true
		if cleanup then
			cleanup()
			cleanup = nil
		end
		for query, state in table.clone(activeQueries) do
			local snapshot = table.clone(state.listeners) :: { Record }
			for _, entry in snapshot do
				if type(entry.cleanupSignal) == "function" then
					(entry.cleanupSignal :: () -> ())()
				end
			end
			table.clear(state.listeners)
			state.onchange = nil
			state.onchangeEntry = nil
			activeQueries[query] = nil
		end
	end
	return owner
end

return SourceMediaQueries
