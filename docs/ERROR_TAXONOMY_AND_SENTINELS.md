# Rubix & REX Error Taxonomy and Internal Sentinel Registry

This document establishes the canonical error code taxonomy, diagnostic reporting contracts, and internal sentinel value policies across the Rubix compiler, Webbix web subsystem, and REX virtual machine ecosystem.

---

## 1. Architecture & Diagnostic Contract

All compiler diagnostics are reported through a single source of truth:
- **Canonical Implementation**: `compiler/middle/warnings.bix`
- **Driver Integration**: Included via `use compiler.middle.warnings;` in `compiler/main.bix`.

The diagnostic pipeline ensures:
1. Every known reachable error code produces a specific, human-actionable message.
2. Every error has a clear categorization:
   - `CATEGORY_LEXER = 1` (`LEXER`)
   - `CATEGORY_PARSER = 2` (`PARSER`)
   - `CATEGORY_SEMANTIC = 3` (`SEMANTIC`)
   - `CATEGORY_REX = 4` (`REX`)
   - `CATEGORY_INTERNAL = 5` (`INTERNAL`)
3. The fallback message `"unspecified compilation error"` is reserved strictly for unclassified, unexpected system anomalies.
4. Internal sentinel values (`-999`, `-999999999`) never leak into the user-facing diagnostic layer.

---

## 2. Documented Compiler Error Taxonomy

### Lexer & Syntax Errors (-1 .. -39)
| Code | Identifier / Concept | Category | Canonical Diagnostic Message |
|------|----------------------|----------|------------------------------|
| `-1` | Syntax error | PARSER | `syntax error` |
| `-2` | Undefined variable | SEMANTIC | `undefined variable` |
| `-3` | Undefined function | SEMANTIC | `undefined function` |
| `-4` | Redefined symbol | SEMANTIC | `redefinition of symbol` |
| `-5` | Break outside loop | SEMANTIC | `break outside loop` |
| `-6` | Continue outside loop | SEMANTIC | `continue outside loop` |
| `-37`| Unknown / unresolved type | SEMANTIC | `unknown type` |

### Semantic & Type Errors (-40 .. -60)
*Prior to clearance pass, codes -40..-45 were collapsed into generic "semantic type mismatch". They are now split into explicit, distinct diagnostics:*
| Code | Identifier | Category | Canonical Diagnostic Message |
|------|------------|----------|------------------------------|
| `-40` | `ERR_TYPE_ASSIGN` | SEMANTIC | `assignment type mismatch` |
| `-41` | `ERR_TYPE_RETURN` | SEMANTIC | `return type mismatch` |
| `-42` | `ERR_TYPE_ARG` | SEMANTIC | `argument type mismatch` |
| `-43` | `ERR_TYPE_BINOP` | SEMANTIC | `invalid binary operation` |
| `-44` | `ERR_TYPE_PTR` | SEMANTIC | `invalid pointer operation` |
| `-45` | `ERR_TYPE_VOID` | SEMANTIC | `void expression used where a value is required` |
| `-46` | Struct member access error | SEMANTIC | `invalid struct member access` |
| `-50` | Redefined struct | SEMANTIC | `redefinition of struct` |
| `-51` | Unknown struct field | SEMANTIC | `unknown struct field` |

### Out of Memory & AST Allocation (-100)
| Code | Identifier | Category | Canonical Diagnostic Message |
|------|------------|----------|------------------------------|
| `-100` | `ERR_AST_ALLOC_FAIL` | INTERNAL | `AST allocation failed - out of memory` |

Emitted when dynamic AST node pool exhaustion occurs in `compiler/frontend/ast_parser.bix`.

---

## 3. REX Subsystem Error Taxonomy (-101 .. -112)

The REX binary format, validator, interpreter, and VM define a unified error namespace:

