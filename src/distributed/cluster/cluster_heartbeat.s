package neurx.distributed.cluster.heartbeat
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file, runtime_read_text_file, runtime_file_exists, runtime_env_get}

struct cluster_heartbeat_record {
    int node_id
    string node_name
    string host
    int rank
    int local_rank
    int timestamp_ms
    bool healthy
    string status
}

struct cluster_heartbeat_state {
    string heartbeat_dir
    string cluster_name
    int record_count
}

struct cluster_heartbeat_scan_result {
    int total_ranks
    int live_ranks
    int failed_ranks
    []int failed_rank_ids
    bool healthy
}

func cluster_heartbeat_zero_records(int capacity) []cluster_heartbeat_record {
    cluster_heartbeat_record[] records = []cluster_heartbeat_record{}
    int i = 0
    for i < capacity {
        records = append(records, cluster_heartbeat_record {
            node_id: 0,
            node_name: "",
            host: "",
            rank: 0,
            local_rank: 0,
            timestamp_ms: 0,
            healthy: false,
            status: ""
        })
        i = i + 1
    }
    records
}

func create_cluster_heartbeat_state(string cluster_name, string heartbeat_dir) cluster_heartbeat_state {
    if heartbeat_dir == "" {
        heartbeat_dir = "/tmp/neurx_cluster/heartbeat"
    }
    runtime_make_dirs(heartbeat_dir)
    cluster_heartbeat_state {
        heartbeat_dir: heartbeat_dir,
        cluster_name: cluster_name,
        record_count: 0
    }
}

func cluster_heartbeat_path(cluster_heartbeat_state state, int rank) string {
    state.heartbeat_dir + "/rank_" + itoa(rank) + ".txt"
}

func cluster_heartbeat_write(
    cluster_heartbeat_state state,
    int node_id,
    string node_name,
    string host,
    int rank,
    int local_rank,
    int timestamp_ms,
    bool healthy,
    string status,
) cluster_heartbeat_state {
    string path = cluster_heartbeat_path(state, rank)
    string payload = ""
    payload = payload + "cluster=" + state.cluster_name + "\n"
    payload = payload + "node_id=" + itoa(node_id) + "\n"
    payload = payload + "node_name=" + node_name + "\n"
    payload = payload + "host=" + host + "\n"
    payload = payload + "rank=" + itoa(rank) + "\n"
    payload = payload + "local_rank=" + itoa(local_rank) + "\n"
    payload = payload + "timestamp_ms=" + itoa(timestamp_ms) + "\n"
    payload = payload + "healthy=" + itoa(healthy ? 1 : 0) + "\n"
    payload = payload + "status=" + status + "\n"
    runtime_write_text_file(path, payload)
    state.record_count = state.record_count + 1
    state
}

func cluster_heartbeat_read(cluster_heartbeat_state state, int rank) string {
    string path = cluster_heartbeat_path(state, rank)
    if !runtime_file_exists(path) {
        return ""
    }
    runtime_read_text_file(path)
}

func cluster_heartbeat_is_live(cluster_heartbeat_state state, int rank) bool {
    string text = cluster_heartbeat_read(state, rank)
    text != ""
}

func cluster_heartbeat_scan(cluster_heartbeat_state state, int total_ranks) cluster_heartbeat_scan_result {
    cluster_heartbeat_scan_result result
    result.total_ranks = total_ranks
    result.live_ranks = 0
    result.failed_ranks = 0
    result.failed_rank_ids = []int{}
    int rank = 0
    for rank < total_ranks {
        if cluster_heartbeat_is_live(state, rank) {
            result.live_ranks = result.live_ranks + 1
        } else {
            result.failed_ranks = result.failed_ranks + 1
            result.failed_rank_ids = append(result.failed_rank_ids, rank)
        }
        rank = rank + 1
    }
    result.healthy = result.failed_ranks == 0
    result
}

func cluster_heartbeat_scan_summary(cluster_heartbeat_scan_result scan) string {
    string out = ""
    out = out + "total_ranks=" + itoa(scan.total_ranks) + "\n"
    out = out + "live_ranks=" + itoa(scan.live_ranks) + "\n"
    out = out + "failed_ranks=" + itoa(scan.failed_ranks) + "\n"
    out = out + "healthy=" + itoa(scan.healthy ? 1 : 0) + "\n"
    out
}

func cluster_heartbeat_summary(cluster_heartbeat_state state) string {
    string out = ""
    out = out + "cluster=" + state.cluster_name + "\n"
    out = out + "heartbeat_dir=" + state.heartbeat_dir + "\n"
    out = out + "records=" + itoa(state.record_count) + "\n"
    out
}

func cluster_heartbeat_default_dir() string {
    runtime_env_get("NEURX_HEARTBEAT_DIR", "/tmp/neurx_cluster/heartbeat")
}
