--!strict
-- Source-value projection over actual ReactLua objects. Native tags and symbols
-- remain untouched: only the explicit source schema and host call gateways differ.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Functions = require(script.Parent.FunctionValues)
local Operations = require(script.Parent.SourceOperations)
local Symbols = require(script.Parent.SourceSymbols)
local Html = require(script.Parent.Html)
local Objects = require(script.Parent.SourceObjects)
local Bridge = {}
export type Realm = {
 react: any,
 jsx: (any,any,any?) -> any,
 jsxs: (any,any,any?) -> any,
 jsxDEV: (any,any,any?,boolean?) -> any,
 cloneElement: (any,any?,...any) -> any,
 element: (any,any?,...any) -> any,
 nativeElement: (any,any?,...any) -> any,
 destroy: () -> (),
}
-- Finite source data protocol; this is not the native renderer's version.
Bridge.protocolVersion = '19.3.1'
local infoToken, propsToken, objectToken = {}, {}, {}
local function packet(...: any): any return Arrays.adopt({...},select('#',...)) end
local function info(value: any, token: any): any
 if type(value)~='table' then return nil end
 local meta=getmetatable(value)
 return if type(meta)=='table' then rawget(meta,token) else nil
end
local function attach(value: any, token: any, state: any)
 local meta=table.clone(getmetatable(value) or {}) :: any
 meta[token]=state
 setmetatable(value,meta)
end
function Bridge.info(element: any): any return info(element,infoToken) end
local function nativeProps(value: any): any
 if Records.owns(value) then return value end
 local exact=info(value,propsToken)
 if exact then return exact end
 local result,keys={},{}
 for key,item in next,value do
  assert(type(key)=='string','Native React props need own string keys')
  result[key]=item;table.insert(keys,key)
 end
 return Records.adopt(result,keys)
end
local function invoke(callback: any,args: any): any
 -- This host boundary is explicitly a free callback ABI. Registered source
 -- method functions use their source dispatch rather than raw receiver-first entry.
 return Functions.invokeReference(Functions.reference(nil,function() return callback end,'free',false),function() return args end,false)
end
local function renderNode(value: any,parents: any?): any
 if Nulls.isNull(value) then return nil end
 if not Arrays.owns(value) then return value end
 local active=parents or {}
 assert(not active[value],'React child arrays cannot contain cycles')
 active[value]=true
 local result={}
 for at=0,Arrays.length(value)-1 do
  local child=renderNode(Operations.get(value,at),active)
  result[at+1]=if child==nil then false else child
 end
 active[value]=nil
 return result
