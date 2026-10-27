--!strict
local Html = require(script.Parent.Html)
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Functions = require(script.Parent.FunctionValues)
local SourceType = require(script.Parent.SourceType)
local Strings = require(script.Parent.Strings)
local NumericStyles = require(script.Parent.NumericStyles)
local Timers = require(script.Parent.Timers)
local Frames = require(script.Parent.Frames)
local RenderNodes = require(script.Parent.RenderNodes)
local SourcePromise = require(script.Parent.SourcePromise)
local SourceJobs = require(script.Parent.SourceJobs)
local SourceAsync = require(script.Parent.SourceAsync)
local WebAnimations = require(script.Parent.WebAnimations)
local Abort = require(script.Parent.Abort)
local AttributeObservers = require(script.Parent.AttributeObservers)
local SourceErrors = require(script.Parent.SourceErrors)
local SourceURL = require(script.Parent.SourceURL)
local SourceArguments = require(script.Parent.SourceArguments)
local SourceReact = require(script.Parent.SourceReact)
local Target = require(script.Parent.Target)
local Properties = require(script.Parent.Properties)
local Collections = require(script.Parent.SourceCollections)
local Values = require(script.Parent.SourceValues)
local Symbols = require(script.Parent.SourceSymbols)
local Json = require(script.Parent.SourceJson)
local Objects = require(script.Parent.SourceObjects)
local DomElements = require(script.Parent.DomElements)
local DomClasses = require(script.Parent.DomClasses)
local SourceDocument = require(script.Parent.SourceDocument)
local Operations = require(script.Parent.SourceOperations)
local Regex = require(script.Parent.SourceRegExp)

local SourceRuntime = {}
local sourceRefs: { [any]: boolean } = setmetatable({}, { __mode = "k" })
local refKeys = Arrays.adopt({ "current" }, 1)
local refSchema: Operations.NativeObject = {
	hasOwn = function(_owner: any, key: any): boolean return key == "current" end,
	get = function(owner: any, key: any, _receiver: any): any
		assert(key == "current", "Native source refs expose only current")
		return owner.current
	end,
	ownKeys = function(_owner: any): any return refKeys end,
	enumerable = function(_owner: any, _key: any): boolean return true end,
	set = function(owner: any, key: any, value: any)
		assert(key == "current", "Native source ref expando properties are unsupported")
		owner.current = value
	end,
}
local function sourceRef(value: any): any
	Properties.ref(value)
	if not sourceRefs[value] then
		Operations.registerObject(value, refSchema)
		sourceRefs[value] = true
	end
	return value
end
local qualifiedElements: { [any]: boolean } = setmetatable({}, { __mode = "k" })
local elementKeys = Arrays.adopt({ "$$typeof", "type", "key", "ref", "props", "_owner" }, 6)
local elementFields = { ["$$typeof"] = true, type = true, key = true, ref = true, props = true, _owner = true }
local elementSchema: Operations.NativeObject = {
	hasOwn = function(owner: any, key: any): boolean
		local info = SourceReact.info(owner)
		return if info and info.projection then Records.hasOwn(info.projection,key) else elementFields[key] == true
	end,
	get = function(owner: any, key: any, _receiver: any): any
		local info = SourceReact.info(owner) or Html.sourceInfo(owner)
		if info and info.projection then return Operations.get(info.projection,key) end
		if info and key == "$$typeof" then return Symbols.Symbol["for"]("react.transitional.element") end
		if info then
			if key == "props" or key == "key" or key == "ref" then return info[key] end
			if key == "type" then return info.tag end
		end
		local value = rawget(owner, key)
		return if value == nil and (key == "key" or key == "ref" or key == "_owner") then Nulls.value else value
	end,
	ownKeys = function(owner: any): any
		local info=SourceReact.info(owner)
		assert(not info or not info.development,'Full development React element debug-field reflection is unsupported')
		return if info and info.projection then Records.ownKeys(info.projection) else elementKeys
	end,
	enumerable = function(owner: any, key: any): boolean
		local info=SourceReact.info(owner)
		if info and info.projection then
			local desc=Operations.getOwnPropertyDescriptor(info.projection,key)
			return desc~=nil and Operations.get(desc,'enumerable')==true
		end
		return true
	end,
	getOwnPropertyDescriptor=function(owner: any,key: any): any
		local info=SourceReact.info(owner)
		assert(info and info.projection,'Native element descriptors need source origin metadata')
		return Operations.getOwnPropertyDescriptor(info.projection,key)
	end,
}
local function sourceElement(react: any, value: any): any
	local validate = react.isValidElement
	if type(validate) == "function" and (validate :: (any) -> boolean)(value) and not qualifiedElements[value] then
		Operations.registerObject(value, elementSchema)
		qualifiedElements[value] = true
	end
	return value
