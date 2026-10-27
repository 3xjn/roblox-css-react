import type React from '@rbxts/react';
import type { ElementFactory, Props, Node } from './Html';
import type { Style } from './StyleObjects';
import type { Bindings } from './Controls';

export interface State {
  readonly [name: string]: unknown;
  readonly checked: boolean;
  readonly indeterminate: boolean;
  readonly disabled: boolean;
  readonly readOnly: boolean;
  readonly required: boolean;
}
export interface ChangeEventDetails {
  readonly reason: 'none';
  readonly event: InputObject;
  readonly isCanceled: boolean;
  readonly isPropagationAllowed: boolean;
  readonly cancel: (this: void) => void;
  readonly allowPropagation: (this: void) => void;
}
export interface PartProps extends Omit<Props, 'className' | 'children' | 'render'> {
  readonly id?: Props['id'];
  readonly key?: Props['key'];
  readonly children?: Node;
  readonly className?: string | ((state: State) => string | undefined);
  readonly style?: Style | ((state: State) => Style | undefined);
  readonly render?: React.ReactElement | ((props: Props, state: State) => Node);
}
export interface RootProps extends PartProps {
  /** Group membership; standalone form values still need a form adapter. */
  readonly value?: string;
  readonly parent?: boolean;
  readonly checked?: boolean;
  readonly defaultChecked?: boolean;
  readonly indeterminate?: boolean;
  readonly disabled?: boolean;
  readonly readOnly?: boolean;
  readonly required?: boolean;
  readonly nativeButton?: boolean;
  readonly onCheckedChange?: (checked: boolean, details: ChangeEventDetails) => void;
}
export interface IndicatorProps extends PartProps { readonly keepMounted?: boolean }
export interface Parts {
  readonly Root: (props: RootProps) => React.ReactElement;
  readonly Indicator: (props: IndicatorProps) => Node;
}

export interface Preparation { readonly props: Props; readonly getChecked?: () => boolean }
export interface Options { readonly group?: { readonly prepare: (props: Props) => Preparation } }
/** Shared CSS-root behavior. Forms, DOM refs and indicator exit transitions are unfinished. */
export declare function create(react: typeof React, bindings: Bindings, element?: ElementFactory, options?: Options): Parts;
