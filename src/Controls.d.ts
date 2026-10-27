import type React from '@rbxts/react';
import type { Component } from './Html';
import type { HostProps } from './Renderer';

export interface ToggleOptions {
  readonly value?: boolean;
  readonly defaultValue?: boolean;
  readonly disabled?: boolean;
  readonly readOnly?: boolean;
  readonly onValueChange?: (value: boolean, input: InputObject, count: number) => void;
}
export interface Bindings {
  readonly useButton?: (props: { readonly disabled?: boolean; readonly onActivated?: (input: InputObject, count: number) => void }) => LuaTuple<[
    (target: GuiObject) => (() => void) | undefined,
    { readonly hovered: boolean; readonly pressed: boolean; readonly focused: boolean; readonly focusVisible: boolean; readonly disabled: boolean },
  ]>;
  readonly useToggle?: (props: ToggleOptions) => LuaTuple<[
    (target: GuiObject) => (() => void) | undefined,
    { readonly value: boolean; readonly interaction: {
      readonly hovered: boolean; readonly pressed: boolean; readonly focused: boolean;
      readonly focusVisible: boolean; readonly disabled: boolean;
    } },
  ]>;
  readonly useTextInput?: (props: TextInputOptions) => LuaTuple<[
    (target: GuiObject) => (() => void) | undefined,
    TextInputState,
    string,
  ]>;
}
export interface TextInputOptions {
  readonly value?: string;
  readonly defaultValue?: string;
  readonly disabled?: boolean;
  readonly readOnly?: boolean;
  readonly flushSync?: (callback: () => void) => void;
  readonly onValueChange?: (value: string) => void;
  readonly onFocusLost?: (value: string, enterPressed: boolean, input: InputObject) => void;
}
export interface TextInputState {
  readonly text: string;
  readonly focused: boolean;
  readonly selected: boolean;
  readonly focusVisible: boolean;
  readonly disabled: boolean;
  readonly readOnly: boolean;
}
/** Native event contract; complete Base UI DOM/form/render behavior is unfinished. */
export declare function create(react: typeof React, bindings: Bindings, options?: { readonly flushSync?: (callback: () => void) => void; readonly bindLabel?: HostProps['bindTarget']; readonly field?: import('./Field').Bridge }): { readonly Button: Component; readonly Toggle: Component; readonly Input: Component; readonly Label: Component };
