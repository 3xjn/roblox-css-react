export type Scalar = { readonly kind: 'undefined' | 'null' | 'nan' | 'positive-infinity' | 'negative-infinity' }
  | { readonly kind: 'string'; readonly value: string }
  | { readonly kind: 'boolean'; readonly value: boolean }
  | { readonly kind: 'number'; readonly value: number };
export interface Metadata {
  readonly version: 1;
  readonly base: string;
  readonly axes: readonly { readonly name: string; readonly choices: readonly { readonly key: string; readonly classes: string; readonly numberKey?: number }[] }[];
  readonly defaults: readonly { readonly name: string; readonly value: Scalar }[];
  readonly compounds: readonly { readonly conditions: readonly { readonly name: string; readonly values: readonly Scalar[]; readonly array: boolean }[]; readonly classes: string }[];
}
/** Explicit null selection, distinct from an absent/undefined prop. */
export interface NullSelection { readonly _cvaNone: unique symbol }
export declare const None: NullSelection;
export type Selector = (props?: Readonly<Record<string, unknown>>) => string;
export type Factory = (metadata: Metadata) => Selector;
export declare function create(metadata: Metadata): Selector;
