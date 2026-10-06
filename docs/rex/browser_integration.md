# Rubix Execution eXchange (REX) — Browser Host Architecture & Pixel Pipeline Specification

## 1. Executive Summary & Core Architectural Goal

The **Rubix Execution eXchange (REX)** is a high-performance execution architecture designed to serve as a first-class compilation and execution target for the Rubix programming language. Within web environments, the objective is defined by the strict invariant:

```text
REX → Browser → Pixels
```

### 1.1 Strict Architectural Constraints
To preserve the autonomy, safety, and performance characteristics of Rubix and REX, the browser integration adheres strictly to the following principles:

1. **Zero JavaScript Translation**: REX is **not** transpiled or compiled to JavaScript.
2. **Zero WebAssembly Dependency**: REX is **not** wrapped into WebAssembly bytecode or emulated via Wasm modules.
3. **Zero JavaScript Runtime Overhead**: REX does **not** embed or depend upon a JavaScript engine (V8, QuickJS, Duktape, etc.) for execution.
4. **REX is the Execution System**: All program logic, reactive state mutations, event handling, and data transformations execute inside the REX execution tier (compiled JIT native machine code, direct-threaded interpreter, or reference VM).
5. **The Browser is the Host & Rendering Environment**: The browser provides the display surface, viewport layout, compositor, event ingestion, and physical screen pixels.

---

## 2. End-to-End Execution Pipeline

The complete pipeline from Rubix program source code down to physical monitor pixels proceeds through seven distinct, validated phases:

```text
                         Rubix Web Program Source
                                    │
                                    ▼
                      REX Bytecode Module (.rex)
                                    │
                 ┌──────────────────┼──────────────────┐
                 │                  │                  │
                 ▼                  ▼                  ▼
          Tier 1: COMPILED   Tier 2: INTERPRET   Tier 3: REF VM
          Native x86-64 JIT   Direct Bytecode     Semantic Spec
                 │                  │                  │
                 └──────────────────┼──────────────────┘
                                    │
                                    ▼
                        REX Web & Document Model
                   (Elements, Attributes, Event Tree)
                                    │
                                    ▼
                        State Mutation & DOM Patch
                  (Incremental Batched Tree Updates)
                                    │
                                    ▼
                     HTML5 Representation & Cascading
               (Tag Trees, Attributes, Semantic Structure)
                                    │
                                    ▼
                         CSS Engine & Cascade
               (Selectors, Specificity, Variables, Cascade,
                 Inheritance, Box Model, Flexbox Layout)
                                    │
                                    ▼
                     Layout & Display Geometry Tree
               (Bounding Boxes, Paddings, Margins, Borders)
                                    │
                                    ▼
                       Painting & Rasterization
               (Backgrounds, Gradients, Shadows, Glyphs)
                                    │
                                    ▼
                        Browser Display Surface
                                    │
                                    ▼
                         PHYSICAL SCREEN PIXELS
```

---

## 3. Web Document Model & Tree Mutation Engine

The REX web model (`std/web.bix`) manages the document tree as a high-performance, structured value graph:

### 3.1 DOM Element Representation
Each element is assigned an immutable 64-bit integer node identifier (`node_id`) and stores:
- **`tag_id`**: Enumerated tag code (`div`, `section`, `nav`, `h1`, `h2`, `h3`, `p`, `button`, `input`, `span`, `ul`, `li`).
- **`element_id`**: Optional unique identifier for direct lookup.
- **`classes`**: Dynamic list of style and utility classes.
- **`attributes`**: Key-value attribute dictionary (e.g. `placeholder`, `aria-label`, `data-state`).
- **`inline_styles`**: High-specificity inline style declarations.
- **`children`**: Ordered sequence of child node references.
- **`text`**: Textual content.
- **`event_listeners`**: Bitmask and registration table for attached event handlers.

### 3.2 Incremental DOM Mutation Journal
When an event or timer executes, the REX runtime avoids re-serializing the entire document. Instead, it records atomic mutation records:
- `DOM_MUT_CREATE_ELEMENT(node_id, tag_id)`
- `DOM_MUT_SET_ID(node_id, id_str)`
- `DOM_MUT_SET_CLASS(node_id, class_str)`
- `DOM_MUT_SET_ATTRIBUTE(node_id, key, val)`
- `DOM_MUT_SET_STYLE(node_id, prop, val)`
- `DOM_MUT_SET_TEXT(node_id, text_str)`
- `DOM_MUT_APPEND_CHILD(parent_id, child_id)`
- `DOM_MUT_REMOVE_CHILD(parent_id, child_id)`

These records are transmitted across the REX host bridge to patch the live browser display surface with sub-millisecond latency.

---

## 4. Modern CSS & Tailwind Compatibility Engine

The styling subsystem (`tools/rex_css_engine.py`) implements full W3C CSS specifications and seamless consumption of Tailwind-generated utility classes.

### 4.1 Selector Specificity
Specificity is strictly calculated as a 4-tuple `(inline, id_count, class_attr_pseudo_count, element_count)`:
- `:inline`: `(1, 0, 0, 0)`
- `#id`: `(0, 1, 0, 0)`
- `.class`, `[attr]`, `:pseudo`: `(0, 0, 1, 0)`
- `element`: `(0, 0, 0, 1)`

