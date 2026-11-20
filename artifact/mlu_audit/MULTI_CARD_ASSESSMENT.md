# Multi-card Assessment

## Enumeration

- **CONFIRMED:** CNMon lists MLU0 through MLU7.
- **CONFIRMED:** CNDev `cndevGetDeviceCount` returned 8 and enumerated handles 0 through 7.
- **CONFIRMED:** user `gaozhi` ran enumeration successfully.

## Physical topology

CNMon PCI topology reports:
- Cards 0/1 on NUMA 2
- Cards 2/3 on NUMA 3
- Cards 4/5 on NUMA 5
- Cards 6/7 on NUMA 6

CNMon reports cards 0/1, 2/3, 4/5, and 6/7 as SGL and cross-pairs as SYS. PCIe cross-card relationships require host/system topology traversal.

## MLU-Link

Card 0 MLU-Link status:
- Link 0: Enable, Serdes Enable, Cable Connected
- Link 1: Enable, Serdes Enable, Cable Connected
- Link 2: Enable, Serdes Enable, Cable Connected
- Link 3: Enable, Serdes Enable, Cable Connected
- Link 4: Enable, Serdes Enable, Cable Connected
- Link 5: Enable, Serdes Enable, Cable Connected
- Link 6: Enable, Serdes Enable, Cable Connected
- Link 7: Enable, Serdes Enable, Cable Connected

For card 0, topology shows direct MLU-Link peers on several ports and a RoCE switch on one port.

MLU-Link status was checked only for card 0. Direct peer SN mappings were observed for card 0 and card 1, but this audit did not execute a peer copy or collective.

## CNCL and collectives

- **NOT FOUND:** host-visible CNCL library or CNCL test utility.
- **NOT TESTED:** all-reduce, all-gather, reduce-scatter, broadcast, send/receive, all-to-all.
- NeurX `src/distributed/nccl_comm.s` is a NCCL-shaped API with in-memory state and placeholders; it is not an evidence-backed CNCL implementation.

## Existing VLLM evidence

Eight root processes named `VLLM::Worker_TP0_DCP0_EP0` through `VLLM::Worker_TP7_DCP7_EP7` were visible. CNMon showed memory allocated to them, especially card 0. Their executable and runtime libraries could not be resolved from `/proc`, so this is **PARTIALLY CONFIRMED** evidence of an external workload, not proof that NeurX can use the cards.

## Communication capabilities

- Device enumeration: **CONFIRMED**
- MLU-Link status: **PARTIALLY CONFIRMED** (card 0 only)
- Peer topology: **PARTIALLY CONFIRMED**
- Peer-to-peer copy: **NOT TESTED**
- Device-to-device memory access: **NOT TESTED**
- CNCL: **NOT FOUND**
- Multi-card synchronization: **NOT TESTED**
- Tensor parallel execution: **NOT TESTED**
- Pipeline parallel execution: **NOT TESTED**

## Classification

The hardware topology is capable-looking and MLU-Link links are reported connected, but eight-card communication is **NOT CONFIRMED** until an executed collectives test demonstrates correct synchronized results.
