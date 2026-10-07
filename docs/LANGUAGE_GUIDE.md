# Rubix Language Guide

A practical, verified guide to writing programs in Rubix (`*.bix`).

> [!NOTE]
> For the complete, formal syntax reference including grammar, lexical structure, enums, ADTs, pattern matching, and memory primitives, consult the authoritative [Rubix Syntax Specification](../syntax.md).

---

## 1. Variables and Types

Variables are declared using the `let` keyword for immutable values and `mut` (or `let mut`) for mutable values:

```rubix
# Primitive integer variable
let count: i64 = 10;

# Type inference (defaults to i64)
let year = 2026;

# Mutable counter
mut counter = 0;
counter = counter + 1;

# String literal (null-terminated byte pointer)
let greeting = "Hello, Rubix!";
```

### Supported Primitive Types
- `i64`: 64-bit signed integer (default integer size)
- `i32`: 32-bit signed integer
- `u8`: 8-bit unsigned byte
- `bool`: Boolean flag (`true` / `false`)
- `f64`: 64-bit IEEE floating-point number
- `f32`: 32-bit single-precision floating point
- `ptr`: Untyped 64-bit raw memory pointer
- `str`: String reference / byte pointer (`*u8`)

---

## 2. Functions

Functions are defined with the `fn` keyword, specifying typed parameters and an explicit return type:

```rubix
fn add(a: i64, b: i64): i64 {
    return a + b;
}

fn fibonacci(n: i64): i64 {
    if n <= 1 {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}
```

### First-Class Functions
Functions can be passed by reference and invoked dynamically:
```rubix
fn square(n: i64): i64 {
    return n * n;
}

fn apply_op(op: *i64, arg: i64): i64 {
    return op(arg);
}
```

### Tail Recursion
Rubix compiles tail-recursive functions with efficient call-frame reuse:

```rubix
fn sum_helper(n: i64, acc: i64): i64 {
    if n <= 0 {
        return acc;
    }
    return sum_helper(n - 1, acc + n);
}
```

---

## 3. Control Flow

### If / Else
```rubix
fn sign(n: i64): i64 {
    if n > 0 {
        return 1;
    } else if n < 0 {
        return -1;
    } else {
        return 0;
    }
}
```

### While Loops & Loop Aliases
```rubix
fn sum_to(limit: i64): i64 {
    let mut total = 0;
    let mut i = 1;
    while i <= limit {
        total = total + i;
        i = i + 1;
    }
    return total;
}
```

---

## 4. Structs & Uniform Function Call Syntax (UFCS)

Structs group contiguous typed fields in memory with 8-byte alignment:

```rubix
struct Point {
    x: i64,
    y: i64
}

fn make_point(x: i64, y: i64): Point {
    let p: Point;
    p.x = x;
    p.y = y;
    return p;
}
```

With UFCS, methods can be invoked using object notation:
```rubix
let v = vec_new(4);
v.vec_push(100);
let len = v.vec_len();
```

---

## 5. Dynamic Collections

The Rubix Standard Library (`std/collections.bix`) provides dynamically sized, heap-allocated collections:

```rubix
use std.collections;

fn main(): i64 {
    # 1. Dynamic Vector with 2x growth
    let v = vec_new(4);
    vec_push(v, 100);
    vec_push(v, 250);
    let item = vec_get(v, 0); # 100
    vec_set(v, 1, 777);       # modifies index 1
    let count = vec_len(v);   # 2

    # 2. Dynamic String
    let s = str_new(8);
    str_append(s, "Rubix 2026");
    let slen = str_len(s);    # 10

    # 3. Dynamic Hash Map
    let m = map_new(16);
    map_put(m, 101, 2026);
    let val = map_get(m, 101); # 2026
    let exists = map_has(m, 101); # 1 (true)

    return 0;
}
```

---

## 6. Built-in I/O & System Primitives

Rubix provides direct access to operating system system calls:

- `sys_write(fd: i64, buf: i64, len: i64): i64`
- `sys_read(fd: i64, buf: i64, max_len: i64): i64`
- `sys_open(path: i64, flags: i64, mode: i64): i64`
- `sys_close(fd: i64): i64`
- `sys_mmap(addr: i64, len: i64, prot: i64, flags: i64, fd: i64, off: i64): i64`
- `sys_munmap(addr: i64, len: i64): i64`
- `sys_exit(code: i64): i64`
- `get_qword(ptr: i64, off: i64): i64`
- `set_qword(ptr: i64, off: i64, val: i64): i64`
