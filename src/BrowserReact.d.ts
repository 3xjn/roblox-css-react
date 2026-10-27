/** Type-only React boundary for source DOM components rendered through Html.
 * Native Roblox component types remain owned by @rbxts/react. This module does
 * not augment the application's global JSX namespace or implement React. */
import type NativeReact from '@rbxts/react';
import type * as Html from './Html';
import type { BrowserEvent } from './BrowserHost';
import type { Null } from './Nulls';

export = BrowserReact;

declare namespace BrowserReact {
  type ReactNode = Html.Node;
  type ReactChild = NativeReact.ReactChild;
  type ReactFragment = NativeReact.ReactFragment;
  type ReactPortal = NativeReact.ReactPortal;
  type ReactElement<P = unknown, T extends NativeReact.ReactElement<P>['type'] = NativeReact.ReactElement<P>['type']> = NativeReact.ReactElement<P, T>;
  type Key = NativeReact.Key;
  type Attributes = NativeReact.Attributes;
  type RefAttributes<T> = NativeReact.RefAttributes<T>;
  type ClassAttributes<T> = NativeReact.ClassAttributes<T>;
  type RefObject<T> = NativeReact.RefObject<T>;
  type MutableRefObject<T> = NativeReact.MutableRefObject<T>;
  type RefCallback<T> = NativeReact.RefCallback<T>;
  type Ref<T> = NativeReact.Ref<T> | unknown;
  type ForwardedRef<T> = NativeReact.ForwardedRef<T> | unknown;
  type LegacyRef<T> = NativeReact.LegacyRef<T>;
  type Context<T> = NativeReact.Context<T>;
  type Provider<T> = NativeReact.Provider<T>;
  type Consumer<T> = NativeReact.Consumer<T>;
  type ProviderProps<T> = NativeReact.ProviderProps<T>;
  type ConsumerProps<T> = NativeReact.ConsumerProps<T>;
  type Dispatch<A> = NativeReact.Dispatch<A>;
  type DispatchWithoutAction = NativeReact.DispatchWithoutAction;
  type SetStateAction<S> = NativeReact.SetStateAction<S>;
  type Reducer<S, A> = NativeReact.Reducer<S, A>;
  type ReducerWithoutAction<S> = NativeReact.ReducerWithoutAction<S>;
  type DependencyList = NativeReact.DependencyList;
  type EffectCallback = NativeReact.EffectCallback;
  type FC<P = {}> = NativeReact.FC<P>;
  type FunctionComponent<P = {}> = NativeReact.FunctionComponent<P>;
  type ComponentType<P = {}> = NativeReact.ComponentType<P>;
  type ComponentClass<P = {}, S = NativeReact.ComponentState> = NativeReact.ComponentClass<P, S>;
  type Component<P = {}, S = {}, SS = unknown> = NativeReact.Component<P, S, SS>;
  type ExoticComponent<P = {}> = NativeReact.ExoticComponent<P>;
  type NamedExoticComponent<P = {}> = NativeReact.NamedExoticComponent<P>;
  type ForwardRefExoticComponent<P> = NativeReact.ForwardRefExoticComponent<P>;
  type ForwardRefRenderFunction<T, P = {}> = NativeReact.ForwardRefRenderFunction<T, P>;
  type JSXElementConstructor<P> = NativeReact.JSXElementConstructor<P>;
  type PropsWithoutRef<P> = NativeReact.PropsWithoutRef<P>;
  type PropsWithRef<P> = NativeReact.PropsWithRef<P>;
  type PropsWithChildren<P = {}> = P & { children?: Html.Node };

  type ElementType<P = Html.Props, Tag extends string = string> = Tag | NativeReact.ComponentType<P> | ((props: P) => Html.Node);
  /** Preserve an existing native component's props before the DOM fallback. */
  type ComponentProps<T> = T extends NativeReact.ElementType ? NativeReact.ComponentProps<T>
    : T extends (props: infer P) => unknown ? P : Html.Props;
  type ComponentPropsWithRef<T> = T extends NativeReact.ElementType ? NativeReact.ComponentPropsWithRef<T> : ComponentProps<T>;
  type ComponentPropsWithoutRef<T> = T extends string ? Html.Props : T extends NativeReact.ElementType ? NativeReact.ComponentPropsWithoutRef<T> : NativeReact.PropsWithoutRef<ComponentProps<T>>;
  type FactoryNode = Html.Node | Null | null | readonly FactoryNode[];
  /** Preserve every native component overload; only source HTML/Fragment
   * rendering adds text, adopted arrays and source null as empty slots. */
  type CreateElement = typeof NativeReact.createElement & {
    (type: string | typeof NativeReact.Fragment, props?: Html.Props | Null | null,
      ...children: FactoryNode[]): Html.Element;
  };
  type HTMLAttributes<T = unknown> = Html.Props;
  type HTMLProps<T = unknown> = Html.Props;
  type AllHTMLAttributes<T = unknown> = Html.Props;
  type AnchorHTMLAttributes<T = unknown> = Html.Props;
  type ButtonHTMLAttributes<T = unknown> = Html.Props;
  type InputHTMLAttributes<T = unknown> = Html.Props;
  type ImgHTMLAttributes<T = unknown> = Html.Props;
  type LabelHTMLAttributes<T = unknown> = Html.Props;
  type SelectHTMLAttributes<T = unknown> = Html.Props;
  type TextareaHTMLAttributes<T = unknown> = Html.Props;
  type FormHTMLAttributes<T = unknown> = Html.Props;
  type SVGAttributes<T = unknown> = Html.Props;
  type SVGProps<T = unknown> = Html.Props;
  /** Values actually accepted by Html.normalizeStyle, including source clears. */
  type CSSProperties = object;
  type UseRef = <T>(initialValue:T|Null|null)=>NativeReact.MutableRefObject<T|Null>;
  type AriaAttributes = { [property: `aria-${string}`]: string | number | boolean | undefined };
  type AriaRole = string;
  type HTMLAttributeReferrerPolicy = '' | 'no-referrer' | 'no-referrer-when-downgrade' | 'origin' | 'origin-when-cross-origin'
    | 'same-origin' | 'strict-origin' | 'strict-origin-when-cross-origin' | 'unsafe-url';

