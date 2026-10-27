import type React from '@rbxts/react';
import type { ElementFactory,DomElementProxy } from './Html';
import type {EventValue} from './SourceCapabilities';
import type * as DomClasses from './DomClasses';
import type * as SourceDOMRect from './SourceDOMRect';
import type {MediaQueryList} from './SourceMediaQueries';
import type * as SourceCookieStore from './SourceCookieStore';
import type {Constructor as PromiseConstructor} from './SourcePromise';
export interface BrowserEvent extends EventValue {
  readonly isDefaultPrevented:()=>boolean;
  readonly isPropagationStopped:()=>boolean;
  readonly nativeEvent:EventValue;
  readonly nativeInput:unknown;
  readonly relatedTarget:unknown|null;
  readonly button:number;
  readonly pointerId:number;
  readonly pointerType:string;
  readonly clientX:number;readonly clientY:number;
  readonly movementX:number;readonly movementY:number;
  readonly key:string;
  readonly shiftKey:boolean;
  readonly ctrlKey:boolean;readonly altKey:boolean;readonly metaKey:boolean;
  readonly buttons?:number;
  readonly detail?:number;
  /** Roblox does not expose physical pointer contact area or pressure. */
  readonly width?:number;readonly height?:number;readonly pressure?:number;
}
export type Event = EventValue;
export type UIEvent = BrowserEvent;
export type MouseEvent = BrowserEvent;
export type PointerEvent = BrowserEvent;
export type TouchEvent = BrowserEvent;
export type KeyboardEvent = BrowserEvent;
export type FocusEvent = BrowserEvent;
export type InputEvent = BrowserEvent;
export type ClipboardEvent = BrowserEvent;
export type WheelEvent = BrowserEvent;
export type EventTarget = DomClasses.NodeValue;
export type CSSStyleDeclaration = ComputedStyle;
export type VisualViewport = Readonly<{ width: number; height: number; offsetLeft: number; offsetTop: number; pageLeft: number; pageTop: number; scale: number }>;
export type HTMLElementTagNameMap = Readonly<Record<string, DomClasses.HTMLElementValue>>;
export type SVGElementTagNameMap = Readonly<Record<string, DomClasses.ElementValue>>;
export type SVGElement = DomClasses.ElementValue;
export type SVGSVGElement = DomClasses.ElementValue;
export type Node = DomClasses.NodeValue;
export type Element = DomClasses.ElementValue;
export type HTMLElement = DomClasses.HTMLElementValue;
export type Text = DomClasses.TextValue;
export type AddEventListenerOptions = Readonly<{ capture?: boolean; once?: boolean; passive?: boolean; signal?: AbortSignal }>;
export type EventListenerOrEventListenerObject = ((event: EventValue) => void) | Readonly<{ handleEvent: (event: EventValue) => void }>;
export interface Options {
  readonly element?:ElementFactory;
  readonly flushSync?:(callback:()=>void)=>unknown;
  readonly createPortal?:(children:React.ReactNode,container:Instance,key?:unknown)=>React.ReactNode;
  readonly portalContainer?:Instance;
  readonly Promise?:PromiseConstructor;
  readonly cookieURL?:string;
}
export interface ResizeObserverInstance {
  readonly observe:(target:unknown,options?:{readonly box?:'border-box'|'content-box'|'device-pixel-content-box'})=>void;
  readonly unobserve:(target:unknown)=>void;
  readonly disconnect:()=>void;
}
export interface ResizeObserverEntry {
  readonly target:unknown;
  readonly contentRect:Readonly<Record<string,number>>;
  readonly contentBoxSize:readonly {readonly inlineSize:number;readonly blockSize:number}[];
  readonly borderBoxSize:readonly {readonly inlineSize:number;readonly blockSize:number}[];
}
export interface ResizeObserverConstructor {
  new(callback:(entries:readonly ResizeObserverEntry[],observer:ResizeObserverInstance)=>void):ResizeObserverInstance;
}
export interface MutationRecord {
  readonly type:'attributes'|'childList'|'characterData';
  readonly target:unknown;
  readonly attributeName?:string;
  readonly oldValue:unknown;
  readonly addedNodes:readonly unknown[];
  readonly removedNodes:readonly unknown[];
}
export interface MutationOptions {
  readonly attributes?:boolean;readonly childList?:boolean;readonly characterData?:boolean;
  readonly subtree?:boolean;readonly attributeFilter?:readonly string[];
  readonly attributeOldValue?:boolean;readonly characterDataOldValue?:boolean;
}
export interface MutationObserverInstance {
  readonly observe:(target:unknown,options:MutationOptions)=>void;
  readonly disconnect:()=>void;
  readonly takeRecords:()=>readonly MutationRecord[];
}
export interface MutationObserverConstructor {
  new(callback:(entries:readonly MutationRecord[],observer:MutationObserverInstance)=>void):MutationObserverInstance;
}
export interface AbortSignal {
  readonly aborted:boolean;
  readonly addEventListener:(type:string,listener:()=>void)=>void;
  readonly removeEventListener:(type:string,listener:()=>void)=>void;
}
export interface AbortControllerConstructor {
  new():{readonly signal:AbortSignal;readonly abort:()=>void};
}
export interface ComputedStyle {
  readonly [name:string]:any;
  readonly getPropertyValue:(name:string)=>string;
}
export interface Globals {
  readonly DOMRect:typeof SourceDOMRect.DOMRect;
  readonly DOMRectReadOnly:typeof SourceDOMRect.DOMRectReadOnly;
  readonly Node:typeof DomClasses.Node;
  readonly Element:typeof DomClasses.Element;
  readonly HTMLElement:typeof DomClasses.HTMLElement;
  readonly ShadowRoot:typeof DomClasses.ShadowRoot;
  readonly Text:typeof DomClasses.Text;
  readonly HTMLTextAreaElement:typeof DomClasses.HTMLTextAreaElement;
  readonly HTMLFormElement:typeof DomClasses.HTMLFormElement;
  readonly HTMLBRElement:typeof DomClasses.HTMLBRElement;
  readonly cookieStore:SourceCookieStore.CookieStore;
  readonly ResizeObserver:ResizeObserverConstructor;
  readonly MutationObserver:MutationObserverConstructor;
  readonly AbortController:AbortControllerConstructor;
  readonly document:Document;
  readonly window:Window;
  readonly getComputedStyle:(target:unknown)=>ComputedStyle;
  readonly navigator:{readonly userAgent:string;readonly platform:string;readonly maxTouchPoints:number};
  readonly CSS:{readonly supports:(property:string,value?:string)=>boolean};
}
export interface Document {
  readonly nodeType:9;readonly nodeName:'#document';
  readonly body:DomElementProxy;readonly documentElement:DomElementProxy;
  readonly defaultView:Window;
  readonly activeElement:DomElementProxy|null;
  readonly contains:(node:unknown)=>boolean;
  readonly createElement:(tagName:string)=>DomElementProxy;
  readonly createTextNode:(data:string)=>DomClasses.TextValue;
  readonly addEventListener:(type:string,listener:(event:EventValue)=>void,options?:unknown)=>(()=>void);
  readonly removeEventListener:(type:string,listener:(event:EventValue)=>void)=>void;
}
export interface Window extends Globals {
  readonly matchMedia:(query:string)=>MediaQueryList;
  readonly innerWidth:number;readonly innerHeight:number;
  readonly addEventListener:(type:string,listener:(event:EventValue)=>void,options?:unknown)=>(()=>void);
  readonly removeEventListener:(type:string,listener:(event:EventValue)=>void)=>void;
}
export interface ReactDom {
  readonly flushSync:(callback:()=>void)=>unknown;
  readonly createPortal:(children:React.ReactNode,container:unknown,key?:unknown)=>React.ReactNode;
}
export interface ReactHooks {
  readonly useId:()=>string;
  readonly useSyncExternalStore:<T>(subscribe:(onStoreChange:()=>void)=>()=>void,getSnapshot:()=>T,getServerSnapshot?:()=>T)=>T;
}
export interface Host {
  readonly element:ElementFactory;
  readonly reactHooks:ReactHooks;
  readonly globals:Globals;
  readonly ownerDocument:(target?:unknown)=>unknown;
  readonly ownerWindow:(target?:unknown)=>unknown;
  readonly getComputedStyle:Globals['getComputedStyle'];
  readonly bindings:{readonly 'react-dom':ReactDom&{readonly '*':ReactDom;readonly default:ReactDom}};
  readonly destroy:()=>void;
}
export type WindowValue = Window;
export type DocumentValue = Document;
export declare function getComputedStyle(target:unknown):ComputedStyle;
export declare function create(react:typeof React,options?:Options):Host;



