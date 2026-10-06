# Generalized Rubix Universal Machine Synthesis (RUMS) Architecture

## 1. Executive Architecture Summary

The **Rubix Universal Machine Synthesis (RUMS)** engine provides a unified code synthesis and lowering framework across diverse target architectures, encompassing physical architectures (x86-64, ARM64, RISC-V64), portable abstract architectures (REX), and synthetic validation targets.

```text
                           Rubix High-Level Source
                                     │
                                     ▼
                      AST & Semantic Type Checking
                                     │
                                     ▼
                Universal Intermediate Representation (UIR)
                                     │
                 ┌───────────────────┴───────────────────┐
                 │                                       │
                 ▼                                       ▼
        Direct Backend Lowering                 RUMS Synthesizer
                 │                         (Machine-Descriptor Driven)
                 │                                       │
                 │                 ┌─────────────────────┼─────────────────────┐
                 │                 │                     │                     │
                 ▼                 ▼                     ▼                     ▼
              x86-64             ARM64                RISC-V64                REX
           (Native ELF)       (Native ELF)          (Native ELF)         (.rex Binary)
```

---

## 2. Machine Descriptor Architecture

RUMS formalizes machine specifications into discrete, loadable machine description structures (`.machine` tables) parsed entirely in pure Rubix by `compiler/rums/machdesc.bix`:

### 2.1 Core Target Descriptors
- **x86-64 (`machdesc_x86_64`)**:
  - Word size: 64-bit.
  - Endianness: Little-endian.
  - General registers: `rax`, `rcx`, `rdx`, `rbx`, `rsp`, `rbp`, `rsi`, `rdi`, `r8`-`r15`.
  - Argument registers: `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`.
  - Return registers: `rax`, `rdx`.
- **ARM64 (`machdesc_arm64`)**:
  - Word size: 64-bit.
  - Endianness: Little-endian.
  - General registers: `x0`-`x30`, `sp`.
  - Argument registers: `x0`-`x7`.
  - Return register: `x0`.
- **RISC-V64 (`machdesc_riscv64`)**:
  - Word size: 64-bit.
  - Endianness: Little-endian.
  - General registers: `x0`-`x31`.
  - Argument registers: `a0`-`a7` (`x10`-`x17`).
  - Return register: `a0` (`x10`).
- **REX Target (`machdesc_rex`)**:
  - Word size: 64-bit.
  - Local value slots: Arbitrary indexable slots `0..N`.
  - Linear memory address space: Configurable 64 KiB pages.
  - Control flow: Relative byte branch offsets.

---

## 3. REX Integration into Generalized RUMS

REX is synthesized from UIR through `compiler/rex/rex_lower.bix`. It maps high-level expressions, control flow, and local variables into the REX binary format:

1. **Local Variable Allocation**: Variables are assigned contiguous local value slots in each function frame.
2. **Control Flow Lowering**: Conditionals (`if`/`else`) and loops (`while`) are lowered into conditional `BR_IF` and unconditional `BR` instructions with backpatched relative offsets.
3. **Multi-Tier Execution Selection**:
   - Once emitted to disk or memory as a `.rex` file, the module can be executed via:
     - **Compiled Native Machine Code (Fast Path)** via `rex_execute_compiled` (Hardware speed).
     - **Direct Bytecode Interpreter** via `rex_interpret_module` (Instant startup).
     - **Reference VM** via `rex_vm_execute` (Differential verification baseline).

---

## 4. Self-Hosting Determinism Invariants

All RUMS synthesizers, REX compilers, interpreters, and VMs are written in **100% pure Rubix**:
- Zero external libraries or compilers required.
- Memory managed via direct OS virtual memory syscalls (`sys_mmap`, `sys_munmap`).
- Exact bit-for-bit determinism across compiler stages:
  - `Stage 1 == Stage 2 == Stage 3` verified on every build.
