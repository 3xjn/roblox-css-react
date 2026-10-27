# React bindings for Roblox CSS

`SourceRuntime.create(React, options?)` supplies the standard context for
`compileProject({ platform: 'roblox', ... })`. It shares the application's React
instance and existing arrays, records, nulls, strings, prepared styles and
function-value providers. An optional `element` factory preserves the app's
host mappings. `{ development: true }` supplies the source environment flag.
Timers and native frame contexts are created on first request; an idle context
adds no event listener. Unmount its source consumers before calling `destroy()`
to cancel only that context's pending callbacks.

`RenderNodes.normalize` is the source render boundary. It converts the source
null value and empty array slots into empty React children, preserving nested
collection order without mutating source data. Ordinary values and unchanged
collections retain identity. The compiler supplies it for supported host/fragment
child expressions; it adds no native instances, listeners or recurring work.

This context does not emulate a browser. Its globals cover owned timers/frames,
`Date.now`, the environment flag and bounded ordinary `Object.keys`,
`Object.values` and shallow native-table `Object.freeze`. Other builtins require
explicit capabilities. `Object.freeze` is qualified for the source graph's
constant tables; full descriptor/array-mutation semantics are not established.
Whole Toast source compilation and generic DOM refs/events are still incomplete.

`Frames` supplies owned native animation-frame requests for compiled source
modules. `require(runtime.CssReact.Frames).create()` returns
`requestAnimationFrame`, `cancelAnimationFrame` and `destroy`. A request schedules
one native PreRender callback batch, sharing a monotonic millisecond timestamp;
idle contexts keep no listener. This platform boundary is separate from CSS
animation clocks. The original Base UI scheduler and transition-status hook run
through the [source data contract](../../tests/data-modules/README.md); Toast
Root/Viewport rendering and performance remain unqualified.

A [roblox-ts consumer example](../../examples/roblox-ts/README.md) now compiles
against declarations for the shared renderer and Coss components. It injects
the same React runtime. Declaration coverage and package distribution remain
incomplete.

Host elements also accept [compiled inline styles](../../docs/inline-styles.md)
through the same renderer in Luau and roblox-ts.

The experimental [Progress parts](../../docs/progress.md) now share state,
formatting-provider and composition behavior across both languages. Their
source-built Coss bar and label composition are in the Studio gallery; Coss
Value's tabular-number styling and layout-size transitions remain gaps.

