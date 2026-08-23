# ADR 0001: Domain-oriented repository layout

- Status: Accepted
- Date: 2026-08-23

## Context

NeurX previously exposed more than one hundred top-level directories. Related
implementations were split across duplicate domains, which made ownership,
dependency direction, testing, and generated-output handling difficult.

## Decision

Production source is grouped under `src/` by domain. Hardware implementations
live under `backends/`; executable entry points, applications, tests, build
definitions, deployment assets, and experiments remain separate top-level
concerns.

Physical paths migrate first while existing `neurx.*` package names remain
compatible. Logical namespace migrations happen one domain at a time after
dependency tests are available.

## Consequences

- New top-level directories require an ADR.
- Production source cannot import `neurx.experimental`.
- Build and deployment files must reference the canonical physical paths.
- Each namespace migration requires its own tested change.
