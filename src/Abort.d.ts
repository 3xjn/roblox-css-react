import type {Provider} from './SourceOperations';
/** Supported source view. EventTarget listener operations remain unsupported. */
export interface Signal {
 readonly aborted:boolean;
 readonly reason:unknown;
 readonly throwIfAborted:()=>void;
}
/** Legacy native free-call API; callbacks receive no DOM Event argument. */
export interface NativeSignal extends Signal {
 readonly addEventListener:(type:'abort',callback:()=>void,options?:{readonly once?:boolean}|boolean)=>void;
 readonly removeEventListener:(type:'abort',callback:()=>void)=>void;
}
export interface Controller {
 readonly signal:NativeSignal;
 readonly abort:(reason?:unknown)=>void;
}
export interface Constructor {new():Controller}
export declare const Controller:Constructor;
export interface SourceController {
 readonly signal:Signal;
 /** Undefined uses a fresh DOMException from the owning source realm. */
 readonly abort:(reason?:unknown)=>void;
}
export interface SourceConstructor {new():SourceController}
export interface Context {
 readonly Controller:SourceConstructor;
 /** Revokes owned default-reason callbacks; does not abort external producers. */
 readonly destroy:()=>void;
}
export declare function createSource(ops:Provider,defaultReason:()=>unknown):Context;
