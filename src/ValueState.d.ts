import type React from '@rbxts/react';
export interface Details { readonly isCanceled: boolean }
export interface Options<T, D extends Details> {
  readonly value?: T;
  readonly defaultValue: T;
  readonly onChange?: (value: T, details: D) => void;
  /** Controlled composition may read its owner's already accepted value before a render. */
  readonly getAccepted?: () => T;
}
/** copy validates and owns data; it must not create resources or run hooks. */
export declare function create<T>(react: typeof React, name: string, copy: (value: unknown) => T):
  <D extends Details>(options: Options<T, D>) => LuaTuple<[T, (value: T, details: D) => boolean, () => T]>;
