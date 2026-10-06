# RWEB + RIX — MASTER BUILD PROMPT

**Workstream A:** RWEB — the language-native, browser-first web standard for Rubix
**Workstream B:** RIX — the modular package platform (npm / npx class) + the package registry website
**Companion spec:** [`WEB_STANDARD_SPEC.md`](rubix/docs/web/WEB_STANDARD_SPEC.md) (architecture & normative lowering tables)
**Status:** v1.1 — this is the working agreement and the north star. Read fully before writing any code.

---

## 0. THE ONE-LINE MISSION

> **If you can describe a website, you can build a website.**

We are **not** building another React or CSS replacement. We are building a **web programming language where making a website feels as easy as describing it** — easy enough for a **10-year-old** — while keeping a **precise, typed layer underneath** for serious developers.

A child writes

```text
card "Aurora"
  white
  round
  soft
  pop when hovered
```

and it becomes a real, standards-compliant website in **any browser** — no CSS, no HTML tags, no pointers, no types, no functions in sight.

**Two decisions are locked:**

1. **RWEB is written in `.bix`.** There is **no** `.rweb` extension. The kid layer and the precise layer are both `.bix` surfaces of the *same* language. (See §8.)
2. **`rix` is modular and behaves like `npm` / `npx`**, backed by a registry **website** where people upload and fetch packages. (See §18.)

---

## 1. THE TWO LAYERS (the central design)

Two surfaces, ONE pipeline. The simple layer **desugars 1:1** into the precise layer. Nothing exists only in one layer. **Both are `.bix`.**

```
┌───────────────────────────────────────────────────────────────┐
│  LAYER S — "DESCRIBE"   (kid English, indentation, in .bix)   │
│  website "Store"                                              │
│  page "/"                                                     │
│    card "Aurora"                                              │
│      white                                                    │
│      round                                                    │
│      pop when hovered                                         │
├───────────────────────────────────────────────────────────────┤
│  LAYER P — "SPECIFY"    (typed Rubix, precise, also .bix)     │
│  Card(app, "Aurora")                                          │
│  Background(app, WebColor.White)                              │
│  Radius(app, WebRadius.Lg)                                    │
│  OnHover(app, Motion.Pop, Feel.Springy)                       │
├───────────────────────────────────────────────────────────────┤
│  WEB IR (WebStyle / WebNode / WebApp) → resolve → HTML + CSS  │
└───────────────────────────────────────────────────────────────┘
```

- **Layer S is sugar.** It is a *front-end layer of `.bix`*, not a second language and not a second file type. Every S construct has exactly one P lowering (§6).
- **Layer P is the anchor.** It is typed, precise, and always available. It is what tests assert against.
- **You never need Layer P to get a great website.** You only drop to it when you want exact control.
- **Mixing is allowed inside one `.bix` file:** a `precise { … }` block may contain Type-P code for anything Layer S can't yet express.

---

## 2. HARD INVARIANTS (never violate, never "improve away")

1. **No CSS anywhere in code.** No `.css` strings, no `style="…"`, no `Style(app, str)`. A CSS literal in source is a **compile error**.
2. **No HTML tags in code.** The author never types `<div>`. Tags are chosen by the compiler from the construct kind.
3. **Not a wrapper.** RWEB is part of the language, parsed by the language, compiled by the language. It is not a preprocessor that spits out someone else's framework.
4. **Browser-first, standards-only.** Output is standard **HTML + CSS + DOM** that runs in **any** browser. We *use* the browser's existing rules (cascade, box-model, `@media`, `@keyframes`, flex, grid, `var()`). We re-implement nothing.
5. **One extension: `.bix`.** No `.rweb`, no `.rcs`, no `.css` as *authoring* formats. (`.rcs`/`.css` survive only as internal IR / debug output.)
6. **Two layers, one truth.** Layer S desugars to Layer P; Layer P writes `WebStyle`; `WebStyle` is the single source of truth for rendering.
7. **Kid-first, not kid-only.** Every default must look good with zero styling. Power is one step down, never removed.
8. **Deterministic.** Identical source ⇒ byte-identical HTML + CSS.
9. **Accessible by construction.** Every construct lowers to a semantic element + ARIA role automatically.
10. **Respect the compiler's limits.** ≤16 fields/struct, ≤32 variants/enum.
11. **Dual target preserved.** The same IR still lowers to the native REX rasterizer (browser is the default backend, not the only one).
12. **`rix` is modular and npm-grade.** No 1,600-line monolith. No fabricated docs. (See §18.)

