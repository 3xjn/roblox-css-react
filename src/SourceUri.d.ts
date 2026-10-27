import type * as SourceErrors from './SourceErrors';

export type URIErrorConstructor=SourceErrors.Constructor;
export interface Methods {
  readonly encodeURIComponent:(value:string)=>string;
  readonly decodeURIComponent:(value:string)=>string;
}
export declare const URIError:URIErrorConstructor;
export declare const encodeURIComponent:Methods['encodeURIComponent'];
export declare const decodeURIComponent:Methods['decodeURIComponent'];
