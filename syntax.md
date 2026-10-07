# Rubix Language Syntax Specification (A–Z)

**Rubix** (`.bix`) is a statically typed, systems programming language designed for deterministic self-hosting compilation, zero runtime dependencies, and direct machine-code generation.

This document serves as the authoritative, comprehensive syntax reference for the Rubix programming language as implemented in compiler version `v0.1.0`.

---

## 1. Comments & Lexical Structure

### Comments
Rubix uses `#` for single-line comments. Everything following `#` on the same line is ignored by the lexer:

```rubix
# This is a full-line comment in Rubix
let x = 42; # Inline trailing comment
```

### Identifiers
Identifiers begin with an ASCII letter (`a-z`, `A-Z`) or underscore (`_`), followed by any number of alphanumeric characters or underscores:

```rubix
let my_var = 10;
let _scratch = 20;
let counter2 = 30;
```

### Semicolons
Statements in Rubix may be delimited by semicolons `;` or newline boundaries. Semicolons are optional after block closures (`}`) and optional on trailing block expressions.

---

## 2. Types & Type System

Rubix has a strict, statically checked type system with 64-bit word orientation on 64-bit architectures.

### 2.1 Primitive Scalar Types
| Type | Bit Width | Description |
|---|---|---|
| `i64` | 64 | Signed 64-bit integer (canonical default integer) |
| `i32` | 32 | Signed 32-bit integer |
| `u8` | 8 | Unsigned 8-bit byte |
| `bool` | 1 / 8 | Boolean value (`true` = 1, `false` = 0) |
| `f64` | 64 | IEEE-754 64-bit double-precision floating point |
| `f32` | 32 | IEEE-754 32-bit single-precision floating point |
| `ptr` | 64 | Untyped generic memory pointer |
| `str` | 64 | Pointer to UTF-8 null-terminated character sequence (`*u8`) |
| `void` | 0 | Unit / empty return type |

### 2.2 Pointer & Reference Types
Pointer types are prefixed with `*`:
```rubix
let p: *i64;
let text: *u8;
```

Address-of operations use `&`:
```rubix
let val = 100;
let addr: *i64 = &val;
```

### 2.3 Fixed-Size Arrays
Fixed-size arrays specify an element type and compile-time size:
```rubix
let nums: [i64; 4];
```
Array indexing uses zero-based bracket notation:
```rubix
let first = nums[0];
nums[1] = 42;
```

---

## 3. Variables & Mutability

### 3.1 Immutable Bindings (`let`)
By default, `let` declares an immutable binding:
```rubix
let answer: i64 = 42;
let year = 2026; # Type inferred as i64
```

### 3.2 Mutable Bindings (`mut` / `let mut`)
Variables intended to be reassigned must be declared with `mut`:
```rubix
mut counter = 0;
counter = counter + 1;

let mut total = 100;
total = total + counter;
```

### 3.3 Tuple Destructuring
Multiple variables can be bound simultaneously:
```rubix
let (left, right) = pair;
```

---

## 4. Functions & Execution

### 4.1 Declaration Syntax
Functions are declared using `fn`, with parenthesized typed arguments and a colon-delimited return type:
```rubix
fn add(a: i64, b: i64): i64 {
    return a + b;
}
```

### 4.2 Expression Returns
The final expression in a block is automatically returned if no explicit `return` is provided:
```rubix
fn multiply(a: i64, b: i64): i64 {
    a * b
}
```

### 4.3 Recursive Functions
Recursive and mutually recursive functions are first-class:
```rubix
fn fib(n: i64): i64 {
    if n <= 1 {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}
```

### 4.4 First-Class Function Values
Functions can be passed as values, assigned to pointer slots, and invoked indirectly:
```rubix
fn square(n: i64): i64 {
    return n * n;
}

fn apply_op(op: *i64, arg: i64): i64 {
    return op(arg);
}

let res = apply_op(square, 8); # 64
```

---

## 5. Control Flow

### 5.1 Conditionals (`if` / `else`)
`if` statements can evaluate boolean and integer expressions:
```rubix
if x > 0 {
    return 1;
} else if x < 0 {
    return -1;
} else {
    return 0;
}
```
`if` blocks may also be used as expressions yielding a value:
```rubix
let sign = if n > 0 { 1 } else { -1 };
```

### 5.2 While Loops (`while` / `loop`)
Loops repeat while a condition holds true:
```rubix
let mut i = 0;
while i < 10 {
    i = i + 1;
}

# `loop` is also supported as an alias for while
mut count = 1;
loop count <= 5 {
    count = count + 1;
}
```

### 5.3 Loop Control (`break` and `continue`)
Loops support immediate termination and step skipping:
```rubix
while true {
    if condition {
        break;
    }
    if skip_item {
        continue;
    }
}
```

