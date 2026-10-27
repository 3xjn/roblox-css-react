import type {Null} from './Nulls';
export interface SearchParams {
  readonly append:(name:string,value:string)=>void;
  readonly set:(name:string,value:string)=>void;
  readonly get:(name:string)=>string|Null;
  readonly getAll:(name:string)=>string[];
  readonly has:(name:string)=>boolean;
  readonly toString:()=>string;
}
/** Absolute HTTP(S), ASCII DNS/canonical IPv4 and form query mutation.
 * Credentials/IPv6/IDNA, relative bases, and property setters are unsupported. */
export interface Value {
  readonly href:string;
  readonly protocol:string;
  readonly hostname:string;
  readonly host:string;
  readonly port:string;
  readonly origin:string;
  readonly pathname:string;
  readonly search:string;
  readonly hash:string;
  readonly searchParams:SearchParams;
  readonly toString:()=>string;
  readonly toJSON:()=>string;
}
export interface Constructor {new(input:string|Value):Value;readonly instanceof:(value:unknown)=>value is Value}
export declare const URL:Constructor;
