# Verified Claims and Quality Ledger: Rubix v0.1.0

This document records the exact, empirically verified claims regarding the Rubix programming language, compiler architecture, performance metrics, and test coverage. Every claim listed here is directly reproducible on an x86-64 Linux environment.

---

## 1. Compiler Pipeline and Autonomy Claims

| Claim | Specification | Verification Method | Status |
| :--- | :--- | :--- | :--- |
| **Zero External Toolchain Dependencies** | The compiler contains zero C, C++, Rust, Python, LLVM, GNU as, or GNU ld dependencies in its build/execution pipeline. | Source audit across `compiler/` & direct execution of `bin/rubix.elf`. | ✅ **Verified** |
| **Deterministic Self-Hosting Bootstrap** | Compiling `compiler/main.bix` with Stage 2 generates a Stage 3 binary that is 100% bit-for-bit identical to Stage 2 (`cmp` exits 0). | `cmp stage2.elf stage3.elf` produces zero differences (SHA-256: `aedfc839685beed1c3c493bf7fb526a3b30a36d9299b7cbdef26f3949a7d635f`). | ✅ **Verified** |
| **Direct ELF64 Generation** | Native executables are produced by directly synthesizing ELF headers, program headers, sections, and machine code bytes into memory. | Generated binaries execute natively as independent Linux ELF64 binaries without an external linker. | ✅ **Verified** |
| **In-Memory JIT Execution (W^X)** | `rubix run <file.bix>` allocates code pages via `mmap`, generates machine code, transitions memory from RW to RX via `mprotect(PROT_READ \| PROT_EXEC)`, and calls entry points directly. | `rubix run examples/01_basics.bix` executes cleanly in memory without disk artifacts. | ✅ **Verified** |

---

## 2. Test Suite and Subsystem Verification

| Test Suite / Subsystem | Test Scope & Description | Test Command | Result |
| :--- | :--- | :--- | :--- |
| **RCS Native Engine** | 38 tests covering tokenization, parsing, motion verbs, specificity, keyframe deduplication, pseudo-classes, and CSS emission. | `./scripts/test.sh` | **38/38 Passed (100%)** |
| **MIR CFG & Invariant Verifier** | Control Flow Graph construction, block dominance, and register validity. | Subsystem runner in `scripts/test.sh` | **PASS (0 errors)** |
| **AST Node Allocation & Kind Resolution** | AST memory arena allocation, node kinds, and expression trees. | Subsystem runner in `scripts/test.sh` | **PASS (0 errors)** |
| **Pattern Matching Expression Evaluation** | Enum constructor decomposition, value extraction, and branch coverage. | Subsystem runner in `scripts/test.sh` | **PASS (0 errors)** |
| **Heap Memory & Safety** | Block allocator, 16-byte alignment, usage tracking, and out-of-memory guards. | Subsystem runner in `scripts/test.sh` | **PASS (0 errors)** |
| **Dynamic Collections (x86-64 / REX)** | Vector doubling realloc, Dynamic String append, Hash Map key collision handling. | Subsystem runner in `scripts/test.sh` | **PASS (0 errors)** |
| **Round 5 Acceptance Suite** | 15 strict language & compiler acceptance requirements. | Acceptance runner in `scripts/test.sh` | **15/15 Passed (0 errors)** |
| **Standard Library Modules** | Type verification of 19 standard library modules across runtime, math, io, and collections. | Verification runner in `scripts/test.sh` | **19/19 Verified Cleanly** |

---

## 3. Shipped Examples Verification

All 8 official language examples compile and execute with zero warnings and zero runtime errors on the native x86-64 / REX Tier 1 runtime:

| Example File | Key Tested Functionality | Status |
| :--- | :--- | :--- |
| `examples/01_basics.bix` | Variable assignment, arithmetic, integer and string printing | ✅ Verified (Tier 1 & Tier 2) |
| `examples/02_control_flow.bix` | If-else branching, nested conditions, while loop accumulation | ✅ Verified (Tier 1 & Tier 2) |
| `examples/03_functions.bix` | Recursive Fibonacci, tail-recursive sum calculation | ✅ Verified (Tier 1 & Tier 2) |
| `examples/04_algorithms.bix` | Euclidean greatest common divisor, integer power algorithm | ✅ Verified (Tier 1 & Tier 2) |
| `examples/05_collatz.bix` | Collatz sequence length computation | ✅ Verified (Tier 1 & Tier 2) |
| `examples/06_primes.bix` | Primality test, prime sieve count under 100 | ✅ Verified (Tier 1 & Tier 2) |
| `examples/07_binary_search.bix` | Power of 2 verification, integer square root | ✅ Verified (Tier 1 & Tier 2) |
| `examples/08_vector_and_map.bix` | Dynamic vector growth, dynamic strings, dynamic hash map | ✅ Verified (Tier 1 native x86-64 & REX only) |

*(Note: Examples 01 to 07 compile and run cleanly across all targets including QEMU ARM64/RISC-V. Example 08 utilizes standard library dynamic collections requiring Tier 1).*

---

## 4. Performance and Execution Speed

| Benchmark | Rubix Native Implementation | Reference Metric | Relative Performance |
| :--- | :--- | :--- | :--- |
| **Heavy Integer Loop** (`bench_loop.bix`, 50M iterations) | **~105 ms** | GCC 13 (`-O0` C baseline: ~228 ms) | **~2.16x faster than GCC -O0** |
| **Recursive Fibonacci** (`bench_fib.bix`, `fib(30)`) | **~6.5 ms** | GCC 13 (`-O0` C baseline: ~6.95 ms) | **~1.07x faster than GCC -O0** |
| **Compilation Latency** (`compiler/main.bix`, ~24,000 lines) | **~1.0 - 1.1 seconds** | Full self-hosting compiler compilation from source to standalone ELF64 binary | **Sub-second to 1.1s cold build** |

---

## 5. Platform Support Truth Matrix

| Platform Target | Tier | Implementation State | Verification Status |
| :--- | :--- | :--- | :--- |
| `x86_64-unknown-linux-elf` | Tier 1 | Native emitter, direct syscalls, ELF64 packager, self-hosting | ✅ **Fully Verified** (Native Host & Self-Hosting, full stdlib) |
| `rex-bytecode` | Tier 1 | Universal bytecode virtual machine & interpreter | ✅ **Fully Verified** (Execution, control flow, loops, recursion, and printed values) |
| `aarch64-unknown-linux-elf` | Tier 2 | RUMS model-driven synthesis, linear-scan regalloc, native ELF emitter | ✅ **Verified under QEMU** (Core language: arithmetic, loops, recursion, functions, builtin print; stdlib dynamic collections pending) |
| `riscv64-unknown-linux-elf` | Tier 2 | RUMS model-driven synthesis, linear-scan regalloc, native ELF emitter | ✅ **Verified under QEMU** (Core language: arithmetic, loops, recursion, functions, builtin print; stdlib dynamic collections pending) |
| `x86_64-pc-windows-pe` | Tier 4 | Target identifier registered; PE/COFF emitter planned | ⚠️ Target registered only |
| `x86_64-apple-darwin-macho` | Tier 4 | Target identifier registered; Mach-O emitter planned | ⚠️ Target registered only |
| `wasm32-unknown-wasi` | Tier 4 | Target identifier registered; WASM emitter planned | ⚠️ Target registered only |

