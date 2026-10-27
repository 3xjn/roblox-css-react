import type {DomElementProxy} from './Html';
export type Kind='node'|'element'|'html'|'textarea'|'form'|'br'|'text'|'document'|'fragment'|'shadow';
export interface RegisteredNode {
  readonly nodeType:number;
  readonly nodeName:string;
}
/** Raw native GuiObjects retain their Roblox API. A DomElementProxy supplies
 * the browser-facing element API; identity tests do not add methods to a GUI. */
export type NodeValue=RegisteredNode|DomElementProxy|GuiObject;
export type ElementValue=DomElementProxy|GuiObject;
export type HTMLElementValue=DomElementProxy;
export interface TextValue extends RegisteredNode {
  readonly nodeType:3;
  readonly nodeName:'#text';
  data:string;
  nodeValue:string;
  textContent:string;
  readonly length:number;
  readonly wholeText:string;
}
export interface HTMLTextAreaElementValue extends DomElementProxy { readonly nodeName:'TEXTAREA'; }
export interface HTMLFormElementValue extends DomElementProxy { readonly nodeName:'FORM'; }
export interface HTMLBRElementValue extends DomElementProxy { readonly nodeName:'BR'; }
export interface ShadowRootValue extends RegisteredNode {
  readonly nodeType:11;
  readonly host:ElementValue;
}
export interface Constructor<Value> {
  /** Browser interface objects exist for instanceof; direct construction
   * throws Illegal constructor at runtime, as it does in a browser. */
  new():Value;
  readonly instanceof:(value:unknown)=>value is Value;
}
export declare const Node:Constructor<NodeValue>;
export declare const Element:Constructor<ElementValue>;
export declare const HTMLElement:Constructor<HTMLElementValue>;
export interface TextConstructor {
  new(data?:string):TextValue;
  readonly instanceof:(value:unknown)=>value is TextValue;
}
export declare const Text:TextConstructor;
export declare const HTMLTextAreaElement:Constructor<HTMLTextAreaElementValue>;
export declare const HTMLFormElement:Constructor<HTMLFormElementValue>;
export declare const HTMLBRElement:Constructor<HTMLBRElementValue>;
export declare const ShadowRoot:Constructor<ShadowRootValue>;
/** Called only by native renderer creation paths. Public nodeType fields do
 * not establish class identity. Registration remains weak across detach. */
export declare function register<T extends object>(value:T,kind:Kind):T;
