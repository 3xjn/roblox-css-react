import type React from '@rbxts/react';
import type * as Html from './Html';
import type * as Arrays from './Arrays';
import type * as Records from './Records';
import type * as Nulls from './Nulls';
import type * as Functions from './FunctionValues';
import type * as SourceType from './SourceType';
import type * as Strings from './Strings';
import type * as NumericStyles from './NumericStyles';
import type * as Timers from './Timers';
import type * as Frames from './Frames';
import type {Normalize} from './RenderNodes';
import type {Constructor as Promises} from './SourcePromise';
import type {SourceConstructor as AbortConstructor} from './Abort';
import type {Constructor as ObserverConstructor} from './AttributeObservers';
import type {ResizeObserverConstructor} from './BrowserHost';
import type {Constructor as ErrorConstructor,DOMExceptionConstructor} from './SourceErrors';
import type * as SourceURL from './SourceURL';
import type * as SourceDocument from './SourceDocument';
import type {SourceElement as AnimationElement} from './WebAnimations';
import type {TargetContext} from './Renderer';
import type {Has} from './Properties';
import type * as Collections from './SourceCollections';
import type * as Values from './SourceValues';
import type * as Symbols from './SourceSymbols';
import type * as Json from './SourceJson';
import type * as DomClasses from './DomClasses';
import type * as SourceObjects from './SourceObjects';
import type * as DomElements from './DomElements';
import type * as SourceOperations from './SourceOperations';
import type * as SourceRegExp from './SourceRegExp';
import type BrowserReact = require('./BrowserReact');
export type SourceReact = Omit<typeof React,Extract<'forwardRef'|'memo'|'createElement'|'cloneElement'|'isValidElement'|'createRef'|'createContext'|'useContext'|'useRef'|'version',keyof typeof React>> & {
  /** Finite source data protocol; reconciliation remains owned by ReactLua. */
  readonly version:'19.3.1';
  readonly forwardRef:typeof BrowserReact.forwardRef;
  readonly memo:typeof BrowserReact.memo;
  readonly createElement:typeof BrowserReact.createElement;
  readonly cloneElement:typeof BrowserReact.cloneElement;
  readonly isValidElement:typeof BrowserReact.isValidElement;
  readonly createRef:typeof BrowserReact.createRef;
  readonly createContext:typeof BrowserReact.createContext;
  readonly useContext:typeof BrowserReact.useContext;
  readonly useRef: BrowserReact.UseRef & typeof BrowserReact.useRef;
  readonly useId:()=>string;
  readonly useInsertionEffect?: typeof React.useLayoutEffect;
  readonly useSyncExternalStore?:<T>(subscribe:(callback:()=>void)=>()=>void,getSnapshot:()=>T,getServerSnapshot?:()=>T)=>T;
};
export type ReactNamespace = SourceReact & {readonly '*':SourceReact;readonly default:SourceReact};
export type DocumentValue=SourceDocument.DocumentValue;
export type WindowValue=SourceDocument.WindowValue;

/** Platform APIs without an installed implementation remain absent at runtime.
 * The embedding application may supply real capabilities in Options.globals. */