end
local schema: Operations.NativeObject={
 hasOwn=function(owner,key) return Records.hasOwn(assert(info(owner,objectToken)).fields,key) end,
 get=function(owner,key,_receiver)
  local state=assert(info(owner,objectToken))
  if key=='displayName' then return state.native.displayName end
  return Operations.get(state.fields,key)
 end,
 ownKeys=function(owner) return Records.ownKeys(assert(info(owner,objectToken)).fields) end,
 enumerable=function(owner,key)
  local desc=Operations.getOwnPropertyDescriptor(assert(info(owner,objectToken)).fields,key)
  return desc~=nil and Operations.get(desc,'enumerable')==true
 end,
 getOwnPropertyDescriptor=function(owner,key)
  local state=assert(info(owner,objectToken))
  local desc=Operations.getOwnPropertyDescriptor(state.fields,key)
  if desc and key=='displayName' and Records.hasOwn(desc,'value') then Operations.set(desc,'value',state.native.displayName) end
  return desc
 end,
 set=function(owner,key,value)
  local state=assert(info(owner,objectToken))
  assert(key~='$$typeof' and key~='render' and key~='type' and key~='compare' and key~='Provider' and key~='Consumer','Mutation of native React structural fields needs a checked host operation')
  Operations.set(state.fields,key,value)
  if key=='displayName' then state.native.displayName=value end
 end,
 define=function(owner,key,value)
  local state=assert(info(owner,objectToken))
  assert(key~='$$typeof' and key~='render' and key~='type' and key~='compare' and key~='Provider' and key~='Consumer','Redefining native React structural fields is unsupported')
  Operations.define(state.fields,key,value)
  if key=='displayName' then state.native.displayName=value end
 end,
 remove=function(owner,key)
  local state=assert(info(owner,objectToken))
  assert(key~='$$typeof' and key~='render' and key~='type' and key~='compare' and key~='Provider' and key~='Consumer','Deleting native React structural fields is unsupported')
  if key=='displayName' then state.native.displayName=nil end
  return Operations.remove(state.fields,key)
 end,
}
local function qualify(native: any, fields: any, kind: string, development: boolean?, nameTarget: any?): any
 local owner={}
 attach(owner,objectToken,{native=native,fields=fields,kind=kind})
 local meta=getmetatable(owner) :: any
 meta.__index=function(_self: any,key: any): any return schema.get(owner,key,owner) end
 meta.__newindex=function(_self: any,key: any,value: any) assert(schema.set)(owner,key,value) end
 if development and (kind=='forwardRef' or kind=='memo') then
  local function writeName(value: any)
   native.displayName=value
   if nameTarget~=nil and not Nulls.truthy(Operations.get(nameTarget,'name')) and not Nulls.truthy(Operations.get(nameTarget,'displayName')) then
    local targetState=info(nameTarget,objectToken)
    local holder=if targetState then targetState.fields else nameTarget
    local old=Operations.getOwnPropertyDescriptor(holder,'name')
    Operations.defineDataProperty(holder,'name',value,false,false,old~=nil and Operations.get(old,'configurable')==true)
    Operations.set(nameTarget,'displayName',value)
   end
  end
  local getter=Operations.functionValue(function(): any return native.displayName end,'',0,'method')
  local setter=Operations.functionValue(function(_receiver: any,args: any) writeName(args[1]) end,'',1,'method')
  Operations.defineAccessor(fields,'displayName',getter,setter,false,true)
  Operations.namedValue(getter,'get');Operations.namedValue(setter,'set')
 end
 Operations.registerObject(owner,schema)
 return owner
