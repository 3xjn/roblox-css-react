import type {Provider} from './SourceOperations';
import type {Context as Promises} from './SourcePromise';
export interface Context {
 readonly asyncFunctionValue:Provider['asyncFunctionValue'];
 readonly awaitValue:Provider['awaitValue'];
 readonly destroy:()=>void;
}
export declare function create(operations:Provider,promises:Promises):Context;
