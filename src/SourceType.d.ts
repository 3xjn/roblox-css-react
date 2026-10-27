import type { Null } from './Nulls';
/** JavaScript classification of supported native values. Symbols retain private
 * native identity; bigint has no representation. No native typeof names leak. */
export type TypeOf = (value: unknown) => string;
export interface TypeValues {
  readonly undefined: undefined;
  readonly string: string;
  readonly number: number;
  readonly boolean: boolean;
  readonly function: (...args: any[]) => unknown;
  readonly object: object | Null;
  readonly symbol: symbol;
  readonly bigint: never;
}
export type TypeIs = <T, K extends keyof TypeValues>(
  value: T,
  kind: K,
) => value is [Extract<T, TypeValues[K]>] extends [never]
  ? T & TypeValues[K]
  : Extract<T, TypeValues[K]>;
export declare const typeOf: TypeOf;
export declare const typeIs: TypeIs;