---

## 3. LAYER S — "DESCRIBE" (the kid layer, in `.bix`)

### 3.1 Rules of the surface

- **Indentation defines structure.** A deeper line is a child of the line above it. No braces, no semicolons, no `fn`, no `let`, no `End()`.
- **First word = the construct.** `card`, `button`, `hero`, `grid`, `page`, `website`.
- **Quoted = content.** `"Aurora"` is text/title. `"/store"` is a link.
- **Bare words = styling & behaviour.** `white`, `round`, `soft`, `pop when hovered`.
- **Numbers are obvious.** `grid 3`, `padding medium`, `small`, `big`.
- **Filler words are accepted** so sentences read naturally: `add`, `a`, `with`, `make` are ignored scaffolding (`add a hero` ≡ `hero`; `with logo "store"` ≡ `logo "store"`).

### 3.2 Canonical example (Layer S, file `store/App.bix`)

```text
website "Aurora Store"
theme light
port 8080

page "/"
    navbar "Aurora Store"
        link "Home" "/"
        link "Projects" "/projects"

    hero "Buy the things"
        badge "New"
        text "Fast. Native. Accessible."
        button "Explore Store" "/store"

    cards 3
        card "Aurora Jacket"
            white
            round
            soft
            spacey
            hover pop
            text "Handmade in the north."
            button "Buy" "/buy"

    footer "Built natively with Webbix & Rubix."
```

### 3.3 Equally valid, more sentence-like

```text
website "Aurora Store"

make a page "/"

add a navbar
  with logo "Aurora Store"
  with link "Home" "/"

add a hero
  badge "New"
  title "Buy the things"
  say "Fast. Native. Accessible."
  button "Explore Store" "/store"

add 3 cards
  card "Aurora Jacket"
    white
    round
    soft
    pop when hovered
    say "Handmade in the north."
```

Both forms are **the same program**. `say` ≡ `text`; `make`/`add`/`a`/`with` are ignored.

---

## 4. THE VISUAL-WORD VOCABULARY (kids learn feelings, not CSS)

Kids never learn `border-radius` or `box-shadow`. They learn a tiny set of **visual words**. The compiler owns the mapping.

### 4.1 Look & feel words
| Word | Meaning for the child | Lowers to (P / CSS) |
|---|---|---|
| `pretty` | "make it look nice" (default) | soft radius + soft shadow + comfortable padding |
| `plain` | "no decoration" | no radius, no shadow, flat |
| `bright` | light surfaces, dark text | light surface + text tokens |
| `dark` | dark surfaces, light text | dark surface + text tokens |
| `soft` | gentle, muted | muted color + soft shadow |
| `loud` | bold, attention-grabbing | accent color + heavier weight |
| `calm` | quiet, low contrast | muted palette |

### 4.2 Size words (context-sensitive)
| Word | On text | On spacing/padding |
|---|---|---|
| `tiny` | `WebTextSize.Xs` | 4px |
| `small` | `WebTextSize.Sm` | 8px |
| `medium` | `WebTextSize.Md` | 16px |
| `big` | `WebTextSize.Xl` | 24px |
| `huge` | `WebTextSize.Xl3` | 40px |

