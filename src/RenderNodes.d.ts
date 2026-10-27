import type {Node as NativeNode} from './Html';
import type {Null} from './Nulls';
export type SourceNode=NativeNode|Null|readonly SourceNode[];
export type Normalize=(value:SourceNode)=>NativeNode;
/** Convert source null/undefined array slots at the render boundary. Ordinary
 * values and unchanged collections retain their identity. Source data is untouched. */
export declare const normalize:Normalize;
