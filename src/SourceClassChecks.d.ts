/** Generic inference uses the construct return type, bypassing roblox-ts's
 * ambient Function.prototype:never without inventing a native prototype API. */
export interface Provider {
  readonly instanceOf:<T>(value:unknown,constructor:abstract new(...args:any[])=>T)=>value is T;
}
export declare const instanceOf:Provider['instanceOf'];
