import type { PlaybackHandle } from '../../css-runtime/types/consumer';
import type { TargetContext } from './Renderer';
import type { Target as AttributeTarget } from './AttributeObservers';
import type {Provider as Operations} from './SourceOperations';
import type {Context as SourcePromises,PromiseValue} from './SourcePromise';

export interface Timing {
  readonly duration: number;
  readonly delay: number;
  readonly iterations: number;
}
export interface Animation {
  readonly finished: Promise<Animation>;
  readonly pending: boolean;
  readonly playState: 'idle' | 'running' | 'paused' | 'finished';
  readonly effect: { readonly getTiming: () => Timing };
}
export interface GetAnimationsOptions { readonly subtree?: boolean }
export interface Element extends AttributeTarget {
  readonly getAnimations: (options?: GetAnimationsOptions) => readonly Animation[];
  readonly hasAttribute: (name: string) => boolean;
}
export interface Context {
  readonly wrap: (handles: readonly PlaybackHandle[]) => readonly Animation[];
  readonly target: (context: TargetContext) => Element;
  readonly destroy: () => void;
}
/** Observe committed CSS playback, using the application's native Promise.
 * Read-only timing/completion is supported; imperative Web Animation controls
 * and browser style/layout flushing are not supplied by this boundary. */
export declare function create(promises: typeof Promise): Context;

/** The same native playback observations, settled by the source Promise realm. */
export interface SourceAnimation {
  readonly finished:PromiseValue<SourceAnimation>;
  readonly pending:boolean;
  readonly playState:Animation['playState'];
  readonly effect:{readonly getTiming:()=>Timing};
}
export interface SourceElement extends AttributeTarget {
  readonly getAnimations:(options?:GetAnimationsOptions)=>readonly SourceAnimation[];
  readonly hasAttribute:(name:string)=>boolean;
}
export interface SourceContext {
  readonly wrap:(handles:readonly PlaybackHandle[])=>readonly SourceAnimation[];
  readonly target:(context:TargetContext)=>SourceElement;
  readonly destroy:()=>void;
}
/** Completion subscribes to actual playback handles. No peer Promise, source
 * cancellation API, native playback cancellation, or polling is introduced. */
export declare function createSource(operations:Operations,promises:SourcePromises):SourceContext;
