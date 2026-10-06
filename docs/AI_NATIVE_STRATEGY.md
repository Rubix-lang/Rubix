# Rubix — AI-Native Strategy: Gaps, Needs, New Concepts & Simple Paths

**Purpose:** Define exactly what Rubix lacks for AI/LLM workloads, what it needs, what
*new* ideas it can contribute that no other language offers, and — most importantly —
how to get there in the *simplest possible way*, borrowing instead of rebuilding.

**Verdict up front:** Rubix can build AI **applications** today (HTTP, JSON, sockets,
async, FFI, raw pointers all exist). It **cannot run LLM inference natively yet** —
missing low-precision numerics, SIMD, real threads, tensor ops. But because Rubix owns
its whole backend, every gap is **additive**, not architectural. This doc plans the climb.

---

## PART 1 — What Is Missing (verified against the code)

| # | Missing | Evidence | Why it blocks AI |
|---|---|---|---|
| 1 | **Low-precision floats** — no fp16/bf16/fp8 | Only `TYPE_F32`/`TYPE_F64` ([`lexer.bix:444-445`](../compiler/frontend/lexer.bix:444)) | LLM weights are fp16/bf16/int8. Without them, a model either won't fit or runs at half speed. |
| 2 | **No SIMD in the live backend** | `grep simd` in [`middle/uir.bix`](../compiler/middle/uir.bix:1), [`rums/machdesc.bix`](../compiler/rums/machdesc.bix:1) → **empty**; only dead [`legacy/codegen/simd.bix`](../legacy/codegen/simd.bix:1) | Matmul is ~90% of inference. Scalar matmul is 10–100× too slow. |
| 3 | **Threads are a documented stub** | [`std/thread.bix:5-9`](../std/thread.bix:5) — *"DO NOT use this module for true multithreaded concurrency"* | No parallelism ⇒ no parallel batch inference. |
| 4 | **No tensor/ML ops** | No `matmul`/`gemm`/`softmax`/`attention`/`quant` in `std/` or `compiler/` | Nothing to build a transformer from. |
| 5 | **FFI too thin** | `ffi_call_c_func(ptr, arg1: Integer, arg2: Integer)` ([`std/ffi.bix:60`](../std/ffi.bix:60)) | Can't pass tensors, floats, structs, or varargs to a C inference lib. |
| 6 | **No accelerator path** | No CUDA/Metal/Vulkan/WebGPU references | No GPU/NPU offload. |
| 7 | **No bare-metal mode** | No `freestanding`/`no_std`/kernel entry; emits Linux ELF userland | Rubix can't *be* an OS kernel. |

---

## PART 2 — What We Need (capability checklist)

**Numerics**
- [ ] `f16`, `bf16` scalar types (storage + arithmetic via promote-to-f32)
- [ ] `i8` / `u8` with saturating and widening ops (for int8 quantized inference)
- [ ] Optional `f8` (block-scaled) later
- [ ] `@deterministic` float mode (fixed reduction order) — see Concept 7

**Vectorization**
- [ ] A portable **kernel IR** that lowers to SSE/AVX2/AVX-512, NEON/SVE, RVV
- [ ] Typed SIMD intrinsics: `fma`, `dot`, `reduce_add`, `pack`, `unpack`
- [ ] Auto-vectorizer for simple `for` loops (bonus, not required)

**Concurrency**
- [ ] Real OS threads (`clone`/`pthread`) — or the process-fork workaround (Part 4)
- [ ] Thread-safe allocator + `atomic` operations that actually are atomic
- [ ] Work-stealing pool for parallel matmul

**Memory & data**
- [ ] Memory-mapped weight loading (`mmap` a model file, zero-copy)
- [ ] Alignment/huge-page control; section placement of weights
- [ ] A tensor type carrying **shape at compile time**

**Interop**
- [ ] FFI v2: floats, structs, pointers-to-structs, varargs, return-struct
- [ ] `safetensors` / `GGUF` readers in `std/`
- [ ] BLAS/cuBLAS bindings via FFI

**Tooling**
- [ ] Kernel profiler (cycles per op) built into `rix debug`
- [ ] Model-run harness / benchmark suite
- [ ] Numerical-parity tests vs reference (fp32→fp16 tolerance checks)

---

## PART 3 — New Concepts Rubix Can Bring (its unique angle)

These are ideas that are **only natural** for a language that owns its compiler, ships
its own ELF, targets three ISAs, and proves byte-determinism. This is where Rubix can be
*genuinely novel* rather than "Rust but newer."

### Concept 1 — Precision as a first-class, per-scope policy
Instead of sprinkling casts, make precision a **region attribute**:
```
@precision(bf16)
fn attention(q: Tensor, k: Tensor, v: Tensor) -> Tensor {
    # arithmetic auto-lowers to bf16 with f32 accumulation
}
```
*New because:* existing languages make you pick types per-variable; Rubix can make the
**whole kernel** declare its numeric policy once, and the backend picks instructions.

