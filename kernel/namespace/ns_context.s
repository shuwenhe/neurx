package neurx.kernel.namespace

use std.slices

struct pid_namespace {
    int ns_id
    int parent_id
    int highest_pid
    int level
}

struct net_namespace {
    int ns_id
    int[] network_interfaces
    int routing_table_id
}

struct mount_namespace {
    int ns_id
    int root_mount_id
    int[] mounted_filesystems
}

struct ipc_namespace {
    int ns_id
    int[] message_queues
    int[] semaphore_sets
    int[] shared_memory_ids
}

struct uts_namespace {
    int ns_id
    string hostname
    string domainname
}

struct namespace_context {
    pid_namespace pid_ns
    net_namespace net_ns
    mount_namespace mnt_ns
    ipc_namespace ipc_ns
    uts_namespace uts_ns
}

struct namespace_container {
    int container_id
    namespace_context nctx
    int running
}

func create_pid_namespace(int parent_id, int level) pid_namespace {
    ns := pid_namespace {
        ns_id: 0,
        parent_id: parent_id,
        highest_pid: 0,
        level: level
    }
    ns
}

func create_net_namespace() net_namespace {
    ns := net_namespace {
        ns_id: 0,
        network_interfaces: int[](),
        routing_table_id: 0
    }
    ns
}

func create_mount_namespace() mount_namespace {
    ns := mount_namespace {
        ns_id: 0,
        root_mount_id: 0,
        mounted_filesystems: int[]()
    }
    ns
}

func create_ipc_namespace() ipc_namespace {
    ns := ipc_namespace {
        ns_id: 0,
        message_queues: int[](),
        semaphore_sets: int[](),
        shared_memory_ids: int[]()
    }
    ns
}

func create_uts_namespace(string hostname) uts_namespace {
    ns := uts_namespace {
        ns_id: 0,
        hostname: hostname,
        domainname: hostname
    }
    ns
}

func create_namespace_context() namespace_context {
    ctx := namespace_context {
        pid_ns: create_pid_namespace(0, 0),
        net_ns: create_net_namespace(),
        mnt_ns: create_mount_namespace(),
        ipc_ns: create_ipc_namespace(),
        uts_ns: create_uts_namespace("neurx")
    }
    ctx
}

func create_namespace_container() namespace_container {
    container := namespace_container {
        container_id: 0,
        nctx: create_namespace_context(),
        running: 0
    }
    container
}

func namespace_container_start(namespace_container container) namespace_container {
    container.running = 1
    container
}

func namespace_container_stop(namespace_container container) namespace_container {
    container.running = 0
    container
}
