/** Empty-constructor subset of Set, with insertion order and mutation during
 * forEach. The supplied implementation owns storage; no renderer is loaded. */
export interface Collection<T> {
  readonly size: number;
  add(value: T): this;
  delete(value: T): boolean;
  has(value: T): boolean;
  clear(): void;
  forEach(callback: (value: T, key: T, set: Collection<T>) => void): void;
  /** Native next/done/value ABI used by roblox-ts for-of lowering. */
  values(): Generator<T, void, unknown>;
}
export interface Constructor {
  new <T>(): Collection<T>;
}
/** Pass the existing Luau Polyfill Set module, not an instance. */
export declare function create(baseSet: unknown): Constructor;