### 4.3 Shape & depth words
| Word | Lowers to |
|---|---|
| `square` | `radius = None` |
| `round` | `radius = Lg` |
| `rounder` | `radius = Xl2` |
| `pill` | `radius = Full` |
| `flat` | `shadow = None` |
| `soft` | `shadow = Sm` |
| `lifted` | `shadow = Md` |
| `floating` | `shadow = Xl` |

### 4.4 Space words
| Word | Lowers to |
|---|---|
| `tight` | pad/gap = small |
| `cozy` | pad/gap = medium |
| `spacey` | pad/gap = big |
| `airy` | pad/gap = huge |

### 4.5 Colour words (theme tokens, never hex)
`white, black, gray, mint, sky, rose, amber, violet, indigo, red, green, blue`
→ `WebColor.White/Black/…` → `var(--color-…)`. Raw hex is **forbidden** in Layer S.

### 4.6 Motion words (verb × feel × trigger)
Grammar: `«verb» [when «trigger»] [«feel»]`  ·  shorthand `«trigger» «verb»` (e.g. `hover pop`).

| Verb | Feature |
|---|---|
| `pop` | scale burst |
| `slide` | directional move |
| `fade` | appear/disappear |
| `float` | gentle hover loop |
| `pulse` | heartbeat |
| `glow` | light up |
| `shake` | error wiggle |
| `spin` | rotate |
| `bounce` | bounce |

| Trigger | When |
|---|---|
| `when hovered` / `hover` | pointer over |
| `when clicked` / `click` | press |
| `when focused` / `focus` | keyboard/pointer focus |
| `when loaded` | on mount |
| `when in view` | scrolled into view |
| `when «state» is over «n»` | reactive condition |

| Feel | Timing |
|---|---|
| `snappy` | 120ms |
| `smooth` (default) | 250ms |
| `gentle` | 500ms |
| `springy` | 450ms, overshoot |
| `slow` | 900ms |

So `pop when hovered springy` ≡ `OnHover(app, Motion.Pop, Feel.Springy, 450)`.

---

## 5. THE FULL CONSTRUCT CATALOG (Layer S)

- **Structure:** `website "Name"` · `theme light|dark` · `port N` · `page "route" ["Title"]` · `navbar "brand"` · `logo "x"` · `link "Label" "url"` · `hero "headline"` · `badge "x"` · `title "x"` · `say "x"` (≡ `text`) · `button "Label" ["url"|state]` · `grid N` · `cards` / `N cards` · `card "Title"` · `section "Title"` · `columns N` · `row` · `col` · `list` · `item "x"` · `image "src" "alt"` · `form` · `input "placeholder"` · `footer "x"` · `divider` · `space N`
- **Styling:** any word from §4.1–4.5 on its own line under a construct.
- **Motion:** any §4.6 phrase: `pop when hovered`, `slide up when loaded smooth`, `pulse forever`, `glow when focused`.
- **Reactive/state:** `count starts at 0` · `when count is over 10, pulse` · `button "+1" adds to count` · `button "reset" sets count to 0`
- **Escape hatch (only sanctioned raw path):** `precise { … }` — a block of **Layer P** (typed Rubix) inside the same `.bix` file.

---

## 6. THE LOWERING TABLE (Layer S → Layer P) — NORMATIVE

Every Layer S construct has exactly one Layer P target. Tests assert it directly.

