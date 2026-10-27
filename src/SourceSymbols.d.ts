export interface Constructor {
  readonly toStringTag:symbol;
  (description?:string):symbol;
  readonly for:(key:string)=>symbol;
  readonly keyFor:(value:symbol)=>string|undefined;
  readonly iterator:symbol;
  readonly match:symbol;
  readonly matchAll:symbol;
  readonly replace:symbol;
  readonly search:symbol;
  readonly split:symbol;
}
export declare const Symbol:Constructor;
/** Internal language intrinsic, preserving undefined versus empty description. */
export declare function description(value:symbol):string|undefined;
