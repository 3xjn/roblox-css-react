import type { PropertyKey } from './Properties';
/** Enumerable own data properties on ordinary source records. Native callers
 * must adopt their tables with an explicit key order before passing them in.
 * Explicit prototypes and symbol keys are supported; no implicit object-key coercion. */
export interface Construction {
  readonly __recordConstruction: never;
}
export interface Provider {
  readonly propertyKey:<K extends PropertyKey>(key:K)=>K extends symbol ? K : string;
  readonly define:(record:object,key:PropertyKey,value:unknown)=>unknown;
  readonly ownKeys:(record:object)=>PropertyKey[];
  readonly getPrototype:(record:object)=>LuaTuple<[boolean,unknown]>;
  readonly setPrototype:(record:object,prototype:object)=>void;
  readonly owns: (value: unknown) => boolean;
  /** Implicit string coercion for strings, safe-integer numbers, NaN and infinities.
   * Symbol input is valid source syntax and throws at runtime. */
  readonly keyString: (key: PropertyKey) => string;
  readonly begin: () => Construction;
  readonly mark: (construction: Construction, ...keys: PropertyKey[]) => {};
  readonly key: <K extends PropertyKey>(
    construction: Construction,
    key: K,
  ) => K;
  readonly spread: <T>(construction: Construction, value: T) => T extends object | null | undefined ? T : Record<string, unknown>;
  readonly finish: <T>(construction: Construction, value: T) => T;
  readonly adopt: <T extends object>(value: T, keys: readonly (keyof T)[]) => T;
  readonly keys: (value: object) => string[];
  readonly values: <T extends object>(value: T) => Array<T[keyof T]>;
  readonly hasOwn: (value: object, key: PropertyKey) => boolean;
  readonly remove: (value: object, key: PropertyKey) => boolean;
  readonly rest: <T extends object, K extends keyof T>(
    value: T,
    excluded: readonly K[],
  ) => Omit<T, K>;
  readonly copy: <T extends object>(value: T) => T;
  readonly enumerate: <T extends object>(
    value: T,
  ) => Generator<Extract<keyof T, string>, void, unknown>;
}
export declare const begin: Provider['begin'];
export declare const owns: Provider['owns'];
export declare const keyString: Provider['keyString'];
export declare const mark: Provider['mark'];
export declare const key: Provider['key'];
export declare const spread: Provider['spread'];
export declare const finish: Provider['finish'];
export declare const adopt: Provider['adopt'];
export declare const keys: Provider['keys'];
export declare const values: Provider['values'];
export declare const hasOwn: Provider['hasOwn'];
export declare const remove: Provider['remove'];
export declare const rest: Provider['rest'];
export declare const copy: Provider['copy'];
export declare const enumerate: Provider['enumerate'];
export declare const propertyKey:Provider['propertyKey'];
export declare const define:Provider['define'];
export declare const ownKeys:Provider['ownKeys'];
export declare const getPrototype:Provider['getPrototype'];
export declare const setPrototype:Provider['setPrototype'];