export interface ValueGlobals extends Values.Globals {
  readonly Map:Collections.MapConstructor;
  readonly Set:Collections.SetConstructor;
  readonly WeakMap:Collections.WeakMapConstructor;
  readonly WeakSet:Collections.WeakSetConstructor;
  readonly URL:SourceURL.Constructor;
  readonly URLSearchParams:SourceURL.SearchParamsConstructor;
  readonly Symbol:Symbols.Constructor;
  readonly JSON:typeof Json;
  readonly Error:ErrorConstructor;
  readonly EvalError:ErrorConstructor;
  readonly RangeError:ErrorConstructor;
  readonly ReferenceError:ErrorConstructor;
  readonly SyntaxError:ErrorConstructor;
  readonly TypeError:ErrorConstructor;
  readonly URIError:ErrorConstructor;
  readonly DOMException:DOMExceptionConstructor;
  readonly Promise:Promises;
  readonly AbortController:AbortConstructor;
  readonly MutationObserver:ObserverConstructor;
  readonly console:{readonly log:(...values:unknown[])=>void; readonly info:(...values:unknown[])=>void;
    readonly debug:(...values:unknown[])=>void; readonly warn:(...values:unknown[])=>void; readonly error:(...values:unknown[])=>void};
  readonly performance:{readonly now:()=>number};
  readonly Node:typeof DomClasses.Node;
  readonly Element:typeof DomClasses.Element;
  readonly HTMLElement:typeof DomClasses.HTMLElement;
  readonly Document:typeof DomClasses.Document;
  readonly ShadowRoot:typeof DomClasses.ShadowRoot;
  readonly window:WindowValue|undefined;
  readonly document:DocumentValue|undefined;
  readonly navigator:unknown;
  readonly CSS:unknown;
  readonly ResizeObserver:ResizeObserverConstructor;
  /** Absent by default. Hosts may supply an actual capability through Options.globals. */
  readonly IntersectionObserver?:unknown;
  /** Optional host capability. Absent by default; source can feature-detect it. */
  readonly WeakRef?:unknown;
  readonly getComputedStyle:typeof DomElements.computedStyle;
  readonly RegExp:typeof SourceRegExp.Constructor;
  readonly Intl:unknown;
  readonly Event:unknown;
  readonly PointerEvent:unknown;
  readonly queueMicrotask:(callback:()=>void)=>void;
}
export type Browser=Pick<Timers.Context,'setTimeout'|'clearTimeout'> & Pick<Frames.Context,'requestAnimationFrame'|'cancelAnimationFrame'> & ValueGlobals & {
  readonly queueMicrotask:(callback:()=>void)=>void;
  readonly [name:string]:unknown;
};
export interface ReactDOM {
 readonly flushSync:(callback:()=>void)=>void;
 readonly createPortal:(children:React.ReactNode,container:unknown,key?:unknown)=>React.ReactNode;
}
export interface ProductionJsxRuntime {
 readonly jsx:JsxRuntime['jsx']; readonly jsxs:JsxRuntime['jsx']; readonly Fragment:typeof React.Fragment;
}
export interface DevelopmentJsxRuntime {
 readonly jsxDEV:JsxRuntime['jsx']|undefined; readonly Fragment:typeof React.Fragment;
}
export interface JsxRuntime {
 readonly jsx:(tag:unknown,props:Html.Props|undefined,key?:unknown)=>React.ReactNode;
 readonly jsxs:JsxRuntime['jsx']; readonly jsxDEV:JsxRuntime['jsx']; readonly Fragment:typeof React.Fragment;
}
export type NumericConstant = number;
export interface Clock {readonly now:()=>number}
export interface Environment {readonly env:{readonly NODE_ENV:'production'|'development'}}
/** Bounded ordinary data operations. Other Object APIs need native bindings. */
export interface Objects extends SourceObjects.Provider {}
export interface Context {
  readonly bindDocumentRoot:(root:Instance)=>void;
  readonly animationTarget:(context:TargetContext)=>AnimationElement;
  readonly domTarget:(target:GuiObject,context:TargetContext,tag?:string)=>{
    readonly element:Html.DomElementProxy;readonly release:()=>void;
  };
  readonly host:{
    readonly element:Html.ElementFactory;
    readonly fragment:typeof React.Fragment;
    readonly rest:Html.Rest;
    readonly staticSvgProps:Html.StaticSvgProps;
    readonly numberStyle:NumericStyles.Factory;
    readonly strings:Strings.Methods;
    readonly typeOf:SourceType.TypeOf;
  };
  readonly globals:Browser & {
    readonly Promise:Promises;
    readonly AbortController:AbortConstructor;
    readonly DOMException:DOMExceptionConstructor;
    readonly MutationObserver:ObserverConstructor;
    readonly Error:ErrorConstructor;
    readonly globalThis:Browser;
    readonly Date:Clock;
    readonly process:Environment;
    readonly Object:Objects;
    readonly arrays:Arrays.Provider;
    readonly renderNodes:Normalize;
    readonly records:Records.Provider;
    readonly nulls:Nulls.Provider;
    readonly functions:Functions.Provider;
    readonly sourceOperations:SourceOperations.Provider;
    readonly propertyHas:Has;
    readonly Infinity:number;
    readonly enumerateKeys:Records.Provider['enumerate'];
    readonly keyString:Records.Provider['keyString'];
    readonly typeIs:SourceType.TypeIs;
    readonly typeOf:SourceType.TypeOf;
  };
  readonly bindings:{
    readonly 'react-dom':ReactDOM & {readonly '*':ReactDOM;readonly default:ReactDOM};
    readonly react:SourceReact & {readonly '*':SourceReact;readonly default:SourceReact};
    readonly 'react/jsx-runtime':ProductionJsxRuntime;
    readonly 'react/jsx-dev-runtime':DevelopmentJsxRuntime;
  };
  /** Unmount source consumers first. Drops only this context's pending work. */
  readonly destroy:()=>void;
}
export interface Options {
  /** Compatibility input accepted but unused by source promises/animations.
   * Native peer consumers may call WebAnimations.create directly. */
  readonly promises?:typeof Promise;
  /** Defer one source FIFO drain. The optional canceler owns only that drain. */
  readonly scheduleJob?:(callback:()=>void)=>(()=>void)|undefined;
  readonly onJobError?:(reason:unknown)=>void;
  readonly flushSync?:(callback:()=>void)=>void;
  readonly createPortal?:ReactDOM['createPortal'];
  /** Additional actual host APIs and application data. Existing owned APIs
   * cannot be overwritten. No unsupported browser APIs are fabricated. */
  readonly globals?:Readonly<Record<string,unknown>>;
  /** Scope DOM membership to this native document root. */
  readonly documentRoot?:Instance;
  readonly element?:Html.ElementFactory;
  readonly development?:boolean;
}
/** Uses the application's React instance. Timers/frames are created on demand;
 * creating an otherwise idle context adds no native event subscription. */
export declare function create(react:typeof React,options?:Options):Context;
