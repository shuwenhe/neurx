// kernel/mm/mm.s
// AI OS memory manager — analogue of Linux mm/memory.c + mm/page_alloc.c
//
// Linux maps:
//   mm/page_alloc.c  → buddy allocator
//   mm/slub.c        → slab/object allocator
//   mm/mmap.c        → virtual address space management
//   mm/vmscan.c      → memory reclaim / LRU eviction
//   mm/swap.c        → swap / offload
//
// NeurX maps:
//   Manages three memory domains:
//     HOST_MEM   → CPU DRAM (tensors, KV cache, activations)
//     DEVICE_MEM → GPU/NPU HBM (model weights, buffers)
//     SHARED_MEM → unified/zero-copy shared (CUDA managed, Metal shared)

int HOST_MEM   = 0
int DEVICE_MEM = 1
int SHARED_MEM = 2

struct mem_region {
    int    region_id
    int    domain          // HOST_MEM | DEVICE_MEM | SHARED_MEM
    int    device_id       // which GPU/NPU, -1 for host
    int    total_bytes
    int    used_bytes
    int    page_size       // bytes, e.g. 4096 or 2MB huge pages
}

struct mem_alloc_result {
    int    region_id
    int    offset          // byte offset within region
    int    size_bytes
    bool   ok
    string err
}

struct mem_state {
    []mem_region regions
    int          next_region_id
}

func new_mem_state() -> mem_state {
    return mem_state{
        regions:       [],
        next_region_id: 0,
    }
}

// register_region: add a memory pool (called at device init)
func register_region(ms mem_state, domain int, device_id int, total_bytes int, page_size int) -> (mem_state, int) {
    mem_region r = mem_region{
        region_id:   ms.next_region_id,
        domain:      domain,
        device_id:   device_id,
        total_bytes: total_bytes,
        used_bytes:  0,
        page_size:   page_size,
    }
    ms.regions = append(ms.regions, r)
    int id = ms.next_region_id
    ms.next_region_id = ms.next_region_id + 1
    return (ms, id)
}

// mem_alloc: allocate from a region (buddy-style, simplified bump)
func mem_alloc(ms mem_state, region_id int, size_bytes int) -> (mem_state, mem_alloc_result) {
    int align = 256  // 256-byte alignment for SIMD/DMA
    int aligned = ((size_bytes + align - 1) / align) * align

    int i = 0
    while i < len(ms.regions) {
        if ms.regions[i].region_id == region_id {
            if ms.regions[i].used_bytes + aligned > ms.regions[i].total_bytes {
                return (ms, mem_alloc_result{ok: false, err: "OOM"})
            }
            int offset = ms.regions[i].used_bytes
            ms.regions[i].used_bytes = ms.regions[i].used_bytes + aligned
            return (ms, mem_alloc_result{
                region_id:  region_id,
                offset:     offset,
                size_bytes: aligned,
                ok:         true,
                err:        "",
            })
        }
        i = i + 1
    }
    return (ms, mem_alloc_result{ok: false, err: "region_not_found"})
}

// mem_free: release bytes back to region (simplified: just decrement used)
func mem_free(ms mem_state, region_id int, size_bytes int) -> mem_state {
    int i = 0
    while i < len(ms.regions) {
        if ms.regions[i].region_id == region_id {
            if ms.regions[i].used_bytes >= size_bytes {
                ms.regions[i].used_bytes = ms.regions[i].used_bytes - size_bytes
            }
        }
        i = i + 1
    }
    return ms
}

// mem_pressure: compute used/total ratio across all host regions
func mem_pressure(ms mem_state) -> float {
    int total = 0
    int used  = 0
    int i = 0
    while i < len(ms.regions) {
        if ms.regions[i].domain == HOST_MEM {
            total = total + ms.regions[i].total_bytes
            used  = used  + ms.regions[i].used_bytes
        }
        i = i + 1
    }
    if total == 0 {
        return 0.0
    }
    return float(used) / float(total)
}
