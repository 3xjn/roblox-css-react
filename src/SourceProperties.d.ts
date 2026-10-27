/** Supplies existence separately from a getter read, including source
 * undefined slots and native prototype tables. */
export declare function has<Key extends PropertyKey, Value>(key: Key, value: Value): value is Value & Record<Key, unknown>;
export type Has = typeof has;
/** Actual lookup for opaque erased-JavaScript values; no result type is inferred. */
export declare function get(value: unknown, key: PropertyKey): unknown;
export type Get = typeof get;
export declare function hasOwn<Key extends PropertyKey>(key: Key, value: unknown): boolean;
export type HasOwnMethod = (this: unknown, key: PropertyKey) => boolean;
/** Called only after the source checker proves the standard inherited member.
 * Own shadows are still observed; an invalid shadow fails at invocation. */
export declare function hasOwnMethod(value: unknown): HasOwnMethod;
export interface Provider { readonly hasOwnMethod: typeof hasOwnMethod }
/** Register native fields whose nil values still represent present source
 * properties. Does not wrap, replace, or mutate the supplied object. */
export declare function register<Value extends object>(value: Value, keys: readonly PropertyKey[]): Value;
