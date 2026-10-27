import type React from '@rbxts/react';
import type { ElementFactory, ElementRenderer, MergeProps, Props, UseRenderElement } from './Html';

/** Native/custom event values are composed; browser synthetic events and refs use host adapters. */
export declare const mergeProps: MergeProps;
export declare function getStateAttributesProps(
  state: Props,
  mapping?: Readonly<Record<string, (value: unknown) => Props | undefined>>,
): Props;
export declare function create(react: typeof React, element?: ElementFactory): {
  readonly useRender: ElementRenderer;
  readonly useRenderElement: UseRenderElement;
  readonly mergeProps: MergeProps;
  readonly getStateAttributesProps: typeof getStateAttributesProps;
};
