# RCS — Rubix Control Style Language Specification

**Name:** **RCS** = **Rubix Control Style**  
**Handle:** `"RCS"`  
**Extension:** **`.rcs`** (canonical lowercase; `.Rcs` and `.RCS` resolve identically)  
**MIME Type:** `text/rcs`  
**Compiler Home:** `rubix/rcs/` (pure native Rubix `.bix` modules)  
**Toolchain CLI:** `rix rcs <file.rcs>`  
**Dual Target:** (1) Native REX Rasterizer IR (pre-baked) and (2) Standard W3C CSS  

---

## 1. Executive Summary & Design Invariants

Rubix Control Style (RCS) is a word-based, human-friendly styling and motion language designed for the Rubix ecosystem. It provides the expressiveness of modern CSS and animation engines without mathematical curves, cubic-beziers, or runtime cascade overhead.

### §0. Non-Negotiable Invariants
1. **Browser Semantics Preserved:** Standard selectors (`tag`, `.class`, `#id`, descendant, child, `:hover`, `:focus`), specificity 4-tuples, cascade resolution, inheritance, and `var(--custom, fallback)` semantics are strictly maintained.
2. **The Middle Is Deleted:** Traditional browsers resolve cascades and selector matching every frame. RCS resolves selectors, cascade priority, specificity, and motion opcodes **once at build time** inside `rix`. Runtime executes pure rendering with zero style calculation.
3. **Zero Math in Motion:** A learner never types a bezier curve, matrix transform, or keyframe percentage. Motion is declared using **verbs** (`pop`, `slide`, `pulse`), **feel-words** (`smooth`, `springy`, `gentle`), and **triggers** (`on hover`, `on load`). All mathematical curves are encapsulated within the toolchain compiler.
4. **Single Cascade Engine:** Pure self-hosted Rubix implementation in [`rubix/rcs/`](file:///home/bishwaxyz/translator/rubix/rcs/). Lexing, parsing, specificity scoring, and `WebStyle` slot mutation compile directly via `rubix_stage2` at native memory speeds with zero Python runtime dependency.
5. **First-Class Inline Syntax:** Bracketed inline styling (`card "Hero" [radius=12, pop on hover]`) lowers into the exact same IR and opcodes as external `.rcs` sheets.
6. **Dual Target Delivery:** Every `.rcs` source compiles both to pre-baked render IR for REX and to standard W3C CSS for browser execution.

---

## 2. Static Style Surface & Alias Dictionary

RCS allows learners to write natural, concise words while offering an escape hatch to raw W3C CSS declarations.

### 2.1 Property Aliases
| RCS Word | Standard CSS Property | Example |
|---|---|---|
| `bg` | `background` | `bg: surface;` |
| `radius` / `rounded` | `border-radius` | `radius: lg;` |
| `size` / `text-size` | `font-size` | `size: xl;` |
| `weight` / `text-weight` | `font-weight` | `weight: bold;` |
| `shadow` / `elevation` | `box-shadow` | `shadow: soft;` |
| `p` / `pad` | `padding` | `pad: 16px;` |
| `m` | `margin` | `m: 8px;` |
| `center` | `display: flex; align-items: center; justify-content: center;` | `center;` |
| `row` | `display: flex; flex-direction: row;` | `row;` |
| `col` | `display: flex; flex-direction: column;` | `col;` |
| `grid` | `display: grid;` | `grid;` |

### 2.2 Theme Token Aliases
RCS links directly to [`library/theme/white.tokens.json`](file:///home/bishwaxyz/translator/library/theme/white.tokens.json):

* **Radius:** `sm` (6px), `md` (10px), `lg` (12px), `xl` (16px), `pill` / `full` (9999px).
* **Typography Sizes:** `xs` (12px), `sm` (13px), `md` (15px), `lg` (18px), `xl` (24px), `2xl` (32px), `3xl` (44px).
* **Font Weights:** `light` (300), `normal` (400), `semibold` (600), `bold` (700).
* **Shadows:** `soft` / `sm` (`0 1px 2px rgba(16, 24, 40, 0.06)`), `md` (`0 4px 8px -2px rgba(16, 24, 40, 0.08)`), `lg` / `strong` (`0 12px 24px -6px rgba(16, 24, 40, 0.10)`).

---

## 3. Declarative Motion Engine

Animations are expressed through three orthogonal dimensions:
$$\text{Motion} = \text{Verb} \times \text{Trigger} \times \text{Feel}$$

### 3.1 Motion Verbs
* `fade`: Opacity transition (`in` or `out`).
* `slide`: Directional translation (`up`, `down`, `left`, `right`) with optional distance (`slide up 20`).
* `pop`: Micro-scale burst (`scale(1.08)`) with spring settle.
* `zoom`: Smooth scaling in or out.
* `bounce`: Vertical oscillation with gravity spring.
* `spin`: Full 360-degree rotation.
* `flip`: 3D card flip around Y-axis.
* `tilt`: Dynamic 2.5D perspective tilt toward pointer.
* `shake`: Horizontal error tremor.
* `pulse`: Gentle rhythmic scale heartbeat.
* `glow`: Radial box-shadow luminescence using accent color.
* `float`: Weightless vertical hover loop.
* `orbit`: 3D perspective revolution.

### 3.2 Feel-Words (Curvature & Timing)
Learners express sensations rather than numerical beziers:
| Feel Word | Duration | Curve Semantics | CSS Equivalent |
|---|---|---|---|
| `instant` | 0ms | Linear | `linear` |
| `snappy` | 120ms | Deceleration curve | `cubic-bezier(0.2, 0, 0, 1)` |
| `smooth` | 250ms | Standard ease-out (Default) | `cubic-bezier(0.4, 0, 0.2, 1)` |
| `gentle` | 500ms | Natural ease-in-out | `ease-in-out` |
| `slow` | 900ms | Cinematic deceleration | `ease-in-out` |
| `springy` / `bouncy` | 450ms | Spring overshoot | `cubic-bezier(0.34, 1.56, 0.64, 1)` |

### 3.3 Triggers & Conditions
* `on load`: Triggers immediately upon element mounting.
* `on hover`: Triggers while cursor hovers over target (`:hover`).
* `on focus`: Triggers when element gains keyboard/pointer focus (`:focus`).
* `on focus-visible`: Triggers on keyboard navigation focus (`:focus-visible`).
* `on focus-within`: Triggers when element or child has focus (`:focus-within`).
* `on click` / `on active`: Micro-interaction upon actuation (`:active`).
* `on checked`: Triggers when input is checked (`:checked`).
* `on disabled`: Triggers when input is disabled (`:disabled`).
* `on in-view` / `on scroll into view`: Intersection observer trigger (`[data-in-view]`).
* `when <condition>`: Reactive state trigger (e.g. `when count > 10`).

#### 3.3.1 Runtime Contract for `when <condition>`
The `when <condition>` clause provides declarative, reactive conditional styling bridging compile-time CSS emission with the Webbix reactive state machine:

1. **Build-Time Compilation:**
   - The RCS compiler extracts the conditional expression `<condition>` from the selector rule header (e.g. `.winner when count > 10`).
   - The selector is normalized to its canonical CSS target (e.g. `.winner`), ensuring standard CSS syntax validity.
   - The emitted stylesheet outputs an explicit structural annotation comment immediately preceding the rule:
     ```css
     /* when: count > 10 */
     .winner {
       background: var(--accent, #6366F1);
       animation: rcs-pop 250ms cubic-bezier(0.4, 0, 0.2, 1);
     }
     ```
2. **Webbix Reactive Runtime Lifecycle (`webbix/runtime`):**
   - The Webbix reactive engine observes component signals referenced in the condition expression (e.g. `count`).
   - On state mutations, the runtime evaluates the expression. When `true`, it applies the state class to the corresponding DOM node (`classList.add("winner")`).
   - When `false`, the runtime detaches the class (`classList.remove("winner")`).
3. **Pure CSS Alternatives:**
   - For conditions that can be evaluated entirely within the DOM without JavaScript execution, developers are encouraged to use native pseudo-classes or attribute selectors:
     - Form state: `.btn on disabled`, `.checkbox on checked`.
     - Visibility/Scroll: `.card on in-view` (toggled via IntersectionObserver setting `[data-in-view]`).
     - Structural/Parent queries: `:has(...)` combinators.

### 3.4 Iteration & Chaining
* `forever`: Loop infinitely.
* `once`: Play once and remain in final state.
* `repeat N`: Repeat exactly $N$ times.
* `after <delay>`: Add offset (e.g. `after 200ms` or `after 0.5s`).
* `then`: Sequential animation chaining.

---

## 4. Declarative 3D Tier

RCS avoids raw projection matrices and Euler angle transformations by providing declarative 3D constructs:
* `depth <N>`: Maps to Z-axis perspective elevation (`translateZ(N * 20px)`).
* `tilt`: Applies 2.5D perspective rotate on hover (`perspective(1000px) rotateX(4deg) rotateY(-4deg)`).
* `flip 3d`: Applies `transform-style: preserve-3d` and rotates 180 degrees.
* `orbit gentle forever`: 3D orbit revolution about the central scene axis.

---

## 5. Inline Syntax (First-Class)

RCS can be authored directly inside component declarations:
```bix
card "collections" [radius=12, pop on hover, slide up on load]
button "Buy Now" [bg=accent, glow on focus]
```
The inline parser extracts properties and motion declarations, passing them through the identical resolver pipeline without runtime divergence.

---

## 6. Build Pipeline & CLI Usage

### Compiling a Sheet
```bash
# Verify and inspect sheet
rix rcs counter.rcs

# Emit standard W3C CSS
rix rcs counter.rcs --emit-css -o dist/counter.css
```

### Build-Time Baking & Compiler Dispatch
1. **Toolchain Integration (`rix`):** When running `rix build`, RCS automatically checks for adjacent `.rcs` files (`app.rcs`, `style.rcs`, or `<name>.rcs`), computing and baking styles directly into the REX binary IR.
2. **Native Compiler Dispatch (`rubix_stage2`):** The pure native Rubix compiler (`rubix/compiler/main.bix`) directly dispatches `.rcs` files into CSS outputs, and automatically compiles adjacent `.rcs` stylesheets alongside `.bix` source files during ELF/binary generation:
```bash
# Direct native compilation from .rcs to .css via rubix_stage2:
rubix_stage2 counter.rcs dist/counter.css
```

---

## 7. Example: Kid Counter (`counter.rcs`)

```rcss
card {
    bg: surface;
    radius: lg;
    shadow: soft;
    center;
    slide up on load;
    pop on hover;
}

button {
    bg: accent;
    color: white;
    radius: md;
    glow accent on focus;
    pop on click;
}

button:hover {
    bg: #1D4ED8;
    pop;
}

.count-display {
    color: text;
    size: xl;
    weight: bold;
}

.winner when count > 10 {
    pulse accent forever;
}
```
*Zero numbers in styling, zero beziers, pure human words.*
