import type { IntersectionObserverConstructor } from './SourceCapabilities';
export interface Host {
  readonly constructor:IntersectionObserverConstructor;
  readonly destroy:()=>void;
}
/** Event-driven observation of native clipping and committed proxy geometry.
 * Pixel/percentage root margins and ratio thresholds are supported. */
export declare function create():Host;
