import type * as Collections from './SourceCollections';
export interface ArrayValues {
  <Value=unknown>(length?:number):Value[];
  <Value>(...items:Value[]):Value[];
  new<Value=unknown>(length?:number):Value[];
  new<Value>(...items:Value[]):Value[];
  readonly new:{<Value=unknown>(length?:number):Value[];<Value>(...items:Value[]):Value[]};
  readonly isArray: (value: unknown) => value is unknown[];
  readonly from: {
    <T,R=T>(value:readonly T[]|Collections.SourceSet<T>|Generator<T>|{readonly length:number},map?:(value:T,index:number)=>R):R[];
    <K,V,R=[K,V]>(value:Collections.SourceMap<K,V>,map?:(value:[K,V],index:number)=>R):R[];
  };
}
export type Primitive = string | number | boolean | null | undefined;
export interface NumberValues {
  (value?: Primitive): number;
  readonly isFinite: (value: unknown) => boolean;
  readonly isInteger: (value: unknown) => boolean;
  readonly isNaN: (value: unknown) => boolean;
  readonly isSafeInteger: (value: unknown) => boolean;
  readonly parseFloat: (value: string) => number;
  /** Primitive input and safe-integer result; larger precision needs a capability. */
  readonly parseInt: (value:Primitive,radix?:number) => number;
  readonly EPSILON: number;
  readonly MAX_VALUE: number;
  readonly MIN_VALUE: number;
  readonly MAX_SAFE_INTEGER: number;
  readonly MIN_SAFE_INTEGER: number;
  readonly NaN: number;
  readonly POSITIVE_INFINITY: number;
  readonly NEGATIVE_INFINITY: number;
}
export interface MathValues {
  readonly abs: (value: number) => number;
  readonly ceil: (value: number) => number;
  readonly floor: (value: number) => number;
  readonly round: (value: number) => number;
  readonly trunc: (value: number) => number;
  readonly sign: (value: number) => number;
  readonly sqrt: (value: number) => number;
  readonly min: (...values: number[]) => number;
  readonly max: (...values: number[]) => number;
  readonly random: () => number;
  readonly PI: number;
  readonly E: number;
}

export interface Globals {
 readonly Array:ArrayValues; readonly Number:NumberValues; readonly Math:MathValues; readonly String:(value?:Primitive)=>string; readonly Boolean:(value?:unknown)=>boolean; readonly NaN:number; readonly Infinity:number; readonly parseInt:NumberValues['parseInt']; readonly parseFloat:NumberValues['parseFloat'];
}
