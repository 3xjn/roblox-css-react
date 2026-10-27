import type React from '@rbxts/react';
import type { ElementFactory, Props, Node, RenderProp } from './Html';
import type { Style } from './StyleObjects';
import type * as Model from '@3xjn/roblox-primitives/src/Field';

export type State = Model.State;
export interface PartProps extends Omit<Props, 'className' | 'style' | 'children'> {
  readonly children?: Node;
  readonly className?: string | ((state: State) => string | undefined);
  readonly style?: Style | ((state: State) => Style | undefined);
  readonly render?: RenderProp;
}
export type Validator = (value: string, formValues: Readonly<Record<string, unknown>>) => unknown;
export interface RootProps extends PartProps {
  readonly name?: string; readonly disabled?: boolean; readonly invalid?: boolean;
  readonly dirty?: boolean; readonly touched?: boolean;
  readonly validationMode?: 'onSubmit' | 'onBlur' | 'onChange';
  readonly validationDebounceTime?: number;
  readonly validate?: Validator;
  readonly actionsRef?: { current: { readonly validate: () => void } | undefined };
}
export interface ItemProps extends PartProps { readonly disabled?: boolean }
export interface LabelProps extends PartProps { readonly nativeLabel?: true }
export interface ErrorProps extends PartProps { readonly match?: boolean | string }
export interface ControlProps extends PartProps {
  readonly value?: string; readonly defaultValue?: string; readonly required?: boolean;
  readonly disabled?: boolean; readonly readOnly?: boolean; readonly placeholder?: string;
  readonly type?: 'text' | 'search'; readonly onValueChange?: (value: string) => void;
}
export interface ValidityState {
  readonly validity: Readonly<Record<string, boolean | undefined>>;
  readonly errors: readonly string[]; readonly error: string;
  readonly value: string; readonly initialValue: string;
}
export interface ValidityProps { readonly children: (state: ValidityState) => Node }
export interface Bridge {
  readonly prepare: (props: Props) => {
    readonly props: Props; readonly connected: boolean; readonly valid: boolean | undefined;
    readonly observe: (state: { readonly focused: boolean }, accepted: string) => void;
  };
}
export interface Parts {
  readonly Root: (props: RootProps) => React.ReactElement;
  readonly Item: (props: ItemProps) => React.ReactElement;
  readonly Label: (props: LabelProps) => React.ReactElement;
  readonly Description: (props: PartProps) => React.ReactElement;
  readonly Error: (props: ErrorProps) => React.ReactElement;
  readonly Control: (props: ControlProps) => React.ReactElement;
  readonly Validity: (props: ValidityProps) => React.ReactElement;
}
export interface Adapter { readonly parts: Parts; readonly control: Bridge }
export interface Options {
  readonly getFormValues?: () => Readonly<Record<string, unknown>>;
  readonly runValidation?: (validate: Validator, value: string, formValues: Readonly<Record<string, unknown>>, finish: (result: unknown) => void) => Model.Cancel | undefined;
  readonly constraints?: (props: Props, value: string) => Model.Validation;
  readonly renderErrors?: (errors: readonly string[]) => Node;
}
/** Native model/input providers supply behavior; source components supply styles. */
export declare function create(react: typeof React, createModel: typeof Model.create, element?: ElementFactory, options?: Options): Adapter;
