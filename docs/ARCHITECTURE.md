# Rubix Architecture Specification

Rubix is an autonomous, self-hosting systems programming language designed for deterministic native execution, mechanical sympathy, and zero toolchain bloat.

---

## 1. High-Level Architecture Overview

The Rubix compiler operates as a single, self-contained native pipeline without delegating to external assemblers, linkers, or runtimes:

```
+--------------------+
|  Rubix Source Code | (*.bix)
+--------------------+
          |
          v
+--------------------+
|   Streaming Lexer  | (compiler/frontend/lexer.bix)
+--------------------+
          |
          v
+--------------------+
|    UIR Frontend    | (compiler/frontend/uir_frontend.bix)
+--------------------+
          |
          v
+--------------------+
| Universal IR (UIR) | (compiler/middle/uir.bix)
+--------------------+
          |
          +---> [Optimization Passes] (compiler/middle/optimizer.bix)
          |
          v
+-------------------------------------------------------------+
| RUMS: Rubix Universal Machine Synthesis (compiler/rums/)   |
|  - Model-Driven Target Architecture (.machine descriptions)  |
|  - Architecture-Agnostic Linear-Scan Register Allocator      |
|  - Machine Byte Encoders (x86-64, ARM64, RISC-V 64, REX)    |
+-------------------------------------------------------------+
          |
          +-------------------------------+
          |                               |
          v                               v
+--------------------+          +--------------------+
| ELF64 Packager     |          | In-Memory Executor |
| (compiler/         |          | (W^X JIT via       |
|  packaging/elf.bix)|          |  sys_mprotect)     |
+--------------------+          +--------------------+
          |                               |
          v                               v
[ Standalone Binary ]           [ Direct CPU Execution ]
 (x86-64, ARM64, RISC-V)
```

---

## 2. Compiler Subsystems & Directory Layout

### Frontend (`compiler/frontend/`)
- **`lexer.bix`**: Streaming token scanner operating directly over raw mmapped byte buffers. Zero allocation per token.
- **`ast.bix`**: AST node representations and memory pool allocation.
- **`symtab.bix`**: Symbol tables for local variables, global symbols, structs, and enums.
- **`parser.bix`**: Recursive descent parser handling statement and expression grammar.
- **`uir_frontend.bix`**: Parses high-level AST constructs into Universal Intermediate Representation (UIR) 3-address virtual register nodes.

### Middle-End (`compiler/middle/`)
- **`uir.bix`**: Definition of hardware-independent Universal Rubix Intermediate Representation. Direct memory-mapped node layout.
- **`optimizer.bix`**: Sequential optimization pass manager providing constant folding, dead code elimination, and identity simplification.
- **`warnings.bix`**: Canonical diagnostic scanner analyzing UIR streams for unreachable code and semantic warnings.

### Backend & Universal Machine Synthesis (`compiler/rums/`)
- **`machdesc.bix`**: Target machine description capturing physical register pools, ABI calling conventions, instruction pattern encodings, and operand bit shifts from declarative `.machine` specifications (`targets/`).
- **`regalloc.bix`**: Target-independent Poletto & Sarkar linear-scan register allocator with preferred register hints and spill weight calculation.
- **`rums.bix`**: Rubix Universal Machine Synthesis backend lowering UIR directly into machine code bytes for target architectures (`x86_64`, `aarch64`, `riscv64`, and `rex`).
- **`uir_bridge.bix` & `emitter.bix`**: Legacy monolithic bridge and AMD64 direct emitter maintained for historical parity.

### Packaging & Execution (`compiler/packaging/` & `compiler/executor/`)
- **`elf.bix`**: Encapsulates machine code bytes into a valid ELF64 executable with `.text`, `.data`, `.symtab`, `.strtab`, and `.shstrtab` sections.
- **`executor.bix`**: Direct in-memory runner applying W^X security transitions (`mprotect(PROT_READ | PROT_EXEC)`) before executing entry addresses on the CPU.

---

## 3. Core Design Principles

1. **Zero External Runtime**:
   Every executable synthesized by Rubix is completely self-contained. Linux kernel system calls (`sys_open`, `sys_read`, `sys_write`, `sys_mmap`, `sys_mprotect`, `sys_munmap`, `sys_exit`) provide all I/O and memory services.
2. **Deterministic 3-Stage Bootstrap**:
   The compiler is capable of reproducing itself identically. Stage 2 compiling the source code yields a Stage 3 executable that matches Stage 2 byte-for-byte.
3. **Mechanical Sympathy**:
   Direct memory buffers and flat struct layouts are preferred over complex pointer webs. Lexing and IR generation stream directly across fixed pages, minimizing cache misses.