| Layer S | Layer P |
|---|---|
| `website "Store"` | `let app = App("Store")` |
| `theme light` | `Theme(app, WebTheme.Light)` |
| `port 8080` | `app.port = 8080` |
| `page "/" "Store"` | `Page(app, "/", "Store")` |
| `navbar "Store"` | `Navbar(app, "Store", …)` |
| `logo "x"` | `Logo(app, "x")` |
| `link "Home" "/"` | `Link(app, "Home", "/")` |
| `hero "…"` | `Hero(app, …)` |
| `badge "New"` | `Badge(app, "New")` |
| `title "x"` | `Title(app, "x")` |
| `say "x"` / `text "x"` | `Text(app, "x")` |
| `button "Shop" "/store"` | `ButtonNavigate(app, "Shop", "/store")` |
| `grid 3` | `Grid(app, 3)` |
| `cards 3` | `Grid(app, 3)` |
| `card "Aurora"` | `Card(app, "Aurora")` + `End(app)` auto-inserted at block end |
| `white` | `Background(app, WebColor.White)` |
| `round` | `Radius(app, WebRadius.Lg)` |
| `soft` | `Elevate(app, WebShadow.Sm)` |
| `spacey` | `Pad(app, 24)` + `Gap(app, 24)` |
| `hover pop` / `pop when hovered springy` | `OnHover(app, Motion.Pop, Feel.Springy, 450)` |
| `count starts at 0` | `State(app, "count", 0)` |
| `when count is over 10, pulse` | `WhenBinding(app, "count", Compare.Gt, 10, Motion.Pulse)` |

**Nesting rule:** S indentation ⇒ `push_parent` / `pop_parent` in [`ui.bix`](rubix/webbix/declarative/ui.bix:36). Every openable construct auto-pushes on open and auto-pops at the end of its indented block — the author never writes `End()`.

---

## 7. THE PIPELINE

```
.bix source
   │  (detect layer: first meaningful line is a RWEB keyword ⇒ Layer S)
   ▼
Layer S AST ──desugar (normative §6)──► Layer P AST
   │                                        │
   │                                        ▼
   │                              Web IR (WebStyle / WebNode / WebApp)
   │                                        │
   │                        ┌───────────────┴───────────────┐
   │                        ▼                               ▼
   │            build-time resolve (cascade)   build-time resolve (same)
   │                        ▼                               ▼
   │            BROWSER BACKEND                  NATIVE REX BACKEND
   │            HTML5 + :root vars               REX style opcodes
   │            + per-node .r<n> CSS             (deterministic rasterizer)
   │            + @keyframes
   ▼
`rix build` / `rix run` / `rix dev`
```

- Layer S is **only a front-end layer** of the same `.bix` source; everything downstream is shared.
- `--emit-css` is a **debug/inspection flag only** (to see the *derived* stylesheet), never an authoring workflow.
- The "middle" (cascade, defaults, theme, responsive) runs **once at build time**. The browser gets pre-resolved, single-class, `!important`-free rules.

---

## 8. FRONT-END DECISION — **LOCKED: `.bix`**

**Decision (settled):** RWEB is authored in **`.bix`**. There is **no `.rweb` extension.** Layer S and Layer P are both `.bix`.

### 8.1 How one extension hosts two layers

The `.bix` front-end **detects the layer per file**:

- **Layer S mode** — the first non-blank, non-comment line begins with a **RWEB keyword** (`website`, `page`, `theme`, `port`, `navbar`, `hero`, `grid`, `cards`, `card`, `section`, `form`, `footer`, …). The parser switches to indentation-based structure for the whole file.
- **Layer P mode** — otherwise (a `fn`/`let`/`struct`/`enum`/`use`/`include` header), which is today's grammar, **completely unchanged**.

This keeps the **existing language untouched** (no new dialect failures) and makes the kid layer purely additive.

### 8.2 Migration note (builder artifacts)

The builder already produced `.rweb` files. These are now **folded into `.bix`**:

| Old (`.rweb`) | New (`.bix`) |
|---|---|
| [`store/App.rweb`](store/App.rweb:1) | `store/App.bix` (Layer S) — replaces the old Layer-P `App.bix` |
| [`store/store.rweb`](store/store.rweb:1) | merged into `store/App.bix` (or `store/store.bix`) |
| [`store/tests/test_store_app.rweb`](store/tests/test_store_app.rweb:1) | `store/tests/test_store_app.bix` |

**Rule:** delete `.rweb`; the compiler must **reject `.rweb`** with a friendly message: *"`.rweb` isn't a Rubix file — rename it to `.bix`."*

