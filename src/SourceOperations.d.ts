declare const bindingToken:unique symbol;
declare const iteratorToken:unique symbol;
export interface Binding {readonly [bindingToken]:never}
export interface Iterator {readonly [iteratorToken]:never}
export interface NativeObject {
 /** Explicit intrinsic object class for Object.prototype.toString. */
 readonly tag?:string;
 readonly hasOwn:(owner:unknown,key:unknown)=>boolean;
 readonly get:(owner:unknown,key:unknown,receiver:unknown)=>unknown;
 readonly ownKeys:(owner:unknown)=>readonly unknown[];
 readonly enumerable:(owner:unknown,key:unknown)=>boolean;
 readonly prototype?:(owner:unknown)=>unknown;
 readonly set?:(owner:unknown,key:unknown,value:unknown)=>void;
 readonly define?:(owner:unknown,key:unknown,value:unknown)=>void;
 readonly remove?:(owner:unknown,key:unknown)=>boolean;
 readonly call?:(owner:unknown,receiver:unknown,args:readonly unknown[])=>unknown;
 readonly getOwnPropertyDescriptor?:(owner:unknown,key:unknown)=>unknown;
 /** Complete ordinary own-property storage, anchored by this native owner. */
 readonly properties?:(owner:unknown)=>object;
 /** Explicit host-only OrdinaryHasInstance case; undefined delegates to the
  * shared source prototype algorithm. User Symbol.hasInstance takes priority. */
 readonly ordinaryHasInstance?:(owner:unknown,value:unknown)=>boolean|undefined;
}
/** Deliberately opaque value operations used by the JavaScript-body compiler.
 * Unsupported native objects/callables require an explicit registered schema;
 * this provider never guesses Lua receiver conventions or object behavior. */
