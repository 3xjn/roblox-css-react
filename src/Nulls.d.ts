import type { TypeIs, TypeOf } from './SourceType';
declare const sourceNull: unique symbol;
/** Opaque native value; source modules continue to use the null keyword. */
export type Null = typeof sourceNull & { readonly [sourceNull]: never };
export interface Provider {
  readonly value: Null;
  readonly isNull: <T>(value: T, observedNull?: Null) => value is T & Null;
  readonly isNullish: <T>(value: T, observedNull?: Null) => value is T & (Null | undefined);
  /** Reverse operand forms retain source evaluation order and narrow the value. */
  readonly nullIs: <T>(observedNull: Null, value: T) => value is T & Null;
  readonly nullishIs: <T>(observedNull: Null, value: T) => value is T & (Null | undefined);
  readonly truthy: <T>(
    value: T,
  ) => value is Exclude<T, Null | null | undefined | false | 0 | ''>;
  readonly optional: <T>(value: T) => Exclude<T, Null> | undefined;
  readonly spreadable: <T>(value: T) => T extends Null | undefined ? {} : T;
  readonly coalesce: <T, R>(
    value: T,
    fallback: () => R,
  ) => Exclude<T, Null | undefined> | R;
  readonly coalesceValue: <T, R>(
    value: T,
    fallback: R,
  ) => Exclude<T, Null | undefined> | R;
  readonly andValue: <T, R>(value: T, nextValue: () => R) => T | R;
  readonly orValue: <T, R>(value: T, nextValue: () => R) => T | R;
  readonly typeOf: TypeOf;
  readonly typeIs: TypeIs;
}
export declare const value: Provider['value'];
export declare const isNull: Provider['isNull'];
export declare const isNullish: Provider['isNullish'];
export declare const nullIs: Provider['nullIs'];
export declare const nullishIs: Provider['nullishIs'];
export declare const truthy: Provider['truthy'];
export declare const optional: Provider['optional'];
export declare const spreadable: Provider['spreadable'];
export declare const coalesce: Provider['coalesce'];
export declare const coalesceValue: Provider['coalesceValue'];
export declare const andValue: Provider['andValue'];
export declare const orValue: Provider['orValue'];
export declare const typeOf: Provider['typeOf'];
export declare const typeIs: Provider['typeIs'];