### 8.3 Manifest (unchanged, but `.bix` entry)

[`store/webbix.pkg`](store/webbix.pkg:1) is the project manifest and points at the `.bix` entry:

```text
package {
    name: "store"
    version: "1.0.0"
    framework: "webbix"
    entry: "App.bix"
    target: "native"
    port: 8080
}
```

---

## 9. COMPILER & CAPACITY CONSTRAINTS

- Structs: **≤16 fields**. Enums: **≤32 variants**.
- Today: [`WebStyle`](rubix/webbix/ir/style.bix:13) = **16/16 FULL**; [`WebKind`](rubix/webbix/ir/types.bix:14) = **32/32 FULL**; [`WebApp`](rubix/webbix/ir/app.bix:39) = 11/16 (headroom).
- **Strategy:** parallel "extension banks" on `WebApp` (`WebStyleExt`, `WebMotion`) — see [`WEB_STANDARD_SPEC.md §11`](rubix/docs/web/WEB_STANDARD_SPEC.md:0). Do **not** break the 16-field limit.
- Enum overflow follows the documented `WEB_KIND_*` extended-registry pattern already in [`types.bix`](rubix/webbix/ir/types.bix:50).

---

## 10. OUTPUT CONTRACT

- **HTML:** semantic element per construct + ARIA role. `button` is a real `<button>`; `image` always has `alt`; landmarks (`nav`/`main`/`footer`) always present.
- **CSS:** reset + `:root` theme vars + only the `@keyframes` actually used + per-node `.r<n>` rules, ordered by ascending node id.
- **Forbidden in output:** `!important`; hand-written class names (`.card`, `.btn`); inline `style=""` blobs; hardcoded hex outside `:root`.
- **Reproducibility:** build twice → byte-identical artifacts. Tested guarantee.

---

## 11. ERROR MESSAGES FOR KIDS

- Speak in the child's words: *"I don't know the word 'shinny'. Did you mean **shiny**?"*
- Always point at the **line** and quote it.
- Always suggest a fix: *"`card` needs a title: write `card \"My title\"`."*
- Never expose compiler internals, error codes like `-49`, or stack traces.
- A correct program must **never** produce a warning.

---

## 12. ANTI-PATTERNS → AUTOMATIC FAIL

1. A CSS string literal in any `.bix` source.
2. `Style(app, …)`, `custom_css`, or `store_get_css()` left in place.
3. A hardcoded `class="card"` / `class="btn"` in the emitter.
4. An `!important` in emitted CSS.
5. A `WebStyle` field silently ignored by the renderer.
6. Motion written but not emitted.
7. A Layer S construct with no row in the §6 lowering table.
8. A `.rweb` (or `.rcs`/`.css`) **authoring** file.
9. A 1,600-line `rix` monolith, or registry code living in `rix/bin/rix`.
10. Fabricated status ("all green", "98/98") not backed by a runnable command an auditor can reproduce.

---

## 13. PHASED ROLLOUT & ACCEPTANCE GATES

| Phase | Deliverable | Gate (demonstrable) |
|---|---|---|
| **P0 — Wire the IR** | Renderer serializes `WebStyle` per node; remove the fixed class blob | Card/Button HTML carries `.r<n>`; CSS derives from IR; `style.animation` appears in output |
| **P1 — Layer P** | Typed setters; delete `Style(app,str)` + `custom_css` | A CSS string in source is a **compile error**; `store/` migrated |
| **P2 — Layer S in `.bix`** | `.bix` layer detection + Layer S parser + desugar (§6) | The §3.2 example compiles from `App.bix`; `.rweb` rejected |
| **P3 — Vocabulary** | Full §4 word tables → setters | Every word maps to exactly one typed setter |
| **P4 — Motion** | `WebMotion` bank; `@keyframes` emission | `pop when hovered springy` produces the exact rule |
| **P5 — Tokens** | `:root` vars from [`white.tokens.json`](library/theme/white.tokens.json:1) | Re-theming edits only the token file |
| **P6 — Retire `.rcs`/`.css`** | Demote `--emit-css` to debug; drop `.rcs` authoring | No doc instructs authoring `.rcs`/`.css` |
| **P7 — Native parity** | REX backend renders the same resolved style | Browser vs native visual parity on the reference app |
| **P8 — `rix` modular** | Split monolith into `rix/lib/`; npm/npx verbs | `rix --help` lists npm-parity verbs; no `NameError` (§18) |
| **P9 — Registry website** | Upload/fetch/search site + client end-to-end | `rix publish` → site → `rix add` round-trip passes |

