export type Key=object|symbol;
/** Native Symbol creation paths supply registration identity. Structural fields
 * on ordinary objects do not affect weak-key eligibility. */
export declare function registerSymbol(value:symbol,registered:boolean):void;
export declare function canBeHeldWeakly(value:unknown):value is Key;
