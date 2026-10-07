# Installation & Setup Guide

Rubix (`v0.1.0`) is a self-hosting systems language compiler targeting native x86-64 Linux with zero external dependencies.

---

## 1. Pre-built Binaries (Recommended)

### Linux x86-64
Download the latest standalone executable from the official releases:

```bash
# Download latest release binary
curl -L -o rubix https://github.com/Rubix-lang/Rubix/releases/latest/download/rubix-v0.1.0-linux-x86_64

# Grant execute permissions
chmod +x rubix

# Verify installation
./rubix --version
# Output: rubix v0.1.0
```

### Verify Integrity
All official releases provide verifiable SHA-256 checksums:

```bash
# Download checksum file
curl -L -o SHA256SUMS https://github.com/Rubix-lang/Rubix/releases/latest/download/SHA256SUMS

# Verify binary integrity
sha256sum -c SHA256SUMS
```

---

## 2. Building & Bootstrapping from Source

Because Rubix is self-hosting and contains zero external dependencies (no C compiler, Python, or LLVM required), bootstrapping is performed using an existing Rubix binary (`bin/rubix`).

### System Requirements & Prerequisites
- **Operating System**: Linux kernel 3.2+
- **Architecture**: x86-64 (AMD64)
- **Standard Tools**: POSIX shell (`sh` / `bash`), `coreutils` (`cmp`, `chmod`, `cp`)

### Step-by-Step Bootstrap Process

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Rubix-lang/Rubix.git
   cd Rubix
   ```

2. **Stage 2 Compilation**:
   Use the repository's bootstrap compiler to compile `compiler/main.bix` from source into a new Stage 2 binary:
   ```bash
   ./bin/rubix compile compiler/main.bix -o stage2.elf
   chmod +x stage2.elf
   ```

3. **Stage 3 Compilation & Determinism Check**:
   Use `stage2.elf` to compile `compiler/main.bix` again into `stage3.elf`, then verify bit-for-bit identity:
   ```bash
   ./stage2.elf compile compiler/main.bix -o stage3.elf
   chmod +x stage3.elf

   # Verify 100% deterministic bootstrap
   cmp stage2.elf stage3.elf
   echo $?  # Must output 0
   ```

4. **Install the Verified Compiler**:
   ```bash
   cp stage3.elf bin/rubix.elf
   chmod +x bin/rubix.elf
   ```

5. **Run the Full Test Suite**:
   ```bash
   ./scripts/test.sh
   ```

---

## 3. Basic Usage & CLI Reference

```bash
# Run a Rubix source file directly in-memory (JIT / memory execution)
./bin/rubix run examples/01_basics.bix

# Compile a Rubix source file to a standalone ELF64 binary
./bin/rubix compile examples/01_basics.bix -o hello_world.elf
./hello_world.elf

# Type-check and verify source syntax without running
./bin/rubix check examples/01_basics.bix

# Output diagnostics in JSON format for editor/tool integration
./bin/rubix check --json examples/01_basics.bix

# Cross-compile for ARM64 using RUMS
./bin/rubix compile examples/01_basics.bix --target aarch64-unknown-linux-elf -o app.arm64.elf
qemu-aarch64 app.arm64.elf

# Cross-compile for RISC-V 64 using RUMS
./bin/rubix compile examples/01_basics.bix --target riscv64-unknown-linux-elf -o app.riscv64.elf
qemu-riscv64 app.riscv64.elf

# Inspect Universal Intermediate Representation (UIR)
./bin/rubix emit uir examples/01_basics.bix

# Inspect raw token stream
./bin/rubix emit tokens examples/01_basics.bix

# Display target architecture and platform registry
./bin/rubix targets
```

---

## 4. Platform Support

| Platform | Architecture | Object Format | Maturity Tier | Status | Binary |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Linux** | x86-64 (AMD64) | ELF64 | Tier 1 | ✅ Verified Native & Self-Hosting | `rubix-v0.1.0-linux-x86_64` |
| **REX Bytecode** | Universal VM | Bytecode | Tier 1 | ✅ Verified JIT / Interpreter / VM | Built-in |
| **Linux** | AArch64 (ARM64) | ELF64 | Tier 2 | ✅ Verified Cross-Target (RUMS / QEMU) | Cross-compilation (`--target aarch64`) |
| **Linux** | RISC-V 64 | ELF64 | Tier 2 | ✅ Verified Cross-Target (RUMS / QEMU) | Cross-compilation (`--target riscv64`) |
| **macOS** | x86-64 | Mach-O | Tier 4 | ⏳ Planned Specification | - |
| **WASM** | Wasm32 | WebAssembly | Tier 4 | ⏳ Planned Specification | - |

*(Note: Native Windows PE/COFF execution is not yet supported. For development on Windows machines, use Linux under WSL2).*

---

## 5. Troubleshooting

**Error: "Permission denied"**
Ensure executable permissions are granted on the binary:
```bash
chmod +x ./rubix
```

**Deterministic Bootstrap Mismatch (`cmp` fails)**
Ensure you are running on an x86-64 Linux kernel and that `compiler/main.bix` has not been modified between Stage 2 and Stage 3 builds.

**Uninstall**
To remove Rubix, simply delete the downloaded binary or cloned repository directory:
```bash
rm -rf path/to/rubix
```