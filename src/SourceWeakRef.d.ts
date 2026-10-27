export interface Value<T extends object|symbol> {deref():T|undefined}
export interface Constructor {new<T extends object|symbol>(target:T):Value<T>}
/** Same-turn retention uses one native deferred job. GC visibility follows
 * the native runtime; browser microtask ordering is not emulated. */
export declare function create():{readonly WeakRef:Constructor;readonly destroy:()=>void};
