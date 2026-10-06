# Rubix Execution eXchange (REX) Binary Format & Multi-Tier Execution Architecture Specification

## 1. Overview & Architectural Vision

The **Rubix Execution eXchange (REX)** is a high-performance, architecture-neutral intermediate target and binary module format designed to serve as a first-class execution target within the **generalized Rubix Universal Machine Synthesis (RUMS)** pipeline.

```text
                         RUBIX SOURCE
                              │
                              ▼
                             UIR
                              │
                       generalized RUMS
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
          x86-64            ARM64              REX
       (Native ELF)      (Native ELF)     (.rex Binary)
                                                │
                          ┌─────────────────────┼─────────────────────┐
                          │                     │                     │
                          ▼                     ▼                     ▼
                  Tier 1: COMPILED      Tier 2: INTERPRETED   Tier 3: REFERENCE VM
                  Native x86-64 JIT      Direct Bytecode         Semantic Baseline
                   (Hardware Speed)     (Instant Startup)      (Differential Proof)
```

REX eliminates traditional VM bottlenecks by providing **three fully integrated, differentially verified execution tiers** in pure, self-hosting Rubix without external toolchains (zero LLVM, zero GCC, zero text assembly):

1. **Tier 1: Compiled JIT Native Machine Code (Fast Path / Default)**: JIT-compiles validated REX modules directly into native CPU machine instructions, achieving native hardware speed with 27x–124x measured speedups over interpreted execution.
2. **Tier 2: Direct Bytecode Interpreter**: High-efficiency, direct-threaded instruction interpreter in pure Rubix for rapid startup and lightweight diagnostics.
3. **Tier 3: Reference VM**: Semantic baseline with full call frame tracking, stack layout invariants, and differential fuzzing validation.

---

## 2. REX Binary Format Specification

REX modules are serialized with a fixed 16-byte module header followed by zero or more tagged sections. All multi-byte integers are serialized in little-endian byte order.

### 2.1 Module Header (16 bytes)

| Offset | Size | Type | Field | Description |
|--------|------|------|-------|-------------|
| 0x00 | 4 | `u8[4]` | `magic` | Fixed identification magic: `\x7FRBX` (`0x7F`, `0x52`, `0x42`, `0x58`) |
| 0x04 | 2 | `u16` | `version` | Format version (Current: `1`) |
| 0x06 | 2 | `u16` | `flags` | Module flags (`0x0001` = relocatable, `0x0002` = debug symbols present) |
| 0x08 | 4 | `u32` | `total_size` | Total length of module in bytes (must match file size exactly) |
| 0x0C | 4 | `u32` | `entry_point` | Exported entry function index (typically `main`) |

### 2.2 Section Structure

Sections follow immediately after the 16-byte header:

```text
+------------------+------------------+-----------------------+
| section_id (u16) |  sec_len (u32)   |   payload (sec_len)   |
+------------------+------------------+-----------------------+
```

Standard section identifiers:
- `0x0001` (**TYPE**): Function type signatures (param count, param types, return type).
- `0x0002` (**IMPORT**): External FFI signatures and symbol identifiers.
- `0x0003` (**FUNCTION**): Function declaration headers and signature associations.
- `0x0004` (**TABLE**): Function pointer indirect dispatch tables.
- `0x0005` (**MEMORY**): Linear memory configuration (initial size, max pages).
- `0x0006` (**GLOBAL**): Module-level global value definitions.
- `0x0007` (**EXPORT**): Exported symbol table mapping names to function indices.
- `0x0008` (**CODE**): Function bodies containing REX bytecode instructions.
- `0x0009` (**DATA**): Linear memory initialization data segments.

---

## 3. REX Instruction Set Architecture (ISA)

REX instructions operate on 64-bit integer values across function local value slots, operand stacks, and linear byte memory:

### 3.1 Control Flow & Function Management
- `0x00 NOP`: No operation.
- `0x01 RET`: Return from function. Pops top value as return value.
- `0x02 BR <i32_offset>`: Unconditional branch relative to current instruction pointer.
- `0x03 BR_IF <i32_offset>`: Conditional branch if top-of-stack value is non-zero.
- `0x04 CALL <u32_fn_idx>`: Direct function invocation.
- `0x05 CALL_INDIR <u32_type_idx>`: Indirect function invocation through table.
- `0x06 TRAP <u32_trap_code>`: Explicit runtime trap.

### 3.2 Constants & Local Slot Operations
- `0x10 CONST_I64 <i64_val>`: Push 64-bit immediate integer onto operand stack.
- `0x11 GET_LOCAL <u32_slot>`: Load value from local slot onto operand stack.
- `0x12 SET_LOCAL <u32_slot>`: Store top-of-stack value into local slot.
- `0x13 TEE_LOCAL <u32_slot>`: Store top-of-stack value into local slot while retaining value on stack.
- `0x14 ADDR_LOCAL <u32_slot>`: Compute linear stack address of local slot.

### 3.3 Arithmetic, Bitwise & Logical Operations
- `0x20 ADD`: Pops `b`, pops `a`, pushes `a + b`.
- `0x21 SUB`: Pops `b`, pops `a`, pushes `a - b`.
- `0x22 MUL`: Pops `b`, pops `a`, pushes `a * b`.
- `0x23 DIV_S`: Signed integer division (traps on division by zero: `TRAP_DIV_BY_ZERO`).
- `0x24 DIV_U`: Unsigned integer division (traps on division by zero).
- `0x25 REM_S`: Signed integer modulo (traps on modulo by zero).
- `0x26 REM_U`: Unsigned integer modulo (traps on modulo by zero).
- `0x27 AND`: Bitwise AND.
- `0x28 OR`: Bitwise OR.
- `0x29 XOR`: Bitwise XOR.
- `0x2A SHL`: Shift left.
- `0x2B SHR_S`: Arithmetic shift right (sign-extended).
- `0x2C SHR_U`: Logical shift right (zero-extended).

