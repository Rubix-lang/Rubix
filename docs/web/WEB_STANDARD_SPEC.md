# RWEB — Rubix Web Standard Specification

**Name:** **RWEB** = **Rubix Web** (the language-native web styling & UI standard)
**Status:** **v1.0-draft** (architecture + normative mapping tables)
**Supersedes:** RCS as a *user-facing* format — see §10
**Owner:** Rubix language + Webbix framework
**Backend (primary):** standard **HTML + CSS + DOM** (runs in any browser)
**Backend (secondary):** native REX rasterizer IR ("dual target", preserved)
**Companion docs:** [`rcs_specification.md`](rubix/docs/rcs/rcs_specification.md), [`browser_integration.md`](rubix/docs/rex/browser_integration.md), [`RUBIX_GAP_ANALYSIS.md`](rubix/docs/RUBIX_GAP_ANALYSIS.md)

---

## 0. Purpose of this document

This document specifies a **browser-first, language-native** web standard for Rubix.

The intent, stated by the language owner:

> *"Style should be **supporting the language**, not a wrapper. **No CSS in code.** The compiler uses the **existing rules of all browsers** — as if we were creating **a new W3C for Rubix** using all the pre-existing (W3C) standards."*

Concretely, this spec defines:

1. A **typed, string-free style surface** (`WebStyle`-based) authored *in Rubix*, not in CSS.
2. A **lowering contract** — a normative `Rubix construct → standard W3C CSS/DOM` mapping (the "new W3C").
3. The **retirement of `.rcs` and `.css` as user-facing artifacts**; they become internal IR at most.
4. The **elimination of `Style(app, css_string)`** and every "wrapper" layer.
5. Coexistence with the existing **native REX** rasterizer target (dual target preserved).

---

## 1. Executive summary & the core audit finding

### 1.1 What is already right

The IR is already "no HTML tags, no CSS strings":

- [`struct WebStyle`](rubix/webbix/ir/style.bix:13) — 16 typed fields (`layout`, `align`, `pad`, colors, `radius`, `shadow`, `animation`, …).
- [`struct WebNode`](rubix/webbix/ir/node.bix:15) — 16 typed fields including `style: WebStyle`.
- [`types.bix`](rubix/webbix/ir/types.bix:1) — typed enums (`WebKind`, `WebLayout`, `WebColor`, `WebTextSize`, `WebWeight`, `WebRadius`, `WebShadow`, `WebAnimation`, `WebRole`, …), each ≤ 32 variants.
- The declarative API ([`app.bix`](rubix/webbix/declarative/app.bix:123)) lets authors write `Card(app, "x")`, `Button(app, "Go", "count")` — no HTML, no CSS.

### 1.2 The blocker (this is the whole problem)

The renderer **ignores the IR style entirely** and substitutes a hardcoded theme:

- [`webbix_render_node()`](webbix/render/render.bix:158) emits **fixed class names** — `class="card"`, `class="btn"`, `class="hero"`, `class="headline"`, `class="grid-2"` — and **never reads `app.nodes[nid].style`**.
- [`webbix_render_css()`](webbix/render/render.bix:71) emits a **fixed CSS blob** keyed to exactly those class names (lines 73–139), including a hardcoded `@media` block.
- Result: `WebStyle` is written ([`web_app_add_node`](rubix/webbix/ir/app.bix:144), [`UiAnimate`](rubix/webbix/declarative/ui.bix:373)) but **never serialized**. Animations are **dead**: `style.animation` is set and never emitted.
- The only escape hatch is `custom_css` via [`Style(app, css: str)`](rubix/webbix/declarative/app.bix:113) — and the one real site, [`store/style.bix`](store/style.bix:6), abuses it with a wall of `!important` overrides.

**Conclusion:** the "language-native" styling model exists as data but is not wired to output. RWEB's central task is to **make the renderer a serializer of `WebStyle`** instead of a printer of fixed classes — and to define the normative mapping it serializes *to*.

