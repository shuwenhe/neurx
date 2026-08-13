int HOST_MEM   = 0
int DEVICE_MEM = 1
int SHARED_MEM = 2
struct mem_region {
    int    region_id
    int    domain
    int    device_id
    int    total_bytes
    int    used_bytes
    int    page_size
}
struct mem_alloc_result {
    int    region_id
    int    offset
    int    size_bytes
    bool   ok
    string err
}
struct mem_state {
    []mem_region regions
    int          next_region_id
}
func new_mem_state() mem_state {
    return mem_state{
        regions:       [],
        next_region_id: 0,
    }
}
func register_region(ms mem_state, int domain, int device_id, int total_bytes, int page_size) (mem_state, int) {
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
func mem_alloc(ms mem_state, int region_id, int size_bytes) (mem_state, mem_alloc_result) {
    int align = 256
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
func mem_free(ms mem_state, int region_id, int size_bytes) mem_state {
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
func mem_pressure(ms mem_state) float {
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
