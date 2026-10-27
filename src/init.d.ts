import type { HostOptions, InlineStyle, Stylesheet } from '@3xjn/roblox-css';
export interface NodeOptions { readonly tag?: string; readonly id?: string; readonly className?: string; readonly text?: string; readonly attributes?: Readonly<Record<string, string>>; readonly states?: Readonly<Record<string, boolean>>; readonly inlineStyle?: InlineStyle; readonly nativeControl?: 'auto' | 'button' }
export interface Node { readonly [key: string]: unknown }
export interface Host { readonly [key: string]: unknown }
export type Key = string | number;
export interface Element { readonly key: Key; readonly props?: NodeOptions; readonly children?: readonly Element[]; readonly labelable?: boolean }
export interface Controller { commit(elements: readonly Element[]): void; getNode(key: Key): Node | undefined; getHost(): Host | undefined; destroy(): void }
export interface Ref<T> { current: T }
export interface React { useRef<T>(value: T): Ref<T>; useLayoutEffect(effect: () => (() => void) | undefined, dependencies?: readonly unknown[]): void }
export declare function createTree(host: Host): Controller;
export declare function createBindings(react: React): { useCssTree(target: GuiObject, stylesheet: Stylesheet, options: HostOptions, elements: readonly Element[]): Ref<Controller | undefined>; readonly [name: string]: unknown };
export declare function createRenderer(source: ModuleScript): unknown;
export declare function createElementFactory(...args: unknown[]): unknown;
export declare function watchTarget(...args: unknown[]): unknown;
export declare function watchImageTarget(...args: unknown[]): unknown;
