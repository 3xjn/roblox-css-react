import type { EventValue } from './SourceCapabilities';
import type { AbortSignal } from './BrowserHost';
import type { Null } from './Nulls';

export interface Environment {
  readonly viewportWidth?: number;
  readonly viewportHeight?: number;
  readonly mediaType?: 'screen' | 'print';
  /** Explicit host capabilities. Pointer and hover are never inferred. */
  readonly features?: Readonly<Record<string, string | number | boolean>>;
}
export interface ChangeEvent extends Omit<EventValue, 'target' | 'currentTarget'> {
  readonly type: 'change';
  readonly matches: boolean;
  readonly media: string;
  readonly target: MediaQueryList;
  readonly target: MediaQueryList | Null;
  readonly currentTarget: MediaQueryList | Null;
}
export type ChangeListener = ((event: ChangeEvent) => void) | { handleEvent(event: ChangeEvent): void };
export interface MediaQueryList {
  readonly matches: boolean;
  readonly media: string;
  onchange: ((event: ChangeEvent) => void) | Null;
  readonly addEventListener: (type: 'change', listener: ChangeListener, options?: { capture?: boolean; once?: boolean; signal?: AbortSignal }) => void;
  readonly removeEventListener: (type: 'change', listener: ChangeListener, options?: { capture?: boolean } | boolean) => void;
  readonly addListener: (listener: ChangeListener) => void;
  readonly removeListener: (listener: ChangeListener) => void;
  readonly dispatchEvent: (event: ChangeEvent) => boolean;
}
export interface Options {
  readonly readEnvironment: () => Environment;
  /** Called only while at least one query has an active listener. */
  readonly subscribe: (listener: () => void) => () => void;
  readonly reportError?: (message: string) => void;
}
export interface Owner {
  readonly matchMedia: (query: string) => MediaQueryList;
  readonly destroy: () => void;
}
/** Bounded media queries evaluated by css-runtime Conditions.match. */
export declare function create(options: Options): Owner;
