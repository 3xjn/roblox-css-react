import type {Provider} from './SourceOperations';
/** Unmapped strict arguments; poison is the owning realm's canonical thrower. */
export declare function create(operations:Provider,packet:readonly unknown[],strict?:boolean,poison?:unknown):unknown;
