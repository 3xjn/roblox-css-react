import type React from '@rbxts/react';
import type * as Variants from './Variants';
import type { HostProps, TargetContext } from './Renderer';
import type { Style as StyleObject } from './StyleObjects';
export type { Factory as NumericStyleFactory } from './NumericStyles';
export type { Value as NumericStyleValue } from './NumericStyles';
export type { Methods as StringMethods } from './Strings';

export type TargetBinder = NonNullable<HostProps['bindTarget']>;

export interface DomRect {
  readonly x: number;
  readonly y: number;
  readonly left: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
  readonly width: number;
  readonly height: number;
}

export interface DomElementProxy {
  value?: string;
  checked?: boolean;
  readonly _instance?: GuiObject;
  readonly _context?: TargetContext;
  readonly style: {
    height: string;
    width: string;
    setProperty(name: string, value: unknown,priority?:string): void;
    removeProperty(name: string): string;
    getPropertyValue(name:string):string;
    getPropertyPriority(name:string):string;
    [name: string]: unknown;
  };
  readonly offsetWidth: number;
  readonly offsetHeight: number;
  readonly clientWidth: number;
  readonly clientHeight: number;
  readonly offsetLeft: number;
  readonly offsetTop: number;
  readonly clientLeft:number;
  readonly clientTop:number;
  readonly scrollLeft:number;
  readonly scrollTop:number;
  readonly parentElement:DomElementProxy|null;
  readonly children:readonly DomElementProxy[];
  readonly isConnected:boolean;
  readonly offsetParent:DomElementProxy|null;
  readonly textContent:string;
  getBoundingClientRect(): DomRect;
  getClientRects():readonly DomRect[];
  setPointerCapture(pointerId: number): void;
  releasePointerCapture(pointerId: number): void;
  hasPointerCapture(pointerId: number): boolean;
  focus(): void;
  blur(): void;
  contains(target: unknown): boolean;
  getAttribute(name: string): string | undefined;
  setAttribute(name:string,value:unknown):void;
  removeAttribute(name:string):void;
  hasAttribute(name: string): boolean;
  matches(selector: string): boolean;
  closest(selector:string):DomElementProxy|null;
  querySelector<T extends DomElementProxy=DomElementProxy>(selector:string):T|null;
  querySelectorAll(selector:string):readonly DomElementProxy[];
  getRootNode():unknown;
  addEventListener(type: string, listener: (event: unknown) => void, options?: unknown): () => void;
  removeEventListener(type: string, listener: (event: unknown) => void, options?: unknown): void;
  readonly [name: string]: unknown;
}

/** Finite keys keep React's PropsWithoutRef/Omit from erasing source fields. */
export interface PropsBase {
  readonly className?: string;
  readonly id?: string;
  readonly htmlFor?: string;
  readonly key?: string | number;
  readonly children?: Node;
  readonly render?: RenderProp;
  readonly ref?: unknown;
}
export interface Props extends PropsBase {
  readonly [name: string]: unknown;
}
/** Platform metadata for an adapter-owned host, separate from source HTML props. */
export type NativeProps = Props & Pick<HostProps, 'nativeControl' | 'labelable' | 'states' | 'bindTarget'>;
/** Component identity is opaque here; each bound adapter owns its prop contract. */
export type Component = (props: never) => Node;
export type Fragment = typeof React.Fragment;
export type Element = React.ReactElement;
/** Source HTML refs receive the native Roblox instance owned by the renderer. */
export type ForwardedRef = React.ForwardedRef<GuiObject>;
/** Dense nested source arrays retain order; false represents an empty render slot. */
export type Node = React.ReactNode | string | number | readonly Node[] | readonly unknown[];
export type Rest = (props: PropsBase | Props, excluded: readonly string[]) => Props;
/** Static assets cannot change baked geometry. This boundary validates the
 * final source spread result and forwards supported root presentation props. */
export interface StaticSvgProps {
  (props:Props|undefined,keys?:readonly string[]):Props;
  (merge:undefined,geometry:undefined,...segments:Props[]):Props;
  (asset:string,geometry:Readonly<Record<string,string|number>>,...segments:Props[]):Props;
}
export type { TypeOf, TypeIs } from './SourceType';
export type ComponentProps<C extends Component> = [Parameters<C>[0]] extends [never] ? Props : Parameters<C>[0];
/** A typed render-function child occupies one slot; ordinary content stays variadic. */
export type ComponentChildren<C extends Component> = [Parameters<C>[0]] extends [never] ? Node[]
  : Parameters<C>[0] extends { readonly children?: infer Child }
    ? (Exclude<Node, undefined> extends Exclude<Child, undefined> ? Node[] : []) | [child: NoInfer<Child>] : [];
