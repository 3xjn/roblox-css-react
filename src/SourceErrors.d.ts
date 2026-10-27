export interface Value {
  name:string;
  message:string;
  stack?:string;
  cause?:unknown;
  readonly toString:(this:void)=>string;
}
export interface Constructor {
  (message?:unknown,options?:{readonly cause?:unknown}):Value;
  new(message?:unknown,options?:{readonly cause?:unknown}):Value;
  readonly new:(message?:unknown,options?:{readonly cause?:unknown})=>Value;
  readonly instanceof:(value:unknown)=>value is Value;
}
export declare const Error:Constructor;
export declare const TypeError:Constructor;
export declare const RangeError:Constructor;
