import type {TargetContext} from './Renderer';
import type {DomElementProxy} from './Html';
import type {SourceElement as AnimationElement} from './WebAnimations';
export interface Options {
 readonly tag?:string;
 readonly document?:unknown;
 readonly pointer?:unknown;
 /** Explicit document membership root. Without it isConnected uses DataModel
  * ancestry, which cannot distinguish separate browser document owners. */
 readonly documentRoot?:Instance;
 readonly animations?:(context:TargetContext)=>AnimationElement;
}
export type ResolvedProperty='transform'|'width'|'height'|'opacity'|'position'|'box-sizing'
 |'padding-top'|'padding-right'|'padding-bottom'|'padding-left'
 |'border-top-width'|'border-right-width'|'border-bottom-width'|'border-left-width'
 |'margin-top'|'margin-right'|'margin-bottom'|'margin-left';
export type ResolvedPropertyAlias='boxSizing'|'paddingTop'|'paddingRight'|'paddingBottom'|'paddingLeft'
 |'borderTopWidth'|'borderRightWidth'|'borderBottomWidth'|'borderLeftWidth'
 |'marginTop'|'marginRight'|'marginBottom'|'marginLeft';
export interface ComputedStyle extends Readonly<Record<ResolvedProperty|ResolvedPropertyAlias,string>> {
 /** Source method borrowing uses the supplied receiver. Named reads require
  * the target's actual resolved-property metadata. Full CSS declaration
  * enumeration/indexed slots and mutation are not implemented. */
 readonly getPropertyValue:(name:string)=>string;
}
/** Mutable inline declaration view. Writes currently support scalar sizing
 * properties; complex CSS values and other setters fail before mutation. */
export interface InlineStyleDeclaration {
 height:string;width:string;minHeight:string;minWidth:string;maxHeight:string;maxWidth:string;
 readonly getPropertyValue:(name:string)=>string;
 readonly getPropertyPriority:(name:string)=>string;
 readonly setProperty:(name:string,value:string,priority?:string)=>void;
 readonly removeProperty:(name:string)=>string;
}
/** Source prototype methods are shared and unbound. The typed native function
 * properties retain their legacy free-call view. release revokes source reads,
 * subscriptions and live style views without destroying the native target. */
export declare function create(target:GuiObject,context:TargetContext,options?:Options):{
 readonly element:DomElementProxy; readonly release:()=>void;
};
export declare function computedStyle(element:DomElementProxy):ComputedStyle;
export declare function unwrap(element:GuiObject|DomElementProxy):GuiObject;
