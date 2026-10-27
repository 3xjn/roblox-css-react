export interface Options {
 /** Defer one FIFO drain; cancellation owns that drain only. */
 readonly schedule?:(callback:()=>void)=>(()=>void)|undefined;
 readonly onError?:(reason:unknown)=>void;
}
export interface Context {readonly enqueue:(callback:()=>void)=>()=>void;readonly destroy:()=>void}
export declare function create(options?:Options):Context;