### 1.3 What RWEB changes, in one line

> **`WebStyle`/`WebNode` become the single source of truth. The renderer lowers them to standard HTML + per-node CSS. No CSS is authored anywhere, ever. `.rcs`/`.css` stop being formats; `Style(app, str)` is deleted.**

---

## 2. Non-negotiable invariants

These mirror and extend [`rcs_specification.md §0`](rubix/docs/rcs/rcs_specification.md:17).

1. **Zero CSS in code.** No function in the language or framework may accept a CSS string. `Style(app, css)` is **removed** (compile error, not deprecation warning).
2. **Zero HTML in code.** Authors never type a tag. Tags are a *lowering target*, chosen by the compiler from `WebKind`.
3. **No second language.** RWEB is not a DSL you learn beside Rubix. Every construct is a **typed Rubix value** (enum / function). `.rcs` is not a format a user authors.
4. **Browser semantics preserved.** Output is standard CSS: real selectors, the W3C cascade, inheritance, the box model, `@media`, `@keyframes`, `@supports`, `var(--token)`. We *use* the browser's engine; we do not re-implement layout.
5. **Single source of truth.** `WebStyle` (and its extension banks, §11) are authoritative. The CSS is a *derived, disposable* artifact.
6. **Dual target.** The same IR still lowers to native REX IR for the rasterizer ([`render.bix`](webbix/render/render.bix:1) path). Browser is merely the default backend.
7. **Deterministic emission.** Identical IR ⇒ byte-identical HTML/CSS (ordering is defined in §8.3). This is required for the byte-level verification protocol (§15).
8. **Accessible by construction.** Every `WebKind` lowers to a semantic element + ARIA role (§12). No opt-in.
9. **Capacity-honest.** The compiler's 16-field struct / 32-variant enum limits are hard (§11). The design fits within them.

---

