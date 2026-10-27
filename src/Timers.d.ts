/** Owned millisecond one-shot callbacks. Native task scheduling is retained. */
export interface Context {
  readonly setTimeout: (callback: () => void, milliseconds: number) => number;
  readonly clearTimeout: (id: number) => void;
  readonly setInterval: (callback: (...args: any[]) => void, milliseconds: number, ...args: any[]) => number;
  readonly clearInterval: (id: number) => void;
  readonly now: () => number;
  readonly destroy: () => void;
}
export declare function create(): Context;
