# Contributing to NeurX

Production code belongs in the matching `src/` domain. Hardware-specific code
belongs in `backends/`, unstable work in `experimental/`, and generated output
in `artifacts/`. New top-level directories require an ADR under `docs/adr/`.

Before committing structural changes, run:

```bash
make check-architecture
git diff --check
```

Keep structural migrations separate from behavioral changes so Git preserves
rename history and reviewers can verify path updates.
