# Rubix — Consolidated Bug & Feature Gap Analysis

**Purpose:** Collect every verified defect and missing capability identified across the
review sessions, then lay out what Rubix needs to reach parity with established
languages. Every bug below was reproduced with a real command on 2026-10-03.

**Evidence baseline:** `run_all_regressions.py` → **87/91 suites passed** (10.82s).

---

## PART A — VERIFIED BUGS

### A1. Regression suite: 4 failing suites

Command:
```
cd rubix && python3 run_all_regressions.py
```
Result tail:
```
REGRESSION BATTERY RESULTS: 87/91 suites passed cleanly (10.82s)
FAILED SUITES:
  - tests/test_ergonomics_error_op.py
  - tests/test_disasm.py
  - tests/test_differential_fuzzing.py
  - tests/test_r2_independent_check.py
```

---

### BUG-1 — Dangling dependency: `scratch/independent_decoder.py` missing
- **Affects:** [`tests/test_r2_independent_check.py`](../tests/test_r2_independent_check.py)
- **Symptom:**
  ```
  File "tests/test_r2_independent_check.py", line 25, in <module>
      import independent_decoder
  ModuleNotFoundError: No module named 'independent_decoder'
  ```
- **Root cause:** The test imports a helper that was **never committed**. `rubix/scratch/` contains
  no `.py` files at all. Git confirms it was never tracked:
  ```
  git ls-files | grep -i independent_decoder   # (empty)
  git log --all -- rubix/scratch/independent_decoder.py   # (empty)
  ```
- **Impact:** **High.** This is the R2a layer of the multi-architecture proof — the very evidence
  answering the "your multi-arch is fake" criticism. That layer can no longer run.
- **Fix:** Re-create `scratch/independent_decoder.py` (`disassemble_arm64`, `disassemble_riscv`)
  and commit it; or retire R2a and rely on the QEMU path (R2c), which passes.

### BUG-2 — Dangling dependency: `scratch/disasm.py` missing
- **Affects:** [`tests/test_disasm.py`](../tests/test_disasm.py)
- **Symptom:**
  ```
  ModuleNotFoundError: No module named 'scratch.disasm'
  ```
- **Root cause:** Same class of bug — helper never committed.
- **Impact:** Medium. Loses independent x86-64/ARM64/RISC-V disassembly coverage.
- **Fix:** Commit `scratch/disasm.py`, or remove the test and fold its coverage into the QEMU suite.

### BUG-3 — Dangling dependency: `scratch/fuzz_gen.py` missing
- **Affects:** [`tests/test_differential_fuzzing.py`](../tests/test_differential_fuzzing.py)
- **Symptom:** The suite *runs and passes* all 50 differential programs, then dies at the end:
  ```
  Summary: 50/50 differential programs executed identically across all architectures.
    [PASS] All fuzzed programs match bit-for-bit across x86-64, ARM64, and RISC-V 64
  Traceback (most recent call last):
    File ".../tests/test_differential_fuzzing.py", line 161, in main
      import scratch.fuzz_gen as fuzz_gen
  ModuleNotFoundError: No module named 'scratch.fuzz_gen'
  ```
- **Root cause:** Late `import` of an uncommitted generator module.
- **Impact:** Medium. The core cross-arch equivalence proof passes, but the suite exits non-zero,
  so CI reports failure and masks the success.
- **Fix:** Commit `scratch/fuzz_gen.py`, or move the import to the top and guard it.

### BUG-4 — Non-zero exit from a passing suite (harness/exit-code bug)
- **Affects:** [`tests/test_ergonomics_error_op.py`](../tests/test_ergonomics_error_op.py)
- **Symptom:**
  ```
  rubix: error[-41] [SEMANTIC]: semantic type mismatch
    file: /tmp/tmpvnn5_3lt.bix
  ...
  SUMMARY: 5/5 passed
  ```
  All 5 assertions pass, yet the runner marks the suite **FAIL**.
- **Root cause:** A negative-case compilation emits `error[-41]` which sets a non-zero process
  exit code. The harness treats *any* non-zero exit as failure, so a deliberately-rejected
  compile is misread as a broken test.
- **Impact:** Medium. False negatives erode trust in the suite; real failures hide among them.
- **Fix:** Teach the harness to distinguish "expected rejection" from "unexpected error"
  (e.g. a per-test `expect_error` flag), or have the suite explicitly return success.