### Concept 2 — Shape-checked tensors as a language primitive
```
fn project(x: tensor<bf16, [B, S, H]>, w: tensor<bf16, [H, H2]>)
    -> tensor<bf16, [B, S, H2]>
```
*New because:* shape errors become **compile errors**, not runtime crashes. This is the
single most requested missing feature in AI tooling, and Rubix's type system can host it.

### Concept 3 — First-party portable kernel IR (extend `.machine`)
[`machdesc.bix`](../compiler/rums/machdesc.bix:1) already defines a `.machine` DSL. Extend
it to describe **vector** ops once and auto-lower to AVX/NEON/RVV:
```
kernel matmul_tile@v1 [m, n, k] {
    acc = fma(a, b, acc)      # lowered per-ISA by machdesc
}
```
*New because:* Halide/Triton do this as external tools; Rubix can make it **part of the
language's own backend** — no separate compiler, no plugin.

### Concept 4 — Weights as linker sections (`@resident`)
Rubix writes its own ELF. So let it link model weights directly:
```
@resident("model.safetensors#layer0") let W0: tensor<bf16, [4096, 4096]>;
```
The compiler places weights in a dedicated segment — huge pages, `mmap`, zero copy,
no runtime loader.
*New because:* no other language treats **model weights as a link-time section**.

### Concept 5 — REX as a portable model bundle
Ship weights + compiled kernels as **one REX module** that runs on x86-64, ARM64, and
RISC-V unchanged (already proven for programs).
*New because:* a **tri-architecture** model file with no runtime dependency is a real
"write once, run on any edge device" story.

### Concept 6 — Capability-typed tools for agents
Make tool-calling type-safe so an LLM can't invoke something it wasn't granted:
```
@tool fn search(q: String) -> Result[String, Error];
@uses(search) fn agent_loop(prompt: String) -> String { ... }
```
*New because:* agent safety becomes a **static property of the program**, not a runtime
prompt-engineering hope.

### Concept 7 — Deterministic numerics as a guarantee (builds on existing strength)
Rubix already proves byte-for-byte determinism across architectures. Extend that to
floats: `@deterministic` pins reduction order so the *same input gives the same output
bits on every CPU*.
*New because:* reproducible ML is a notorious unsolved problem. Rubix can make it a
language invariant — and it can *prove* it with its existing differential harness.

### Concept 8 — Integer-first inference path
Rubix already has integers and raw bytes. Offer an **int8-only** inference mode so a
model runs **without needing float support at all**:
```
@quant(int8, per_channel)
fn linear_int8(x: tensor<i8,[B,K]>, w: tensor<i8,[K,N]>, scale: Scalar) -> tensor<i8,[B,N]>
```
*New because:* it turns the *missing float story* into a **feature** — edge devices
thrive on int8 — and it's the **simplest** path (Part 4).

### Concept 9 — Streaming tokens as a language construct
Token generation is an infinite `yield` stream:
```
for tok in model.generate(prompt) { print(tok); }
```
*New because:* it makes "streaming" a first-class control-flow concept instead of a
callback soup.

### Concept 10 — Gradual AI adoption: "Borrow → Native"
Let a module declare *where* it gets its speed:
```
@backend(borrow)  # FFI to llama.cpp / BLAS
fn attention(...) { ... }

@backend(native)  # Rubix's own codegen + SIMD
fn matmul(...) { ... }
```
*New because:* you can ship AI in Rubix **today** (borrow) and replace hot paths
one-by-one (native) **without changing call sites**. It's a migration strategy baked
into the language.

---

## PART 4 — How To Deal With It The Simple Way (pragmatic shortcuts)

The theme: **borrow before you build; use integers before floats; use processes before
threads.** Each shortcut deliberately trades "pure" for "working this month."

### Shortcut A — Start with int8, not fp16
Integers and byte-level memory **already exist**. Quantized inference is the fastest
route to a working model with zero new type-system work.
- **Effort:** low. **Payoff:** a running (small) LLM without touching floats.
- **Do:** add `i8` matmul kernels over `set_byte`/`get_byte` buffers.

### Shortcut B — Use processes, not threads (the threading gap workaround)
[`std/thread.bix`](../std/thread.bix:1) admits threads are sequential stubs. But the OS is
Linux — so **`fork()` + `mmap(MAP_SHARED)`** gives you real parallelism **today**,
bypassing the thread stub entirely.
- **Do:** add `std/proc.bix` with `fork`, shared-memory channel, and a worker pool.
- **Effort:** low. **Payoff:** real multi-core matmul now; swap to real threads later.

### Shortcut C — FFI to `llama.cpp` / BLAS before writing kernels
Widen FFI (Part 2) just enough to call `llama.cpp`. You get real inference in Rubix
**immediately**, with Rubix handling the AI *system* around it.
- **Do:** FFI v2 (floats + pointers + struct-by-pointer), then a thin `std/llm.bix` wrapper.
- **Effort:** medium. **Payoff:** "Rubix runs an LLM" is true this quarter.

