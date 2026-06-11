# distributed layer

This directory holds distributed training and parallel execution state for neurx.

## Current modules

- `comm/comm.s`: process groups and collective primitives
- `ddp/ddp.s`: DDP bucket and synchronization bookkeeping
- `tp/tp.s`: tensor-parallel shard mapping
- `tp_collective/tp_collective.s`: TP collective wrappers
- `pp/pp.s`: pipeline parallel execution state
- `zero/zero.s`: ZeRO-style shard bookkeeping
- `pipelining/pipelining.s`: pipeline stage and schedule state
- `launcher/launcher.s`: distributed config detection and launcher helpers

## Intended split

- `distributed/comm/`: process-group and collective primitives
- `distributed/ddp/`: gradient bucketing and synchronization
- `distributed/tp/`: tensor parallel mapping
- `distributed/tp_collective/`: TP collectives on top of process groups
- `distributed/pp/`: pipeline parallel runtime
- `distributed/zero/`: ZeRO-style optimizer and gradient sharding
- `distributed/pipelining/`: pipeline stage planning and schedules
- `distributed/launcher/`: distributed runtime detection and launch helpers

## Migration rule

Keep package names stable while moving the files into subdirectories.
