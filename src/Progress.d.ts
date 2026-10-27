import type React from '@rbxts/react';
import type { ElementFactory, Props, RenderProp, Node } from './Html';
import type { Style } from './StyleObjects';

export interface State { readonly status: 'indeterminate' | 'progressing' | 'complete' }
export interface CommonPartProps extends Omit<Props, 'className' | 'children'> {
  readonly id?: Props['id'];
  readonly key?: Props['key'];
  readonly className?: string | ((state: State) => string | undefined);
  readonly style?: Style | ((state: State) => Style | undefined);
  readonly render?: RenderProp;
}
export interface PartProps extends CommonPartProps { readonly children?: Node }
export interface ValueProps extends CommonPartProps {
  readonly children?: Node | ((formatted: string, value: number | undefined) => Node);
}
export interface RootProps extends PartProps {
  /** Undefined represents indeterminate progress in the native API. */
  readonly value?: number;
  readonly min?: number;
  readonly max?: number;
  readonly locale?: unknown;
  readonly format?: Readonly<Record<string, unknown>>;
  readonly getAriaValueText?: (formatted: string, value: number | undefined) => string;
}
export type FormatNumber = (value: number, locale: unknown, options: Readonly<Record<string, unknown>>) => string;
export interface Options { readonly formatNumber?: FormatNumber }
export interface Parts {
  readonly Root: (props: RootProps) => React.ReactElement;
  readonly Track: (props: PartProps) => React.ReactElement;
  readonly Indicator: (props: PartProps) => React.ReactElement;
  readonly Label: (props: PartProps) => React.ReactElement;
  readonly Value: (props: ValueProps) => React.ReactElement;
}

/** Shared-root composition only. No browser Intl, DOM refs or native accessibility bridge is bundled. */
export declare function create(react: typeof React, element?: ElementFactory, options?: Options): Parts;
