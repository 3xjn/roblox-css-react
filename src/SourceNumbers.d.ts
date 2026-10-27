import type {Null} from './Nulls';
/** Primitive IEEE-754 nondecimal conversion follows V8's radix algorithm.
 * Receiver/radix coercion and boxed Number values are outside this boundary.
 * Decimal formatting uses exact binary64 midpoint intervals. */
export interface Provider {
  readonly toString:(value:number,radix?:number)=>string;
  readonly optionalToString:(value:number|Null|undefined,radix:()=>number|undefined)=>string|undefined;
}
export declare const toString:Provider['toString'];
export declare const optionalToString:Provider['optionalToString'];