## 3. Layer architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ L0  LANGUAGE SURFACE  (Rubix .bix — typed, string-free)              │
│     Card(), Button(), Hero(), Grid() + Background(), Radius(),       │
│     Pad(), TextSize(), OnHover(), Motion.* …   → writes WebStyle     │
├──────────────────────────────────────────────────────────────────────┤
│ L1  WEB IR  (native, typed, in-memory)                               │
│     WebApp{ nodes:[WebNode;96] } → WebNode{ style:WebStyle, … }      │
├──────────────────────────────────────────────────────────────────────┤
│ L2  THE MIDDLE — build-time style RESOLUTION (per node)              │
│     role defaults ⊕ node-local style ⊕ theme tokens ⊕ breakpoints    │
│     → a ResolvedStyle record (the ONLY cascade that runs at build)   │
├──────────────────────────────────────────────────────────────────────┤
│ L3  LOWERING BACKENDS                                                │
│     (a) BROWSER  → HTML5 + :root vars + per-node .r<n> CSS rules     │
│     (b) NATIVE   → REX style opcodes for the rasterizer (dual)       │
├──────────────────────────────────────────────────────────────────────┤
│ L4  THEME TOKENS  (library/theme/white.tokens.json → CSS vars)       │
└──────────────────────────────────────────────────────────────────────┘
```

The key relocation versus the old design: **the "middle" (cascade) is executed at build time inside the language**, not at runtime by the browser. This is exactly the RCS §0.2 promise ("The Middle Is Deleted") — but now it happens over `WebStyle`, not over a separate `.rcs` language.

---

## 4. L0 — The language-native style surface

### 4.1 Rule

Every styling function is a **typed setter on the current node**. No strings, no CSS. It reuses the existing auto-parenting model ([`Ui`](rubix/webbix/declarative/ui.bix:15): `push_parent` / `current_parent` so the caller never sees node IDs).

### 4.2 Target developer surface (grounded in existing call style)

```bix
fn app_create(): *App {
    let app = App("store")
    Theme(app, WebTheme.Light)
    Tokens(app, "white")                 # binds library/theme/white.tokens.json → CSS vars

    Page(app, "/", "Store")
      Navbar(app, "store", "", "Home", "/", "Projects", "/projects")
      Hero(app, "New", "Buy the things", "Fast. Native. Accessible.", "Shop", "/store")

      Grid(app, 3)
        Card(app, "Aurora")
          Background(app, WebColor.White)
          Radius(app, WebRadius.Lg)
          Elevate(app, WebShadow.Soft)
          Pad(app, 20)
          OnHover(app, Motion.Pop, Feel.Springy, 250)
          Text(app, "Handmade in the north.")
        End(app)
      End(app)
    End(app)
    return app
}
```

Compare the **forbidden** pattern being deleted ([`store/App.bix:15`](store/App.bix:15)):

```bix
Style(app, store_get_css())   # ← DELETED: this is CSS-as-a-string in code
```

### 4.3 Motion is language, not a file

RCS's verb/feel/trigger vocabulary (§3 of the RCS spec) is **promoted into the language** as enums + one function:

| RCS word (old `.rcs`) | RWEB construct |
|---|---|
| `pop on hover` | `OnHover(app, Motion.Pop, Feel.Springy, 250)` |
| `slide up on load` | `OnLoad(app, Motion.SlideUp, Feel.Smooth, 400)` |
| `pulse accent forever` | `OnMount(app, Motion.Pulse, Feel.Gentle, -1)` (`-1` = infinite) |
| `glow on focus` | `OnFocus(app, Motion.Glow, Feel.Snappy, 150)` |
| `when count > 10` | `WhenBinding(app, "count", Compare.Gt, 10, Motion.Pulse)` |

`Motion`, `Feel`, `Trigger` are typed enums (see §11 for where their numeric values live, since `WebStyle` is full).

**Cold-path property setters** (a growing, curated list — each maps 1:1 to a standard CSS property per §7):

```bix
Background(app, WebColor.Primary)     # background
TextColor(app, WebColor.White)        # color
TextSize(app, WebTextSize.Xl)         # font-size
Weight(app, WebWeight.Bold)           # font-weight
Pad(app, 16)                          # padding
Gap(app, 12)                          # gap
Radius(app, WebRadius.Md)             # border-radius
Elevate(app, WebShadow.Md)            # box-shadow
AlignItems(app, WebAlign.Center)      # align-items
JustifyItems(app, WebAlign.Between)   # justify-content
Columns(app, 3)                       # grid-template-columns
Row(app) / Col(app, 8)                # display:flex; flex-direction
```

No setters exist that take a `str` of CSS. That is the enforcement of invariant §2.1.

---

## 5. L1 — Web IR (source of truth)

### 5.1 Existing shape (unchanged)

- [`WebStyle`](rubix/webbix/ir/style.bix:13) — 16 fields, all `i64` enum values.
- [`WebNode`](rubix/webbix/ir/node.bix:15) — 16 fields; carries `style: WebStyle`, `kind`, `text`, `link_url`, `state_binding`, etc.
- [`WebApp`](rubix/webbix/ir/app.bix:39) — 11 fields; `nodes: [WebNode; 96]`, `state_keys/vals: [i64;32]`, `theme`, `custom_css`.

### 5.2 The one IR change this spec mandates

`custom_css: str` is **removed from `WebApp`** (invariant §2.1). Its intended role — *project-specific styling* — is filled by the typed setters, which write `style`/extension banks. Removing it is the mechanical guarantee that no CSS string can enter the pipeline.

### 5.3 What is currently broken (must be fixed by RWEB)

| Location | Problem |
|---|---|
| [`render.bix:250`](webbix/render/render.bix:250) | `Card` emits `class="card"`, ignores `style.radius/shadow/bg_color` |
| [`render.bix:213`](webbix/render/render.bix:213) | `Button` emits `class="btn"`, ignores `style.bg_color` |
| [`render.bix:373`](rubix/webbix/declarative/ui.bix:373) | `UiAnimate` writes `style.animation`; never emitted |
| [`render.bix:71`](webbix/render/render.bix:71) | Fixed CSS blob; not derived from any IR |
| [`app.bix:113`](rubix/webbix/declarative/app.bix:113) | `Style(app, css)` — the CSS-string hole |

---

## 6. L2 — The Middle: build-time style resolution

Resolution runs **once, at build time**, producing a `ResolvedStyle` per node. It is the *only* cascade and it is fully deterministic.

**Precedence (low → high):**

1. **Reset** — the normative browser reset (equivalent to `*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}`), emitted once (§8).
2. **Kind/role defaults** — `WebKind.Card` implies `radius=Lg, shadow=Sm, bg=surface, pad=20` unless overridden. This is where the old hardcoded `.card {}` blob is re-expressed as *data*, not text.
3. **Theme tokens** — token values for the active `WebTheme` (L4), referenced as `var(--…)`.
4. **Node-local style** — whatever the L0 setters wrote into `WebStyle`.
5. **Responsive overrides** — `is_responsive` + breakpoint bank (§11) produce `@media` rules.

The resolver emits a **`ResolvedStyle`** — an ordered list of `(property_id, value_id)` pairs — which §7 turns into CSS declarations. This is the "single cascade engine" of RCS §0.2, now living over `WebStyle`.

**Why build-time:** the browser receives already-resolved, already-specific, per-node declarations. No runtime style recalculation, no `!important`, no specificity wars.

---

## 7. L3 — The Lowering Contract (the "new W3C for Rubix")

This is the **normative** core of RWEB: the mapping from Rubix values to standard W3C CSS. It is normative so that both backends (§8, §9) and all tooling agree.

### 7.1 Color → CSS custom property

Tokens are the bridge to [`white.tokens.json`](library/theme/white.tokens.json:6). Emitted to `:root` (§8.2).

| `WebColor` | CSS |
|---|---|
| `Default` / `Current` | `currentColor` |
| `Primary` | `var(--color-primary)` |
| `Secondary` | `var(--color-secondary)` |
| `Accent` | `var(--color-accent)` |
| `Success/Warning/Danger/Info` | `var(--color-…)` |
| `Muted` | `var(--color-muted)` |
| `White` / `Black` | `#ffffff` / `#000000` |
| `Gray50…Gray900` | `var(--gray-50)…var(--gray-900)` |
| `Transparent` | `transparent` |