### BUG-5 — `yugant-portfolio` test battery fails to compile (`-37`)
- **Affects:** [`yugant-portfolio/tests/test_portfolio.bix`](../../yugant-portfolio/tests/test_portfolio.bix)
- **Symptom:**
  ```
  ./rix/bin/rix test yugant-portfolio/tests/test_portfolio.bix
  rubix: error[-37] [SEMANTIC]: unspecified compilation error
    file: scratch/tmpccaypu4r.bix
  [FAIL] yugant-portfolio/tests/test_portfolio.bix -> Error code: -37
  ```
- **Root cause:** Semantic compilation failure inside the test battery. Note that
  `src/App.bix` **does** compile fine (104,058 bytes), so the fault is specific to the test file.
- **Impact:** High (for the example project). The flagship example ships unable to self-verify.
- **Fix:** Bisect the test file to isolate the expression triggering `-37`.

### BUG-6 — Error code `-37` has no message ("unspecified compilation error")
- **Affects:** Compiler diagnostics ([`compiler/main.bix`](../compiler/main.bix))
- **Symptom:** `error[-37] [SEMANTIC]: unspecified compilation error` — no file line, no column,
  no cause.
- **Root cause:** Diagnostic taxonomy gap; `-37` is emitted without a specific message.
- **Impact:** Medium. Undebuggable for users; forces source-level bisection.
- **Fix:** Assign `-37` a concrete message and emit file:line:col like other diagnostics.

### BUG-7 — `rix create` scaffold produces a site that never serves
- **Affects:** [`rix/bin/rix`](../../rix/bin/rix) `cmd_create`
- **Symptom:** A freshly scaffolded project's `main()` is:
  ```
  fn main(): i64 {
      let app = app_create();
      return Build(app);        # builds — but never listens
  }
  ```
  So `rix create foo && rix serve foo` prints the banner but **returns nothing on the port**.
- **Root cause:** The template omits `Serve(app, port)`. The working portfolio succeeds only
  because someone hand-added `return Serve(app, APP_PORT);`
  ([`src/App.bix:37`](../../yugant-portfolio/src/App.bix)).
- **Impact:** High. "Create a website with Rubix" does not work out of the box.
- **Fix:** Wire `return Serve(app, <port>);` into the scaffold's `main()`.

### BUG-8 — Python REX host serves a hardcoded app, not the project it runs in
- **Affects:** [`tools/rex_browser_host.py`](../tools/rex_browser_host.py)
- **Symptom:** Launched from `/tmp` (unrelated cwd), the host still returns the Rubix showcase:
  ```
  cwd of host process: /tmp
  served page title contains 'Rubix REX': True
  ```
- **Root cause:** The host never reads a project dir, `.bix` file, or cwd. The app is built in
  Python memory (`build_showcase_app()`), so the working directory is irrelevant.
- **Impact:** High (as a hosting layer). It cannot host an arbitrary project at all.
- **Fix:** Make the host load and serve the target project, or clearly scope it as a demo and
  route real hosting through `rix serve`.

### BUG-9 — Python REX host shares one global state across every visitor, forever
- **Affects:** [`tools/rex_browser_host.py`](../tools/rex_browser_host.py)
- **Symptom:** Client A clicks increment 5×; brand-new clients B and C immediately see `5`:
  ```
  CLIENT A sees state: 0
  CLIENT A clicked 5x
  CLIENT B (brand new connection) sees state: 5
  CLIENT C (brand new connection) sees state: 5
  ```
- **Root cause:** A single `self.state` dict and one `self.nodes` DOM per process. No sessions,
  cookies, or per-client scoping. Handlers mutate shared DOM nodes via `set_text`.
- **Impact:** High. One visitor's action rewrites the page served to everyone — a data-leak-grade
  defect for any real multi-user site.
- **Fix:** Introduce per-session state/DOM (session id ↔ app instance).

### BUG-10 — "Zero ELF" claim contradicts the shipped ELF writer
- **Affects:** [`compiler/main.bix:5`](../compiler/main.bix) vs [`compiler/packaging/elf.bix`](../compiler/packaging/elf.bix)
- **Symptom:** The banner states `Zero GCC, zero Clang, zero LLVM, zero 'as', zero 'ld', zero text
  assembly, zero ELF.` Yet `compiler/packaging/elf.bix` emits a full ELF64 (with `.symtab`,
  `.strtab`, `.shstrtab`), and tests assert `e_machine == 183 / 243`.