### 3.4 Comparisons
- `0x30 EQ`: Pushes `1` if `a == b`, else `0`.
- `0x31 NE`: Pushes `1` if `a != b`, else `0`.
- `0x32 LT_S`: Signed `a < b`.
- `0x33 LT_U`: Unsigned `a < b`.
- `0x34 LE_S`: Signed `a <= b`.
- `0x35 LE_U`: Unsigned `a <= b`.
- `0x36 GT_S`: Signed `a > b`.
- `0x37 GT_U`: Unsigned `a > b`.
- `0x38 GE_S`: Signed `a >= b`.
- `0x39 GE_U`: Unsigned `a >= b`.

### 3.5 Linear Memory & Allocation
- `0x40 LOAD_I64 <u32_align> <u32_offset>`: Load 64-bit integer from linear memory.
- `0x41 STORE_I64 <u32_align> <u32_offset>`: Store 64-bit integer to linear memory.
- `0x42 LOAD_U8 <u32_align> <u32_offset>`: Load 8-bit unsigned integer from linear memory.
- `0x43 STORE_U8 <u32_align> <u32_offset>`: Store 8-bit integer to linear memory.
- `0x48 MEM_GROW`: Grow linear memory in 64 KiB page increments.
- `0x49 MEM_SIZE`: Current linear memory size in pages.
- `0x4A STACK_ALLOC <u32_size>`: Fast linear bump allocator in memory pool.

---

## 4. Multi-Tier Execution Architecture

### 4.1 Tier 1: Compiled JIT Native Machine Code (Fast Path)

The JIT compiler (`compiler/rex/rex_compiler.bix`) compiles validated REX modules directly into native x86-64 machine instructions:

1. **Context Embedding**: Emits a 32-byte self-unpacking header at offset 0 (`EB 1E` short jump to offset 32). Stores `mem_buf`, `mem_size`, and `alloc_ptr` at quadword offsets 1, 2, 3.
2. **Top-Level Anchor & Fast Stack Unwinding**: Preserves host callee-saved registers (`rbx`, `r12`-`r15`), saves host `rsp` to `rbx`, and sets stack limit in `r15` (`mov r15, rsp; sub r15, 65536`). Any runtime trap immediately restores `rsp = rbx` and returns the negative trap code without recursive unwinding.
3. **Register Mapping & Calling Convention**:
   - `rax`: Primary accumulator, return value, arithmetic destination.
   - `rcx`: Secondary accumulator, right-hand operand, shift counter.
   - `r12`: Pointer to linear memory base buffer.
   - `r13`: Linear memory size in bytes.
   - `r14`: Current dynamic allocation pointer.
   - `r15`: Stack overflow guard address.
4. **Hardware Division & Trap Inlining**: Compiles `DIV_S` and `REM_S` with native zero checks (`test rcx, rcx; jz trap_div0`), avoiding OS signal handling overhead.

### 4.2 Tier 2: Direct Bytecode Interpreter

Implemented in `compiler/rex/rex_interp.bix`:
- Direct-threaded instruction evaluation in pure Rubix.
- Operates on pre-allocated frame stack buffers (`frame_buf`) and linear memory space.
- Zero JIT-compilation latency; ideal for fast turnaround during test iterations.

### 4.3 Tier 3: Reference VM Baseline

Implemented in `compiler/rex/rex_vm.bix`:
- Formal specification reference implementation.
- Tracks explicit frame structures: `[fn_idx, caller_frame, return_ip, local_base, stack_base]`.
- Serves as the ground-truth baseline for automated differential fuzzing.

---

## 5. Empirical Performance Benchmarks

Measured on physical x86-64 hardware using `tests/test_rex_benchmarks.py`:

| Benchmark Workload | Reference VM | Interpreter | Compiled JIT | Speedup vs VM | Speedup vs Interp |
|-------------------|--------------|-------------|--------------|---------------|-------------------|
| **Recursive Fibonacci (n=24)** | 30.85 ms | 31.57 ms | **0.52 ms** | **58.9x** | **60.3x** |
| **Tight Accumulator Loop (N=500k)** | 123.94 ms | 142.65 ms | **1.14 ms** | **108.4x** | **124.7x** |
| **Collatz Path Length Sum (N=500)** | 11.03 ms | 11.07 ms | **0.41 ms** | **26.9x** | **27.0x** |

All three tiers produce 100% identical outputs and identical trap codes across all test cases.

---

## 6. CLI Usage & Target Selection

### 6.1 Compiling Rubix Source to REX Binary
```bash
# Compiles source.bix into a standalone binary artifact source.rex
./bin/rubix_stage1 source.bix source.rex
```

### 6.2 Executing REX Modules
```bash
# Execute using Compiled JIT Native Machine Code (Fast Path / Default)
./bin/rubix_stage1 source.rex

# Explicitly specify execution mode:
./bin/rubix_stage1 source.rex --mode=compiled     # Native JIT (Fast Path)
./bin/rubix_stage1 source.rex --mode=interpret    # Direct Bytecode Interpreter
./bin/rubix_stage1 source.rex --mode=vm           # Reference Semantic VM
```