export interface Provider {
 readonly wrapThrown:(value:unknown)=>unknown;
 readonly raise:(value:unknown)=>never;
 readonly caught:(value:unknown)=>unknown;
 readonly intrinsicError:(kind:string,message:string)=>never;
 readonly inspectIntrinsicError:(value:unknown)=>{readonly kind:string;readonly message:string}|undefined;
 readonly regexp:(pattern:string,flags:string)=>unknown;
 readonly get:(receiver:unknown,key:unknown)=>unknown;
 readonly key:(value:unknown)=>unknown;
 readonly set:(receiver:unknown,key:unknown,value:unknown)=>unknown;
 readonly define:(receiver:unknown,key:unknown,value:unknown)=>unknown;
 readonly remove:(receiver:unknown,key:unknown)=>boolean;
 readonly delete:Provider['remove'];
 readonly unary:(operator:string,value:unknown)=>unknown;
 readonly binary:(operator:string,left:unknown,right:unknown)=>unknown;
 readonly call:(callback:unknown,receiver:unknown,args:readonly unknown[])=>unknown;
 readonly construct:(constructor:unknown,args:readonly unknown[],newTarget?:unknown)=>unknown;
 readonly functionValue:(callback:(this:void,receiver:unknown,args:readonly unknown[],newTarget:unknown)=>unknown,name:string,length:number,kind:'ordinary'|'arrow'|'method')=>unknown;
 readonly classValue:(name:string,base:unknown,derived:boolean,constructor:((this:void,frame:unknown,args:readonly unknown[])=>unknown)|undefined,fields:((this:void,receiver:unknown)=>void)|undefined,length:number)=>unknown;
 readonly classThis:(frame:unknown)=>unknown;
 readonly classNewTarget:(frame:unknown)=>unknown;
 readonly superConstruct:(frame:unknown,args:readonly unknown[])=>unknown;
 readonly defineMethod:(owner:unknown,key:unknown,value:unknown)=>unknown;
 readonly defineAccessor:(owner:unknown,key:unknown,get:unknown,set:unknown,enumerable:boolean,configurable?:boolean)=>unknown;
 readonly defineField:(owner:unknown,key:unknown,value:unknown)=>unknown;
 readonly defineDataProperty:(owner:unknown,key:unknown,value:unknown,writable:boolean,enumerable:boolean,configurable:boolean)=>unknown;
 readonly getOwnPropertyDescriptor:(owner:unknown,key:unknown)=>unknown;
 readonly getPrototype:(owner:unknown)=>unknown;
 readonly setIntrinsicTag:(owner:unknown,tag:string)=>unknown;
 readonly namedValue:(value:unknown,key:unknown,prefix?:string)=>unknown;
 readonly argumentsObject:(args:readonly unknown[],strict?:boolean)=>unknown;
 readonly asyncFunctionValue:Provider['functionValue'];
 readonly awaitValue:(value:unknown)=>unknown;
 readonly truthy:(value:unknown)=>boolean;
 readonly toPrimitive:(value:unknown,hint?:'default'|'string'|'number')=>unknown;
 readonly string:(value:unknown)=>string;
 readonly number:(value:unknown)=>number;
 readonly keys:(value:unknown)=>string[];
 /** A previously resolved iterator method avoids repeating an observable getter. */
 readonly iterable:(value:unknown,method?:unknown)=>Generator<unknown,void,unknown>;
 readonly array:(values:readonly unknown[],length:number,holes?:readonly number[])=>unknown[];
 readonly arrayPush:(target:unknown,value:unknown)=>void;
 readonly arrayHole:(target:unknown)=>void;
 readonly arraySpread:(target:unknown,value:unknown)=>void;
 readonly object:(prototype?:unknown)=>unknown;
 readonly setPrototype:(value:unknown,prototype:unknown)=>unknown;
 readonly spreadObject:(target:unknown,value:unknown)=>void;
 readonly requireObject:(value:unknown)=>void;
 readonly objectRest:(value:unknown,exclusions:readonly unknown[])=>unknown;
 readonly binding:(kind:'var'|'let'|'const',name:string)=>Binding;
 readonly initialize:(binding:Binding,value:unknown)=>unknown;
 readonly read:(binding:Binding)=>unknown;
 readonly write:(binding:Binding,value:unknown)=>unknown;
 readonly iterator:(value:unknown)=>Iterator;
 readonly next:(iterator:Iterator)=>unknown;
 readonly iteratorRest:(iterator:Iterator)=>unknown[];
 readonly close:(iterator:Iterator,abrupt?:boolean)=>void;
 readonly registerNative:(callback:unknown,policy:'free'|'method',name?:string,length?:number)=>unknown;
 /** Explicit source-call result conversion; direct native calls retain their ABI. */
 readonly registerCall:(callback:unknown,invoke:(callback:unknown,receiver:unknown,args:readonly unknown[])=>unknown)=>()=>void;
 /** The returned release function owns the registration lease; retain it until release. */
 readonly registerConstructor:(constructor:unknown,invoke:(constructor:unknown,args:readonly unknown[],newTarget:unknown)=>unknown,supportsNewTarget?:boolean)=>()=>void;
 readonly registerBuiltinConstructors:()=>()=>void;
 readonly registerObject:(value:unknown,capability:NativeObject)=>()=>void;
 readonly registerNamespace:(value:object,name:string)=>()=>void;
}
export declare const get:Provider['get'];
export declare const raise:Provider['raise'];
export declare const wrapThrown:Provider['wrapThrown'];
export declare const caught:Provider['caught'];
export declare const intrinsicError:Provider['intrinsicError'];
export declare const inspectIntrinsicError:Provider['inspectIntrinsicError'];
export declare const classValue:Provider['classValue'];
export declare const classThis:Provider['classThis'];
export declare const classNewTarget:Provider['classNewTarget'];
export declare const superConstruct:Provider['superConstruct'];
export declare const defineMethod:Provider['defineMethod'];
export declare const defineAccessor:Provider['defineAccessor'];
export declare const defineField:Provider['defineField'];
export declare const defineDataProperty:Provider['defineDataProperty'];
export declare const getOwnPropertyDescriptor:Provider['getOwnPropertyDescriptor'];
export declare const getPrototype:Provider['getPrototype'];
export declare const setIntrinsicTag:Provider['setIntrinsicTag'];
export declare const namedValue:Provider['namedValue'];
export declare const argumentsObject:Provider['argumentsObject'];
export declare const regexp:Provider['regexp'];
export declare const key:Provider['key'];
export declare const set:Provider['set'];
export declare const define:Provider['define'];
export declare const remove:Provider['remove'];
export declare const unary:Provider['unary'];
export declare const binary:Provider['binary'];
export declare const call:Provider['call'];
export declare const construct:Provider['construct'];
export declare const functionValue:Provider['functionValue'];
export declare const asyncFunctionValue:Provider['asyncFunctionValue'];
export declare const awaitValue:Provider['awaitValue'];
export declare const truthy:Provider['truthy'];
export declare const toPrimitive:Provider['toPrimitive'];
export declare const string:Provider['string'];
export declare const number:Provider['number'];
export declare const keys:Provider['keys'];
export declare const iterable:Provider['iterable'];
export declare const array:Provider['array'];
export declare const arrayPush:Provider['arrayPush'];
export declare const arrayHole:Provider['arrayHole'];
export declare const arraySpread:Provider['arraySpread'];
export declare const object:Provider['object'];
export declare const setPrototype:Provider['setPrototype'];
export declare const spreadObject:Provider['spreadObject'];
export declare const requireObject:Provider['requireObject'];
export declare const objectRest:Provider['objectRest'];
export declare const binding:Provider['binding'];
export declare const initialize:Provider['initialize'];
export declare const read:Provider['read'];
export declare const write:Provider['write'];
export declare const iterator:Provider['iterator'];
export declare const next:Provider['next'];
export declare const iteratorRest:Provider['iteratorRest'];
export declare const close:Provider['close'];
export declare const registerNative:Provider['registerNative'];
export declare const registerCall:Provider['registerCall'];
export declare const registerConstructor:Provider['registerConstructor'];
export declare const registerBuiltinConstructors:Provider['registerBuiltinConstructors'];
export declare const registerObject:Provider['registerObject'];
export declare const registerNamespace:Provider['registerNamespace'];
