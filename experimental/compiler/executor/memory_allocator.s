package neurx.experimental.compiler.executor.memory_allocator

use neurx.experimental.compiler.ir.graph.computation_graph

struct memory_block {
    int block_id
    int offset
    int size
    bool allocated
}

struct memory_arena {
    int total_size
    vec[memory_block] blocks
    int next_block_id
}

struct allocation_result {
    int block_id
    int offset
    bool success
    string error_message
}

func new_memory_arena(int total_size) memory_arena {
    blocks = vec[memory_block]()

    blocks.push(memory_block {
        block_id: 0,
        offset: 0,
        size: total_size,
        allocated: false,
    })

    memory_arena {
        total_size: total_size,
        blocks: blocks,
        next_block_id: 1,
    }
}

func (arena: &mut memory_arena) allocate(int size) allocation_result {
    for i, block in arena.blocks {
        if !block.allocated && block.size >= size {
            arena.blocks[i].allocated = true

            if block.size > size {
                new_block = memory_block {
                    block_id: arena.next_block_id,
                    offset: block.offset + size,
                    size: block.size - size,
                    allocated: false,
                }
                arena.next_block_id = arena.next_block_id + 1
                arena.blocks.push(new_block)
            }

            return allocation_result {
                block_id: block.block_id,
                offset: block.offset,
                success: true,
                error_message: "",
            }
        }
    }

    allocation_result {
        block_id: -1,
        offset: -1,
        success: false,
        error_message: "no suitable memory block found",
    }
}

func (arena: &mut memory_arena) deallocate(int block_id) bool {
    for i, block in arena.blocks {
        if block.block_id == block_id && block.allocated {
            arena.blocks[i].allocated = false
            return true
        }
    }
    false
}

func (arena: &memory_arena) get_used_memory() int {
    int used = 0
    for block in arena.blocks {
        if block.allocated {
            used = used + block.size
        }
    }
    used
}

func (arena: &memory_arena) get_free_memory() int {
    arena.total_size - arena.get_used_memory()
}

func (arena: &memory_arena) get_fragmentation_ratio() float {
    if arena.total_size == 0 {
        return 0.0
    }

    largest_free = 0
    for block in arena.blocks {
        if !block.allocated && block.size > largest_free {
            largest_free = block.size
        }
    }

    1.0 - (largest_free as float / arena.get_free_memory() as float)
}

func allocate_for_graph(g: &computation_graph) memory_arena {
    total_memory = g.total_memory_bytes()
    arena = new_memory_arena(total_memory)

    for vt in g.values {
        mem = vt.memory_bytes()
        result = arena.allocate(mem)
        if !result.success {
            break
        }
    }

    arena
}

func (arena: &memory_arena) summary_string() string {
    s = ""
    s = s + "Memory Arena Summary\n"
    s = s + "Total memory: " + arena.total_size as string + " bytes\n"
    s = s + "Used memory: " + arena.get_used_memory() as string + " bytes\n"
    s = s + "Free memory: " + arena.get_free_memory() as string + " bytes\n"
    s = s + "Fragmentation ratio: " + (arena.get_fragmentation_ratio() * 100.0) as int as string + "%\n"
    s = s + "Number of blocks: " + arena.blocks.len() as string + "\n"
    s
}
