export interface Value {
  getTime(): number; valueOf(): number; setTime(time: number): number;
  getFullYear(): number; getUTCFullYear(): number; getMonth(): number; getUTCMonth(): number;
  getDate(): number; getUTCDate(): number; getDay(): number; getUTCDay(): number;
  getHours(): number; getUTCHours(): number; getMinutes(): number; getUTCMinutes(): number;
  getSeconds(): number; getUTCSeconds(): number; getMilliseconds(): number; getUTCMilliseconds(): number;
  /** Local getters and setters use the device zone supplied by Roblox DateTime. */
  getTimezoneOffset(): number;
  setFullYear(year: number, month?: number, day?: number): number;
  setUTCFullYear(year: number, month?: number, day?: number): number;
  setMonth(month: number, day?: number): number; setUTCMonth(month: number, day?: number): number;
  setDate(day: number): number; setUTCDate(day: number): number;
  setHours(hour: number, minute?: number, second?: number, millisecond?: number): number;
  setUTCHours(hour: number, minute?: number, second?: number, millisecond?: number): number;
  setMinutes(minute: number, second?: number, millisecond?: number): number;
  setUTCMinutes(minute: number, second?: number, millisecond?: number): number;
  setSeconds(second: number, millisecond?: number): number; setUTCSeconds(second: number, millisecond?: number): number;
  setMilliseconds(millisecond: number): number; setUTCMilliseconds(millisecond: number): number;
  toISOString(): string; toJSON(): string | null | undefined; toString(): string; toUTCString(): string;
  toLocaleString(locale?: string): string; toLocaleDateString(locale?: string): string; toLocaleTimeString(locale?: string): string;
}
export interface Constructor {
  new(): Value;
  new(value: number | string | Value): Value;
  new(year: number, month: number, day?: number, hour?: number, minute?: number, second?: number, millisecond?: number): Value;
  (): string;
  (value: number | string | Value): string;
  /** roblox-ts superclass ABI entry used by Date subclasses. */
  readonly constructor: (self: Value, ...args: unknown[]) => Value;
  readonly now: () => number;
  readonly UTC: (year: number, month?: number, day?: number, hour?: number, minute?: number, second?: number, millisecond?: number) => number;
  readonly parse: (value: string) => number;
  readonly instanceof: (value: unknown) => value is Value;
  readonly prototype: Value;
}
export declare const Date: Constructor;