| Code | Symbolic Constant | Category | Component | Canonical Diagnostic Message |
|------|-------------------|----------|-----------|------------------------------|
| `-101` | `REX_ERR_BAD_MAGIC` | REX | Decoder / Loader | `invalid REX binary magic header` |
| `-102` | `REX_ERR_VERSION` | REX | Decoder / Loader | `unsupported REX binary version` |
| `-103` | `REX_ERR_TRUNCATED` | REX | Decoder / Loader | `truncated REX binary or premature EOF` |
| `-104` | `REX_ERR_SECTION_LEN` | REX | Decoder / Loader | `invalid REX section length` |
| `-105` | `REX_ERR_DUP_SECTION` | REX | Decoder / Loader | `duplicate REX section encountered` |
| `-106` | `REX_ERR_BAD_FUNC` | REX | Validator | `invalid REX function index` |
| `-107` | `REX_ERR_BAD_REG` | REX | Validator / VM | `invalid REX value or local register slot` |
| `-108` | `REX_ERR_BAD_OPCODE` | REX | Validator / VM | `invalid or unknown REX instruction opcode` |
| `-109` | `REX_ERR_BAD_BRANCH` | REX | Validator | `invalid REX branch target offset` |
| `-110` | `REX_ERR_TYPE_MISMATCH` | REX | Validator / Interp | `REX type mismatch or signature violation` |
| `-111` | `REX_ERR_NO_MAIN` | REX | Loader / VM | `missing main function export in REX module` |
| `-112` | `REX_ERR_CALL_ARITY` | REX | Validator / Interp | `function call arity mismatch in REX invocation` |

---

## 4. Internal Sentinels & Runtime Execution Traps

Unlike compiler error codes above, sentinel values are internal control-flow markers or runtime guard triggers. They are outside the user-facing compiler error taxonomy.

### 4.1. `SENTINEL_NOT_FOUND = -999999999`
- **Definition**: Constant defined in `compiler/common/constants.bix`.
- **Purpose**: Serves as a "sentinel null" or "key not found" indicator for fixed-size integer return values in compiler lookup tables.
- **Origins**:
  - `compiler/frontend/symtab.bix`: Returned by symbol table lookup when an identifier is not present in the current lexical scope.
  - `compiler/frontend/uir_frontend.bix`: Returned by enum member lookups and type alias table queries when a symbol cannot be resolved.
  - `compiler/frontend/parser.bix`: Used to differentiate between zero constants (`0`) and missing symbol table entries.
- **User-Facing**: **NO**.
- **Propagation Policy**:
  - Sentinels are strictly local to front-end resolution functions.
  - Callers check `if (cval != -999999999)`:
    - If found: the actual value is processed.
    - If not found: caller decides whether to try parent scopes, fallback resolvers, or emit a real semantic error (such as `-2 ERR_UNDEFINED_VAR` or `-37 ERR_UNKNOWN_TYPE`).
  - **Invariant**: `-999999999` must NEVER be passed to `diag_report_error` or returned as the compiler process exit code.

### 4.2. `REX_TRAP_CYCLE_LIMIT = -999`
- **Definition**: Constant defined in `compiler/common/constants.bix`.
- **Purpose**: Runtime safety trap protecting the REX Virtual Machine (`compiler/rex/rex_vm.bix`) from infinite loops, runaway recursion, or unmetered compute exhaustion.
- **Origin**:
  - `compiler/rex/rex_vm.bix`: At the VM execution loop termination, `if steps >= 10000000 { return -999; }`.
- **User-Facing**: **NO** (at compile time). At runtime in host harnesses (e.g. testing harnesses or browser servers), `-999` is caught to indicate cycle ceiling reached.
- **Propagation Policy**:
  - Returned from `rex_vm_execute` to indicate abnormal termination due to instruction budget exhaustion.
  - Distinct from bytecode format errors (`-101..-112`), representing a dynamic operational limit rather than a static binary or validation fault.
  - Should never reach the compiler's static diagnostic reporter.

---

## 5. Verification & Testing

Every code and sentinel contract in this document is validated by:
- `tests/test_diagnostic_matrix.py`: Verifies all 20 error codes (-37, -40..-45, -100, -101..-112) against the compiler's diagnostic output and verifies absence of `"unspecified compilation error"`.
- `tests/test_warnings_unit.py`: Exercises middle-end diagnostic generation.
- Full 93+ test suite baseline ensuring compiler self-hosting and zero regressions.
