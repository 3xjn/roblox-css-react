import type { InlineStyle, PropertyMetadata } from '../../css-runtime/types/consumer';
export interface Style {
  readonly kind: 'style-object';
  readonly entries: readonly { readonly name: string; readonly declaration?: InlineStyle['declarations'][number] }[];
  readonly properties?: Readonly<Record<string, PropertyMetadata>>;
}
export declare function is(value: unknown): value is Style;
export declare function toInline(style: Style): InlineStyle;
export declare function merge(previous: Style | undefined, incoming: Style): Style;