[Checkbox Root and Indicator](../../docs/checkbox.md) now share checked/mixed
state, cancellation and native button behavior across Luau and roblox-ts.
An explicit [native control mapping](../../docs/native-controls.md#preserve-the-logical-tag)
keeps its logical span tag and CSS selectors independent of its GuiButton.
The [static SVG asset path](../../docs/static-svg-assets.md) now renders the
unchanged Coss wrapper in the gallery. Its source-built Label captions activate
the existing Button binding through [explicit association metadata](../../docs/labels.md).
The optional [CheckboxGroup bridge](../../docs/checkbox-groups.md) shares array
selection and parent cycles using the same native bindings. General SVG document
styling and form/Field integration remain work.

The experimental [source compiler example](../../examples/compiled-coss/README.md)
uses optional bridges: `Html` converts supported source props, `Variants`
selects compiled CVA metadata, `Controls` connects class-free control parts
to the existing native behavior bindings, and `Composition` merges props and
provides render callbacks/element replacement. They share the application's React
and CSS root. These ports retain the [CVA license](LICENSE.cva) and
[Base UI license](LICENSE.base-ui).
`Variants.None` is an explicit null choice, distinct from an absent prop. These
bridges do not yet supply full browser/Base UI APIs or arbitrary source support.

The source compiler can request a `strings` dependency for primitive-string
search. Given a package ModuleScript named `cssReactModule`, load it with
`require(cssReactModule.Strings)`. It retains JavaScript UTF-16 positions over valid
Unicode scalar strings using native Luau matching, without a string prototype,
native UI objects or recurring work. See the
[search contract and limits](../../tests/source-strings/README.md).

`Controls.Button` uses the native button primitive without adding visual classes.
Register it with `Html.create(React, { button = controls.Button })` to handle a
source button's props. Fragment-producing factories also receive the same
application's `React.Fragment`. The renderer preserves leading, interleaved and
trailing text in supported flex containers through [anonymous text items](../../docs/ordered-flex-text.md).
For intrinsic hosts and fragments, `Html.create` protects nested child collections
with virtual React fragments and private collection copies. This prevents React
Luau's stable-key assignment from turning collection metadata into extra text.
The adapter preserves keyed children, component props and logical layout; it
adds no native wrappers. Cyclic collections are rejected. The source example
checks nested text/element collections and explicit formatter failure/recovery;
general inline formatting and arbitrary iterable/lazy/portal behavior remain unfinished.

`Composition` supports native/custom event arguments with handlers called from
right to left. It does not provide browser synthetic event cancellation, merged
refs, lazy render elements or a DOM. Render callbacks receive raw source props;
intrinsic elements use the existing `Html` boundary. Raw style objects can be
merged for a supplied adapter, but `Html` still requires the existing compiled
inline-style path for CSS rendering. These helpers create no native instances,
listeners, wrappers or recurring work. See the
[source example](../../examples/compiled-coss/README.md) for observed coverage.

This optional Luau package connects a React component to the CSS host. Supply your existing React module:

```lua
local bindings = CssReact.createBindings(React)

local function Panel(props)
    bindings.useCssTree(props.target, props.stylesheet, props.options, {
        {
            key = "panel",
            props = { className = "block p-4", attributes = { ["data-slot"] = "panel" } },
            children = props.items,
        },
    })
    return nil
end
```

`target` is an existing `GuiObject` whose content area the CSS host fills. React still owns that target and the surrounding app. The hook owns one CSS host and its generated descendants. It does not introduce per-element Roblox wrappers or a second layout system.

The [portable Rojo model](../../README.md#use-in-a-roblox-project) mounts `Css` and `CssReact` beside each other beneath a consumer-owned folder. Keep those module names and sibling relationship when mapping source directly. `src/Runtime.luau` contains that peer-dependency import and its type reexports. React itself is supplied by the consumer, so hooks use the same instance as the application's renderer. No package-manager distribution has been published.

## Experimental CSS renderer

`createRenderer` uses the application's installed React Luau reconciler. Unlike
the hooks below, this path takes ordinary React elements and preserves their
child ordering through reconciliation. It is qualified against React Luau
17.2.1 in Studio; it is not a complete browser host or Coss component port.

```luau
-- reconcilerModule is the installed react-reconciler initializer ModuleScript,
-- not the result of requiring it. Keep using your application's React module.
local renderer = CssReact.createRenderer(reconcilerModule)
local root = renderer.createRoot(target, stylesheet, options)

root.render(React.createElement("div", { className = "p-4" }, "Hello"))

-- Before removing the target:
root.unmount()
-- When no longer using this renderer, releases all its roots and module copy:
renderer.destroy()
```

For group opacity and rounded descendant clipping, put the target under a
`LayerCollector` with `ZIndexBehavior = Enum.ZIndexBehavior.Sibling`. Configure
the collector you own before mounting; the renderer preserves that setting.
A default `ScreenGui` uses Global order and cannot supply CanvasGroup flattening.
For a screen owned by your application:

```luau
local screen = Instance.new("ScreenGui")
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui
local target = Instance.new("Frame")
target.Size = UDim2.fromScale(1, 1)
target.BackgroundTransparency = 1
target.BorderSizePixel = 0
target.Parent = screen
```

The caller owns this screen and target; destroy them after disposing the renderer.
The [clipping contract](../../docs/clipping.md#surface-contract) describes
context loss/recovery and native limits.

`renderer.flushSync(callback)` flushes React updates through this renderer's
isolated reconciler. Use it for controlled native editing callbacks that must
commit accepted values before editor reconciliation. It shares the factory's
closed/reentry guards; do not call it from render/effects or another renderer
operation. It does not force deferred CSS/native scene painting to finish.

The initializer and all its descendants must be archivable. The factory makes
one owned sibling copy so upstream relative peer imports keep using the app's
dependencies. It never reconfigures the original reconciler. Supply a supported
React Luau dependency layout; arbitrary renderer versions or modules with
absolute imports into the original reconciler are not qualified. Native React
Roblox roots continue using their own renderer.

A target belongs to one CSS renderer root at a time across factories. Unmount
releases it for reuse; destroying a renderer unmounts its roots in reverse
creation order and removes its reconciler copy. Both operations are idempotent.
Rendering after unmount and creating roots after disposal fail. Use these
operations outside React render/effects; this experimental API uses synchronous
legacy roots and rejects reentrant operations.

Destroying the target, its ancestor, or the owned host schedules one deferred
React unmount and releases target ownership/listeners. It does not dispose the
renderer factory, which may own other roots or create replacements. Call
`renderer.destroy()` when its owner is removed. Unparenting/reparenting a target
does not unmount its root. During disposal React removes its logical tree/effects
before final CSS host release; it does not paint an empty scene. External native
destruction can already have removed those native objects before effects run.

Supply a live target. The factory rejects targets whose destruction it observed,
but cannot reliably detect an object destroyed before any registration: this
runtime still permits adding children to such an object. No parent-state guess
or property-write probe is used. Native scene painting remains deferred by the
CSS host even though React commits are synchronous; immediate target reads do
not prove paint completion.

Host props are currently `id`, `className`, `attributes`, `states`, `text`,
`children` and `bindTarget`. Tags select existing CSS paint targets; they do not add browser
control behavior. Scalar/text-only children work within existing text-layout
limits; ordered text and elements work in supported flex containers. General
inline formatting still requires a provider. Unsupported props (including
DOM callbacks) report an adapter requirement. Refs currently expose internal
logical records and are not a supported public native-ref contract. Native
control adapters, portals, Suspense, StrictMode/concurrency and Volt verification
remain unfinished. See [renderer integration](../../docs/react-renderer.md).

`bindTarget` takes a stable function `(GuiObject) -> (() -> ())?`. The renderer
uses the existing native-target watcher after the logical node commits. The
function receives the committed native target and may return cleanup. Reordering
or changing text/styles preserves the binding when both target and function
identity survive. Replacing/removing the function, deleting the node, replacing
the native target, or disposing the root releases it. All owned bindings are
attempted during teardown even if one cleanup throws. The callback owns cleanup
of partial setup if it throws before returning a release function.

Keep the binder stable across React renders. It should configure native behavior,
not imperatively reenter renderer operations. Feed event state into React or
your behavior adapter; no DOM event bubbling or synthetic event model is added.
Native input properties remain owned by the independent primitives package.

## Tree contract

Each element has a `key`, optional `props`, and an ordered `children` array. The root list and every children list must be dense arrays with indices 1 through their length; sparse, keyed and mixed tables are rejected before host writes. Keys are strings or finite numbers, unique across the surface. Stable keys preserve logical identity across prop changes, sibling reordering and moves between parents. Array order is CSS source order; it is independent of flex `order`.

Props match the CSS runtime's node inputs: `tag`, `id`, `className`, `attributes`, `states` and `text`. Each render describes the complete desired props. Removing a prop restores the node default, including clearing an old ID, attributes, states or text. Tags are logical selector metadata, not requests for native Roblox widget classes. The current renderer's layout/text limits still apply.

`text` describes leading text. Optional `textAfter` maps a one-based element-child index to the following text sequence. Maps are copied and validated before writes; omitting an old map clears it. Supported flex formatting creates private anonymous text items without adding selectable/styleable logical children. Ordinary React children supply this metadata automatically. See [ordered flex text](../../docs/ordered-flex-text.md) for anchors, ownership and limits.

Trees are snapshotted and validated in a layout effect before host writes. Render evaluation does not create native objects or mutate the host. Inputs must remain immutable during a render/commit. Keep `target`, `stylesheet` and `options` identities stable; changing any of them replaces the host. Use your application's normal memoization for options and compiled stylesheets.

`useCssTree` returns a ref. After the layout effect, its `current` controller exposes `getNode(key)` and `getHost()` for existing host APIs such as scene subscriptions and target lookup. These reads do not cause React renders. Do not add/remove/reparent nodes outside the controller, and do not manually destroy a hook-owned controller. Unmount or a dependency replacement releases it. Interaction and form states still require behavior adapters; passing a tag does not create browser button/input behavior.

An invalid key/cycle is rejected before writes. Unexpected host errors release the affected host and surface the error; there is no native rollback claim. React error boundaries can remount a fresh surface. A descriptor commit is one synchronous batch; the existing runtime coalesces CSS/layout work through its deferred invalidation events.

## Shared roots for separate components

The experimental `useCssRoot`, `useCssNode` and `useNodeTarget` hooks let
separate React components contribute to one CSS tree. The internal `Composer`
collects their committed registrations and delegates to the existing keyed tree
controller. It is unrelated to Coss's chat Composer component.

```luau
local bindings = CssReact.createBindings(React)

local function Item(props)
    local node = bindings.useCssNode(props.root, {
        parent = props.parent,
        sourceOrder = props.index,
        props = { className = "cell" },
    })
    bindings.useNodeTarget(props.root, node, props.bind)
    return nil
end

local function Panel(props)
    local root = bindings.useCssRoot(props.target, props.stylesheet, props.options)
    local panel = bindings.useCssNode(root, {
        sourceOrder = 0,
        props = { className = "row" },
    })
    return React.createElement(Item, { root = root, parent = panel, index = 1 })
end
```

Keep the root's target, stylesheet and options stable to retain its host. A
dependency replacement releases that host and creates a new one; component
registrations survive the replacement. Do not attach, detach, destroy or mutate
the hook-owned controller directly. Hooks manage node removal and subscriptions.
Keep target binders stable when their ownership has not changed.

`sourceOrder` is an explicit finite ordering label among siblings. Gaps are
allowed; ties are rejected. It controls selector/source order independently of
CSS flex `order`. The hooks do not infer ordering from React keys or table
iteration. A child can register before its parent in the same React commit:
the event-driven deferred batch sees the completed registrations. Props and
attribute/state maps are snapshotted during registration. Missing parents,
cycles and duplicate ordering labels fail validation before tree writes and
retain the prior scene. Correcting a registration schedules another commit.
Unexpected host errors retain the keyed controller's release-on-failure policy.

Native binders observe committed targets and are released when nodes disappear,
the host changes, or the React component unmounts. No marker Instances, native
layout wrappers, polling, second React copy or patched reconciler are added.
The installed React Luau 17.2.1 reconciler initializer writes its host config
into a required module; the adapter does not splice a second renderer into it.

Seventeen local Lune assertions exercised the internal registry against actual
StyleRoot/Tree modules, including ordering, child-before-parent registration,
snapshotting, failed-validation retention, deferred coalescing, detach/reattach
and teardown. They also cover rejection of recursive commits, a listener update
deferred until the outer commit finishes, and host teardown despite a throwing
listener. Listener failures are reported without skipping other cleanup.
In Studio 0.744.0.7441077, two actual React child components shared
one host. Their 20px Frames moved between x=30 and x=54 without replacement or
rebinding. Removing one child released one binding. Replacing host options
released the remaining old binding and attached a fresh target; unmount left
three setups matched by three cleanups and no registered nodes. The temporary
host was removed and the normal Coss demo retained.

This is a hook-level composition path. It still requires explicit ordering. An
experimental reconciler renderer separately has bounded Studio evidence for automatic
React-keyed ordering, hook state and isolated contexts alongside React Roblox;
see [renderer integration](../../docs/react-renderer.md). The normal Coss demo
now uses that renderer. Public
Provider/Element components, mixed inline content, general portals, full ref/event
semantics, StrictMode effect replay and concurrent-update behavior remain
unfinished or unverified. The older Coss surface harness remains separate from
this hook API.

## Native targets

The optional [Field adapter](../../docs/fields.md) combines the independent
native field model with the existing input and label bindings. It adds no
native layout wrapper or second TextBox binding. Source-built Coss Field parts
and the name-field Particle use the same adapter from Luau and roblox-ts.

Call `bindings.useNativeTarget(surfaceRef, elementKey, bind)` after `useCssTree`. `elementKey` is the declarative tree key, not a raw scene-fragment key. The binder receives the committed `GuiObject` and can return a cleanup function. A missing key or `nil` binder disables the binding. Cleanup runs on native replacement/destruction, key/host/binder change and unmount. Scene commits with the same native target preserve the binding.

Keep `bind` stable with `React.useCallback` or an equivalent stable callback. An inline function intentionally changes the binding every render; an initial state callback that then triggers another render can create a feedback loop. Retain the native binding handle in a ref and call `setDisabled` from a layout effect when controlled disabled values change. Avoid rebinding merely to reflect the binding's own state feedback.

For a block-scene element tagged `button`, the target is an initially inactive native `TextButton`. Bind it through a shared primitives scope:

```lua
local bindButton = React.useCallback(function(target)
    if not target:IsA("GuiButton") then return nil end
    local binding = scope.bindButton(target, {
        onState = setButtonState,
        onActivated = onPress,
    })
    return binding.destroy
end, { scope, setButtonState, onPress })

bindings.useNativeTarget(surfaceRef, "confirm", bindButton)
```

The component owns the shared scope and must destroy it when its surface is removed. Native control feedback still needs mapping to logical CSS states (see the primitives package). This hook adds no visual wrappers and does not couple the React adapter to that behavior package.

Without React, `CssReact.watchTarget(host, sceneKey, bind)` observes a raw scene key and returns an unsubscribe/cleanup function. Binding errors close that subscription and surface the error; the watcher does not repeatedly retry. A watcher can follow a replacement target after the previous instance is destroyed. It uses scene and destruction events, never timer checks.

## Image targets

`bindings.useImageTarget(surfaceRef, elementKey, bindImage)` follows the committed
`ImageLabel` inside a CSS image fragment. It uses the same lifecycle rules and
declarative keys as `useNativeTarget`, while keeping the outer layout frame as
the element's primary native target. A non-image/missing element releases the
image binding.

```luau
local bindImage = React.useCallback(function(image)
    local observer = scope.bindImage(image, { onState = onImageState })
    return observer.destroy
end, { scope, onImageState })

bindings.useImageTarget(surfaceRef, "avatar-image", bindImage)
```

`CssReact.watchImageTarget(host, sceneKey, bindImage)` is the standalone raw-key
version. These adapters observe native targets; they do not own loading,
fallback visibility or request handling. See [image loading](../../docs/image-loading.md)
and `examples/BindCssImage.luau` for the independent observer and its limits.

## Image content providers

`require(CssReactModule.Images).create(React, options)` adapts a caller-owned
image pack to source components. Supply a unique provider `name` and synchronous
`getAsset(name)` returning `{ source, natural?, useCurrentColor? }` or `nil`.
It uses your React instance and the existing image renderer.

```luau
local images = require(CssReactModule.Images).create(React, {
    name = "app-icons",
    getAsset = function(name)
        local asset = myIconAssets[name]
        return if asset then { source = asset, useCurrentColor = true } else nil
    end,
})
local SearchIcon = images.component("search", "svg")
-- In the existing CSS root options:
-- imageContentSource = images.resolve
```

The component preserves the requested tag, class, id and scalar `role`, `aria-*`
and `data-*` props. It owns `data-css-image-provider` and `data-css-image` metadata;
callers cannot override those attributes. Children are rejected. Asset records
and natural-size records are copied before reaching the host. No native view,
download, executor API or recurring listener is created by this adapter.

For a passive CSS box, connect `images.resolve` to `imageContentSource`. For an
`img` component, connect it to `imageSource` instead. Different providers return
`nil, nil` for each other's metadata; combine resolvers in a caller-owned
callback if needed. A matching provider with an unknown asset reports an
explicit failure. CSS owns the dimensions of non-replaced boxes. See
[images](../../docs/images.md) for fitting, color, failure and lifecycle limits.
This is not a general SVG renderer or a Lucide prop implementation. Packs and
their licensing stay with the application; the compiled Coss example includes
three optional Lucide asset references.

## Use without React

For source-built non-UI logic, `require(CssReactModule.OrderedSet).create(Set)`
adapts the application's existing Luau Polyfill Set constructor. It loads no
renderer. The empty-constructor subset supports `size`, `add`, `delete`, `has`,
`clear`, ordered `forEach(value, key, set)`, and `values()` with the native
`next()`/`done`/`value` ABI used by roblox-ts Generator loops. The original
collection owns storage. Independent live cursors handle removals, additions,
clear/reinsert and nested traversal. Exhaustion is permanent; `forEach` releases
its cursor on success or an exception without allocating a result record per
callback. Table keys use private identity tokens so
their `__eq` metamethod cannot merge distinct objects during deletion.
Primitive keys include undefined, NaN and normalized zero. Iterator ownership
uses weak keys; abandoned cursors are reclaimed by Roblox GC. Removed/cleared
keys are released from ledgers immediately. Collection timing after an early
break/return is not forced or qualified. A cursor snapshots existing entries
at creation; mutations update live cursors, so cost depends on entry and cursor
counts. Iterable constructors, JavaScript Symbols, prototype overrides,
`thisArg` and arbitrary native value-datatype identity remain unqualified.
See the [data module tests](../../tests/data-modules/README.md).

`require(CssReactModule.Records)` supplies ordinary own data properties to
source-built modules without loading React. Records remain plain Lua tables
with weak presence/order metadata. The compiler's `records` binding instruments
literals, spreads, rest declarations and deletion. Use `adopt(table, keyOrder)`
for native inputs, `copy` for tracked shallow copies, and the same provider for
`keys`, `hasOwn` and own-data `enumerate`. Explicit undefined stays present;
deleting then re-adding a property moves its insertion position. Array-index
keys sort numerically before other string keys. Spreads snapshot values before
later expressions can change their source. There are no native instances,
services, listeners or recurring tasks.

This is an opt-in data boundary, not a general JavaScript object model. Numeric
keys support safe integers, NaN and infinities; other number formatting, symbols,
descriptors/prototypes and primitive string spreads remain unfinished. Unknown
native tables fail rather than inventing insertion order. `values` supports dense
values including undefined through the shared source-array representation.
Raw native table mutation and `table.clone` do not maintain the metadata. See the
[compiler contract](../react-compiler/README.md#own-record-properties).

`require(CssReactModule.Arrays)` keeps source array values in native numeric
slots, with weak metadata for length and own presence. It reuses native
`__len` and [generalized iteration](https://luau.org/syntax/#generalized-iteration).
Literals, spreads and `Object.values` retain nil positions; array holes remain
distinct from present undefined. The source compiler's optional `arrays` binding
routes supported operations through this provider. Callback traversal follows
the source operation's initial length, while ordinary iteration observes live
length. No native instances, services, listeners, recurring tasks or frame scans
are introduced by this runtime. Construction and callbacks cost proportional
work; no zero-cost or FPS claim is made.

Native callers adopt arrays with explicit logical length and optional zero-based
present indexes. Construction helpers are the compiler ABI. Unsupported native
tables fail rather than guessing their missing length/presence. Source arrays
crossing modules need the same provider instance. Function rest declarations/
bindings, prototypes, named properties and broader coercion remain
unfinished. See [source array coverage](../react-compiler/README.md#source-arrays)
and the [native contracts](../../tests/data-modules/README.md).

The same provider transports function arguments with explicit counts. Rest
expressions create fresh tracked arrays when observed; forwarding-only functions
can pass native varargs directly. Calls expand tracked packets with their logical
length, including trailing nils. Optional calls defer argument effects. Generic
callback/result relationships stay checked at the native boundary. These helpers
add no background work. See [function arguments](../react-compiler/README.md#function-arguments)
for supported forms and receiver/overload limitations.

`require(CssReactModule.SourceType)` provides the shared JavaScript `typeOf`
classification and a typed `typeIs` predicate for source-built data modules.
The HTML bridge uses the same implementation. Supported native objects classify
as `object`, including the canonical data-null marker. Symbol and bigint
representations remain unfinished.
`Records.keyString` exposes the existing bounded string/safe-integer key
formatter. Neither helper adds services, instances, listeners or recurring work.
See the [compiler boundaries](../react-compiler/README.md#native-value-boundaries).

`require(CssReactModule.Nulls)` supplies the data compiler's canonical null value
and checked nullish operations. It is distinct from nil, immutable, and shared
across source module contexts. Native callers use `Nulls.value` and the exported
opaque `Null` type. Arrays and Records use the same instance for predicates,
joins and nullable spreads. The helpers add no background work; a lazy nullish
fallback may allocate its source callback. This is a bounded data contract,
separate from rendered React children, coercion and JSON serialization. See
[source null](../react-compiler/README.md#source-null) for supported operations
and diagnostics.

`require(CssReactModule.FunctionValues)` keeps function names/display names as
weak metadata without wrapping the function. Values are strings only, so the
metadata cannot retain a function through an owner reference. `invoke` forwards
native varargs directly, retaining trailing nil arguments and return values.
It adds no instances, services, listeners, recurring tasks or frame scans. Use
the compiler's explicit `functions` binding; callable tables, prototypes and
general function properties remain outside this contract. See
[source function boundaries](../react-compiler/README.md#functions-and-source-owned-types).

`CssReact.createTree(host)` creates the same keyed controller for a host owned exclusively by it. Call `controller.commit(elements)`, then `controller.destroy()` when finished. No React dependency is required for this entry point.

This package is an initial hook-level adapter. Declarative component composition, React portals and general native event/ref semantics remain unfinished. Coss harness components have bounded Studio observations documented in `packages/coss/README.md`; they do not establish general React lifecycle, StrictMode replay, concurrent updates or visual fidelity. Static analysis includes an integration example against the actual CSS host in `examples/ReactSurface.luau`; it does not replace runtime evidence.

On 2026-10-22, 14 Lune assertions exercised the unchanged controller against the
actual StyleRoot: reparenting, root reordering, deletion of an old parent,
ancestor inversion, empty commits, teardown, and invalid child-array/key/cycle
rejection before revision changes. A separate Studio 0.744.0.7441077 host used
one document root and retained a child's logical identity and native Frame
through reparenting, rejected a nested keyed children table while preserving
the scene, and retained that Frame through ancestor inversion. Its dimensions
changed from 20 x 20 to 220 x 40 with the new style. The temporary host was
destroyed and the normal Coss demo retained. These observations cover the keyed
controller and native scene, not React effect replay or arbitrary composition.

API reference: [React Luau hooks](https://react-luau.dev/api-reference/react/). The adapter uses the application's React instance and its `useRef`/`useLayoutEffect` APIs; it does not fork React reconciliation.

## Repository setup

This repository contains the `@3xjn/roblox-css-react` package. It is in active development and has not been published to npm.

Related packages:

- [@3xjn/roblox-css](https://github.com/3xjn/roblox-css)
- [@3xjn/roblox-primitives](https://github.com/3xjn/roblox-primitives)

Authenticate Git with GitHub before running `npm install`; development dependencies use the related private GitHub repositories.

Build the Luau module with `rojo build default.project.json --output CssReact.rbxm`. Runtime imports expect the related modules as siblings in the Roblox package tree.

The development gallery and cross-package tests remain in the private [roblox-styling workspace](https://github.com/3xjn/roblox-styling).
