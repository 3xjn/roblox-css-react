import type React from '@rbxts/react';
import type { Component } from './Html';
import type { ImageData, ImageProvider, ImageProviderInputs } from '../../css-runtime/types/consumer';

export interface Options {
  readonly name: string;
  readonly getAsset: (name: string) => ImageData | undefined;
}

/** No asset downloads or native instances; content lives in the existing CSS box. */
export declare function create(react: typeof React, options: Options): {
  readonly component: (asset: string, tag: string) => Component;
  /** Select a caller-owned asset using a compiled source data attribute. */
  readonly fromAttribute: (tag: string, attribute: string) => Component;
  readonly resolve: ImageProvider;
  readonly inputs: ImageProviderInputs;
};
