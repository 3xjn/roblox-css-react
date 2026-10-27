--!strict
-- Explicit values for the existing native abort capability. Source EventTarget
-- listener dispatch is deliberately separate. Source default reasons are supplied
-- by the owning genuine DOMException realm and revoked when that realm closes.
local Properties = require(script.Parent.Properties)
local Nulls = require(script.Parent.Nulls)
local Records = require(script.Parent.Records)
local Arrays = require(script.Parent.Arrays)
local Functions = require(script.Parent.FunctionValues)
local Operations = require(script.Parent.SourceOperations)
local Symbols = require(script.Parent.SourceSymbols)
local SourceType = require(script.Parent.SourceType)
export type Signal = {
	read aborted: boolean, read reason: unknown,
	read addEventListener: ("abort", () -> (), ({once:boolean?}|boolean)?) -> (),
	read removeEventListener: ("abort", () -> ()) -> (), read throwIfAborted: () -> (),
}
type Listener = {callback:any,once:boolean,capture:boolean,native:boolean}
type SignalState = {aborted:boolean,reason:any,listeners:{Listener},signal:any,fields:any,native:any,defaultReason:(() -> any)?}
local signalToken,controllerToken={},{}
local function signalState(owner:any):SignalState
	local meta=if type(owner)=="table" then getmetatable(owner) else nil
	local value:any=if type(meta)=="table" then rawget(meta,signalToken) else nil
	if not value then return Operations.intrinsicError("TypeError","Illegal AbortSignal receiver") end
	return value
end
local function controllerState(owner:any):any
	local meta=if type(owner)=="table" then getmetatable(owner) else nil
	local value:any=if type(meta)=="table" then rawget(meta,controllerToken) else nil
	if not value then return Operations.intrinsicError("TypeError","Illegal AbortController receiver") end
	return value
end
local function packet(...:any):any return Arrays.adopt({...},select("#",...)) end
local function abort(current:SignalState,reason:any)
	if current.aborted then return end
	local resolved=reason
	if resolved==nil then
		resolved=if current.defaultReason then current.defaultReason() else table.freeze({name="AbortError",message="The operation was aborted"})
	end
	current.aborted=true
	current.reason=resolved
	local event = Operations.object()
	for key, value in { type = "abort", target = current.signal, currentTarget = current.signal } do
		Operations.defineDataProperty(event, key, value, true, true, true)
	end
	for _, listener in table.clone(current.listeners) do
		local index = table.find(current.listeners, listener)
		if not index then continue end
		if listener.once then table.remove(current.listeners, index) end
		local callback = listener.callback
		local ok, failure = pcall(function()
			if listener.native then
				callback(event)
			elseif SourceType.typeOf(callback) == "function" then
				Operations.call(callback, current.signal, packet(event))
			else
				Operations.call(Operations.get(callback, "handleEvent"), callback, packet(event))
			end
		end)
		if not ok then warn(failure) end
	end

end
local signalPrototype=Operations.object()
Operations.defineDataProperty(signalPrototype,Symbols.Symbol.toStringTag,"AbortSignal",false,false,true)
local function method(prototype:any,name:string,length:number,callback:any)
	local value=Operations.registerNative(callback,"method",name,length)
	Operations.defineDataProperty(prototype,name,value,true,true,true)
	return value
end
local function getter(prototype:any,name:string,callback:any)
	Operations.defineAccessor(prototype,name,Operations.registerNative(callback,"method","get "..name,0),nil,true,true)
end
getter(signalPrototype,"aborted",function(self:any):boolean return signalState(self).aborted end)
getter(signalPrototype,"reason",function(self:any):any return signalState(self).reason end)
method(signalPrototype,"throwIfAborted",0,function(self:any)
	local current=signalState(self)
	if current.aborted then Operations.raise(current.reason) end
end)
local function capture(options:any):boolean
	if type(options) == "boolean" then return options end
	return if Nulls.isNullish(options) then false else Operations.truthy(Operations.get(options, "capture"))
end
local function addListener(self:any,kind:any,callback:any,options:any,native:boolean?)
	local current = signalState(self)
	if Operations.string(kind) ~= "abort" or Nulls.isNullish(callback) then return end
	local useCapture = capture(options)
	for _, listener in current.listeners do
		if listener.callback == callback and listener.capture == useCapture then return end
	end
	local once = not Nulls.isNullish(options) and type(options) ~= "boolean" and Operations.truthy(Operations.get(options, "once"))
	table.insert(current.listeners, { callback = callback, capture = useCapture, once = once, native = native == true })
end
local function removeListener(self:any,kind:any,callback:any,options:any)
	local current = signalState(self)
	if Operations.string(kind) ~= "abort" then return end
	local useCapture = capture(options)
	for index, listener in current.listeners do
		if listener.callback == callback and listener.capture == useCapture then table.remove(current.listeners, index); return end
	end
end
method(signalPrototype,"addEventListener",2,addListener)
method(signalPrototype,"removeEventListener",2,removeListener)

