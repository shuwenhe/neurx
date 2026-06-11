# distributed index

## Compatibility surface

- `comm/comm.s`
- `ddp/ddp.s`
- `tp/tp.s`
- `tp_collective/tp_collective.s`
- `pp/pp.s`
- `zero/zero.s`
- `pipelining/pipelining.s`
- `launcher/launcher.s`

## Suggested migration order

1. `comm.s` -> `distributed/comm/comm.s`
2. `tp.s` -> `distributed/tp/tp.s`
3. `tp_collective.s` -> `distributed/tp_collective/tp_collective.s`
4. `ddp.s` -> `distributed/ddp/ddp.s`
5. `pp.s` -> `distributed/pp/pp.s`
6. `zero.s` -> `distributed/zero/zero.s`
7. `pipelining.s` -> `distributed/pipelining/pipelining.s`
8. `launcher.s` -> `distributed/launcher/launcher.s`
