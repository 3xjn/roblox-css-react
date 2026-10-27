/** DOMRect geometry over primitive unrestricted-number values.
 * String/boolean/object/null WebIDL conversion is intentionally outside this
 * native value provider; callers must supply primitive numbers or omit values. */
export interface DOMRectInit {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
}
export interface DOMRectJSON {
  x: number;
  y: number;
  width: number;
  height: number;
  top: number;
  right: number;
  bottom: number;
  left: number;
}
export interface DOMRectReadOnly {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  readonly top: number;
  readonly right: number;
  readonly bottom: number;
  readonly left: number;
  toJSON(): DOMRectJSON;
}
export interface DOMRect extends DOMRectReadOnly {
  x: number;
  y: number;
  width: number;
  height: number;
}
export interface DOMRectReadOnlyConstructor {
  new(x?: number, y?: number, width?: number, height?: number): DOMRectReadOnly;
  readonly fromRect: (other?: DOMRectInit) => DOMRectReadOnly;
  readonly instanceof: (value: unknown) => value is DOMRectReadOnly;
}
export interface DOMRectConstructor {
  new(x?: number, y?: number, width?: number, height?: number): DOMRect;
  readonly fromRect: (other?: DOMRectInit) => DOMRect;
  readonly instanceof: (value: unknown) => value is DOMRect;
}
export interface Provider {
  readonly DOMRectReadOnly: DOMRectReadOnlyConstructor;
  readonly DOMRect: DOMRectConstructor;
}
export declare const DOMRectReadOnly: Provider['DOMRectReadOnly'];
export declare const DOMRect: Provider['DOMRect'];