local signalSchema:Operations.NativeObject={
	tag="AbortSignal",
	hasOwn=function(owner:any,key:any):boolean
		if key=="onabort" or key=="dispatchEvent" then error("Source AbortSignal EventTarget capability is not installed",2) end
		return Records.hasOwn(signalState(owner).fields,key)
	end,
	get=function(owner:any,key:any,receiver:any):any return Records.readOwn(signalState(owner).fields,key,receiver) end,
	ownKeys=function(owner:any):any return Records.ownKeys(signalState(owner).fields) end,
	enumerable=function(owner:any,key:any):boolean local d=Records.descriptor(signalState(owner).fields,key);return d~=nil and d.enumerable end,
	getOwnPropertyDescriptor=function(owner:any,key:any):any return Operations.getOwnPropertyDescriptor(signalState(owner).fields,key) end,
	properties=function(owner:any):any return signalState(owner).fields end,
	prototype=function(owner:any):any local explicit,parent=Records.getPrototype(signalState(owner).fields);return if explicit then parent else signalPrototype end,
}
local controllerSchema:Operations.NativeObject={
	tag="AbortController",
	hasOwn=function(owner:any,key:any):boolean return Records.hasOwn(controllerState(owner).fields,key) end,
	get=function(owner:any,key:any,receiver:any):any return Records.readOwn(controllerState(owner).fields,key,receiver) end,
	ownKeys=function(owner:any):any return Records.ownKeys(controllerState(owner).fields) end,
	enumerable=function(owner:any,key:any):boolean local d=Records.descriptor(controllerState(owner).fields,key);return d~=nil and d.enumerable end,
	getOwnPropertyDescriptor=function(owner:any,key:any):any return Operations.getOwnPropertyDescriptor(controllerState(owner).fields,key) end,
	properties=function(owner:any):any return controllerState(owner).fields end,
	prototype=function(owner:any):any local explicit,parent=Records.getPrototype(controllerState(owner).fields);return if explicit then parent else controllerState(owner).prototype end,
}
local signalFields={aborted=true,reason=true,addEventListener=true,removeEventListener=true,throwIfAborted=true}
local function createController(prototype:any,defaultReason:(() -> any)?):any
	local current:SignalState={aborted=false,reason=nil,listeners={},signal=nil,fields=Operations.object(),native={},defaultReason=defaultReason}
	local signal:any={}
	current.signal=signal
	setmetatable(signal,{[signalToken]=current,__index=function(self:any,key:any):any
		local state=signalState(self)
		if key=="aborted" then return state.aborted elseif key=="reason" then return state.reason end
		return state.native[key]
	end})
	current.native.addEventListener=Operations.registerNative(function(kind:any,callback:any,options:any)
		local normalized = options
		if type(options) == "table" then
			normalized = Operations.object()
			Operations.defineDataProperty(normalized, "once", options.once, true, true, true)
			Operations.defineDataProperty(normalized, "capture", options.capture, true, true, true)
		end
		addListener(signal,kind,callback,normalized,true)
	end,"free","addEventListener",2)
	current.native.removeEventListener=Operations.registerNative(function(kind:any,callback:any,options:any)
		removeListener(signal,kind,callback,options)
	end,"free","removeEventListener",2)
	current.native.throwIfAborted=Operations.registerNative(function() if current.aborted then error(current.reason,0) end end,"free","throwIfAborted",0)
	Records.setReceiver(current.fields,signal)
	Operations.registerObject(signal,signalSchema)
	Properties.register(signal,function(key:any):boolean return signalFields[key]==true end)
	local state:any={signal=signal,prototype=prototype,fields=Operations.object(),nativeAbort=Operations.registerNative(function(reason:any)abort(current,reason)end,"free","abort",0)}
	local controller:any={}
	setmetatable(controller,{[controllerToken]=state,__index=function(self:any,key:any):any
		local value=controllerState(self)
		if key=="signal" then return value.signal elseif key=="abort" then return value.nativeAbort end
		return nil
	end})
	Records.setReceiver(state.fields,controller)
	Operations.registerObject(controller,controllerSchema)
	return controller
end
local function makeConstructor(ops:any,defaultReason:(() -> any)?,isOpen:(() -> boolean)?):any
 local controllerPrototype:any=nil
 local Controller=ops.classValue("AbortController",nil,false,function(frame:any)
  assert(not isOpen or isOpen(),"AbortController source realm has been destroyed")
  local prototype=Operations.get(Operations.classNewTarget(frame),"prototype")
  local kind=SourceType.typeOf(prototype)
  return createController(if not Nulls.isNull(prototype) and (kind=="object" or kind=="function") then prototype else controllerPrototype,defaultReason)
 end,nil,0)
 controllerPrototype=ops.get(Controller,"prototype")
 ops.defineDataProperty(controllerPrototype,Symbols.Symbol.toStringTag,"AbortController",false,false,true)
 getter(controllerPrototype,"signal",function(self:any):any return controllerState(self).signal end)
 method(controllerPrototype,"abort",0,function(self:any,reason:any)
  local current=signalState(controllerState(self).signal)
  if current.aborted then return end
  assert(reason~=nil or current.defaultReason~=nil,"Source AbortController.abort without a reason requires a real DOMException capability")
  abort(current,reason)
 end)
 return Controller
end
local Controller=makeConstructor(Operations,nil,nil)
local function createSource(ops:any,defaultReason:() -> any):any
 -- External producers may retain controllers. Only this revocable box owns the
 -- realm callback, so destroying a context severs that edge without aborting
 -- producers or erasing their user-owned reasons/properties/listeners.
 local box:{callback:(() -> any)?,closed:boolean}={callback=defaultReason,closed=false}
 local function getDefault():any
  local callback=box.callback
  assert(callback~=nil,"AbortController default DOMException realm has been destroyed")
  return callback()
 end
 local source=makeConstructor(ops,getDefault,function():boolean return not box.closed end)
 return {Controller=source,destroy=function()box.closed=true;box.callback=nil end}
end
return {Controller=Controller,createSource=createSource,resolveSignal=function(signal:any):any signalState(signal); return signal end}