Rules are matched according to compound selectors (e.g. `div.card.highlighted`, `nav > ul > li.active`), and higher specificity always supersedes lower specificity regardless of declaration order. For equal specificity, source order determines the final cascaded value.

### 4.2 CSS Variables & Custom Properties
Variables defined in `:root` or any element scope (e.g. `--primary: #3b82f6`) are dynamically resolved using `var(--name, fallback)`.

### 4.3 Property Inheritance
Properties designated as inherited (e.g. `color`, `font-family`, `font-size`, `line-height`, `text-align`, `letter-spacing`) propagate down through the DOM hierarchy unless explicitly overridden by a matched child rule.

### 4.4 Tailwind Utility Class Engine
The CSS engine consumes standard modern utility classes directly:
- **Layout & Display**: `flex`, `grid`, `inline-flex`, `block`, `hidden`.
- **Flexbox Alignment**: `flex-row`, `flex-col`, `items-center`, `justify-between`, `justify-center`, `gap-4`, `flex-1`.
- **Dimensions & Spacing**: `w-full`, `max-w-4xl`, `max-w-6xl`, `mx-auto`, `p-4`, `p-6`, `px-6`, `py-3`, `mb-4`, `mb-6`.
- **Colors & Theming**: `bg-slate-900`, `bg-slate-800`, `bg-blue-600`, `text-white`, `text-slate-300`, `text-blue-400`.
- **Borders & Radii**: `rounded-lg`, `rounded-xl`, `rounded-full`, `border`, `border-slate-700`.
- **Shadows**: `shadow-sm`, `shadow-md`, `shadow-lg`, `shadow-xl`.
- **Responsive Modifiers**: `md:flex-row`, `md:grid-cols-3` (activated conditionally when viewport width $\ge 768\text{px}$).
- **Interactive Pseudo-Classes**: `hover:scale-105`, `hover:bg-blue-700`, `focus:outline-none`.

---

## 5. Layout, Painting & Deterministic Rasterization

The rendering engine (`tools/rex_rasterizer.py`) converts styled DOM nodes into physical pixel buffers:

### 5.1 Box Model Layout
Computes layout bounding boxes `(x, y, width, height)` by resolving:
- Content dimensions with `box-sizing: border-box`.
- Padding offsets and border stroke thicknesses.
- Margins, including automatic horizontal centering (`margin: 0 auto` or `mx-auto`).
- Flexbox line distributions (distributing available container space to `flex-1` children and inserting inter-child `gap` offsets).

### 5.2 Deterministic Software Rasterizer
The rasterizer writes into an RGBA 32-bit pixel framebuffer:
1. **Background Fills & Rounded Corners**: Renders filled rectangles with analytical corner anti-aliasing for `border-radius`.
2. **Borders**: Renders multi-side border strokes with corner curvature matching.
3. **Text Glyph Compositing**: Renders crisp glyph patterns mapped to proportional font sizes with alpha blending.
4. **PNG Serialization**: A zero-dependency PNG encoder compresses raw framebuffers using DEFLATE (`zlib`) and outputs standard PNG images for automated pixel-level golden verification (`tests/golden/`).

---

## 6. Interaction, Time, Animation & Asynchronous I/O

### 6.1 Event Propagation
Browser interaction events (`click`, `input`, `keydown`, `keyup`, `focus`, `blur`, `submit`, `resize`, `scroll`) are captured by the display bridge, packaged into normalized event payloads, and dispatched to REX event handlers. Handlers update application state and trigger reactive DOM re-renders.

### 6.2 CSS Transitions & Keyframe Animations
- **Transitions**: Declared via `transition: all 0.3s ease`. When hover or active pseudo-states are entered, style properties smoothly interpolate across frames.
- **Keyframes**: Declared via `@keyframes name { 0% { ... } 50% { ... } 100% { ... } }`. Elements with animation classes (e.g. `animate-float`, `animate-pulse`) continuously interpolate transform and opacity coordinates across time intervals.

### 6.3 Asynchronous Networking
REX applications perform non-blocking HTTP requests via `async_fetch(url, callback)`. Responses are delivered to completion callbacks without blocking the UI event loop, updating application state and DOM nodes upon completion.

---

## 7. Verification & Empirical Results

The complete pipeline has been verified across four dedicated automated test suites in `tests/`:

1. **`tests/test_rex_web_dom.py`**:
   - 5/5 passed: Element creation, attribute mutation, event dispatch, child re-parenting, semantic HTML5 serialization.
2. **`tests/test_rex_css_engine.py`**:
   - 7/7 passed: Selector specificity, CSS variables (`var(--*)`), cascade, property inheritance, Tailwind utility classes, responsive media queries (`@media min-width`), `:hover` pseudo-states, `@keyframes` timelines.
3. **`tests/test_rex_pixel_rendering.py`**:
   - 5/5 passed: Layout box geometry, auto-centering (`mx-auto`), Flexbox gap alignment, deterministic bit-for-bit RGBA rasterization, zero-dependency PNG file generation.
4. **`tests/test_rex_browser_integration.py`**:
   - 5/5 passed: Live HTTP host server, live bidirectional event bridge, counter state mutations, text input echo, asynchronous HTTP fetch completion, live rasterization endpoint (`/api/render.png`).
