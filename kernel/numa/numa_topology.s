package neurx.kernel.numa

use std.slices

struct numa_node {
    int node_id
    int cpu_start
    int cpu_end
    int memory_base
    int memory_size
    int distance_to_other_nodes
}

struct numa_topology {
    numa_node[] nodes
    int num_nodes
    int num_cpus_total
}

struct numa_policy {
    int policy_type
    int preferred_node
    int fallback_node
}

struct numa_stats {
    int node_id
    int memory_used
    int memory_free
    int memory_swapped
    int page_faults_local
    int page_faults_remote
}

func create_numa_topology(int num_nodes) numa_topology {
    topo := numa_topology {
        nodes: numa_node[](),
        num_nodes: num_nodes,
        num_cpus_total: 0
    }
    topo
}

func numa_topology_add_node(numa_topology topo, int node_id, int cpu_start, int cpu_end, int mem_base, int mem_size) numa_topology {
    node := numa_node {
        node_id: node_id,
        cpu_start: cpu_start,
        cpu_end: cpu_end,
        memory_base: mem_base,
        memory_size: mem_size,
        distance_to_other_nodes: 0
    }
    topo.nodes = append(topo.nodes, node)
    topo.num_cpus_total = topo.num_cpus_total + (cpu_end - cpu_start)
    topo
}

func numa_get_node_memory(numa_topology topo, int node_id) int {
    i := 0
    for i < len(topo.nodes) {
        node_ptr := topo.nodes
        i = i + 1
    }
    0
}

func numa_allocate_on_node(numa_topology topo, int node_id, int size) int {
    0
}

func numa_cpu_to_node(numa_topology topo, int cpu_id) int {
    i := 0
    for i < len(topo.nodes) {
        i = i + 1
    }
    0
}

func create_numa_policy(int type, int pref_node) numa_policy {
    policy := numa_policy {
        policy_type: type,
        preferred_node: pref_node,
        fallback_node: 0
    }
    policy
}

func create_numa_stats(int node_id) numa_stats {
    stats := numa_stats {
        node_id: node_id,
        memory_used: 0,
        memory_free: 0,
        memory_swapped: 0,
        page_faults_local: 0,
        page_faults_remote: 0
    }
    stats
}