type PropsArguments<P, Children extends unknown[]> = {} extends P
  ? [props?: NoInfer<P>, ...children: Children]
  : [props: NoInfer<P>, ...children: Children];
export type ComponentArguments<C extends Component> = ComponentProps<C> extends { readonly children: infer Child }
  ? [props: NoInfer<ComponentProps<C>>]
    | PropsArguments<Omit<ComponentProps<C>, 'children'>,
        Exclude<Node, undefined> extends Exclude<Child, undefined>
          ? [child: NoInfer<Child>, ...children: Node[]] : [child: NoInfer<Child>]>
  : PropsArguments<ComponentProps<C>, ComponentChildren<C>>;
export interface ElementFactory {
  <C extends Component>(type: C, ...args: ComponentArguments<C>): React.ReactElement;
  <P>(type:React.ComponentType<P>|React.ExoticComponent<P>,props?:P,...children:Node[]):React.ReactElement;
  (type: string | Fragment, props?: Props,
    ...children: Node[]): React.ReactElement;
}
export type ClassName = (...values: unknown[]) => string;
export type VariantFactory = Variants.Factory;
export type PropsInput = Props | ((props: Props) => Props) | undefined;
export type MergeProps = (...props: PropsInput[]) => Props;
export type RenderProp = React.ReactElement | ((props: any, state: any) => React.ReactElement);
export interface RenderOptions {
  readonly defaultTagName?: string;
  readonly props?: Props | readonly PropsInput[];
  readonly render?: RenderProp;
  readonly state?: Props;
  readonly stateAttributesMapping?: Readonly<Record<string, (value: unknown) => Props | undefined>>;
  readonly customStyleHookMapping?: Readonly<Record<string, (value: unknown) => Props | undefined>>;
  readonly ref?: unknown;
  readonly enabled?: boolean;
  readonly className?: string | ((state: Props) => string | undefined);
  readonly style?: Props | StyleObject | ((state: Props) => Props | StyleObject | undefined);
}
export type ElementRenderer = (options: RenderOptions) => React.ReactNode;
export type UseRenderElement = (
  element: string | ((props: Props, state: Props) => React.ReactNode) | undefined,
  componentProps?: Props,
  params?: RenderOptions,
) => React.ReactNode;

/** Uses the supplied React instance; native input subscriptions are attached lazily. */
export declare function create(react: typeof React, components?: Readonly<Record<string, Component>>,environment?:Props): ElementFactory;
export declare function isIntrinsic(tag: string): boolean;
/** Independent semantic display defaults for the supported HTML subset. Table role values are retained
 * for fidelity; the current CSS renderer does not implement table formatting contexts. */
export declare function getDisplayDefaults(): Record<string, string>;
export declare function rest(props: PropsBase | Props, excluded: readonly string[]): Props;
export declare const staticSvgProps:StaticSvgProps;
export declare function toHostProps(props?: Props,tagName?:string,environment?:Props): HostProps & { readonly children?: Props['children']; readonly key?: Props['key']; readonly ref?: unknown };
export declare function normalizeStyle(value: unknown): StyleObject | undefined;
export declare function createDomProxy(initialAttributes?: Readonly<Record<string, string>>): DomElementProxy;
/** Inert metadata only; nonempty script bodies and external sources throw. */
export declare function createScriptProxy(initialAttributes?:Readonly<Record<string,string>>):DomElementProxy;
export declare function fromInstance(target:GuiObject):DomElementProxy;
export declare function notifyMutation(target:unknown,record:Props):void;
export declare function mergeRefs(...refs: unknown[]): unknown;
export declare function mergeBinders(first?: TargetBinder, second?: TargetBinder): TargetBinder | undefined;
/** JavaScript primitive classifications; platform objects map to object. No null representation. */
export declare function typeOf(value: unknown): string;
export declare const typeIs: import('./SourceType').TypeIs;
/** String classes and scalar conditions; array/object/numeric class normalization is separate. */
export declare function createClassName(merge: (...values: (string | undefined)[]) => string): ClassName;

/** Data/orientation bridge, not full Base UI render/style/accessibility support. */
export declare function createSeparator(element: ElementFactory): Component;
