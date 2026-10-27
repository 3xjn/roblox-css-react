export interface PromiseValue<Value> {
  readonly then: <Result1 = Value, Result2 = never>(this: void, fulfilled?: ((value: Value) => Result1 | PromiseValue<Result1>) | null, rejected?: ((reason: unknown) => Result2 | PromiseValue<Result2>) | null) => PromiseValue<Result1 | Result2>;
  readonly catch: <Result = never>(this: void, rejected: (reason: unknown) => Result | PromiseValue<Result>) => PromiseValue<Value | Result>;
  readonly finally: (this: void, settled?: (() => unknown) | null) => PromiseValue<Value>;
}
export type Settled<Value> = { readonly status: 'fulfilled'; readonly value: Value } | { readonly status: 'rejected'; readonly reason: unknown };
export interface Constructor {
  new <Value>(executor: (resolve: (value: Value | PromiseValue<Value>) => void, reject: (reason: unknown) => void) => void): PromiseValue<Value>;
  readonly resolve: <Value>(this: void, value: Value | PromiseValue<Value>) => PromiseValue<Awaited<Value>>;
  readonly reject: (this: void, reason: unknown) => PromiseValue<never>;
  readonly all: <Value>(this: void, values: readonly (Value | PromiseValue<Value>)[]) => PromiseValue<Awaited<Value>[]>;
  readonly allSettled: <Value>(this: void, values: readonly (Value | PromiseValue<Value>)[]) => PromiseValue<Settled<Awaited<Value>>[]>;
  readonly race: <Value>(this: void, values: readonly (Value | PromiseValue<Value>)[]) => PromiseValue<Awaited<Value>>;
  readonly any: <Value>(this: void, values: readonly (Value | PromiseValue<Value>)[]) => PromiseValue<Awaited<Value>>;
}
export interface Options {
  /** An asynchronous FIFO microtask scheduler returning an optional canceler. */
  readonly enqueue?: (callback: () => void) => (() => void) | undefined;
}
export interface Context { readonly Promise: Constructor; readonly destroy: () => void }
/** Client-only. Destroy drops owned pending reactions after consumers unmount. */
export declare function create(options?: Options): Context;
