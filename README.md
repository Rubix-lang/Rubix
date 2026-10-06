# Rubix

**Self-hosting x86-64 Linux compiler written in itself.**

## What Works (v0.1)
- Self-hosting compiler with deterministic bootstrap (stage2 == stage3 bit-for-bit)
- Core language: integers, control flow, functions, pattern matching, Result/Option
- Collections: Vec, String, HashMap with 2× growth
- First-class function pointers, UFCS (uniform function call syntax)
- Manual memory management (heap_alloc, heap_init)
- Direct x86-64 machine code generation, no LLVM
- Zero external dependencies (not even libc)

## What Doesn't Work Yet
- Float arithmetic (f32/f64) - parses but no SSE2 codegen
- Generics - syntax parses but no monomorphization
- Traits/interfaces - not implemented
- Module system - only `use std.X` works
- Cross-compilation - Windows/macOS/WASM targets are stubs
- Debug info - no DWARF
- Package manager, LSP, incremental builds - not implemented

## Verified
- Deterministic bootstrap: stage2 == stage3 byte-for-bit (SHA-256: ab06d2bf...)
- Full test suite: 38/38 RCS + subsystems + heap + collections + Round 5 + stdlib = 0 errors
- All 8 examples run with zero warnings

## Building
```bash
./bin/rubix compile compiler/main.bix -o rubix.elf
./rubix.elf compile compiler/main.bix -o rubix2.elf
cmp rubix.elf rubix2.elf  # should exit 0
```

## License
MIT