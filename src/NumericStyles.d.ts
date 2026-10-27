import type { Style } from './StyleObjects';
export interface Template {
  readonly kind: 'numeric-style';
  readonly base: Style;
  readonly arity: number;
  readonly slots: readonly {
    readonly entry: number; readonly argument: number; readonly pixels: boolean;
    readonly unit?: string;
    readonly domain: { readonly zero: boolean; readonly ranges: readonly { readonly minimum?: number; readonly maximum?: number; readonly integer?: boolean }[] };
  }[];
  readonly keys?: readonly number[];
}
export type Value = number | boolean | '' | undefined;
export type Factory = (template: Template) => (...values: Value[]) => Style;
export declare const create: Factory;
