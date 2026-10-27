/** Supplied implementations must preserve the source API's semantics. The
 * runtime does not substitute Lua patterns or ASCII for RegExp or Intl. */
import type * as Collections from './SourceCollections';
import type * as SourcePromise from './SourcePromise';
import type * as SourceErrors from './SourceErrors';
import type * as SourceWeakRef from './SourceWeakRef';
import type * as SourceURL from './SourceURL';
export interface RegExpValue {
  readonly source: string;
  readonly flags: string;
  lastIndex: number;
  readonly test: (this: void, value: string) => boolean;
  readonly exec: (this: void, value: string) => (string[] & { readonly index: number; readonly input: string }) | null;
}
export interface RegExpConstructor {
  new (source: string | RegExpValue, flags?: string): RegExpValue;
  (source: string | RegExpValue, flags?: string): RegExpValue;
}
export interface MapValue<Key, Value> {
  readonly size: number;
  readonly get: (this: void, key: Key) => Value | undefined;
  readonly has: (this: void, key: Key) => boolean;
  readonly set: (this: void, key: Key, value: Value) => MapValue<Key, Value>;
  readonly delete: (this: void, key: Key) => boolean;
  readonly clear: (this: void) => void;
  readonly forEach: (this: void, callback: (value: Value, key: Key, map: MapValue<Key, Value>) => void) => void;
}
export interface MapConstructor {
  new <Key, Value>(entries?: readonly (readonly [Key, Value])[]): MapValue<Key, Value>;
}
export interface SetValue<Value> {
  readonly size: number;
  readonly add: (this: void, value: Value) => SetValue<Value>;
  readonly has: (this: void, value: Value) => boolean;
  readonly delete: (this: void, value: Value) => boolean;
  readonly clear: (this: void) => void;
  readonly forEach: (this: void, callback: (value: Value, key: Value, set: SetValue<Value>) => void) => void;
}
export interface SetConstructor {
  new <Value>(values?: readonly Value[]): SetValue<Value>;
}
export interface WeakMapValue<Key extends object, Value> {
  readonly get: (this: void, key: Key) => Value | undefined;
  readonly has: (this: void, key: Key) => boolean;
  readonly set: (this: void, key: Key, value: Value) => WeakMapValue<Key, Value>;
  readonly delete: (this: void, key: Key) => boolean;
}
export interface WeakMapConstructor {
  new <Key extends object, Value>(entries?: readonly (readonly [Key, Value])[]): WeakMapValue<Key, Value>;
}
export interface Json {
  readonly stringify: (this: void, value: unknown, replacer?: ((this:object,key: string, value: unknown) => unknown) | readonly (string | number)[], space?: string | number) => string | undefined;
  readonly parse: (this: void, value: string, reviver?: (this:object,key: string, value: unknown) => unknown) => unknown;
}
export interface Console {
  readonly log: (this: void, ...values: unknown[]) => void;
  readonly info: (this: void, ...values: unknown[]) => void;
  readonly warn: (this: void, ...values: unknown[]) => void;
  readonly error: (this: void, ...values: unknown[]) => void;
  readonly debug: (this: void, ...values: unknown[]) => void;
}
export interface EventValue {
  readonly type: string;
  readonly bubbles: boolean;
  readonly cancelable: boolean;
  readonly composed: boolean;
  readonly defaultPrevented: boolean;
  readonly isTrusted: boolean;
  readonly timeStamp: number;
  readonly target:unknown|null;
  readonly currentTarget:unknown|null;
  readonly eventPhase:number;
  readonly cancelBubble:boolean;
  readonly preventDefault: (this: void) => void;
  readonly stopPropagation: (this: void) => void;
  readonly stopImmediatePropagation: (this: void) => void;
  readonly composedPath: (this: void) => readonly unknown[];
}
export interface EventConstructor {
  new (type: string, options?: { readonly bubbles?: boolean; readonly cancelable?: boolean; readonly composed?: boolean }): EventValue;
}
export interface SymbolConstructor {
  (description?: string | number): symbol;
  readonly for: (this: void, key: string) => symbol;
  readonly keyFor: (this: void, value: symbol) => string | undefined;
  readonly iterator: symbol;
}
export interface Intl {
  readonly NumberFormat: new (locale?: string | readonly string[], options?: Readonly<Record<string, unknown>>) => {
    readonly format: (this: void, value: number) => string;
    readonly formatToParts: (this: void, value: number) => readonly { readonly type: string; readonly value: string }[];
    readonly resolvedOptions: (this: void) => Readonly<Record<string, unknown>>;
  };
  readonly Collator: new (locale?: string | readonly string[], options?: Readonly<Record<string, unknown>>) => {
    readonly compare: (this: void, left: string, right: string) => number;
    readonly resolvedOptions: (this: void) => Readonly<Record<string, unknown>>;
  };
}
export type PromiseValue<Value> = SourcePromise.PromiseValue<Value>;
export type PromiseConstructor = SourcePromise.Constructor;
export interface IntersectionEntry {
  readonly target:unknown;
  readonly isIntersecting:boolean;
  readonly intersectionRatio:number;
  readonly time:number;
  readonly boundingClientRect:Readonly<Record<string,number>>;
  readonly intersectionRect:Readonly<Record<string,number>>;
  readonly rootBounds:Readonly<Record<string,number>>|null;
}
export interface IntersectionObserverValue {
  readonly observe:(target:unknown)=>void;
  readonly unobserve:(target:unknown)=>void;
  readonly disconnect:()=>void;
  readonly takeRecords:()=>readonly IntersectionEntry[];
}
export interface IntersectionObserverConstructor {
  new(callback:(entries:readonly IntersectionEntry[],observer:IntersectionObserverValue)=>void,options?:{readonly root?:unknown;readonly rootMargin?:string;readonly threshold?:number|readonly number[]}):IntersectionObserverValue;
}
export interface Options {
  readonly Error?:SourceErrors.Constructor;
  readonly TypeError?:SourceErrors.Constructor;
  readonly RangeError?:SourceErrors.Constructor;
  readonly WeakRef?:SourceWeakRef.Constructor;
  readonly URL?:SourceURL.Constructor;
  readonly RegExp?: RegExpConstructor;
  readonly Map?: MapConstructor;
  readonly Set?: SetConstructor;
  readonly WeakMap?: WeakMapConstructor;
  readonly WeakSet?:Collections.WeakSetConstructor;
  readonly JSON?: Json;
  readonly console?: Console;
  readonly Event?: EventConstructor;
  readonly Symbol?: SymbolConstructor;
  readonly Intl?: Intl;
  readonly Promise?:PromiseConstructor;
  readonly IntersectionObserver?:IntersectionObserverConstructor;
  readonly performance?:{readonly now:()=>number};
}
export interface Globals extends Options {
  readonly Error:SourceErrors.Constructor;
  readonly TypeError:SourceErrors.Constructor;
  readonly RangeError:SourceErrors.Constructor;
  readonly WeakRef:SourceWeakRef.Constructor;
  readonly URL:SourceURL.Constructor;
  readonly console: Console;
  /** Constructed client event; dispatch remains owned by the native renderer. */
  readonly Event: EventConstructor;
  readonly Map:Collections.MapConstructor;
  readonly Set:Collections.SetConstructor;
  readonly WeakMap:Collections.WeakMapConstructor;
  readonly WeakSet:Collections.WeakSetConstructor;
  readonly Symbol:SymbolConstructor;
  readonly performance:{readonly now:()=>number};
  readonly IntersectionObserver:IntersectionObserverConstructor;
  readonly JSON:Json;
  readonly Promise:PromiseConstructor;
}
export declare function create(options?: Options): Globals;
export declare function isSymbol(value:unknown):value is symbol;
export declare function destroy(globals:Globals):void;
export declare function createEvent(type:string,options?:{readonly bubbles?:boolean;readonly cancelable?:boolean;readonly composed?:boolean}):EventValue;
