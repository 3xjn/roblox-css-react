import type React from '@rbxts/react';
import type { Style } from './StyleObjects';
import type {
  HostOptions,
  InlineStyle,
  Stylesheet,
  ComputedStyle,
  BoxGeometry,
} from '../../css-runtime/types/consumer';

export interface Root {
  readonly render: (element: React.ReactNode) => void;
  readonly unmount: () => void;
}

export interface Renderer {
  readonly flushSync: (callback: () => void) => void;
  readonly createRoot: (
    target: GuiObject,
    stylesheet: Stylesheet,
    options: HostOptions,
    onDiagnostic?: (message: string) => void,
  ) => Root;
  readonly destroy: () => void;
}

/** Pass the reconciler ModuleScript, not its required export. */
export declare function create(source: ModuleScript): Renderer;

/** Props accepted by the existing CSS reconciler, rather than native instance props. */
export interface HostProps {
  /** Explicit native view; preserves logical tag, CSS matching and layout. */
  readonly nativeControl?: 'auto' | 'button';
  /** Explicit form-control semantics for an adapter whose source tag is not labelable. */
  readonly labelable?: boolean;
  /** Build-time compiled React style object; raw CSSProperties are not accepted. */
  readonly style?: Style;
  readonly id?: string;
  readonly className?: string;
  readonly attributes?: Readonly<Record<string, string>>;
  readonly states?: Readonly<Record<string, boolean>>;
  readonly text?: string;
  readonly inlineStyle?: InlineStyle;
  readonly bindTarget?: (
    target: GuiObject,
    context?: TargetContext,
  ) => (() => void) | undefined;
}

/** Native binding context. Values resolve against this renderer's current scene. */
export interface TargetContext {
  readonly setState?: (name: string, active: boolean) => void;
  readonly resolveLabelControl: () => GuiObject | undefined;
  readonly getComputedStyle: () => ComputedStyle | undefined;
  readonly getLayoutBox: () => BoxGeometry | undefined;
  readonly subscribeScene: (callback: (revision: number) => void) => () => void;
  readonly setInlineStyle?: (style:InlineStyle|undefined)=>void;
  readonly getParentElement?:()=>GuiObject|undefined;
  readonly getChildElements?:()=>readonly GuiObject[];
  readonly claimDomProxy?:(proposed:unknown)=>unknown;
  readonly getSelectorNode?:()=>unknown;
  readonly getInlineStyle?:()=>InlineStyle|undefined;
}