end
function Bridge.create(react: any, host: any, qualifyElement: any, development: boolean?): Realm
 local closed=false
 local boxes: {[any]: boolean}=setmetatable({},{__mode='k'}) :: any
 local wrappers: {[any]: any}=setmetatable({},{__mode='kv'}) :: any
 local dispatches: {[any]: any}=setmetatable({},{__mode='kv'}) :: any
 local refs: {[any]: any}=setmetatable({},{__mode='kv'}) :: any
 local refSources: {[any]: any}=setmetatable({},{__mode='kv'}) :: any
 local originals: {[any]: any}=setmetatable({},{__mode='kv'}) :: any
 local nativeTags: {[any]: any}={}
 local publicTags: {[string]: any}={}
 local tagNames: {[string]: string}={Fragment='react.fragment',StrictMode='react.strict_mode',Suspense='react.suspense',Profiler='react.profiler',SuspenseList='react.suspense_list'}
 for name,description in tagNames do
  if react[name]~=nil then
   local symbol=Symbols.Symbol['for'](description)
   publicTags[name]=symbol;nativeTags[symbol]=react[name]
  end
 end
 local function gateway(callback: any, transform: any?, after: any?): any
  assert(not closed,'Source React runtime is destroyed')
  local box: any={callback=callback,transform=transform,after=after}
  boxes[box]=true
  local wrapped=function(...: any): any
   if box.callback==nil then return nil end
   local args=packet(...)
   if box.transform then args=(box.transform :: any)(args) end
   local result=invoke(box.callback,args)
   return if box.after then (box.after :: any)(result) else result
  end
  originals[wrapped]=callback
  return wrapped
 end
 local function dependencies(value: any, retainPrevious: boolean?): any
  assert(not closed,'Source React runtime is destroyed')
  -- The native 17 peer additionally invalidates on a dependency length change.
  -- A native ref and commit effect adapt this input to the source 19 protocol;
  -- actual native hooks still own memo storage, scheduling and cleanup.
  local reference=react.useRef(nil)
  local previous=reference.current
  local candidate: any=nil
  if not Nulls.isNullish(value) then
   assert(Arrays.owns(value),'Source hook dependencies need a logical source array')
   local equal=previous~=nil
   if previous then
    local at=0
    while at<Arrays.length(value) and at<Arrays.length(previous.source) do
     local nextValue=Operations.get(value,at)
     local previousValue=Operations.get(previous.source,at)
     if not Objects.is(nextValue,previousValue) then equal=false;break end
     at+=1
    end
   end
   if equal then
    candidate=if retainPrevious then previous else {source=value,native=previous.native}
   else candidate={source=value,native={table.freeze({})}} end
  end
  -- An interrupted render must not replace the last committed dependency
  -- reference. This callback is revocable along with other owned host entries.
  react.useLayoutEffect(gateway(function() reference.current=candidate end))
  return if candidate then candidate.native else nil
 end
 local function component(tag: any): any
  if nativeTags[tag]~=nil then return nativeTags[tag] end
  local state=info(tag,objectToken)
  if state then return if state.kind=='context' then state.native.Provider else state.native end
  if type(tag)~='function' or not Functions.isSource(tag) then return tag end
  local wrapper=wrappers[tag]
  if wrapper then return wrapper end
  wrapper=gateway(tag,function(args: any): any
   Arrays.set(args,0,nativeProps(args[1]))
   -- React19 no longer forwards the native peer's legacy context argument.
   Arrays.set(args,1,nil);Arrays.setLength(args,2)
   return args
  end,renderNode)
  wrappers[tag]=wrapper
  return wrapper
 end
 local function keys(value: any): any
  if Records.owns(value) then return Records.keys(value) end
  local result={}
  for key in next,value do assert(type(key)=='string','React config requires own string keys');table.insert(result,key) end
  return Arrays.adopt(result,#result)
 end
 local function read(value: any,key: string): any
  return if Records.owns(value) then Operations.get(value,key) else value[key]
 end
 local function sourceCopy(value: any,skip: any?,symbols: boolean?): any
  local result=Operations.object()
  if Nulls.isNullish(value) then return result end
  for _,key in keys(value) do if not skip or not skip[key] then Operations.define(result,key,read(value,key)) end end
  if symbols and Records.owns(value) then
   for _,key in Records.ownKeys(value) do
    if type(key)~='string' then
     local desc=Operations.getOwnPropertyDescriptor(value,key)
     if Operations.get(desc,'enumerable') then Operations.define(result,key,Operations.get(value,key)) end
    end
   end
  end
  return result
 end
 local function keyString(value: any): string return Operations.binary('+','',value) end
 local function checkKey(value: any)
  local ok=pcall(keyString,value)
  if not ok then keyString(value) end
 end
 local function freeze(value: any): any return Operations.call(Operations.get(Objects,'freeze'),nil,packet(value)) end
 local function sourceKey(config: any,explicit: any): (any,boolean)
  if development and explicit~=nil then checkKey(explicit) end
  local key=if explicit==nil then Nulls.value else keyString(explicit)
  local valid=not Nulls.isNullish(config) and read(config,'key')~=nil
  if valid then
   if development then checkKey(read(config,'key')) end
   key=keyString(read(config,'key'))
  end
  return key,valid
 end
 local function refValue(ref: any): any
  assert(not closed,'Source React runtime is destroyed')
  if Nulls.isNullish(ref) then return nil end
  if not refs[ref] then
   if type(ref)=='function' then
    refs[ref]=gateway(ref,function(args: any): any
     if args[1]==nil then Arrays.set(args,0,Nulls.value) end
     return args
    end,function(result: any): any
     assert(type(result)~='function','React ref cleanup return functions require a renderer with native ref cleanup ownership')
     return nil
    end)
   else
    assert(type(ref)=='table','React refs need a callback or mutable object')
    local box: any={reference=ref}
    boxes[box]=true
    refs[ref]=setmetatable({}, {
     __index=function(_self: any,key: any): any
      assert(key=='current','Native ref proxy exposes only current')
      if not box.reference then return nil end
      local value=box.reference.current
      return if Nulls.isNull(value) then nil else value
     end,
     __newindex=function(_self: any,key: any,value: any)
      assert(key=='current','Native ref proxy exposes only current')
      if box.reference then box.reference.current=if value==nil then Nulls.value else value end
     end,
    })
   end
   refSources[refs[ref]]=ref
  end
  return refs[ref]
 end
 local function takesNativeRef(tag: any): boolean
  local state=info(tag,objectToken)
  if state and state.kind=='memo' then return takesNativeRef(Operations.get(state.fields,'type')) end
  return state and state.kind=='forwardRef' or type(tag)~='function' or not Functions.isSource(tag)
 end
 local function make(tag: any,props: any,key: any): any
  assert(not closed,'Source React runtime is destroyed')
  local config: Html.Props={}
  for _,name in keys(props) do if name~='ref' then config[name]=read(props,name) end end
  config.children=renderNode(config.children)
  local tagState=info(tag,objectToken)
  if tagState and tagState.kind=='consumer' and type(config.children)=='function' then
   config.children=gateway(config.children,function(args: any): any
    -- The actual React19 development consumer uses callComponentInDEV(value,
    -- undefined); its production path calls render(value) directly.
    if development then Arrays.set(args,1,nil);Arrays.setLength(args,2) end
    return args
   end,renderNode)
  end
  if not Nulls.isNullish(key) then config.key=key end
  local ref=read(props,'ref')
  if takesNativeRef(tag) then config.ref=refValue(ref) end
  local element=host(component(tag),config)
  local resolvedRef=if ref==nil then Nulls.value else ref
  local projection=Records.adopt({['$$typeof']=Symbols.Symbol['for']('react.transitional.element'),type=tag,key=key,ref=resolvedRef,props=props},{'$$typeof','type','key','ref','props'})
  if development then
   if not Nulls.isNull(key) and key~='' then
    local getter=Operations.functionValue(function(): any return nil end,'warnAboutAccessingKey',0,'method')
    Operations.set(getter,'isReactWarning',true)
    Operations.defineAccessor(props,'key',getter,nil,false,true)
    Operations.namedValue(getter,'warnAboutAccessingKey')
   end
   if Nulls.isNull(resolvedRef) then Operations.defineDataProperty(projection,'ref',resolvedRef,false,false,false)
   else
    local getter=Operations.functionValue(function(): any return resolvedRef end,'',0,'method')
    Operations.defineAccessor(projection,'ref',getter,nil,false,false)
    Operations.namedValue(getter,'elementRefGetterWithDeprecationWarning')
   end
   freeze(props);freeze(projection)
  end
  local state={tag=tag,props=props,key=key,ref=resolvedRef,projection=projection,development=development==true}
  attach(element,infoToken,state)
  if type(element.props)=='table' then attach(element.props,propsToken,props) end
  return qualifyElement(element)
 end
 local function createElement(tag: any,config: any?,...: any): any
  assert(not closed,'Source React runtime is destroyed')
  local key=sourceKey(config,nil)
  local props=sourceCopy(config,{key=true,__self=true,__source=true})
  local count=select('#',...)
  if count==1 then Operations.define(props,'children',(...)) elseif count>1 then Operations.define(props,'children',packet(...)) end
  if type(tag)=='function' and Functions.isSource(tag) or info(tag,objectToken) then
   local defaults=Operations.get(tag,'defaultProps')
   if Nulls.truthy(defaults) then
    for _,name in Operations.keys(defaults) do if read(props,name)==nil then Operations.define(props,name,Operations.get(defaults,name)) end end
   end
  end
  return make(tag,props,key)
 end
 local function emitJsx(tag: any,config: any,explicit: any?,staticChildren: boolean?): any
  assert(not closed,'Source React runtime is destroyed')
  assert(not Nulls.isNullish(config),'JSX config must be an object')
  if development then
   local children=read(config,'children')
   if staticChildren and Arrays.owns(children) then freeze(children) end
  end
  local key=sourceKey(config,explicit)
  local props=config
  local hasKey=if Records.owns(config) then Operations.binary('in','key',config) else config.key~=nil
  if hasKey then
   props=Operations.object()
   local names=if Records.owns(config) then Operations.keys(config) else keys(config)
   for _,name in names do if name~='key' then Operations.define(props,name,read(config,name)) end end
  elseif Records.owns(config) then
   for _,name in keys(config) do
    local desc=Operations.getOwnPropertyDescriptor(config,name)
    assert(name=='ref' or Operations.binary('in','value',desc),'JSX config with deferred accessors needs a native lazy-props bridge')
   end
  end
  return make(tag,props,key)
 end
 local function jsx(tag: any,config: any,explicit: any?): any return emitJsx(tag,config,explicit,false) end
 local jsxs=if development then function(tag: any,config: any,explicit: any?): any return emitJsx(tag,config,explicit,true) end else jsx
 local function jsxDEV(tag: any,config: any,explicit: any?,staticChildren: boolean?): any return emitJsx(tag,config,explicit,staticChildren) end
 local function cloneElement(element: any,config: any?,...: any): any
  assert(not closed,'Source React runtime is destroyed')
  local previous=Bridge.info(element)
  if not previous then return qualifyElement(Html.cloneElement(react,host,element,config,...)) end
  local props=sourceCopy(previous.props,nil,true)
  local key,validKey=sourceKey(config,nil)
  if not validKey then key=previous.key end
  if not Nulls.isNullish(config) then
   for _,name in keys(config) do
    if name~='key' and name~='__self' and name~='__source' then
     if name~='ref' or read(config,'ref')~=nil then Operations.define(props,name,read(config,name)) end
    end
   end
  end
  local count=select('#',...)
  if count==1 then Operations.define(props,'children',(...)) elseif count>1 then Operations.define(props,'children',packet(...)) end
  return make(previous.tag,props,key)
 end
 local source=table.clone(react)
 for name,value in publicTags do source[name]=value end
 source.version=Bridge.protocolVersion
 source.createElement,source.cloneElement=createElement,cloneElement
 source.forwardRef=function(render: any): any
  assert(not closed,'Source React runtime is destroyed')
  local wrapped=gateway(render,function(args: any): any
   local props=nativeProps(args[1])
   if Operations.binary('in','ref',props) then
    local without=Operations.object()
    for _,name in Operations.keys(props) do if name~='ref' then Operations.define(without,name,Operations.get(props,name)) end end
    props=without
   end
   Arrays.set(args,0,props)
   Arrays.set(args,1,if args[2]==nil then Nulls.value else refSources[args[2]] or args[2])
   return args
  end,renderNode)
  local result=react.forwardRef(wrapped)
  local fields=Records.adopt({['$$typeof']=Symbols.Symbol['for']('react.forward_ref'),render=render},{'$$typeof','render'})
  return qualify(result,fields,'forwardRef',development,render)
 end
 source.memo=function(tag: any,compare: any?): any
  assert(not closed,'Source React runtime is destroyed')
  local wrapped=if compare==nil then nil else gateway(compare,function(args: any): any
   Arrays.set(args,0,nativeProps(args[1]));Arrays.set(args,1,nativeProps(args[2]));return args
  end,function(result: any): boolean return Nulls.truthy(result) end)
  local result=react.memo(component(tag),wrapped)
  return qualify(result,Records.adopt({['$$typeof']=Symbols.Symbol['for']('react.memo'),type=tag,compare=if compare==nil then Nulls.value else compare},{'$$typeof','type','compare'}),'memo',development,tag)
 end
 source.createContext=function(default: any): any
  assert(not closed,'Source React runtime is destroyed')
  local result=react.createContext(default)
  local consumer=result.Consumer
  local context=qualify(result,Records.adopt({['$$typeof']=Symbols.Symbol['for']('react.context')},{'$$typeof'}),'context')
  local contextState=assert(info(context,objectToken))
  local projectedConsumer=qualify(consumer,Records.adopt({['$$typeof']=Symbols.Symbol['for']('react.consumer'),_context=context},{'$$typeof','_context'}),'consumer')
  Operations.define(contextState.fields,'Provider',context);Operations.define(contextState.fields,'Consumer',projectedConsumer)
  return context
 end
 for _,name in {'useMemo','useEffect','useLayoutEffect','useInsertionEffect'} do
  local hook=react[name]
  if type(hook)=='function' then source[name]=function(callback: any,deps: any): any
   if name=='useMemo' then return (hook :: any)(gateway(callback),dependencies(deps,true)) end
   return (hook :: any)(gateway(callback,nil,function(cleanup: any): any
    return if type(cleanup)=='function' then gateway(cleanup) else cleanup
   end),dependencies(deps))
  end end
 end
 if type(source.useInsertionEffect)~='function' and type(source.useLayoutEffect)=='function' then
  source.useInsertionEffect=source.useLayoutEffect
 end
 if type(source.useId)~='function' then
  local nextId=0
  local useId=function(): string
   assert(not closed,'Source React runtime is destroyed')
   local ref=react.useRef(nil)
   if ref.current==nil then nextId+=1;ref.current=':r'..tostring(nextId)..':' end
   return ref.current
  end
  Operations.registerNative(useId,'free','useId',0)
  source.useId=useId
 end
 if type(source.useSyncExternalStore)~='function' then
  local useSyncExternalStore=function(subscribe: any,getSnapshot: any): any
   assert(not closed,'Source React runtime is destroyed')
   local value=invoke(getSnapshot,packet())
   local _,setState=react.useState(0)
   local current=react.useRef({value=value,getSnapshot=getSnapshot})
   local function check()
    local ok,nextValue=pcall(invoke,current.current.getSnapshot,packet())
    if not ok or not Objects.is(current.current.value,nextValue) then
     setState(function(previous: number): number return previous+1 end)
    end
   end
   react.useLayoutEffect(function()
    current.current.value=value
    current.current.getSnapshot=getSnapshot
    check()
   end)
   react.useEffect(function()
    local unsub=invoke(subscribe,packet(Operations.registerNative(check,'free')))
    check()
    return if type(unsub)=='function' then gateway(unsub) else nil
   end,{subscribe})
   return value
  end
  Operations.registerNative(useSyncExternalStore,'free','useSyncExternalStore',2)
  source.useSyncExternalStore=useSyncExternalStore
 end
 source.useContext=function(context: any): any
  assert(not closed,'Source React runtime is destroyed')
  local state=info(context,objectToken)
  return react.useContext(if state then state.native else context)
 end
 source.useCallback=function(callback: any,deps: any): any
  local wrapped=gateway(callback)
  local selected=react.useCallback(wrapped,dependencies(deps,true))
  -- Own gateways carry their source identity without a strong registry edge.
  return originals[selected] or selected
 end
 source.useImperativeHandle=function(ref: any,create: any,deps: any)
  return react.useImperativeHandle(refValue(ref),gateway(create),dependencies(deps))
 end
 for _,name in {'useState','useReducer'} do
  local hook=react[name]
  if type(hook)=='function' then source[name]=function(...: any): ...any
   local args=packet(...)
   if name=='useState' then
    if type(args[1])=='function' then Arrays.set(args,0,gateway(args[1])) end
   else
    Arrays.set(args,0,gateway(args[1]))
    if type(args[3])=='function' then Arrays.set(args,2,gateway(args[3])) end
   end
   local value,nativeDispatch=(hook :: any)(table.unpack(args,1,Arrays.length(args)))
   local dispatch=dispatches[nativeDispatch]
   if not dispatch then
    dispatch=gateway(nativeDispatch,function(actions: any): any
     if name=='useState' and type(actions[1])=='function' then Arrays.set(actions,0,gateway(actions[1])) end
     return actions
    end)
    Operations.registerNative(dispatch,'free',nil,1)
    dispatches[nativeDispatch]=dispatch
   end
   return value,dispatch
  end end
 end
 return {
  react=source,jsx=jsx,jsxs=jsxs,jsxDEV=jsxDEV,cloneElement=cloneElement,element=createElement,
  nativeElement=function(tag: any,props: any,...: any): any return host(component(tag),props,...) end,
  destroy=function()
   if closed then return end
   closed=true
   for box in boxes do box.callback,box.transform,box.after,box.reference=nil,nil,nil,nil end
   table.clear(wrappers);table.clear(dispatches);table.clear(originals);table.clear(refs);table.clear(refSources)
  end,
 }
end
return Bridge
