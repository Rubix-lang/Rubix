# RCS — Port From Python To A Real Rubix Compiling Method

**Document:** Architecture Plan & Autonomous Build Prompt  
**Status:** Approved for Implementation  
**Target:** Native Rubix Compiler Pipeline (`rubix/rcs/*.bix` compiled directly by `rubix_stage2`)  
**Baseline Reference:** Validated Python Implementation in [`rix/lib/rcs/`](file:///home/bishwaxyz/translator/rix/lib/rcs/)  

---

## PART 1 — THE PORTING PLAN

### §0. Strategic Rationale & Invariants
The Python implementation in `rix/lib/rcs/` established and proved the language semantics, test battery (Suite 105), feel-word mappings, and dual-target emission. 
Porting RCS to native Rubix (`.bix`) achieves:
1. **Self-Hosting Independence:** The Rubix toolchain (`rubix_stage2`) compiles and bakes `.rcs` files into native ELF/REX binaries without requiring a host Python interpreter.
2. **Sub-Millisecond Build Times:** Lexing, parsing, cascade resolution, and opcode generation run directly in native machine code, operating at memory-bandwidth speeds on zero-allocation token spans.
3. **Zero-Copy Node Mutation:** Instead of serializing JSON or traversing Python dicts, the native compiler operates directly on [`WebNode`](file:///home/bishwaxyz/translator/rubix/webbix/ir/node.bix:18) and [`WebStyle`](file:///home/bishwaxyz/translator/rubix/webbix/ir/style.bix:13) structs in contiguous memory buffers.

**Invariants that must never break:**
* Zero math in user code: Feel-words (`smooth`, `snappy`, `gentle`, `springy`) map to compile-time curves.
* Browser rules preserved: Specificity 4-tuple, cascade precedence, and CSS variable substitution remain identical.
* Single cascade engine: Reuses Webbix node traversal and specificity math.
* Dual target: Emits baked native REX IR nodes and W3C CSS text.

---

### §1. Target Module Structure in Native Rubix

```
rubix/rcs/
├── lexer.bix       # Native zero-copy tokenizer (Token, TokenType, span tracking)
├── ast.bix         # RCS Rule, Selector, Declaration, and Motion AST structs
├── parser.bix      # Recursive descent parser for .rcs files & inline [...] blocks
├── tokens.bix      # Embedded White Theme token dictionary (:root default)
├── motion.bix      # Feel-word table, motion opcodes, and curve interpolation
├── resolver.bix    # Cascade, specificity (4-tuple), and WebStyle resolution
├── bake.bix        # Direct in-memory mutation of WebNode trees
└── emit_css.bix    # Native W3C CSS string emitter for browser targets
```

---

### §2. Data Structures & Memory Layout in `.bix`

#### Token & AST Layout (`lexer.bix`, `ast.bix`)
```rubix
enum RcsTokenType {
    Ident,
    Selector,
    Colon,
    Semicolon,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    String,
    Number,
    Dimension,
    Color,
    Operator,
    Eof
}

struct RcsToken {
    kind: RcsTokenType,
    start: *u8,
    len: i64,
    line: i64,
    col: i64,
}

struct RcsDeclaration {
    prop_name: str,
    prop_val: str,
}

struct RcsMotionDecl {
    verb: str,
    direction: str,
    amount: i64,
    target_color: str,
    trigger: str,
    feel: str,
    repeat: i64,
    delay_ms: i64,
    state_condition: str,
}

struct RcsRule {
    selectors: *str,
    selector_count: i64,
    declarations: *RcsDeclaration,
    decl_count: i64,
    motion_rules: *RcsMotionDecl,
    motion_count: i64,
    state_condition: str,
}
```

---

### §3. Direct Mutation of Webbix IR (`bake.bix`)
The native port stamps directly into the Webbix application tree:
```rubix
fn rcs_bake_node(app: *WebApp, node_id: i64, rule: *RcsRule): void {
    let node = &app.nodes[node_id];
    
    # Map declarations directly into WebStyle fields
    for let i = 0; i < rule.decl_count; i++ {
        let decl = rule.declarations[i];
        if str_eq(decl.prop_name, "border-radius") {
            node.style.radius = rcs_parse_radius(decl.prop_val);
        } else if str_eq(decl.prop_name, "box-shadow") {
            node.style.shadow = rcs_parse_shadow(decl.prop_val);
        } else if str_eq(decl.prop_name, "background") {
            node.style.bg_color = decl.prop_val;
        }
    }
}
```

---

### §4. Phases & Verification Gates

| Phase | Milestone | Acceptance Gate |
|---|---|---|
| **Phase 1** | Native Lexer & Parser (`rubix/rcs/lexer.bix`, `parser.bix`) | Correctly tokenizes and parses all 20 test sheets from `test_rcs_engine.py`. |
| **Phase 2** | Native Motion Engine (`rubix/rcs/motion.bix`) | `pop on hover`, `slide up on load`, and `pulse forever` compile to byte opcodes. |
| **Phase 3** | Resolver & In-Memory Bake (`rubix/rcs/resolver.bix`, `bake.bix`) | `card` node in `counter.bix` has `WebStyle` stamped with zero Python involvement. |
| **Phase 4** | Native CSS Emitter (`rubix/rcs/emit_css.bix`) | Byte-for-byte or semantic parity with `emit_css.py` output. |
| **Phase 5** | Self-Hosting Stage 2 Compiler Hook | `rubix_stage2` compiles `.bix` + `.rcs` directly into executable ELF binaries. |

---

## PART 2 — THE BUILD PROMPT

> **TASK — Port Rubix Control Style (RCS) from Python to Native Rubix (`.bix`).**
>
> **Identity & Scope**
> - Home: Native compiler modules in **`rubix/rcs/`** (`lexer.bix`, `parser.bix`, `motion.bix`, `resolver.bix`, `bake.bix`, `emit_css.bix`).
> - Specification: Follow [`rcs_specification.md`](file:///home/bishwaxyz/translator/rubix/docs/rcs/rcs_specification.md).
> - Golden Reference: Match the behavior of [`rix/lib/rcs/`](file:///home/bishwaxyz/translator/rix/lib/rcs/).
>
> **Hard Requirements**
> 1. **Pure Rubix Implementation:** All modules must be authored in `.bix` and compile cleanly with `rubix_stage2`.
> 2. **Zero Runtime Middle:** Lower selectors and cascade directly into [`WebNode`](file:///home/bishwaxyz/translator/rubix/webbix/ir/node.bix:18) style slots during compilation.
> 3. **Feel-Words Without Math:** Pre-calculate curve opcodes inside `motion.bix`. Zero beziers exposed to the user.
> 4. **Embedded Theme Tokens:** Embed [`white.tokens.json`](file:///home/bishwaxyz/translator/library/theme/white.tokens.json) defaults directly in `tokens.bix` for `:root` fallback.
> 5. **Dual Target:** Provide native functions `rcs_bake_tree(app: *WebApp)` and `rcs_emit_css(sheet: *RcsSheet): str`.
>
> **Acceptance Criteria**
> - Run `counter.rcs` through the native compiler: verify memory mutation of `WebStyle`.
> - All 105 regression suites remain 100% green (`105/105 passed cleanly`).
> - Zero compiler warnings or memory safety issues on 64-bit Linux.