end
local function stateTuple(callback: any, _receiver: any, arguments: any): any
	local state, dispatch = callback(table.unpack(arguments, 1, Arrays.length(arguments)))
	assert(type(dispatch) == "function", "Native React state hook must return its dispatch function")
	Operations.registerNative(dispatch, "free")
	return Arrays.adopt({ state, dispatch }, 2)
end
local function sourceRest(props: Html.Props, excluded: { string }): Html.Props
	local snapshot = Html.rest(props, excluded)
	if Records.owns(snapshot) then return snapshot end
	-- ReactLua clones component config before invoking a component. This narrow
	-- host snapshot owns only the string fields that survived that native copy;
	-- it cannot reconstruct source insertion order or erased undefined fields.
	local keys = {}
	for key in next, snapshot do
		assert(type(key) == "string", "Native component props snapshots require own string keys")
		table.insert(keys, key)
	end
	return Records.adopt(snapshot, keys)
end
type React = Html.React & { read Fragment: any, read useLayoutEffect: any }
export type Options = {
	element: Html.Factory?,
	development: boolean?,
	-- Accepted for older callers; source promises/animations do not consume it.
	promises: unknown?,
	flushSync: ((() -> ()) -> ())?,
	createPortal: ((any, any, any?) -> any)?,
	globals: { [string]: any }?,
	documentRoot: Instance?,
	scheduleJob: ((() -> ()) -> (() -> ())?)?,
	onJobError: ((any) -> ())?,
}

local function cleanupAll(callbacks: { () -> () })
	local failed, first = false, nil :: any
	for _, callback in callbacks do
		local ok, reason = pcall(callback)
		if not ok and not failed then failed, first = true, reason end
	end
	if failed then error(first, 0) end
end

