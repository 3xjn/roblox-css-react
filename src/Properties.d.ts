/** Source property values; numeric keys normalize to strings, symbols retain identity. */
export type PropertyKey = string | number | symbol;
/** Numeric keys normalize to strings; Symbol keys retain identity. */
export type Has = (key: PropertyKey, receiver: unknown) => boolean;
export declare const has: Has;
/** Opaque native proxies declare existence without running their getters. */
export declare function register(receiver: object, resolver: (key: PropertyKey) => boolean): () => void;
/** Declare React's public ref field without replacing its native metatable. */
export declare function ref<T extends {current:unknown}>(receiver:T):T;