---

## 14. VERIFICATION PROTOCOL

Drive the **real shipped binary** (`rubix_stage2` via mmap + ctypes), never a Python reimplementation; assert on exact bytes.

1. `test_desugar_table.py` — every §6 row: Layer S in ⇒ exact Layer P out.
2. `test_web_style_lowering.py` — known `WebStyle` ⇒ exact CSS declarations. (Builder has a `.bix` version at [`webbix/tests/test_web_style_lowering.bix`](webbix/tests/test_web_style_lowering.bix:1).)
3. `test_no_css_strings.py` — static scan; fail on any CSS literal or `Style(app,`.
4. `test_determinism.py` — build twice; assert byte-identical HTML+CSS.
5. `test_motion_emission.py` — `pop when hovered springy` ⇒ `.r<n>:hover{…}` + `@keyframes`.
6. `test_a11y_mapping.py` — each construct ⇒ correct element + role.
7. `test_kid_errors.py` — misspelled word ⇒ friendly, actionable message.
8. `test_rweb_rejected.py` — a `.rweb` file yields the rename message.
9. `test_store_migration.py` — migrated site serves HTML with zero `!important` and no hand-written classes.
10. **rix:** `test_rix_modular.py` (no logic in `rix/bin`), `test_rix_packaging.py`, `test_lockfile_determinism.py`, `test_registry_roundtrip.py`.

`make test` stays green; `make stage2` stays **byte-reproducible**.

---

## 15. WORKING AGREEMENT

- **Two roles.** A **builder** writes implementation code. An **auditor** verifies: reads the working tree, runs the real binary, reproduces claims independently, reports verdicts. The auditor does **not** author implementation code.
- **No claim without a runnable proof.** Every "fixed / passing / stable" statement cites a command and reproducible output.
- **Ground truth over transcripts.** Pasted transcripts are *claims to verify*, not facts.
- **Docs must not lie.** No fabricated phase completion, no invented test counts.
- **Small, gated steps.** Land one phase at a time; each phase passes its gate before the next begins.

---

## 16. CANONICAL REFERENCE — "Aurora card", all forms

```text
# Layer S — store/App.bix
website "Aurora Store"
theme light
page "/"
  cards 3
    card "Aurora"
      white
      round
      soft
      spacey
      hover pop springy
      text "Handmade in the north."
```

```bix
# Layer P — the desugared program (still .bix)
fn app_create(): *App {
    let app = App("Aurora Store")
    Theme(app, WebTheme.Light)
    Page(app, "/", "")
    Grid(app, 3)
    Card(app, "Aurora")
    Background(app, WebColor.White)
    Radius(app, WebRadius.Lg)
    Elevate(app, WebShadow.Sm)
    Pad(app, 24)
    Gap(app, 24)
    OnHover(app, Motion.Pop, Feel.Springy, 450)
    Text(app, "Handmade in the north.")
    End(app)   # closes Card
    End(app)   # closes Grid
    End(app)   # closes Page
    return app
}
```