> Proposed additions (needs enum work, §11): `Surface`, `Border`, `Text` — the alias words RCS used. Until then, map `surface→--color-surface` via tokens only.

### 7.2 Container / layout

| Construct | CSS |
|---|---|
| `WebLayout.Column` | `display:flex;flex-direction:column` |
| `WebLayout.Row` | `display:flex;flex-direction:row` |
| `WebLayout.Grid` + `columns=N` | `display:grid;grid-template-columns:repeat(N,1fr)` |
| `WebLayout.Stack` | `display:flex;flex-direction:column` |
| `WebLayout.Flex` | `display:flex` |
| `WebLayout.Absolute/Fixed/Sticky` | `position:absolute/fixed/sticky` |
| `WebAlign.Start/Center/End/Stretch/Baseline` | `align-items:flex-start/center/flex-end/stretch/baseline` |
| `WebAlign.Between/Around/Evenly` | `justify-content:space-between/space-around/space-evenly` |
| `gap` (i64) | `gap:<n>px` |
| `padding_x/padding_y` | `padding:<py>px <px>px` |

### 7.3 Typography

| Construct | CSS |
|---|---|
| `WebTextSize.Xs…Xl6` | `font-size:var(--fs-xs)…` (or fixed px if tokens absent) |
| `WebWeight.Thin…Black` | `font-weight:100…900` |
| `text_color` | `color:<color>` |

### 7.4 Surface

