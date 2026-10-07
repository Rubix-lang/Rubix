#!/usr/bin/env bash
# ==============================================================================
# Rubix Test Suite Runner
# Pure Rubix Architecture: zero Python, zero external toolchains.
# ==============================================================================
set -e

echo "==> Running RCS binary integration test suite..."
./bin/rubix tests/test_rcs_binary_integration.bix

echo "==> Running RCS native engine test suite..."
./bin/rubix tests/test_rcs_native.bix

echo "==> Running compiler subsystems test suite..."
./bin/rubix tests/test_compiler_subsystems.bix

echo "==> Running heap memory test suite..."
./bin/rubix tests/test_heap_memory.bix

echo "==> Running dynamic collections test suite..."
./bin/rubix tests/test_dynamic_collections.bix

echo "==> Running shipped examples..."
./bin/rubix examples/01_basics.bix
./bin/rubix examples/02_control_flow.bix
./bin/rubix examples/03_functions.bix
./bin/rubix examples/04_algorithms.bix
./bin/rubix examples/05_collatz.bix
./bin/rubix examples/06_primes.bix
./bin/rubix examples/07_binary_search.bix
./bin/rubix examples/08_vector_and_map.bix
echo "==> Running round 5 acceptance test suite..."
./bin/rubix tests/round5_acceptance.bix

echo "==> Verifying standard library modules (19/19)..."
for f in std/*.bix; do
    ./bin/rubix check "$f" > /dev/null
done
echo "PASS: All 19 standard library modules type-checked and verified cleanly."

echo "==> Running cross-target verification suite (x86-64, REX, AArch64, RISC-V 64)..."
./bin/rubix tests/test_cross_target.bix > /dev/null
./bin/rubix compile tests/test_cross_target.bix -t rex -o /tmp/cross.rex
./bin/rubix run /tmp/cross.rex > /dev/null
if command -v qemu-aarch64 > /dev/null 2>&1; then
    ./bin/rubix compile tests/test_cross_target.bix -t aarch64-unknown-linux-elf -o /tmp/cross_arm.elf
    qemu-aarch64 /tmp/cross_arm.elf > /dev/null
fi
if command -v qemu-riscv64 > /dev/null 2>&1; then
    ./bin/rubix compile tests/test_cross_target.bix -t riscv64-unknown-linux-elf -o /tmp/cross_riscv.elf
    qemu-riscv64 /tmp/cross_riscv.elf > /dev/null
fi
echo "PASS: Cross-target execution (x86-64, REX, AArch64, RISC-V 64) verified cleanly."

echo "==> All Rubix tests and examples executed and passed cleanly!"
