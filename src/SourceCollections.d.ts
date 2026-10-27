/** Source collections preserve JavaScript identity, insertion order, and live iteration. */
export interface SourceMap<K=unknown,V=unknown> {
  readonly size:number;
  get(key:K):V|undefined;
  has(key:K):boolean;
  set(key:K,value:V):this;
  delete(key:K):boolean;
  clear():void;
  keys():Generator<K>;
  values():Generator<V>;
  entries():Generator<[K,V]>;
  iterator():Generator<[K,V]>;
  forEach(callback:(value:V,key:K,map:SourceMap<K,V>)=>void):void;
}
export interface SourceSet<T=unknown> {
  readonly size:number;
  add(value:T):this;
  has(value:T):boolean;
  delete(value:T):boolean;
  clear():void;
  keys():Generator<T>;
  values():Generator<T>;
  entries():Generator<[T,T]>;
  iterator():Generator<T>;
  forEach(callback:(value:T,key:T,set:SourceSet<T>)=>void):void;
}
/** Uses native weak keys; a value retaining its own key follows Luau's GC behavior. */
export interface SourceWeakMap<K extends object|symbol=object,V=unknown> {
  get(key:K):V|undefined;
  has(key:K):boolean;
  set(key:K,value:V):this;
  delete(key:K):boolean;
}
export interface MapConstructor {
  new<K=unknown,V=unknown>(entries?:readonly (readonly [K,V])[]|SourceMap<K,V>|Generator<readonly [K,V]>):SourceMap<K,V>;
}
export interface SetConstructor {
  new<T=unknown>(values?:readonly T[]|SourceSet<T>|Generator<T>):SourceSet<T>;
}
export interface WeakMapConstructor {
  new<K extends object|symbol=object,V=unknown>(entries?:readonly (readonly [K,V])[]|SourceMap<K,V>|Generator<readonly [K,V]>):SourceWeakMap<K,V>;
}
export interface SourceWeakSet<T extends object|symbol=object> {
  add(value:T):this;
  has(value:unknown):boolean;
  delete(value:unknown):boolean;
}
export interface WeakSetConstructor {
  new<T extends object|symbol=object>(values?:readonly T[]|SourceSet<T>|Generator<T>):SourceWeakSet<T>;
}
export declare const Map:MapConstructor;
export declare const Set:SetConstructor;
export declare const WeakMap:WeakMapConstructor;
export declare const WeakSet:WeakSetConstructor;
/** Shared source iteration; accepts adopted arrays, these collections, or next/done/value iterators. */
export declare function iterator<T>(value:readonly T[]|SourceSet<T>|Generator<T>):Generator<T>;

