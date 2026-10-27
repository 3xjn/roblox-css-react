import type { Null } from './Nulls';
export interface Target {
  readonly snapshotAttributes: () => { readonly [name: string]: string };
  readonly subscribeAttributes: (callback: () => void) => () => void;
}
export interface Record {
  readonly type: 'attributes' | 'childList' | 'characterData';
  readonly target: Target;
  readonly attributeName: string | Null;
  readonly addedNodes?: readonly Target[];
  readonly removedNodes?: readonly Target[];
  readonly previousSibling?: Target | Null;
  readonly nextSibling?: Target | Null;
  readonly oldValue: string | Null;
}
export interface Options {
  readonly attributes?: boolean;
  readonly attributeOldValue?: boolean;
  readonly attributeFilter?: readonly string[];
  readonly subtree?: boolean;
  readonly childList?: boolean;
  readonly characterData?: boolean;
  readonly characterDataOldValue?: boolean;
}
export interface Observer {
  readonly observe: (target: Target, options: Options) => void;
  readonly disconnect: () => void;
  readonly takeRecords: () => readonly Record[];
}
export interface Constructor { new (callback: (records: readonly Record[], observer: Observer) => void): Observer }
export interface Context {
  readonly constructor: Constructor;
  readonly destroy: () => void;
}
/** Observes committed CSS attributes and mounted native child changes. */
export declare function create(): Context;
