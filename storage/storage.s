// storage/storage.s
// AI OS storage layer — analogue of Linux block/ + drivers/nvme/ + fs/io_uring/
//
// Linux maps:
//   block/blk-core.c      → block I/O request queue
//   drivers/nvme/host/    → NVMe command submission (SQ/CQ rings)
//   io_uring/io_uring.c   → async I/O submission ring
//   mm/readahead.c        → readahead prefetch
//   fs/page-writeback.c   → writeback / dirty page flush
//
// NeurX maps:
//   AI workloads need storage for:
//     - Model weights (large sequential read, lazy tensor loading)
//     - KV cache offload (random read/write, latency-sensitive)
//     - Checkpoints (large sequential write, periodic)
//     - Vector index (random read, high IOPS)
//     - Datasets (streaming sequential read)
//
//   Uses a submission/completion ring model (io_uring-inspired) so that
//   the agent scheduler is never blocked by storage I/O.

// I/O operation types
int IO_READ       = 0
int IO_WRITE      = 1
int IO_READAHEAD  = 2   // prefetch hint
int IO_FLUSH      = 3   // fsync equivalent

// I/O priority (mirrors Linux IO scheduler classes)
int IOPRIO_RT     = 0   // KV cache, real-time inference
int IOPRIO_NORMAL = 1   // checkpoint save/restore
int IOPRIO_IDLE   = 2   // background dataset prefetch

// Request state
int IOREQ_PENDING    = 0
int IOREQ_SUBMITTED  = 1
int IOREQ_COMPLETE   = 2
int IOREQ_ERROR      = 3

struct io_request {
    int    req_id
    int    op              // IO_*
    string path            // VFS or raw path
    int    offset_bytes
    int    length_bytes
    int    priority        // IOPRIO_*
    int    state           // IOREQ_*
    int    submitted_at_ms
    int    completed_at_ms
    string err
    int    owner_pid       // agent that issued this request
}

struct io_ring {
    []io_request  submission_queue   // SQ: pending requests
    []io_request  completion_queue   // CQ: finished requests
    int           sq_head
    int           sq_tail
    int           depth              // max outstanding requests
    int           next_req_id
}

struct storage_state {
    io_ring  ring
    int      total_capacity_mb       // logical capacity
    int      used_mb
    []string mount_points            // e.g. ["neurx://weights", "/checkpoints"]
    bool     writeback_enabled
    int      writeback_dirty_mb      // how much dirty data is pending flush
}

func new_storage_state(depth int, total_mb int) -> storage_state {
    io_ring r = io_ring{
        submission_queue: [],
        completion_queue: [],
        sq_head:          0,
        sq_tail:          0,
        depth:            depth,
        next_req_id:      0,
    }
    return storage_state{
        ring:              r,
        total_capacity_mb: total_mb,
        used_mb:           0,
        mount_points:      [],
        writeback_enabled: true,
        writeback_dirty_mb: 0,
    }
}

// io_submit: enqueue an I/O request (like io_uring_enter with SQE)
func io_submit(ss storage_state, op int, path string, offset int,
               length int, priority int, owner_pid int) -> (storage_state, int) {
    int rid = ss.ring.next_req_id
    io_request req = io_request{
        req_id:          rid,
        op:              op,
        path:            path,
        offset_bytes:    offset,
        length_bytes:    length,
        priority:        priority,
        state:           IOREQ_PENDING,
        submitted_at_ms: 0,
        completed_at_ms: 0,
        err:             "",
        owner_pid:       owner_pid,
    }
    ss.ring.submission_queue = append(ss.ring.submission_queue, req)
    ss.ring.next_req_id      = ss.ring.next_req_id + 1
    return (ss, rid)
}

// io_complete: driver signals completion (like io_uring CQE post)
func io_complete(ss storage_state, req_id int, err string) -> storage_state {
    int i = 0
    while i < len(ss.ring.submission_queue) {
        if ss.ring.submission_queue[i].req_id == req_id {
            io_request r = ss.ring.submission_queue[i]
            if err == "" {
                r.state = IOREQ_COMPLETE
            } else {
                r.state = IOREQ_ERROR
                r.err   = err
            }
            ss.ring.completion_queue = append(ss.ring.completion_queue, r)

            // remove from SQ
            []io_request sq = []
            int j = 0
            while j < len(ss.ring.submission_queue) {
                if j != i {
                    sq = append(sq, ss.ring.submission_queue[j])
                }
                j = j + 1
            }
            ss.ring.submission_queue = sq
            return ss
        }
        i = i + 1
    }
    return ss
}

// io_poll: collect completed requests for an owner (like io_uring_peek_cqe)
func io_poll(ss storage_state, owner_pid int) -> (storage_state, []io_request) {
    []io_request done = []
    []io_request remaining = []
    int i = 0
    while i < len(ss.ring.completion_queue) {
        if ss.ring.completion_queue[i].owner_pid == owner_pid {
            done = append(done, ss.ring.completion_queue[i])
        } else {
            remaining = append(remaining, ss.ring.completion_queue[i])
        }
        i = i + 1
    }
    ss.ring.completion_queue = remaining
    return (ss, done)
}

// readahead: submit a prefetch hint for a tensor shard (like madvise MADV_WILLNEED)
func storage_readahead(ss storage_state, path string, offset int,
                       length int, owner_pid int) -> (storage_state, int) {
    return io_submit(ss, IO_READAHEAD, path, offset, length, IOPRIO_IDLE, owner_pid)
}

// checkpoint_write: submit a high-throughput sequential write
func storage_checkpoint_write(ss storage_state, path string,
                               data_bytes int, owner_pid int) -> (storage_state, int) {
    ss.writeback_dirty_mb = ss.writeback_dirty_mb + data_bytes / (1024 * 1024)
    return io_submit(ss, IO_WRITE, path, 0, data_bytes, IOPRIO_NORMAL, owner_pid)
}