function SourceRuntime.create(react: React, options: Options?)
	local settings: Options = options or {}
	if settings.documentRoot then
		assert(typeof(settings.documentRoot) == "Instance", "A document requires its actual native membership root")
		assert(not settings.globals or settings.globals.document == nil and settings.globals.window == nil,
			"An owned native document cannot be replaced by supplied document/window values")
	end
	local closed = false
	local timers: Timers.Context? = nil
	local frames: Frames.Context? = nil
	local jobs = SourceJobs.create({ schedule = settings.scheduleJob,
		onError = if settings.onJobError then function(reason: any) (settings.onJobError :: any)(Operations.caught(reason)) end else nil })
	local sourceOperations = table.clone(Operations) :: any
	local errorRealm = SourceErrors.create(sourceOperations)
	sourceOperations.caught = function(failure: any): any
		local value = Operations.caught(failure)
		local intrinsic = Operations.inspectIntrinsicError(value)
		if intrinsic then
			local constructor = assert(errorRealm[intrinsic.kind], "Unknown source intrinsic Error kind")
			return sourceOperations.construct(constructor, Arrays.adopt({ intrinsic.message }, 1))
		end
		return value
	end
	local raise: (any) -> never = sourceOperations.raise
	local argumentsPoison = sourceOperations.functionValue(function(): never
		return raise(sourceOperations.construct(errorRealm.TypeError,
			Arrays.adopt({ "Restricted strict arguments property" }, 1)))
	end, "", 0, "method")
	sourceOperations.argumentsObject = function(args: any, strict: boolean?): any
		return SourceArguments.create(sourceOperations, args, strict, argumentsPoison)
	end
	local urlRealm = SourceURL.create(sourceOperations)
	local promiseRealm = SourcePromise.create(sourceOperations, jobs)
	local asyncRealm = SourceAsync.create(sourceOperations, promiseRealm)
	sourceOperations.asyncFunctionValue, sourceOperations.awaitValue = asyncRealm.asyncFunctionValue, asyncRealm.awaitValue
	local abortRealm = Abort.createSource(sourceOperations, function(): any
		return sourceOperations.construct(errorRealm.DOMException,
			Arrays.adopt({ "This operation was aborted", "AbortError" }, 2))
	end)
	table.freeze(sourceOperations)
	local animationProvider: any = nil
	local attributeProvider: any = nil
	local domTargets: { [any]: boolean } = {}
	local documentRealm: SourceDocument.Context? = nil
	local documentClosed = false
	local documentRoot = settings.documentRoot
	local function releaseDomTargets()
		local callbacks: { () -> () } = {}
		for boundary in table.clone(domTargets) do table.insert(callbacks, boundary.release) end
		cleanupAll(callbacks)
	end
	local function animationTarget(context: Target.Context): WebAnimations.SourceElement
		assert(not closed, "Source runtime is destroyed")
		if not animationProvider then
			animationProvider = WebAnimations.createSource(sourceOperations, promiseRealm)
		end
		return animationProvider.target(context)
	end
	local function domTarget(target: GuiObject, context: Target.Context, tag: string?): any
		assert(not closed, "Source runtime is destroyed")
		assert(not documentClosed, "Source document is destroyed")
		local boundary = DomElements.create(target, context, {
			tag = tag,
			document = if documentRealm then documentRealm.document elseif settings.globals then settings.globals.document else nil,
			window = if documentRealm then documentRealm.window else nil,
			documentRoot = documentRoot,
			animations = animationTarget,
			events = if documentRealm then documentRealm.events else nil,
			pointer = if documentRealm then documentRealm.pointer else nil,
		})
		local release = boundary.release
		boundary.release = function()
			domTargets[boundary] = nil
			release()
		end
		domTargets[boundary] = true
		return boundary
	end
	local function observers(): any
		assert(not closed, "Source runtime is destroyed")
		if not attributeProvider then
			attributeProvider = AttributeObservers.create()
		end
		return attributeProvider
	end
	local queueState: any = { properties = Records.adopt({}, {}) }
	queueState.native = function(callback: any)
		assert(not closed, "Source runtime is destroyed")
		assert(SourceType.typeOf(callback) == "function", "TypeError: queueMicrotask callback must be callable")
		jobs.enqueue(function()
			local arguments = Arrays.adopt({}, 0)
			if type(callback) == "function" then
				Functions.invokeReference(Functions.reference(nil, function() return callback end, "free", false), function() return arguments end, false)
			else sourceOperations.call(callback, nil, arguments) end
		end)
	end
	local function queueMicrotask(callback: () -> ())
		queueState.native(callback)
	end
	queueState.source = function(_receiver: any, arguments: any)
		assert(not closed, "Source runtime is destroyed")
		local callback = arguments[1]
		assert(SourceType.typeOf(callback) == "function", "TypeError: queueMicrotask callback must be callable")
		jobs.enqueue(function() sourceOperations.call(callback, nil, Arrays.adopt({}, 0)) end)
	end
	Functions.named(queueMicrotask, "queueMicrotask", 1, false)
	Functions.source(queueMicrotask, queueState.source, queueState.properties)
	local flushSync = function(callback: () -> ())
		assert(not closed, "Source runtime is destroyed")
		assert(settings.flushSync, "Supply this renderer's flushSync implementation")(callback)
	end
	local createPortal = function(children: any, container: any, key: any?): any
		assert(not closed, "Source runtime is destroyed")
		assert(not Nulls.isNullish(container), "A portal requires its renderer's container")
		if settings.createPortal then return settings.createPortal(children, container, key) end
		-- Inline fallback retains context and React lifecycle when the host has no
		-- cross-root portal implementation. The caller's root owns the result.
		local kind = DomClasses.kind(container)
		assert(kind == "element" or kind == "html" or (typeof(container) == "Instance" and container:IsA("GuiObject")),
			"A portal requires a renderer DOM element or GuiObject")
		return react.createElement(react.Fragment, if key ~= nil then { key = key } else nil, children)
	end
	local function timer(): Timers.Context
		assert(not closed, "Source runtime is destroyed")
		if timers == nil then
			timers = Timers.create()
		end
		return timers :: Timers.Context
	end
	local function frame(): Frames.Context
		assert(not closed, "Source runtime is destroyed")
		if frames == nil then
			frames = Frames.create()
		end
		return frames :: Frames.Context
	end
	local browser: { [string]: any } = {
		queueMicrotask = queueMicrotask,
		setTimeout = function(callback: () -> (), milliseconds: number): number
			return timer().setTimeout(callback, milliseconds)
		end,
		clearTimeout = function(id: number)
			if timers then
				timers.clearTimeout(id)
			end
		end,
		requestAnimationFrame = function(callback: Frames.Callback): number
			return frame().requestAnimationFrame(callback)
		end,
		cancelAnimationFrame = function(id: number)
			if frames then
				frames.cancelAnimationFrame(id)
			end
		end,
	}
	for name, value in Values :: { [string]: any } do browser[name] = value end
	browser.Map, browser.Set, browser.WeakMap, browser.WeakSet = Collections.Map, Collections.Set, Collections.WeakMap, Collections.WeakSet
	browser.URL, browser.URLSearchParams = urlRealm.URL, urlRealm.URLSearchParams
	browser.Symbol, browser.JSON = Symbols.Symbol, Json
	browser.RegExp = Regex.Constructor
	browser.Node, browser.Element = DomClasses.Node, DomClasses.Element
	browser.HTMLElement, browser.ShadowRoot = DomClasses.HTMLElement, DomClasses.ShadowRoot
	browser.Document = DomClasses.Document
	browser.getComputedStyle = DomElements.computedStyle
	browser.performance = table.freeze({ now = function(): number return os.clock() * 1000 end })
	browser.console = table.freeze({ log = print, info = print, debug = print, warn = warn, error = warn })
	local NumberFormat = Operations.functionValue(function(_this, _args)
		local formatter = Operations.object()
		Operations.define(formatter, "format", Operations.functionValue(function(_, callArgs)
			local num = Operations.number(Operations.get(callArgs, 0))
			return Values.String(num)
		end, "format", 1, "ordinary"))
		Operations.define(formatter, "formatToParts", Operations.functionValue(function(_, callArgs)
			local num = Operations.number(Operations.get(callArgs, 0))
			local text = Values.String(num)
			local parts = {}
			if text:sub(1, 1) == "-" then
				table.insert(parts, Records.adopt({ type = "minusSign", value = "-" }, { "type", "value" }))
				text = text:sub(2)
			end
			local dot = text:find(".", 1, true)
			if dot then
				table.insert(parts, Records.adopt({ type = "integer", value = text:sub(1, dot - 1) }, { "type", "value" }))
				table.insert(parts, Records.adopt({ type = "decimal", value = "." }, { "type", "value" }))
				table.insert(parts, Records.adopt({ type = "fraction", value = text:sub(dot + 1) }, { "type", "value" }))
			else
				table.insert(parts, Records.adopt({ type = "integer", value = text }, { "type", "value" }))
			end
			return Arrays.adopt(parts, #parts)
		end, "formatToParts", 1, "ordinary"))
		Operations.define(formatter, "resolvedOptions", Operations.functionValue(function()
			return Records.adopt({ locale = "en-US", numberingSystem = "latn", style = "decimal", useGrouping = "auto" }, { "locale", "numberingSystem", "style", "useGrouping" })
		end, "resolvedOptions", 0, "ordinary"))
		return formatter
	end, "NumberFormat", 2, "ordinary")
	local intl = Records.adopt({ NumberFormat = NumberFormat }, { "NumberFormat" })

	local MutationObserver = Operations.classValue("MutationObserver", nil, false, function(_frame: any, args: any): any
		local callback = Operations.get(args, 0)
		assert(SourceType.typeOf(callback) == "function", "MutationObserver callback must be callable")
		local result = Operations.object()
		local function adoptRecords(records: any): any
			for index, record in records do
				if type(index) == "number" and type(record) == "table" and not Records.owns(record) then
					Records.adopt(record, { "type", "target", "attributeName", "oldValue", "addedNodes", "removedNodes", "previousSibling", "nextSibling" })
				end
			end
			return records
		end
		local native = observers().constructor.new(function(records: any, _observer: any)
			Operations.call(callback, result, Arrays.adopt({ adoptRecords(records), result }, 2))
		end)
		for _, name in { "observe", "disconnect", "takeRecords" } do
			local methodName = name
			Operations.define(result, methodName, Operations.registerNative(function(_self: any, ...: any): any
				local value = native[methodName](...)
				return if methodName == "takeRecords" then adoptRecords(value) else value
			end, "method", methodName, if methodName == "observe" then 2 else 0))
		end
		return result
	end, nil, 1)
	local globals = {
		Intl = intl,
		Infinity = math.huge,
		queueMicrotask = queueMicrotask,
		Promise = promiseRealm.Promise,
		AbortController = abortRealm.Controller,
		DOMException = errorRealm.DOMException,
		MutationObserver = MutationObserver,
		Error = errorRealm.Error,
		EvalError = errorRealm.EvalError,
		RangeError = errorRealm.RangeError,
		ReferenceError = errorRealm.ReferenceError,
		SyntaxError = errorRealm.SyntaxError,
		TypeError = errorRealm.TypeError,
		URIError = errorRealm.URIError,
		globalThis = browser,
		setTimeout = browser.setTimeout,
		clearTimeout = browser.clearTimeout,
		requestAnimationFrame = browser.requestAnimationFrame,
		cancelAnimationFrame = browser.cancelAnimationFrame,
		Date = table.freeze({
			now = function(): number
				return DateTime.now().UnixTimestampMillis
			end,
		}),
		process = table.freeze({
			env = table.freeze({ NODE_ENV = if settings.development then "development" else "production" }),
		}),
		Object = Objects,
		arrays = Arrays,
		renderNodes = RenderNodes.normalize,
		records = Records,
		nulls = Nulls,
		functions = Functions,
		sourceOperations = sourceOperations,
		propertyHas = Properties.has,
		enumerateKeys = Records.enumerate,
		keyString = Records.keyString,
		typeIs = SourceType.typeIs,
		typeOf = SourceType.typeOf,
	}
	for _, name in { "Promise", "AbortController", "DOMException", "MutationObserver", "Error", "Object", "Date" } do
		SourceType.register((globals :: any)[name], "function")
	end
	for name, value in browser do globals[name] = value end
	do
		local ok, result = pcall(SourceDocument.create, settings.documentRoot, DomElements.computedStyle, function()
			documentClosed = true
			releaseDomTargets()
		end)
		if not ok then
			asyncRealm.destroy(); promiseRealm.destroy(); abortRealm.destroy(); jobs.destroy(); urlRealm.destroy(); errorRealm.destroy()
			error(result, 0)
		end
		documentRealm = result
		globals.Event, globals.EventTarget = result.events.Event, result.events.EventTarget
		browser.Event, browser.EventTarget = result.events.Event, result.events.EventTarget
		globals.PointerEvent, browser.PointerEvent = result.events.PointerEvent, result.events.PointerEvent
		globals.document, globals.window = result.document, result.window
		browser.document, browser.window = result.document, result.window
	end
	-- Validate supplied ownership before acquiring any shared native schema.
	-- Failed construction must not leave a lease on a canonical namespace.
	for name in settings.globals or {} do
		if type(name) ~= "string" or globals[name] ~= nil then
			if documentRealm then documentRealm.destroy() end
			asyncRealm.destroy(); promiseRealm.destroy(); abortRealm.destroy(); jobs.destroy(); urlRealm.destroy(); errorRealm.destroy()
			error("Supplied globals cannot replace an owned runtime API", 2)
		end
	end
	for name, value in globals :: { [string]: any } do
		if type(value) == "function" then Operations.registerNative(value, "free", name) end
	end
	local namespaceReleases: { () -> () } = {}
	table.insert(namespaceReleases, Operations.registerBuiltinConstructors())
	for _, entry in {
		{ globals.Date, "Date" }, { globals.process, "process" }, { globals.process.env, "process.env" },
		{ Json, "JSON" }, { browser.console, "console" }, { browser.performance, "performance" },
	} do
		table.insert(namespaceReleases, Operations.registerNamespace(entry[1], entry[2]))
	end
	for name, value in settings.globals or {} do
		globals[name] = value
	end
	for name, value in globals do
		if name ~= "globalThis" then browser[name] = value end
	end
	local globalThis = if documentRealm then documentRealm.window else browser
	browser.globalThis, globals.globalThis = globalThis, globalThis
	table.freeze(browser)
	if documentRealm then documentRealm.installGlobals(browser)
	else table.insert(namespaceReleases, Operations.registerNamespace(browser, "globalThis")) end
	local buttonScope: any = nil
	local function bindSourceButton(target: GuiButton, options: any): any
		if not buttonScope then
			buttonScope = require(script.Parent.Parent.Primitives).createScope()
		end
		return buttonScope.bindButton(target, options)
	end
	local function bindSourceTextInput(target: TextBox, options: any): any
		if not buttonScope then
			buttonScope = require(script.Parent.Parent.Primitives).createScope()
		end
		return buttonScope.bindTextInput(target, options)
	end
	local nativeElement = settings.element or Html.create(react, if (settings :: any).staticSvg then { svg = (settings :: any).staticSvg } else nil, { createTarget = domTarget, sourceElements = true, bindSourceButton = bindSourceButton, bindSourceTextInput = bindSourceTextInput, pointerEvent = globals.PointerEvent })
	local reactBridge: any = nil
	local function element(tag: any, props: Html.Props?, ...: any): any
		if type(tag) ~= "string" and props ~= nil and Records.owns(props) then
			-- ReactLua table.clone retains metatables but cannot retain an owner's
			-- source ledger. Give native component config its own plain snapshot;
			-- intrinsic source metadata stays on the exact Html-owned path.
			local snapshot: Html.Props = {}
			for _, key in Records.keys(props) do snapshot[key] = Operations.get(props, key) end
			props = snapshot
		end
		return sourceElement(react, if reactBridge then reactBridge.nativeElement(tag,props,...) else nativeElement(tag, props, ...))
	end
	reactBridge = SourceReact.create(react, nativeElement, function(value: any): any return sourceElement(react, value) end, settings.development)
	local sourceReact = reactBridge.react
	if type((react :: any).isValidElement) == "function" then
		sourceReact.isValidElement = function(value: any): boolean
			local valid = (react :: any).isValidElement(value)
			if valid then sourceElement(react, value) end
			return valid
		end
	end
	for _, name in { "useState", "useReducer" } do
		local nativeHook = sourceReact[name]
		if type(nativeHook) == "function" then
			local invoke = nativeHook :: (...any) -> ...any
			local function hook(...: any): ...any
				assert(not closed, "Source runtime is destroyed")
				return invoke(...)
			end
			sourceReact[name] = hook
			table.insert(namespaceReleases, Operations.registerCall(hook, stateTuple))
		end
	end
	sourceReact.useRef = function(...: any): any
		assert(not closed, "Source runtime is destroyed")
		local ref = (react :: any).useRef(...)
		return sourceRef(ref)
	end
	if type((react :: any).createRef) == "function" then
		sourceReact.createRef = function(): any
			assert(not closed, "Source runtime is destroyed")
			local ref = (react :: any).createRef()
			ref.current = Nulls.value
			return sourceRef(ref)
		end
	end
	local namespaceKeys = {}
	for key in sourceReact do
		assert(type(key) == "string", "Source module namespaces require named exports")
		table.insert(namespaceKeys, key)
	end
	table.sort(namespaceKeys)
	Records.adopt(sourceReact, namespaceKeys)
	local releaseNamespace = Properties.register(sourceReact, function(key: any): boolean
		return Records.hasOwn(sourceReact, key)
	end)
	table.freeze(sourceReact)
	local releaseReactOperations = Operations.registerNamespace(sourceReact, "React")
	local reactBindings = Records.copy(sourceReact)
	reactBindings["*"] = sourceReact
	reactBindings.default = sourceReact
	local reactDom = table.freeze({ flushSync = flushSync, createPortal = createPortal })
	local releaseDomOperations = Operations.registerNamespace(reactDom, "ReactDOM")
	local jsxRuntime = table.freeze({ jsx = reactBridge.jsx, jsxs = reactBridge.jsxs, Fragment = sourceReact.Fragment })
	local jsxDevRuntime = table.freeze(Records.adopt({ jsxDEV = if settings.development then reactBridge.jsxDEV else nil, Fragment = sourceReact.Fragment }, { "Fragment", "jsxDEV" }))
	local releaseJsxOperations = Operations.registerNamespace(jsxRuntime, "JSX")
	local releaseJsxDevOperations = Operations.registerNamespace(jsxDevRuntime, "JSXDEV")
	return table.freeze({
		animationTarget = animationTarget,
		domTarget = domTarget,
		bindDocumentRoot = function(root: Instance)
			assert(not closed and not documentClosed, "Source document is destroyed")
			assert(documentRealm).bindRoot(root)
			documentRoot = root
		end,
		host = table.freeze({
			element = element,
			fragment = react.Fragment,
			rest = sourceRest,
			staticSvgProps = Html.staticSvgProps,
			numberStyle = NumericStyles.create,
			strings = Strings,
			typeOf = SourceType.typeOf,
		}),
		globals = table.freeze(globals),
		bindings = table.freeze({
			["react-dom"] = table.freeze({ ["*"] = reactDom, default = reactDom, flushSync = flushSync, createPortal = createPortal }),
			react = table.freeze(reactBindings),
			["react/jsx-runtime"] = jsxRuntime,
			["react/jsx-dev-runtime"] = jsxDevRuntime,
		}),
		destroy = function()
			if closed then
				return
			end
			closed = true
			local callbacks: { () -> () } = {
				reactBridge.destroy, asyncRealm.destroy, promiseRealm.destroy, jobs.destroy,
				abortRealm.destroy, urlRealm.destroy, errorRealm.destroy,
				function() cleanupAll(namespaceReleases) end,
				releaseReactOperations, releaseDomOperations, releaseJsxOperations, releaseJsxDevOperations,
				releaseDomTargets, releaseNamespace,
			}
			if documentRealm then table.insert(callbacks, documentRealm.destroy) end
			if attributeProvider then table.insert(callbacks, attributeProvider.destroy) end
			if animationProvider then table.insert(callbacks, animationProvider.destroy) end
			if timers then table.insert(callbacks, timers.destroy) end
			if frames then table.insert(callbacks, frames.destroy) end
			if buttonScope then table.insert(callbacks, buttonScope.destroy) end
			cleanupAll(callbacks)
		end,
	})
end
return SourceRuntime
