# ==============================================================================
# Rubix Compiler — Native Independent Compiler
# Pure Rubix Architecture: .bix -> Machine Code Bytes -> Native Execution
# Zero GCC, zero Clang, zero LLVM, zero Python, zero external toolchains.
# ==============================================================================

.PHONY: all test stage2 rubix clean

all: test

rubix:
	@echo "==> Building standalone rubix native compiler binary..."
	./bin/rubix compile compiler/main.bix -o scratch/rubix.elf
	@cp scratch/rubix.elf bin/rubix.elf
	@chmod +x bin/rubix.elf
	@echo "==> Successfully built rubix binary"

stage2:
	@echo "==> Rebuilding bin/rubix_stage2 using pure Rubix..."
	./bin/rubix compile compiler/main.bix -o scratch/stage2.bin
	@cp scratch/stage2.bin bin/rubix_stage2
	@chmod +x bin/rubix_stage2
	@echo "==> Rebuilt bin/rubix_stage2 successfully"

test:
	@echo "==> Running RCS binary integration test suite..."
	./bin/rubix tests/test_rcs_binary_integration.bix
	@echo "==> Running RCS native engine test suite..."
	./bin/rubix tests/test_rcs_native.bix
	@echo "==> Running compiler subsystems test suite..."
	./bin/rubix tests/test_compiler_subsystems.bix
	@echo "==> Running heap memory test suite..."
	./bin/rubix tests/test_heap_memory.bix
	@echo "==> Running dynamic collections test suite..."
	./bin/rubix tests/test_dynamic_collections.bix
	@echo "==> Running shipped examples..."
	./bin/rubix examples/01_basics.bix
	./bin/rubix examples/02_control_flow.bix
	./bin/rubix examples/03_functions.bix
	./bin/rubix examples/04_algorithms.bix
	./bin/rubix examples/05_collatz.bix
	./bin/rubix examples/06_primes.bix
	./bin/rubix examples/07_binary_search.bix
	./bin/rubix examples/08_vector_and_map.bix
	@echo "==> All Rubix tests and examples passed cleanly!"

clean:
	@echo "==> Cleaning temporary artifacts..."
	@rm -f *.bin *.o *.s *.a scratch/*.bin scratch/*.css scratch/*.elf
