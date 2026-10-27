/** Ordinary source arrays with explicit length and own slot presence. Native
 * tables enter through adopt with an explicit logical length. */
type Source = readonly unknown[];
type Callback<A extends Source, R> = (
  value: A[number],
  index: number,
  array: A,
) => R;
export interface Provider {
  readonly forward: <A extends unknown[]>() => {
    <R>(resolve: () => (...args: A) => R, optional: false): (...args: A) => R;
    <R>(
      resolve: () => ((...args: A) => R) | undefined,
      optional: true,
    ): (...args: A) => R | undefined;
  };
  readonly rest: <A extends unknown[], R>(
    callback: (args: A) => R,
  ) => (...args: A) => R;
  readonly restPrefix:<Fixed extends unknown[],Rest extends unknown[],R>(callback:(...args:[...Fixed,Rest])=>R,count:number)=>(...args:[...Fixed,...Rest])=>R;
  /** Internal array storage represents an unmapped arguments object. Runtime
   * branding keeps it distinct from ordinary source arrays. */
  readonly withArguments: {
    <A extends unknown[], R>(callback: (packet: unknown[], ...args: A) => R): (...args: [...A, ...unknown[]]) => R;
    <Fixed extends unknown[], Rest extends unknown[], R>(callback: (packet: unknown[], ...args: [...Fixed, Rest]) => R, count: number): (...args: [...Fixed, ...Rest]) => R;
  };
  readonly withMethodArguments: {
    <Self,A extends unknown[],R>(callback:(this:Self,packet:unknown[],...args:A)=>R):(this:Self,...args:[...A,...unknown[]])=>R;
    <Self,Fixed extends unknown[],Rest extends unknown[],R>(callback:(this:Self,packet:unknown[],...args:[...Fixed,Rest])=>R,count:number):(this:Self,...args:[...Fixed,...Rest])=>R;
  };
  /** Capture native class/method varargs before a generated rest table loses trailing nil slots. */
  readonly bindConstructor:<C>(value:C)=>C;
  readonly bindMethod:<C extends new(...args:any[])=>unknown,Key extends keyof InstanceType<C>|keyof C>(value:C,name:Key)=>Key extends keyof InstanceType<C>?InstanceType<C>[Key]:Key extends keyof C?C[Key]:never;
  readonly restArgs:<A extends unknown[]>(value:A,fixed:number)=>A;
  readonly currentArguments:()=>unknown[];
  readonly construct:<C extends new(...args:any[])=>unknown>(value:C,args:readonly [...ConstructorParameters<C>,...unknown[]])=>InstanceType<C>;
  readonly superArguments:<C extends new(...args:any[])=>unknown>(value:C,args:readonly [...ConstructorParameters<C>,...unknown[]],fixed:number)=>LuaTuple<ConstructorParameters<C>>;
  readonly call: <F extends (this: void, ...args: any[]) => unknown>(
    callback: F,
    args: readonly [...Parameters<F>, ...unknown[]],
  ) => ReturnType<F>;
  readonly callOptional: <F extends (this: void, ...args: any[]) => unknown>(
    callback: F | undefined,
    args: readonly [...Parameters<F>, ...unknown[]],
  ) => ReturnType<F> | undefined;
  readonly callOptionalLazy: <
    F extends (this: void, ...args: any[]) => unknown,
  >(
    callback: F | undefined,
    args: () => readonly [...Parameters<F>, ...unknown[]],
  ) => ReturnType<F> | undefined;
  readonly literal: <A extends Source>(
    value: A,
    length: number,
    holes?: readonly number[],
  ) => A;
  readonly adopt: <A extends Source>(
    value: A,
    length: number,
    present?: readonly number[],
  ) => A;
  readonly finish: <A extends Source>(value: A) => A;
  readonly slot: <T>(value: T) => T;
  readonly hole: () => undefined;
  readonly spread: <A extends Source>(value: A) => A;
  readonly length: {
    (value: readonly []): 0;
    (value: Source): number;
  };
  readonly optionalCall: <A extends Source, R>(value: A | import('./Nulls').Null | undefined, callback: (value: A) => R) => R | undefined;
  readonly values:<A extends Source>(value:A)=>Generator<A[number],void,unknown>;
  readonly entries:<A extends Source>(value:A)=>Generator<[number,A[number]],void,unknown>;
  readonly owns: (value: unknown) => boolean;
  readonly isArray: (value: unknown) => boolean;
  readonly keys: (value: Source) => string[];
  readonly setLength: (value: unknown[], length: number) => number;
  readonly has: (value: Source, index: number) => boolean;
  readonly remove: (value: Source, index: number) => boolean;
  readonly map: <A extends Source, R>(
    value: A,
    callback: Callback<A, R>,
  ) => R[];
  readonly filter: {
    <A extends Source, S extends A[number]>(
      value: A,
      callback: (value: A[number], index: number, array: A) => value is S,
    ): S[];
    <A extends Source>(value: A, callback: Callback<A, unknown>): A[number][];
  };
  readonly forEach: <A extends Source>(
    value: A,
    callback: Callback<A, unknown>,
  ) => void;
  readonly some: <A extends Source>(
    value: A,
    callback: Callback<A, unknown>,
  ) => boolean;
  readonly every: <A extends Source>(
    value: A,
    callback: Callback<A, unknown>,
  ) => boolean;
  readonly find: {
    <A extends Source, S extends A[number]>(
      value: A,
      callback: (value: A[number], index: number, array: A) => value is S,
    ): S | undefined;
    <A extends Source>(
      value: A,
      callback: Callback<A, unknown>,
    ): A[number] | undefined;
  };
  readonly findIndex: <A extends Source>(
    value: A,
    callback: Callback<A, unknown>,
  ) => number;
  readonly slice: <A extends Source>(
    value: A,
    start?: number,
    end?: number,
  ) => A[number][];
  readonly push: <A extends unknown[]>(
    value: A,
    ...items: A[number][]
  ) => number;
  readonly pushItems: <A extends unknown[]>(
    value: A,
    items: readonly A[number][],
  ) => number;
  readonly unshiftItems: <A extends unknown[]>(
    value: A,
    items: readonly A[number][],
  ) => number;
  readonly spliceArgs: <A extends unknown[]>(
    value: A,
    args: readonly [
      start?: number,
      deleteCount?: number,
      ...items: A[number][],
    ],
  ) => A[number][];
  readonly pop: <T>(value: T[]) => T | undefined;
  readonly shift: <T>(value: T[]) => T | undefined;
  readonly unshift: <A extends unknown[]>(
    value: A,
    ...items: A[number][]
  ) => number;
  readonly splice: <A extends unknown[]>(
    value: A,
    start?: number,
    deleteCount?: number,
    ...items: A[number][]
  ) => A[number][];
  readonly includes: <T>(
    value: readonly T[],
    search: T,
    fromIndex?: number,
  ) => boolean;
  readonly indexOf: <T>(
    value: readonly T[],
    search: T,
    fromIndex?: number,
  ) => number;
  readonly lastIndexOf: <T>(value: readonly T[], item: T, from?: number) => number;
  readonly flatMap: <A extends Source, Result>(value: A, callback: Callback<A, Result | readonly Result[]>) => Result[];
  readonly concat:<T,U>(value:readonly T[],...items:readonly (U|readonly U[])[])=>(T|U)[];
  readonly concatItems:<T,U>(value:readonly T[],items:readonly (U|readonly U[])[])=>(T|U)[];
  readonly reduce:{
    <A extends Source>(value:A,callback:(accumulator:A[number],value:A[number],index:number,array:A)=>A[number]):A[number];
    <A extends Source,R>(value:A,callback:(accumulator:R,value:A[number],index:number,array:A)=>R,initial:R):R;
  };
  readonly sort: <T>(value: T[], compare?: (left: T, right: T) => number) => T[];
  readonly reverse:<A extends unknown[]>(value:A,...ignored:unknown[])=>A[number][];
  readonly fill: <T>(value: T[], item: T, start?: number, end?: number) => T[];
  readonly at: <T>(value: readonly T[], index: number) => T | undefined;
  readonly join: (value: Source, separator?: string) => string;
}
export declare const literal: Provider['literal'];
export declare const rest: Provider['rest'];
export declare const restPrefix: Provider['restPrefix'];
export declare const withArguments: Provider['withArguments'];
export declare const withMethodArguments: Provider['withMethodArguments'];
export declare const bindConstructor: Provider['bindConstructor'];
export declare const bindMethod: Provider['bindMethod'];
export declare const restArgs: Provider['restArgs'];
export declare const currentArguments: Provider['currentArguments'];
export declare const construct: Provider['construct'];
export declare const superArguments: Provider['superArguments'];
export declare const isArray: Provider['isArray'];
export declare const forward: Provider['forward'];
export declare const call: Provider['call'];
export declare const callOptional: Provider['callOptional'];
export declare const callOptionalLazy: Provider['callOptionalLazy'];
export declare const adopt: Provider['adopt'];
export declare const finish: Provider['finish'];
export declare const slot: Provider['slot'];
export declare const hole: Provider['hole'];
export declare const spread: Provider['spread'];
export declare const length: Provider['length'];
export declare const optionalCall: Provider['optionalCall'];
export declare const owns: Provider['owns'];
export declare const keys: Provider['keys'];
export declare const setLength: Provider['setLength'];
export declare const has: Provider['has'];
export declare const remove: Provider['remove'];
export declare const map: Provider['map'];
export declare const filter: Provider['filter'];
export declare const forEach: Provider['forEach'];
export declare const some: Provider['some'];
export declare const every: Provider['every'];
export declare const find: Provider['find'];
export declare const findIndex: Provider['findIndex'];
export declare const slice: Provider['slice'];
export declare const push: Provider['push'];
export declare const pushItems: Provider['pushItems'];
export declare const unshiftItems: Provider['unshiftItems'];
export declare const spliceArgs: Provider['spliceArgs'];
export declare const pop: Provider['pop'];
export declare const shift: Provider['shift'];
export declare const unshift: Provider['unshift'];
export declare const splice: Provider['splice'];
export declare const includes: Provider['includes'];
export declare const indexOf: Provider['indexOf'];
export declare const lastIndexOf: Provider['lastIndexOf'];
export declare const flatMap: Provider['flatMap'];
export declare const concat: Provider['concat'];
export declare const concatItems: Provider['concatItems'];
export declare const reduce: Provider['reduce'];
export declare const sort: Provider['sort'];
export declare const reverse:Provider['reverse'];
export declare const fill: Provider['fill'];
export declare const at: Provider['at'];
export declare const join: Provider['join'];
