.PHONY: check-compiler-layout
check-compiler-layout:
	@test -f src/compiler/compiler.s
	@test -f experimental/compiler/README.md
	@! grep -R "neurx\.compilation" experimental/compiler --include='*.s' --include='*.md'
	@echo "Compiler layout checks passed."
