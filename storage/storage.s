int IO_READ       = 0
int IO_WRITE      = 1
int IO_READAHEAD  = 2
int IO_FLUSH      = 3
int IOPRIO_RT     = 0
int IOPRIO_NORMAL = 1
int IOPRIO_IDLE   = 2
int IOREQ_PENDING    = 0
int IOREQ_SUBMITTED  = 1
int IOREQ_COMPLETE   = 2
int IOREQ_ERROR      = 3
struct io_request {
    int    req_id
    int    op
    string path
    int    offset_bytes
    int    length_bytes
    int    priority
    int    state
    int    submitted_at_ms
    int    completed_at_ms
    string err
    int    owner_pid
}

struct io_ring {
    []io_request  submission_queue
    []io_request  completion_queue
    int           sq_head
    int           sq_tail
    int           depth
    int           next_req_id
}

struct storage_state {
    io_ring  ring
    int      total_capacity_mb
    int      used_mb
    []string mount_points
    bool     writeback_enabled
    int      writeback_dirty_mb
}

func new_storage_state(depth int, total_mb int) storage_state {
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

func io_submit(ss storage_state, op int, path string, offset int,
               length int, priority int, owner_pid int) (storage_state, int) {
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

func io_complete(ss storage_state, req_id int, err string) storage_state {
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

func io_poll(ss storage_state, owner_pid int) (storage_state, []io_request) {
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

func storage_readahead(ss storage_state, path string, offset int,
                       length int, owner_pid int) (storage_state, int) {
    return io_submit(ss, IO_READAHEAD, path, offset, length, IOPRIO_IDLE, owner_pid)
}

func storage_checkpoint_write(ss storage_state, path string,
                               data_bytes int, owner_pid int) (storage_state, int) {
    ss.writeback_dirty_mb = ss.writeback_dirty_mb + data_bytes / (1024 * 1024)
    return io_submit(ss, IO_WRITE, path, 0, data_bytes, IOPRIO_NORMAL, owner_pid)
}