---

## 6. Composite Types: Structs & ADTs

### 6.1 Structs
Structs group contiguous typed fields in memory with natural word alignment:
```rubix
struct Vector {
    data: *i64,
    len: i64,
    cap: i64
}

struct Point {
    x: i64,
    y: i64
}
```

Field access and mutation use the dot operator `.`:
```rubix
let p: Point;
p.x = 10;
p.y = 20;
let dist_sq = p.x * p.x + p.y * p.y;
```

### 6.2 Enums and Algebraic Data Types (ADTs)
Enums define distinct variants, optionally carrying payloads:
```rubix
enum Status {
    Pending,
    Running,
    Completed,
    Failed
}
```

Built-in monadic types `Result` and `Option` represent fallible and optional values:
```rubix
fn safe_divide(num: i64, den: i64): Result {
    if den == 0 {
        return Err(404);
    }
    return Ok(num / den);
}
```

---

## 7. Pattern Matching (`match`)

Rubix provides pattern matching over values, enum variants, and result types using `match` and fat-arrow `=>` branches:

```rubix
let res = safe_divide(100, 5);

match res {
    Ok(val) => {
        print "Quotient: ";
        print val;
    },
    Err(code) => {
        print "Division error: ";
        print code;
    }
}
```

Enum variant matching:
```rubix
match status {
    Status.Pending   => print "Task pending",
    Status.Running   => print "Task in progress",
    Status.Completed => print "Task finished cleanly",
    _                => print "Unknown status"
}
```

---

## 8. Uniform Function Call Syntax (UFCS)

Rubix supports Uniform Function Call Syntax on structs and pointer types. A function whose first parameter is `self: *T` or `self: T` can be invoked using method syntax `instance.method(args...)`:

```rubix
let v = vec_new(4);

# Standard call:
vec_push(v, 100);

# UFCS method call (identical compiled machine code):
v.vec_push(200);
let len = v.vec_len();
```

UFCS provides clean, object-like ergonomics without requiring complex class hierarchies or dynamic dispatch overhead.

---

## 9. Memory Model & Systems Primitives

Rubix operates directly on machine memory without a mandatory garbage collector or hidden C runtime.

### 9.1 Memory Layout
- **Stack:** Local variables and fixed-size arrays reside on the call stack with 8-byte alignment.
- **Heap:** Dynamic structures allocate memory using kernel `sys_mmap` calls or the Rubix buddy allocator (`std/memory.bix`).
- **Pointers:** Raw 64-bit virtual memory addresses.

### 9.2 Low-Level Access Primitives
When implementing runtimes, allocators, and hardware drivers, Rubix provides zero-overhead primitive accessors:
```rubix
# Read 8 bytes from (base_ptr + offset_bytes)
let q = get_qword(ptr, offset);

# Write 8 bytes to (base_ptr + offset_bytes)
set_qword(ptr, offset, value);

# Read single byte
let b = get_byte(ptr, offset);

# Write single byte
set_byte(ptr, offset, byte_val);
```

### 9.3 Kernel Syscall Primitives
Rubix programs can invoke Linux x86-64 syscalls directly:
```rubix
let fd = sys_open("output.txt", 577, 493);
let bytes = sys_write(fd, buf, len);
sys_close(fd);
sys_exit(0);
```

---

## 10. Honest Perspective: "Is Rubix Easy?"

A balanced, truthful assessment of the Rubix development experience:

### What Is Easy
1. **Clean, Readable Grammar:** The surface syntax resembles a pleasant blend of Python and Rust: minimal punctuation, no header files, and intuitive keywords (`let`, `mut`, `fn`, `while`, `match`).
2. **Deterministic, Instant Compilation:** No multi-minute C++ or Rust compile times. Rubix builds complete executables in milliseconds directly to machine code.
3. **Zero Dependencies:** No need to install GCC, Clang, Rust, Python, Make, CMake, or LLVM. A single static `rubix` executable compiles and links complete standalone ELF binaries.
4. **UFCS Ergonomics:** Method-style chaining (`v.vec_push(10)`) without OOP baggage or virtual function table overhead.

### What Requires Care
1. **Manual Memory Management:** Rubix does not have an automatic garbage collector or borrow checker. If you allocate heap buffers with `sys_mmap` or `alloc()`, you are responsible for freeing them.
2. **Direct Memory Safety:** Pointers and `get_qword`/`set_qword` give you raw access to virtual memory. Incorrect pointer arithmetic can cause segmentation faults, just like in C.
3. **Systems Mindset:** Rubix is designed for developers who want full control over machine bytes, data layouts, and operating system calls. It is not an interpreted scripting sandbox.

In short: **Rubix is easy to read, write, and reason about, but gives you the full, unvarnished power and responsibility of a native systems language.**
