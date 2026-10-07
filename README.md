# Rubix Programming Language

**Rubix** (`v0.1.0`) is a self-hosting systems programming language designed for mechanical sympathy, deterministic native execution, and instantaneous compilation. The compiler pipeline operates without external toolchain dependencies: zero Python, C, C++, Rust, LLVM, or GCC. It generates standalone x86-64 Linux ELF64 executables directly from source.

---

## Key Highlights

- **Pure Self-Hosting Compiler**: The entire compiler (`compiler/main.bix`, ~24,000 lines) compiles itself with bit-for-bit deterministic reproducibility (`Stage 2 == Stage 3`).
- **Direct Native Code Emission**: Directly encodes AMD64 machine instructions and ELF64 binary headers in memory. No external assemblers (`as`) or linkers (`ld`) are invoked.
- **Dual Execution Modes**:
  - **In-Memory JIT Execution** (`rubix run`): Allocates pages via `mmap`, generates machine code, transitions memory from RW to RX via `mprotect(PROT_READ | PROT_EXEC)` (W^X), and calls entry points directly on physical CPU.
  - **Ahead-of-Time Compilation** (`rubix compile`): Synthesizes standalone, self-sufficient Linux ELF64 binaries.
- **High Performance**: Heavy integer loop benchmark (`bench_loop.bix`, 50M iterations) executes in **~105ms** (~2.16x faster than GCC -O0); recursive Fibonacci (`bench_fib.bix`, `fib(30)`) executes in **~6.5ms**.
- **Universal Backend (RUMS)**: Cross-targets ARM64 (`aarch64`) and RISC-V 64 (`riscv64`) via model-driven `.machine` specifications, verified under QEMU.
- **Sub-Second Compilation**: Compiles the entire self-hosting compiler codebase in ~1.0–1.1 seconds.
- **Native RCS Styling Engine**: Built-in declarative styling and animation engine (`rcs/`) compiling directly to web-standard CSS without external tools.

---

## Quick Start

### 1. Installation
Rubix is supported natively on **Linux x86-64**. Download the pre-built binary:

```bash
# Download binary
curl -L -o rubix https://github.com/Rubix-lang/Rubix/releases/latest/download/rubix-v0.1.0-linux-x86_64
chmod +x rubix

# Verify installation
./rubix --version
# Output: rubix v0.1.0
```

For full installation and bootstrap steps, see [INSTALL.md](INSTALL.md).

### 2. Running & Compiling Code

```bash
# Execute directly in-memory
./rubix run examples/01_basics.bix

# Compile to a standalone native ELF64 executable
./rubix compile examples/01_basics.bix -o hello
./hello

# Syntax and type check only
./rubix check examples/01_basics.bix

# Check syntax with JSON output for IDE tooling
./rubix check --json examples/01_basics.bix

# Emit Universal Intermediate Representation (UIR)
./rubix emit uir examples/01_basics.bix
```

---

## Language at a Glance

### Functions, Recursion, & Basic Types
```rubix
fn fibonacci(n: i64): i64 {
    if n <= 1 {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

fn main(): i64 {
    let result = fibonacci(10);
    print "Fibonacci(10):";
    print result;
    return 0;
}
```

### Dynamic Collections (`std/collections.bix`)
```rubix
use std.collections;

fn demo(): i64 {
    # Dynamically expanding vector
    let vec = vec_new(4);
    vec_push(vec, 100);
    vec_push(vec, 250);
    let first = vec_get(vec, 0); # 100

    # Dynamic hash map
    let map = map_new(16);
    map_put(map, 101, 2026);
    let val = map_get(map, 101);    # 2026
    return 0;
}
```

For the complete formal syntax reference, see the [Rubix Syntax Specification](syntax.md) and the practical [Language Guide](docs/LANGUAGE_GUIDE.md).

---

## Architecture

The compiler pipeline is organized as modular subsystems integrated into a unified driver:

```
Source (*.bix)
      │
      ▼
Streaming Lexer (compiler/frontend/lexer.bix)
      │
      ▼
UIR Frontend Parser (compiler/frontend/uir_frontend.bix)
      │
      ▼
Universal Intermediate Representation (compiler/middle/uir.bix)
      │
      ├──▶ Native Optimization Framework (compiler/middle/optimizer.bix)
      │
      ▼
Linear-Scan Register Allocator (compiler/rums/regalloc.bix)
      │
      ▼
x86-64 Machine Emitter & Bridge (compiler/legacy/emitter.bix)
      │
      ├──▶ In-Memory Execution (W^X mprotect)
      ▼
ELF64 Packager (compiler/packaging/elf.bix) ──▶ Standalone Executable
```

For complete architectural details, see [Architecture Specification](docs/ARCHITECTURE.md).

---

## Platform Support

| Platform | Arch | Format | Maturity Tier | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Linux** | x86-64 | ELF64 | **Tier 1** | ✅ Verified Native & Self-Hosting (Full stdlib) |
| **REX** | Bytecode | REX VM | **Tier 1** | ✅ Verified JIT / Interpreter / VM |
| **Linux** | AArch64 | ELF64 | **Tier 2** | ✅ Verified Cross-Target (RUMS / QEMU core codegen) |
| **Linux** | RISC-V 64 | ELF64 | **Tier 2** | ✅ Verified Cross-Target (RUMS / QEMU core codegen) |
| **macOS** | x86-64 | Mach-O | **Tier 4** | ⏳ Planned Target Specification |
| **WASM** | Wasm32 | WASM | **Tier 4** | ⏳ Planned Target Specification |

*(Note: Windows PE/COFF is Tier 4 planned; Rubix does not run natively on Windows yet. Windows users can run Rubix under WSL2).*

---

## Quality & Test Ledger

All components are validated natively via `./scripts/test.sh`:
- **RCS Styling Engine**: 38/38 tests passing (100%).
- **Compiler Subsystems**: MIR CFG verifier, AST memory arena, pattern matching evaluators.
- **Runtime Safety**: Heap memory allocator, 16-byte alignment, OOM guards, dynamic collections.
- **Round 5 Acceptance**: 15/15 acceptance criteria verified cleanly.
- **Standard Library**: 19/19 stdlib modules verified.
- **Shipped Examples**: All 8 examples in `examples/` compile and run cleanly on Tier 1 (examples 01-07 verified cross-target).
- **Cross-Target Core**: Arithmetic, loops, recursion, functions, and printing verified on x86-64, REX VM, QEMU ARM64, and QEMU RISC-V 64.

For the complete verification audit and benchmark numbers, see [Verified Claims](docs/VERIFIED_CLAIMS.md).

---

## Documentation Index

- [Rubix Syntax Specification (A–Z)](syntax.md)
- [Installation Guide](INSTALL.md)
- [Architecture Specification](docs/ARCHITECTURE.md)
- [Language Guide](docs/LANGUAGE_GUIDE.md)
- [RCS Specification](docs/RCS_SPECIFICATION.md)
- [Verified Claims & Quality Ledger](docs/VERIFIED_CLAIMS.md)

---

## License

This project is licensed under the terms specified in [LICENSE](LICENSE).