| Construct | CSS |
|---|---|
| `radius` (`WebRadius.None…Full`) | `border-radius:0/6/10/12/16/24/9999px` |
| `shadow` (`WebShadow.None…Xl2/Inner/Glow`) | `box-shadow:none/var(--shadow-sm)…/inset …/0 0 24px var(--color-accent)` |
| `bg_color` | `background:<color>` |
| `border_color` + border width (§11) | `border:1px solid <color>` |

### 7.5 Motion (`WebAnimation` × `WebEasing` × `WebAnimTrigger`)

Motion lowers to **`@keyframes` + `animation` / `transition`**. The RCS feel-word table ([`rcs_specification.md §3.2`](rubix/docs/rcs/rcs_specification.md:76)) becomes the normative timing table:

| `Feel` | duration | curve |
|---|---|---|
| `Instant` | 0ms | `linear` |
| `Snappy` | 120ms | `cubic-bezier(0.2,0,0,1)` |
| `Smooth` | 250ms | `cubic-bezier(0.4,0,0.2,1)` |
| `Gentle` | 500ms | `ease-in-out` |
| `Slow` | 900ms | `ease-in-out` |
| `Springy` | 450ms | `cubic-bezier(0.34,1.56,0.64,1)` |

| `WebAnimation` | emitted `@keyframes` |
|---|---|
| `FadeIn` / `FadeOut` | `opacity 0→1` / `1→0` |
| `SlideUp/Down/Left/Right` | `transform: translate*(±20px)→0` |
| `ScaleUp` ("pop") | `transform: scale(1.08)→1` (spring settle) |
| `Bounce` | keyframed `translateY` oscillation |
| `Pulse` | `scale` heartbeat |
| `Spin` | `rotate 0→360deg` |
| `Glow` | `box-shadow` luminescence via `var(--color-accent)` |
| `Float` | vertical hover loop |
| `Shimmer` | background-position sweep |

**Trigger → CSS surface:**

| `WebAnimTrigger` | Where the animation attaches |
|---|---|
| `Mount` | base rule `animation: …` |
| `Hover` | `.r<n>:hover { animation/transition … }` |
| `Focus` / `FocusVisible` | `.r<n>:focus` / `:focus-visible` |
| `Click` | `.r<n>:active` |
| `Visible` | `.r<n>[data-in-view]` (toggled by IntersectionObserver) |
| `StateChange` | `.r<n>.is-<state>` (toggled by the reactive runtime) |
| `Continuous` | `animation-iteration-count: infinite` |

The `when <condition>` runtime contract ([`rcs_specification.md §3.3.1`](rubix/docs/rcs/rcs_specification.md:99)) is preserved verbatim: the build emits a `/* when: … */` annotation and the Webbix runtime toggles `is-<state>`.

### 7.6 Kind → HTML + ARIA (accessibility is the mapping, not a feature)

| `WebKind` | Element | Role |
|---|---|---|
| `Page` | `<main>` | — |
| `Nav` / `NavLink` | `<nav>` / `<a>` | — |
| `Hero` | `<section>` | `region` |
| `Title` / `Heading` | `<h1>` / `<h2…h6>` | `heading` |
| `Text` / `Paragraph` | `<p>` | — |
| `Button` | `<button>` (or `<a>` if `link_url`) | `button` |
| `Card` / `ProjectCard` | `<article>` | `article` |
| `Badge` | `<span>` | — |
| `Form` / `Label` / `Input` | `<form>` / `<label>` / `<input>` | `form` / `textbox` |
| `List` / `ListItem` | `<ul>` / `<li>` | `list` / `listitem` |
| `Image` | `<img alt="…">` | `img` |
| `Modal` | `<dialog>` | `dialog` |
| `Tabs`/`TabPanel` | `<div role="tablist">` / `role="tabpanel"` | from `WebRole` |
| `Table` | `<table>` | — |
| `EscapeHatch` | author-specified raw element (the only sanctioned raw path) | — |

The existing [`WebRole`](rubix/webbix/ir/types.bix:351) enum exists for exactly this and should be wired.

---

## 8. L3a — Browser backend emission

