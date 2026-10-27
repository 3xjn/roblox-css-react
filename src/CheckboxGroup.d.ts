import type React from '@rbxts/react';
import type { Props, Node, ElementFactory } from './Html';
import type { Style } from './StyleObjects';
import type { ChangeEventDetails, Preparation } from './Checkbox';

export interface State {
  readonly [name: string]: unknown;
  readonly disabled: boolean;
  readonly touched: boolean;
  readonly dirty: boolean;
  readonly filled: boolean;
  readonly focused: boolean;
}
export interface RootProps extends Omit<Props, 'className' | 'style' | 'children' | 'render'> {
  readonly children?: Node;
  readonly value?: readonly string[];
  readonly defaultValue?: readonly string[];
  readonly allValues?: readonly string[];
  readonly disabled?: boolean;
  readonly onValueChange?: (value: readonly string[], details: ChangeEventDetails) => void;
  readonly className?: string | ((state: State) => string | undefined);
  readonly style?: Style | ((state: State) => Style | undefined);
  readonly render?: React.ReactElement | ((props: Props, state: State) => Node);
}
export interface Adapter {
  readonly Root: (props: RootProps) => React.ReactElement;
  readonly control: { readonly prepare: (props: Props) => Preparation };
}
/** Shared context for Checkbox.create's optional group bridge. No native targets are created. */
export declare function create(react: typeof React, element?: ElementFactory): Adapter;