- **Root cause:** Claim-vs-code mismatch (likely "zero external ld" was intended).
- **Impact:** Low (docs), but undermines credibility of the "zero everything" statement.
- **Fix:** Reword to "zero external `ld`/`as`; own ELF writer" and keep the ELF code.

### BUG-11 — No import gate in the test runner
- **Affects:** [`run_all_regressions.py`](../run_all_regressions.py)
- **Symptom:** Three suites burn a full run before dying on `ModuleNotFoundError` at import/end.
- **Root cause:** No pre-flight check that every suite can be imported before running.
- **Impact:** Medium. Missing fixtures aren't caught until deep into a run.
- **Fix:** Add a fast import-gate pass (`python -c "import <suite>"` over all suites) that fails
  the build immediately on any missing module.

---

## PART B — MISSING ARTIFACTS (all `rubix/scratch/`, never committed)

| Expected file | Referenced by | Status |
|---|---|---|
| `scratch/independent_decoder.py` | `test_r2_independent_check.py` | MISSING |
| `scratch/disasm.py` | `test_disasm.py` | MISSING |
| `scratch/fuzz_gen.py` | `test_differential_fuzzing.py` | MISSING |

Pattern: test scripts were committed; their helper modules were not. Root fix is a committed
`conftest`/fixtures directory plus the import gate (BUG-11).

---

## PART C — FEATURE & PARITY GAPS

Grouped by area, with what Rubix already has (✅) versus what established languages provide (❌/◐).

### C1. Language features
| Feature | Rubix | Peer languages | Priority |
|---|---|---|---|
| Static types, structs, enums, tuples | ✅ | C/Rust/Go | — |
| Pointers, casts, manual memory | ✅ | C/Zig | — |
| `Option`/`Result` + `?` operator | ✅ | Rust/Swift | — |
| Generics / parametric polymorphism | ❌ | C++/Rust/Go | P1 |
| Traits / interfaces / typeclasses | ◐ | Rust/Go/Haskell | P1 |
| Closures / first-class lambdas | ◐ | most | P1 |
| Pattern matching | ◐ (enums) | Rust/Swift/OCaml | P2 |
| String interpolation, `defer`, pipelines | ✅ | modern langs | — |
| Compile-time evaluation (`comptime`/const fn) | ❌ | Zig/Rust(on the way) | P2 |
| Sum types with exhaustiveness checking | ◐ | Rust/OCaml | P2 |
| Module/visibility system | ◐ | most | P1 |
| Async/await or concurrency model | ❌ (has threads std) | Go/Rust/JS | P1 |
| Floating point | ✅ (tested) | all | — |

### C2. Toolchain & developer experience
| Capability | Rubix | Notes | Priority |
|---|---|---|---|
| Self-hosting compiler, own backend | ✅ | x86-64/ARM64/RISC-V verified on QEMU | — |
| Own assembler + ELF writer | ✅ | | — |
| REPL | ✅ (`tools/repl.bix`) | | — |
| Formatter | ✅ (`tools/formatter.bix`) | | — |
| LSP | ✅ (`tools/lsp.bix`) | verify editor integration | P1 |
| Doc generator | ✅ (`tools/docgen.bix`) | | — |
| Debugger (breakpoints, DWARF, stack traces) | ❌ | essential for parity | P0 |
| Package manager + registry | ❌ | `rubix.pkg`-style manifest exists in scaffold | P0 |
| Build system / incremental builds | ◐ (`Makefile`, `rix`) | | P1 |
| Error diagnostics with line:col + codes | ◐ | `-37` unspecified (BUG-6) | P0 |
| Warnings taxonomy | ✅ (`middle/warnings.bix`) | | — |
| Test runner | ✅ (`run_all_regressions.py`) | needs import gate (BUG-11) | P0 |

### C3. Standard library & ecosystem
| Area | Rubix | Priority |
|---|---|---|
| Core, string, math, collections, fs, json | ✅ | — |
| HTTP client/server, web, wire, ffi, thread | ✅ | — |
| Matrix, async, cli | ✅ (present) | — |
| Regex, date/time, crypto, compression, unicode/i18n | ❌ | P1 |
| Networking breadth (TLS, DNS, sockets beyond basic) | ◐ | P1 |
| Package registry / dependency resolution | ❌ | P0 |
| Third-party library ecosystem | ❌ | P2 (grows with P0) |