### 8.1 Document skeleton (emitted, never authored)

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>…</title>
  <meta name="description" content="…">
  <style>
    /* 1. reset */
    /* 2. :root tokens (from L4) */
    /* 3. keyframes (only those referenced) */
    /* 4. per-node rules, ascending node id */
  </style>
</head>
<body> …nodes… </body>
</html>
```

### 8.2 Theme tokens → CSS custom properties

`Tokens(app, "white")` maps [`white.tokens.json`](library/theme/white.tokens.json:1) into `:root`:

```css
:root{
  --color-primary:#4f46e5; --radius-lg:12px;
  --shadow-sm:0 1px 2px rgba(16,24,40,.06);
  --fs-xl:24px; /* … */
}
```

Tokens are the *only* place raw hex lives; `WebStyle` refers to semantic names, so re-theming is a token swap, not a code edit.

### 8.3 Per-node scoping & determinism

- Each node gets a stable class **`.r<node-id>`** (e.g. `.r7`). This is the RWEB analogue of the old `.card`/`.btn` classes — but **derived**, not hardcoded.
- Rules are emitted **in ascending node-id order**, properties in the fixed canonical order of §7. This makes output **byte-reproducible** (invariant §2.7) and diff-stable.
- **No `!important`** is ever emitted. Specificity is trivially single-class; the build-time cascade (§6) already resolved conflicts. This deletes the entire [`store/style.bix`](store/style.bix:6) `!important` wall.

### 8.4 Example lowering

IR: `Card` node #7 with `radius=Lg, shadow=Soft, bg=White, hover=Pop(Springy,250)`.

Emitted:

```html
<article class="r7">…</article>
```
```css
.r7{
  display:flex; flex-direction:column;
  background:#ffffff; border-radius:var(--radius-lg);
  box-shadow:var(--shadow-sm); padding:20px;
}
.r7:hover{ animation:r-pop 250ms cubic-bezier(.34,1.56,.64,1); }
@keyframes r-pop{ 0%{transform:scale(1)} 60%{transform:scale(1.08)} 100%{transform:scale(1)} }
```

---

## 9. L3b — Native REX backend (dual target preserved)

The same `ResolvedStyle` is consumed by the native path: [`webbix_render_document`](webbix/render/render.bix:290)'s sibling for REX bakes resolved declarations into **REX style opcodes** for the deterministic rasterizer ([`browser_integration.md §5`](rubix/docs/rex/browser_integration.md:140)). The `WebStyle`-to-opcode table is a separate normative table but shares §7's semantics, so a project renders identically in a browser and natively.

Selection is explicit: `Backend(app, WebBackend.Browser | WebBackend.Native | WebBackend.Both)`.

---

## 10. Retirement of `.rcs` and `.css` as user artifacts

| Artifact | Today | After RWEB |
|---|---|---|
| `.rcs` files | User-authored styling language | **Not authored.** The verb/feel vocabulary is absorbed into `Motion`/`Feel`/`Trigger` enums (§4.3) |
| `.css` files | Output; `Style(app, css)` | **Never authored, never committed.** In-memory emission only |
| [`rubix/rcs/`](rubix/rcs/parser.bix:1) modules | A whole parallel language | **Retained as internal IR helpers** (lexer/resolver reused to power `rcs_parse_inline`), then **retired** as `WebStyle` coverage completes |
| [`main.bix` `.rcs` dispatch](rubix/compiler/main.bix:21886) | `.rcs → .css` | **`--emit-css` becomes a debug flag** (inspect the *derived* stylesheet); the `.rcs` *source* dispatch is removed in a later phase |
| [`store/style.bix`](store/style.bix:1), [`store/style.css`](store/style.css) | Hand-written CSS strings | **Deleted**; styling moves to typed L0 setters |

**Inline syntax** ([`rcs_parse_inline`](rubix/rcs/parser.bix:169), currently dead in production) is either (a) wired as sugar that desugars to the equivalent typed setters, or (b) retired in favour of the setter API. Decision pending (§16).

---

## 11. Capacity & compiler constraints (must be respected)

The compiler enforces **≤16 fields per struct** and **≤32 variants per enum**. Current usage:

- `WebStyle` = **16/16 — FULL.** Cannot add one field.
- `WebKind` = **32/32 — FULL** (already spilling to `WEB_KIND_*` int constants, [types.bix:50](rubix/webbix/ir/types.bix:50)).
- `WebApp` = **11/16 — 5 free.**

### 11.1 Strategy: parallel "extension banks" (recommended)

Rather than fight the 16-field limit, add **parallel per-node banks** to `WebApp` (which has headroom):

```bix
struct WebStyleExt {      # 16 fields — the cold/long-tail style properties
    depth: i64, opacity: i64, border_width: i64, position: i64,
    line_height: i64, letter_spacing: i64, min_width: i64, max_width: i64,
    overflow: i64, cursor: i64, variant: i64, z_index: i64,
    aspect: i64, transform_x: i64, transform_y: i64, flags: i64
}
struct WebMotion {        # 8 fields — motion needs trigger+easing+timing
    animation: i64, trigger: i64, easing: i64,
    duration_ms: i64, delay_ms: i64, iterations: i64,
    direction: i64, stagger_ms: i64
}
```

`WebApp` gains **2 fields** (`style_ext: [WebStyleExt;96]`, `motion: [WebMotion;96]`) → 13/16. Within limit. Access is by node id (same index as `nodes[]`).

### 11.2 Boolean bit-packing

`WebStyle.is_responsive` can be repurposed as a **bit flag word** for tightly-clustered toggles (e.g. `IS_HIDDEN`, `IS_STICKY`, `FULL_WIDTH`) with normative bit assignments. Costs no fields.

### 11.3 Enum overflow (extended registry)

Continue the established [`WEB_KIND_*`](rubix/webbix/ir/types.bix:50) pattern: a normative **extended-kind registry** with a documented `(int → HTML element, ARIA role)` row per id. Same approach for any enum that reaches 32.

### 11.4 Raising the limit (P2 option)

Formally raising the compiler's struct-field / enum-variant ceilings is possible but touches the whole compiler; it is **P2**, and RWEB must not *depend* on it.

---

## 12. Accessibility & semantics by construction

Because `WebKind → element + role` is a **normative table** (§7.6), every RWEB app is accessible without extra author effort: `Button` is a real `<button>`, `Image` always has `alt` (from `desc`), `Nav`/`Main` landmarks are emitted, and focus triggers map to `:focus-visible`. This closes the a11y gaps implicitly.

---

## 13. Migration of the `store/` prototype (first proof)

Target replacement of the pattern in [`store/App.bix`](store/App.bix:12):

```bix
# BEFORE
Style(app, store_get_css())            # CSS string + !important wall