```css
/* derived output — never authored */
:root{ --radius-lg:12px; --shadow-sm:0 1px 2px rgba(16,24,40,.06); }
.r4{ display:grid; grid-template-columns:repeat(3,1fr); gap:24px; }
.r5{ display:flex; flex-direction:column; background:#ffffff;
     border-radius:var(--radius-lg); box-shadow:var(--shadow-sm);
     padding:24px; }
.r5:hover{ animation:r-pop 450ms cubic-bezier(.34,1.56,.64,1); }
@keyframes r-pop{ 0%{transform:scale(1)} 60%{transform:scale(1.08)} 100%{transform:scale(1)} }
```

> A child wrote the first block. The browser ran the last block. That gap is the entire product.

---

## 17. NORTH STAR

**If you can describe a website, you can build a website.**

When a design choice is unclear, pick the option a 10-year-old would find friendlier — as long as the precise layer underneath stays exact, typed, standards-compliant, and verifiable.

---

# VOLUME B — RIX, THE PACKAGE PLATFORM

## 18. RIX = npm + npx, MODULAR, WITH A REGISTRY WEBSITE

### 18.1 Goal

`rix` is the toolbelt: `npm` (install / publish / search / lockfile) **plus** `npx` (run a package without installing) **plus** a **registry website** where anyone uploads packages and anyone fetches them.

**Today's reality (audited):** `rix/bin/rix` is a **1,635-line monolith**; `rubix/bin/rix` is a byte-identical duplicate; `rix/lib/` is **empty**; and `rix add` throws **`NameError: name 'RegistryClient' is not defined`** at [`rix/bin/rix:1028`](rix/bin/rix:1028). Docs in [`library/DECISIONS.md`](library/DECISIONS.md:96) falsely claim this is done. All of that is fixed by this volume.

### 18.2 Modular layout (the whole point)

```text
rix/
  bin/rix                  # THIN launcher only — argument parsing + dispatch. No logic.
  lib/rix/
    __init__.py            # version + re-exports
    cli.py                 # verb registry, arg parsing, help
    config.py              # .rixrc / global config, registry URL, auth token
    manifest.py            # read/write webbix.pkg + rix.toml (name, version, deps, entry)
    lockfile.py            # deterministic lockfile read/write + integrity pinning
    semver.py              # Version, ranges, satisfies(), max_satisfying()
    resolver.py            # DependencyResolver (transitive graph, conflict rules)
    registry.py            # RegistryClient (HTTP: fetch metadata, tarball, publish)
    cache.py               # ContentCache (sha256-keyed, ~/.rix/cache)
    integrity.py           # sha256 verify, safe tar extraction (path-traversal safe)
    signing.py             # pure-Python Ed25519 (no `cryptography` dependency)
    install.py             # install/add/remove/update orchestration
    runner.py              # `rix run`, `rix test`, `rix x <pkg>` (npx-class exec)
    build.py               # `rix build` (wire to the compiler + RWEB pipeline)
    local_registry.py      # server-side: index + db + package storage (dev)
    doctor.py              # environment checks
  templates/               # `rix create` scaffolds (RWEB in .bix!)
  tests/                   # rix's own tests
```

**Rule:** `rix/bin/rix` may contain **only** imports and a call to `cli.main()`. All behavior lives in `rix/lib/rix/`. Deleting `rubix/bin/rix` (the duplicate) is required — one implementation, one source of truth.

### 18.3 npm / npx parity

| npm | rix |
|---|---|
| `npm init` | `rix init` / `rix create` |
| `npm install` | `rix install` |
| `npm install <pkg>` / `npm i` | `rix add <pkg>` |
| `npm uninstall` | `rix remove <pkg>` |
| `npm update` | `rix update` |
| `npm ci` | `rix ci` |
| `npm run <script>` | `rix run <script>` |
| `npm test` | `rix test` |
| `npm publish` | `rix publish` |
| `npm search` | `rix search <term>` |
| `npm view <pkg>` | `rix info <pkg>` |
| `npm cache` | `rix cache <ls|clean|verify>` |
| `npm audit` | `rix audit` |
| `npm doctor` | `rix doctor` |
| `npx <pkg>` | `rix x <pkg>` (exec without installing) |
| — | `rix build` · `rix dev` · `rix compile` · `rix fmt` · `rix check` |

