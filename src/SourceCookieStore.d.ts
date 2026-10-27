import type {Constructor,PromiseValue} from './SourcePromise';
import type {Null} from './Nulls';
export interface CookieListItem {name:string;value:string}
export interface GetOptions {readonly name?:string;readonly url?:string}
export interface DeleteOptions {readonly name:string;readonly domain?:string|Null|null;readonly path?:string;readonly partitioned?:boolean}
export interface CookieInit extends DeleteOptions {
  readonly value:string;
  readonly expires?:number|Null|null;
  readonly maxAge?:number|Null|null;
  readonly sameSite?:'strict'|'lax'|'none';
}
export interface CookieStore {
  readonly get:(nameOrOptions?:string|GetOptions)=>PromiseValue<CookieListItem|Null>;
  readonly getAll:(nameOrOptions?:string|GetOptions)=>PromiseValue<CookieListItem[]>;
  readonly set:{(options:CookieInit):PromiseValue<undefined>;(name:string,value:string):PromiseValue<undefined>};
  readonly delete:(nameOrOptions:string|DeleteOptions)=>PromiseValue<undefined>;
}
export interface Options {
  readonly Promise:Constructor;
  readonly now?:()=>number;
  /** The virtual document's creation URL. Defaults to https://roblox.invalid/.
   * The store never reads or writes browser, Roblox account or network cookies. */
  readonly url?:string;
}
export interface Context {readonly cookieStore:CookieStore;readonly destroy:()=>void}
/** Runtime-local secure document cookie storage. Operations follow Cookie Store
 * name/value, path, partition and expiration rules. Only host-only or exact-host
 * domains are supported; suffix domains need a public-suffix capability. Change
 * events, HTTP cookies, service workers and persistent storage are not exposed. */
export declare function create(options:Options):Context;