  type BaseSyntheticEvent<E = unknown, C = unknown, T = unknown> = BrowserEvent;
  type SyntheticEvent<T = unknown, E = unknown> = BrowserEvent;
  type UIEvent<T = unknown, E = unknown> = BrowserEvent;
  type ClipboardEvent<T = unknown> = BrowserEvent;
  type CompositionEvent<T = unknown> = BrowserEvent;
  type DragEvent<T = unknown> = BrowserEvent;
  type FocusEvent<T = unknown, Related = unknown> = BrowserEvent;
  type FormEvent<T = unknown> = BrowserEvent;
  type ChangeEvent<T = unknown> = BrowserEvent;
  type KeyboardEvent<T = unknown> = BrowserEvent;
  type MouseEvent<T = unknown, E = unknown> = BrowserEvent;
  type TouchEvent<T = unknown> = BrowserEvent;
  type PointerEvent<T = unknown> = BrowserEvent;
  type WheelEvent<T = unknown> = BrowserEvent;
  type AnimationEvent<T = unknown> = BrowserEvent;
  type TransitionEvent<T = unknown> = BrowserEvent;
  type EventHandler<E = BrowserEvent> = (event: E) => void;
  type ReactEventHandler<T = unknown> = EventHandler<SyntheticEvent<T>>;
  type FocusEventHandler<T = unknown> = EventHandler<FocusEvent<T>>;
  type FormEventHandler<T = unknown> = EventHandler<FormEvent<T>>;
  type ChangeEventHandler<T = unknown> = EventHandler<ChangeEvent<T>>;
  type KeyboardEventHandler<T = unknown> = EventHandler<KeyboardEvent<T>>;
  type MouseEventHandler<T = unknown> = EventHandler<MouseEvent<T>>;
  type TouchEventHandler<T = unknown> = EventHandler<TouchEvent<T>>;
  type PointerEventHandler<T = unknown> = EventHandler<PointerEvent<T>>;
  type WheelEventHandler<T = unknown> = EventHandler<WheelEvent<T>>;

  // Hooks and components retain the application's native identities. The
  // source factory delegates HTML strings through the native Html boundary.
  const Children: typeof NativeReact.Children;
  const Fragment: typeof NativeReact.Fragment;
  const createElement: CreateElement;
  const cloneElement: typeof NativeReact.cloneElement;
  const isValidElement: typeof NativeReact.isValidElement;
  const createContext: typeof NativeReact.createContext;
  const createRef: typeof NativeReact.createRef;
  const forwardRef: typeof NativeReact.forwardRef;
  const memo: typeof NativeReact.memo;
  const useState: typeof NativeReact.useState;
  const useReducer: typeof NativeReact.useReducer;
  const useRef: typeof NativeReact.useRef;
  const useContext: typeof NativeReact.useContext;
  const useEffect: typeof NativeReact.useEffect;
  const useLayoutEffect: typeof NativeReact.useLayoutEffect;
  const useMemo: typeof NativeReact.useMemo;
  const useCallback: typeof NativeReact.useCallback;
  const useImperativeHandle: typeof NativeReact.useImperativeHandle;
  const useDebugValue: typeof NativeReact.useDebugValue;
  /** Stable within a mounted component, using the native implementation when available. */
  const useId: () => string;
  /** Snapshot/subscription contract backed by native hooks when the fork has no built-in implementation. */
  const useSyncExternalStore: <T>(subscribe:(onStoreChange:()=>void)=>()=>void,getSnapshot:()=>T,getServerSnapshot?:()=>T)=>T;

  namespace JSX {
    type Element = Html.Element;
    type ElementType = BrowserReact.ElementType;
    interface ElementChildrenAttribute { children: {} }
    interface IntrinsicAttributes extends NativeReact.Attributes {}
    interface IntrinsicElements { [tag: string]: Html.Props }
    type LibraryManagedAttributes<C, P> = P;
  }
}