Every verb must (a) work offline against `local_registry`, (b) never raise a bare `NameError`, and (c) print an actionable error if a module is missing.

### 18.4 Registry website (upload & fetch)

The site already has a skeleton in [`library/`](library/README.md:1): [`api/src/main.bix`](library/api/src/main.bix:1) (routes are stubs), [`db/schema.sql`](library/db/schema.sql:1) (real: users, packages, versions with `integrity`/`signature`/`dependencies`, reports), [`theme/white.tokens.json`](library/theme/white.tokens.json:1), and a sample package.

**Required endpoints (RWEB/Webbix service):**

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/search?q=` | search the index |
| `GET` | `/api/v1/pkg/{name}` | package metadata + versions |
| `GET` | `/api/v1/pkg/{name}/{version}` | single version record |
| `GET` | `/api/v1/pkg/{name}/{version}/download` | tarball (integrity-checked) |
| `POST` | `/api/v1/publish` | upload a new version (auth + signature) |
| `POST` | `/api/v1/report` | report a package |
| `GET` | `/api/v1/keys/{owner}` | owner public key (for verification) |

**Storage topology:** Cloudflare holds the index/metadata; GitHub stores tarballs (cold). Authentication uses **pure-Python Ed25519 signatures** (`signing.py`) since `cryptography` is not installed — no new runtime dependency.

**End-to-end gate:** `rix publish` from `store/` → the site shows it → `rix add store` on another machine fetches, verifies the signature and sha256, and installs. That round-trip is the acceptance test.

### 18.5 Determinism & security (non-negotiable)

- **Lockfile is deterministic** — sorted, no timestamps, no platform-specific fields; byte-identical across runs.
- **Integrity always verified** — sha256 of the tarball, checked before extraction.
- **Safe extraction** — reject absolute paths, `..` traversal, symlinks escaping the root.
- **Signatures always verified** — a package whose signature fails to verify is never installed.
- **No fabricated status** — `rix doctor` reports *measured* facts, not hardcoded "ALL SYSTEMS HEALTHY".

### 18.6 rix verification (must be runnable)

- `test_rix_modular.py` — assert `rix/bin/rix` (excluding the launcher) has no logic; every verb resolves to a `rix/lib/rix/` module.
- `test_rix_packaging.py` — `rix init` → `rix add` → lockfile → `rix ci` reproduces exactly.
- `test_lockfile_determinism.py` — identical lockfile bytes across repeated resolves.
- `test_registry_roundtrip.py` — publish → search → fetch → verify against `local_registry.py`.
- `test_no_duplicate_rix.py` — `rubix/bin/rix` is gone; only one implementation exists.

---

## 19. OPEN QUESTIONS (answers recorded in a decisions log)

1. **Manifest format:** keep `webbix.pkg` (block syntax) and add `rix.toml`, or unify to one? *(Current: `webbix.pkg` exists in [`store/webbix.pkg`](store/webbix.pkg:1).)*
2. **Registry hostname & auth:** what is the canonical registry URL, and is publishing key-based only or key+token?
3. **Layer-S detection edge cases:** a `.bix` file starting with a comment then `card` — confirm comment-skipping rule.
4. **`precise { }` block:** confirm it may contain full Layer P (functions, structs), or setters only.
5. **`.rcs` legacy:** read-only importer, or hard cut?

---

## 20. DEFINITION OF DONE (v1.0)

A new user can:

1. Install `rix`.
2. `rix create my-site` → a `.bix` Layer-S scaffold.
3. Write the §3.2 example **in `.bix`** and `rix run` it → a real website in a browser, **zero CSS/HTML authored**.
4. `rix publish` it, and someone else `rix add`s it.
5. All §14 and §18.6 tests pass; `make stage2` is byte-reproducible; no doc claims anything unproven.
