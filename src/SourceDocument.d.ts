import type * as DomClasses from './DomClasses';
import type * as DomElements from './DomElements';
import type {DomElementProxy} from './Html';
import type {Null} from './Nulls';
/** An explicitly rooted renderer document with detached portal containers. */
export interface DetachedElement extends DomClasses.RegisteredNode {
 readonly tagName:string;readonly parentNode:DetachedElement|Null;
 appendChild(child:DetachedElement):DetachedElement;removeChild(child:DetachedElement):DetachedElement;remove():void;
 setAttribute(name:string,value:string):void;getAttribute(name:string):string|Null;
 hasAttribute(name:string):boolean;removeAttribute(name:string):void;
 querySelector(selector:string):DetachedElement|Null;
}
export interface DocumentValue extends DomClasses.RegisteredNode {
 readonly nodeType:9;readonly nodeName:'#document';readonly ownerDocument:Null;
 readonly isConnected:boolean;readonly defaultView:WindowValue;
 readonly body:DetachedElement;createElement(tagName:string):DetachedElement;
 querySelector(selector:string):DetachedElement|Null;
 contains(node:DocumentValue|DomElementProxy|DetachedElement|Null|undefined):boolean;
}
/** Actual realm identities and installed host globals; no WindowProxy/DOM layout claim. */
export interface WindowValue {
 readonly document:DocumentValue;readonly window:WindowValue;readonly self:WindowValue;readonly globalThis:WindowValue;
 readonly PointerEvent:unknown;
 readonly Node:typeof DomClasses.Node;readonly Element:typeof DomClasses.Element;
 readonly HTMLElement:typeof DomClasses.HTMLElement;readonly Document:typeof DomClasses.Document;
 readonly ShadowRoot:typeof DomClasses.ShadowRoot;readonly getComputedStyle:typeof DomElements.computedStyle;
}
export interface Context {
 readonly document:DocumentValue;readonly window:WindowValue;
 readonly bindRoot:(root:Instance)=>void;readonly installGlobals:(values:Readonly<Record<string,unknown>>)=>void;readonly destroy:()=>void;
}
export declare function create(root:Instance|undefined,computedStyle:typeof DomElements.computedStyle,onDestroy?:()=>void):Context;
