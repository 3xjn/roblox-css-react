import type * as Records from './Records';
/** TypeScript's standard property-key union; runtime coercion still uses ToPropertyKey. */
export type PropertyKey=string|number|symbol;
export interface Provider {
 readonly is:(left:unknown,right:unknown)=>boolean;
 readonly hasOwn:Records.Provider['hasOwn'];
 readonly freeze:<T extends object>(value:T)=>Readonly<T>;
 readonly keys:Records.Provider['keys'];
 readonly values:Records.Provider['values'];
 readonly entries:<T extends object>(value:T)=>[string,T[keyof T]][];
 readonly assign:<T extends object>(target:T,...sources:readonly object[])=>T;
}
export declare const is:Provider['is'];
export declare const hasOwn:Provider['hasOwn'];
export declare const freeze:Provider['freeze'];
/** Internal intrinsic routing; preserves canonical Object identity. */
export declare function configure(routes:Pick<Provider,'keys'|'values'|'entries'|'assign'|'hasOwn'|'freeze'>):void;
export declare const keys:Provider['keys'];
export declare const values:Provider['values'];
export declare const entries:Provider['entries'];
export declare const assign:Provider['assign'];