# AFTER
Tokens(app, "white")
Theme(app, WebTheme.Light)
# styling expressed as typed setters on each component (§4.2)
```

- **Delete** [`store/style.bix`](store/style.bix:1) and [`store/style.css`](store/style.css).
- Replace the `!important` overrides with `WebStyle` setters + token references.
- Gate: the served HTML must contain **zero** `!important`, **zero** hand-written class names, and **per-node `.r<n>` rules** derived from the IR.

---

## 14. Phased rollout & acceptance gates

| Phase | Deliverable | Gate |
|---|---|---|
| **P0 — Wire the IR** | `render.bix` serializes `WebStyle` per node; delete fixed class blob | Card/Button HTML carries `.r<n>`; CSS derives from IR; `style.animation` observable in output |
| **P1 — Delete CSS strings** | Remove `Style(app,str)` + `custom_css`; add typed setters | Compiling any `Style(app, "…")` is a **compile error**; `store/` migrated |
| **P2 — Tokens** | `Tokens(app, name)` → `:root` vars from `white.tokens.json` | Re-theming changes only the token file |
| **P3 — Extension banks** | `WebStyleExt` + `WebMotion` (§11) | Motion (trigger/easing/duration) emission passes byte-checks |
| **P4 — Retire RCS as a format** | `.rcs` source authoring removed; `--emit-css` demoted to debug | No user-facing doc instructs authoring `.rcs` |
| **P5 — Native parity** | REX backend renders the same `ResolvedStyle` | Browser vs native visual parity on a reference app |
| **P6 — Compiler limit raise** | (Optional) raise 16-field/32-variant ceilings | Only if P3 proves constraining |

---

## 15. Verification protocol

Follow the proven pattern of [`test_rcs_binary_integration.py`](rubix/tests/test_rcs_binary_integration.py:15): drive the **real shipped binary** (`rubix_stage2`, mmap+ctypes), never a Python reimplementation, and assert on raw bytes.

Required new tests:

1. `test_web_style_lowering.py` — build an app with known `WebStyle`; assert emitted CSS contains the exact expected declarations (`.r<n>{border-radius:var(--radius-lg);…}`).
2. `test_no_css_strings.py` — static scan: fail if any `.bix` passes a CSS-shaped literal to `Style(`; assert `custom_css` no longer exists in `WebApp`.
3. `test_determinism.py` — build twice; assert **byte-identical** HTML+CSS (§8.3).
4. `test_a11y_mapping.py` — for each `WebKind`, assert the correct element+role (§7.6).
5. `test_motion_emission.py` — `OnHover(Motion.Pop, Feel.Springy, 250)` ⇒ `.r<n>:hover{animation:r-pop 250ms cubic-bezier(.34,1.56,.64,1)}` + matching `@keyframes`.
6. `test_store_migration.py` — the migrated `store/` serves HTML with zero `!important` and no hand-written classes.

`make test` must stay green and the `stage2` artifact **byte-reproducible**, as verified previously.

---

## 16. Open questions (record answers in a decisions log)

1. **Inline sugar:** wire [`rcs_parse_inline`](rubix/rcs/parser.bix:169) as setter sugar, or drop it entirely?
2. **Color enum:** add `Surface/Border/Text` variants (needs a free enum slot) or route purely through tokens?
3. **Per-node vs utility classes:** `.r<n>` (chosen: deterministic, diff-stable) vs precomputed utility classes (smaller CSS). RWEB picks `.r<n>`; revisit at P6.
4. **`EscapeHatch`:** confirm it is the *only* sanctioned raw-HTML path, and how it is gated.
5. **`.rcs` legacy:** keep a read-only importer for existing `.rcs` files, or a hard cut?

---

## Appendix A — Deleted surface (what disappears)

```bix
fn Style(app: *App, css: str): void        # DELETED  (app.bix:113)
custom_css: str                            # DELETED from WebApp  (ir/app.bix:52)
fn store_get_css(): str                    # DELETED  (store/style.bix:6)
webbix_render_css(theme, lb, rb): str      # REPLACED by IR-driven emitter (render.bix:71)
webbix_css_rule(sel, props, lb, rb): str   # REPURPOSED: joins declarations only (render.bix:28)
```

## Appendix B — Added surface (what appears)

```bix
Tokens(app, name)                          # :root CSS vars from the theme token file
Background/TextColor/TextSize/Weight/…     # typed L0 setters → WebStyle
Radius/Elevate/Pad/Gap/Columns/…           # typed L0 setters → WebStyle
OnHover/OnLoad/OnFocus/OnMount/WhenBinding # typed motion → WebMotion bank
struct WebStyleExt { … }                   # 16-field cold-style bank
struct WebMotion   { … }                   # 8-field motion bank
fn web_resolve_style(app)                  # build-time cascade (the Middle)
fn web_emit_css(app)                       # IR → standard W3C CSS (browser backend)
fn web_emit_rex_style(app)                 # IR → REX style opcodes (native backend)
```

---

*RWEB is the language's own web standard: authored in typed Rubix, lowered to the browsers' existing standards, with `.rcs`/`.css` demoted to derived internals.*
