import type React from '@rbxts/react';
import type * as Html from './Html';
import type {SourceReact,JsxRuntime} from './SourceRuntime';
/** Finite React 19.3.1 source data protocol over an actual ReactLua peer.
 * Native symbols, reconciliation, hooks and lifecycle remain peer-owned.
 * Deferred JSX accessors without a key, native ref-cleanup returns and complete
 * development debug-field reflection remain explicit unsupported boundaries. */
export declare const protocolVersion:'19.3.1';
export interface Realm {
 readonly react:SourceReact;
 readonly jsx:JsxRuntime['jsx'];
 readonly jsxs:JsxRuntime['jsx'];
 readonly jsxDEV:(tag:unknown,props:Html.Props,key?:unknown,staticChildren?:boolean)=>React.ReactNode;
 readonly element:Html.Factory;
 readonly nativeElement:Html.Factory;
 readonly cloneElement:typeof React.cloneElement;
 readonly destroy:()=>void;
}
export interface Origin {
 readonly tag:unknown;
 readonly props:Html.Props;
 readonly key:unknown;
 readonly ref:unknown;
 readonly projection:object;
 readonly development:boolean;
}
export declare function info(element:unknown):Origin|undefined;
export declare function create(react:typeof React,host:Html.Factory,qualifyElement:(element:unknown)=>unknown,development?:boolean):Realm;
