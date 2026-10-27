/** Native representation of the supported ECMAScript regex subset. Parsing and
 * matching throw UnsupportedRegExp errors for unsupported syntax/Unicode
 * representation or explicit resource budgets; they never approximate a match. */
declare const regexpValue:unique symbol;
export interface Value {readonly [regexpValue]:never}
export declare function create(pattern:string,flags?:string):Value;
export declare function owns(value:unknown):value is Value;
export declare function read(value:Value,property:string):unknown;
export declare function writeLastIndex(value:Value,nextIndex:unknown):void;
export declare function test(value:Value,input:string,suppliedIndex?:number):boolean;
export declare function exec(value:Value,input:string,suppliedIndex?:number):unknown;
export declare function length(input:string):number;
export declare function slice(input:string,first:number,finish:number):string;
export declare function advance(input:string,index:number,unicode:boolean):number;
export interface Constructor {
 (pattern?:unknown,flags?:unknown):Value;
 new(pattern?:unknown,flags?:unknown):Value;
 readonly new:(pattern?:unknown,flags?:unknown)=>Value;
}
export declare const Constructor:Constructor;