### Shortcut D — Offload matmul to WebGPU from the browser host
REX already targets the browser. Instead of writing a native GPU backend, let the
**host** dispatch matmul to **WebGPU**.
- **Do:** a `@backend(webgpu)` shim in [`rex_browser_host.py`](../tools/rex_browser_host.py:1).
- **Effort:** low. **Payoff:** GPU-class speed with **zero compiler work**.

### Shortcut E — Target one tiny model first
Don't aim at 70B. Aim at a **~10–100M param** transformer. It fits in cache, runs
scalar, and proves the pipeline end-to-end.
- **Do:** a "hello inference" suite (tiny GPT) in `tests/`.
- **Payoff:** an honest, demoable milestone.

### Shortcut F — Reuse `.machine` for ISA description
Don't write a new vector abstraction — extend the existing [`machdesc.bix`](../compiler/rums/machdesc.bix:1)
DSL. It already parses ISA descriptions.
- **Do:** add vector register classes + `fma`/`dot` ops.
- **Effort:** medium. **Payoff:** one description → three ISAs.

### Shortcut G — Compile-time allocation policy instead of a runtime allocator
Rubix owns the ELF. Pre-place the KV-cache and scratch buffers **statically** (`@resident`)
so there's no allocator in the hot loop.
- **Payoff:** predictable latency, no GC/allocator stalls.

### Priority order (do these in sequence)
1. **A** (int8 kernels) — smallest step to a real model
2. **B** (fork+shm parallelism) — unlocks multi-core with no thread work
3. **C** (FFI v2 → llama.cpp) — makes "Rubix runs LLMs" true
4. **F** (vector `.machine`) — native speed for hot loops
5. **D** (WebGPU offload) — free GPU
6. **E** (tiny model e2e) — the demo
7. Floats (`f16`/`bf16`) properly, then **Concept 2/4/7** as differentiators

---

## PART 5 — Staged Plan

### Phase 0 — "Borrow" (weeks, low risk)
Goal: **Rubix runs an LLM via FFI.** Deliverables: FFI v2, `std/llm.bix`, tiny-model demo.
Claim we can make: *"Rubix orchestrates and hosts LLM inference."*

### Phase 1 — "Parallel & Quantized" (1–2 months)
Goal: **Rubix does its own int8 matmul, multi-core.** Deliverables: `i8` kernels,
`std/proc.bix` (fork+shm), benchmark vs scalar.
Claim: *"Rubix computes quantized inference natively, in parallel."*

### Phase 2 — "Vector & Float" (3–6 months)
Goal: **Native fp16/bf16 + SIMD.** Deliverables: `f16`/`bf16` types, vector `.machine`
ops, auto-lowering to AVX2/NEON/RVV, numerics parity tests.
Claim: *"Rubix runs small transformers natively at usable speed on three ISAs."*

### Phase 3 — "Accelerate" (6–12 months)
Goal: **GPU + tensor stdlib.** Deliverables: WebGPU/cuBLAS backend, `softmax`/`attention`,
shape-checked tensors (Concept 2).
Claim: *"Rubix is an AI-native language."*

### Phase 4 — "LLM OS" (long horizon)
Goal: **bare-metal + kernel primitives.** Deliverables: freestanding target, memory
management, schedulers, device drivers, `@resident` model linking (Concept 4).
Claim: *"An OS whose scheduler understands models."*

---

## PART 6 — Risks & Honesty Guardrails

| Risk | Mitigation |
|---|---|
| Claiming inference speed before SIMD/threads exist | Publish benchmarks **only** when phases land; label borrow-mode clearly |
| Float precision bugs (bf16 rounding) | Numerical-parity test suite vs fp32 reference, with tolerance gates |
| Threading stub mistaken for real concurrency | Keep the honest header in [`thread.bix`](../std/thread.bix:5); ship `proc.bix` as "real parallelism today" |
| Codegen complexity explosion for SIMD | Start with a **signed, fixed kernel** set — not a general auto-vectorizer |
| Doc-vs-code drift (see taxonomy bug) | Every capability claim must link to a test that proves it |

**Guardrail:** mirror the compiler's own style — *document the limitation in the source*
the way [`std/thread.bix`](../std/thread.bix:5) already does. Honesty is a feature.

---

## PART 7 — TL;DR Cheat Sheet

- **Missing:** fp16/bf16/int8, SIMD, real threads, tensor ops, wide FFI, GPU, bare-metal.
- **Need:** precision types, vector kernel IR, parallelism, mmap weights, FFI v2, benchmarks.
- **New concepts Rubix can uniquely own:** per-scope precision policy, shape-checked
  tensors, first-party portable kernel IR, weights as linker sections, REX model bundles,
  capability-typed agent tools, deterministic numerics, integer-first inference,
  streaming tokens, `@backend(borrow|native)` gradual adoption.
- **Simplest paths:** int8 before floats · fork before threads · FFI before kernels ·
  WebGPU offload instead of a GPU backend · one tiny model first · reuse `.machine`.
- **North star:** *Borrow → Native → Accelerate → OS.* Ship each stage, claim only what
  a test proves.
