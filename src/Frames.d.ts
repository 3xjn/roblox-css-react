/** Owned, one-shot animation-frame requests against Roblox's native render event. */
export type Callback = (timestamp: number) => void;
export interface Context {
  readonly requestAnimationFrame: (callback: Callback) => number;
  readonly cancelAnimationFrame: (id: number) => void;
  readonly destroy: () => void;
}
/** Callbacks in one batch share a monotonic timestamp in milliseconds. */
export declare function create(): Context;
