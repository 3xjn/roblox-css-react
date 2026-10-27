import type { PropertyKey } from './Properties';
type Callback = (this: void, ...args: any[]) => unknown;
type AnyCallable = (this: any, ...args: any[]) => unknown;
import type { Null } from './Nulls';
export interface Reference<Receiver, Value> {
  readonly owner: Receiver;
  readonly value: Value;
  readonly mode: 'free' | 'method' | 'dynamic';
}
export interface Provider {
  readonly readMethod: <T, K extends keyof T>(owner: T, key: K) => T[K];
  readonly isSource:(value:unknown)=>boolean;
  /** Explicit callable-table metadata; its owner retains store and dispatch. */
  readonly callable:(value:object,store:object,dispatch:(receiver:unknown,args:readonly unknown[])=>unknown)=>void;
  readonly source:(value:AnyCallable,dispatch:(receiver:unknown,args:readonly unknown[])=>unknown,store:object)=>void;
  readonly native:<F extends AnyCallable>(value:F,receiver:boolean,name?:string,length?:number)=>F;
  readonly removeProperty:(value:AnyCallable,key:PropertyKey)=>boolean;
  readonly getProperty:<T=unknown>(value:AnyCallable,key:PropertyKey)=>T;
  readonly setProperty:<T>(value:AnyCallable,key:PropertyKey,item:T)=>T;
  readonly keys:(value:AnyCallable)=>string[];
  readonly ownKeys:(value:AnyCallable)=>PropertyKey[];
  readonly hasOwn:(value:AnyCallable,key:PropertyKey)=>boolean;
  readonly named: <F extends AnyCallable>(value: F, name: string, length?: number, receiver?: boolean) => unknown extends ReturnType<F> ? (...args: Parameters<F>) => any : F;
  readonly length: (value: AnyCallable) => number;
  readonly name: <F extends AnyCallable>(value: F) => string;
  readonly displayName: <F extends AnyCallable>(value: F) => string | undefined;
  readonly setDisplayName: <F extends AnyCallable, V extends string | undefined>(
    value: F,
    displayName: V,
  ) => V;
  readonly invoke: <F extends Callback>(
    value: F,
    ...args: [...Parameters<F>, ...unknown[]]
  ) => ReturnType<F>;
  readonly reference: {
    <Receiver, Value>(owner: Receiver, read: (this: void, owner: Exclude<Receiver, Null | null | undefined>) => Value,
      mode: Reference<Receiver, Value>['mode'], optionalOwner: false): Reference<Receiver, Value>;
    <Receiver, Value>(owner: Receiver, read: (this: void, owner: Exclude<Receiver, Null | null | undefined>) => Value,
      mode: Reference<Receiver, Value>['mode'], optionalOwner: boolean): Reference<Receiver, Value> | undefined;
  };
  readonly invokeReference: {
    <Receiver, Value>(reference: Reference<Receiver, Value>,
      args: () => readonly [...Parameters<Extract<Value, AnyCallable>>, ...unknown[]], optionalCallee: false,
      count?: number): ReturnType<Extract<Value, AnyCallable>>;
    <Receiver, Value>(reference: Reference<Receiver, Value> | undefined,
      args: () => readonly [...Parameters<Extract<Value, AnyCallable>>, ...unknown[]], optionalCallee: boolean,
      count?: number): ReturnType<Extract<Value, AnyCallable>> | undefined;
  };
  /** Explicit dynamic capability: the runtime requires compiler-registered
   * receiver ABI metadata before invoking an opaque source value. */
  readonly invokeChecked: <Receiver>(reference: Reference<Receiver, unknown> | undefined,
    args: () => readonly unknown[], optionalCallee: boolean, count?: number) => unknown;
}
export declare const named: Provider['named'];
export declare const readMethod: Provider['readMethod'];
export declare const name: Provider['name'];
export declare const displayName: Provider['displayName'];
export declare const setDisplayName: Provider['setDisplayName'];
export declare const invoke: Provider['invoke'];
export declare const length: Provider['length'];
export declare const reference: Provider['reference'];
export declare const invokeReference: Provider['invokeReference'];
export declare const invokeChecked: Provider['invokeChecked'];
export declare const getProperty:Provider['getProperty'];
export declare const setProperty:Provider['setProperty'];
export declare const keys:Provider['keys'];
export declare const ownKeys:Provider['ownKeys'];
export declare const hasOwn:Provider['hasOwn'];
export declare const source:Provider['source'];
export declare const isSource:Provider['isSource'];
export declare const callable:Provider['callable'];
export declare const native:Provider['native'];
export declare const removeProperty:Provider['removeProperty'];