### C4. Platform & web
| Capability | Rubix | Priority |
|---|---|---|
| Multi-arch codegen (x86-64/ARM64/RISC-V) | ✅ QEMU-verified 16/16 | — |
| Native HTTP server + HTML render (`rix serve`) | ✅ working | — |
| **Per-client interaction without JS** | ❌ (global state; REX frontier) | P0 |
| Windows/macOS targets | ◐ (Windows scripts exist) | P1 |
| WASM / JS interop escape hatch | ❌ (by design) | P2 |
| Debug/release profiles, LTO, PGO | ❌ | P2 |
| Reproducible builds signed/verified | ◐ (stage equality tested) | P1 |

### C5. Correctness & CI
| Capability | Rubix | Priority |
|---|---|---|
| Differential multi-arch fuzzing | ✅ (50/50 pass) | — |
| QEMU cross-arch execution proof | ✅ 16/16 | — |
| CI with import gate + no false failures | ❌ | P0 |
| Independent decoder cross-check (R2a) | ❌ (helper missing) | P1 |
| Memory-safety hardening tests | ✅ (adversarial, OOB) | — |

---

## PART D — PRIORITIZED ROADMAP

### P0 — Correctness & credibility (do first)
1. Fix BUG-5 (`-37`) in the portfolio test battery.
2. Fix BUG-6: give `-37` a concrete diagnostic with file:line:col.
3. Fix BUG-1/2/3: commit or retire `independent_decoder.py`, `disasm.py`, `fuzz_gen.py`.
4. Fix BUG-4: stop marking passing suites as FAIL.
5. Fix BUG-11: add the import gate to `run_all_regressions.py`.
6. Fix BUG-7: scaffold `main()` must call `Serve(app, port)`.
7. Fix BUG-9: per-session state/DOM so visitors don't share state.
8. Add a real **debugger** and a **package manager** (the two biggest parity holes).

### P1 — Parity & usability
9. Generics, traits/interfaces, closures completion.
10. Async/concurrency model beyond raw threads.
11. Docs claim hygiene: fix BUG-10 ("zero ELF").
12. LSP end-to-end verification in a real editor.
13. Regex, date/time, crypto, unicode/i18n in stdlib.
14. macOS/Windows target polish + signed reproducible builds.

### P2 — Ecosystem & polish
15. Pattern matching + exhaustiveness, comptime.
16. Package registry with a population of libraries.
17. WASM/JS interop escape hatch.
18. Profiles, LTO, PGO.
19. R2a independent-decoder reinstatement (if wanted as a second oracle).

---

## PART E — WHAT ALREADY WORKS (for balance)

- Self-hosting compiler; own x86-64/ARM64/RISC-V backends — **QEMU-verified 16/16**.
- Own assembler + ELF64 writer (with section tables).
- Multi-arch differential fuzzing — **50/50 identical exits**.
- Web pipeline: `rix serve` returns real HTML from a native binary
  (`Server: Webbix/1.0.0 (Rubix-Native x86-64)`, HTTP 200).
- Web framework layers (IR, router, HTTP, reactive state, HTML serializer) in pure Rubix.
- DX tooling present: REPL, formatter, LSP, docgen.
- Stdlib breadth: core/string/math/collections/fs/json/http/web/wire/ffi/thread/matrix/async/cli.
- Robustness: adversarial + OOB + overflow + thread audit suites pass.

---

## SUMMARY SCORECARD

| Dimension | State |
|---|---|
| Compiler correctness | **Strong** (87/91 suites, QEMU-verified multi-arch) |
| Test infrastructure | **Weak** (4 broken suites, no import gate, false FAIL) |
| Example projects | **Weak** (portfolio test `-37`; scaffold won't serve) |
| Web interactivity | **Incomplete** (global state; no-JS frontier) |
| Language feature parity | **~60%** (missing generics, traits, closures polish, async) |
| Tooling parity | **~70%** (no debugger, no package manager) |
| Ecosystem parity | **~10%** (no registry, no third-party libs) |

**Bottom line:** Rubix's *foundations* — the compiler, multi-arch backend, and web pipeline —
are genuinely real and verified. The gaps are in **test infrastructure integrity (P0)**,
**example-project correctness (P0)**, **per-user web state (P0)**, and **developer tooling
parity (debugger + package manager)**. Closing P0 makes Rubix trustworthy; closing P1/P2 makes
it a peer of established languages.
