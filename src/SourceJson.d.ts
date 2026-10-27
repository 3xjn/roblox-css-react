/** JSON over ordinary adopted source records/arrays and Unicode scalar strings.
 * Replacer/reviver receive the actual holder as their JavaScript this receiver. */
export type Replacer = (this: object, key: string, value: unknown) => unknown;
export type Reviver = (this: object, key: string, value: unknown) => unknown;
export declare function stringify(value: unknown, replacer?: Replacer | readonly (string | number)[], space?: string | number): string | undefined;
export declare function parse(value: string, reviver?: Reviver): unknown;
