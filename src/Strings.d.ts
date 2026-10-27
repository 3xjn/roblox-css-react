/** Primitive-string operations with JavaScript UTF-16 positions over valid
 * scalar strings. Nonempty slices splitting a surrogate pair fail explicitly;
 * empty slices remain representable. No object coercion or RegExp search. */
export interface Methods {
  readonly startsWith: (value: string, search: string, position?: number) => boolean;
  readonly includes: (value: string, search: string, position?: number) => boolean;
  readonly endsWith: (value: string, search: string, endPosition?: number) => boolean;
  readonly slice:(value:string,start?:number,end?:number)=>string;
  /** Returns a UTF-16 code unit, including either half of an astral scalar. */
  readonly charCodeAt:(value:string,index?:number)=>number;
}
export declare const startsWith: Methods['startsWith'];
export declare const includes: Methods['includes'];
export declare const endsWith: Methods['endsWith'];
export declare const slice:Methods['slice'];
export declare const charCodeAt:Methods['charCodeAt'];
