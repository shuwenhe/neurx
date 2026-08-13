int GPU_NVIDIA = 0
int GPU_AMD    = 1
int GPU_APPLE  = 2
int GPU_ASCEND = 3
int STREAM_HIGH   = 0
int STREAM_NORMAL = 1
int STREAM_LOW    = 2
int JOB_PENDING   = 0
int JOB_RUNNING   = 1
int JOB_DONE      = 2
int JOB_ERROR     = 3

struct gpu_device {
    int    gpu_id
    int    gpu_type
    string name
    int    total_mem_mb
    int    free_mem_mb
    int    sm_count
    int    max_streams
    bool   available
    string driver_version
}

struct gpu_stream {
    int    stream_id
    int    gpu_id
    int    priority
    bool   active
    int    pending_jobs
    int    completed_jobs
}

struct gpu_job {
    int    job_id
    int    stream_id
    string kernel_name
    int    grid_x
    int    grid_y
    int    block_size
    int    shared_mem_bytes
    int    state
    int    submitted_at_ms
    int    completed_at_ms
    string err
}

struct gpu_fence {
    int    fence_id
    int    stream_id
    bool   signaled
}

struct gpu_state {
    []gpu_device devices
    []gpu_stream  streams
    []gpu_job     jobs
    []gpu_fence   fences
    int           next_stream_id
    int           next_job_id
    int           next_fence_id
}

func new_gpu_state() gpu_state {
    return gpu_state{
        devices:         [],
        streams:         [],
        jobs:            [],
        fences:          [],
        next_stream_id:  0,
        next_job_id:     0,
        next_fence_id:   0,
    }
}

func gpu_register(gs gpu_state, gpu_type int, name string, total_mem_mb int,
                  sm_count int, max_streams int, driver_version string) (gpu_state, int) {
    int id = len(gs.devices)
    gpu_device d = gpu_device{
        gpu_id:         id,
        gpu_type:       gpu_type,
        name:           name,
        total_mem_mb:   total_mem_mb,
        free_mem_mb:    total_mem_mb,
        sm_count:       sm_count,
        max_streams:    max_streams,
        available:      true,
        driver_version: driver_version,
    }
    gs.devices = append(gs.devices, d)
    return (gs, id)
}

func gpu_stream_create(gs gpu_state, int gpu_id, int priority) (gpu_state, int) {
    int sid = gs.next_stream_id
    gpu_stream s = gpu_stream{
        stream_id:      sid,
        gpu_id:         gpu_id,
        priority:       priority,
        active:         true,
        pending_jobs:   0,
        completed_jobs: 0,
    }
    gs.streams = append(gs.streams, s)
    gs.next_stream_id = gs.next_stream_id + 1
    return (gs, sid)
}

func gpu_submit_job(gs gpu_state, stream_id int, kernel_name string,
                    grid_x int, grid_y int, block_size int, shared_mem_bytes int) (gpu_state, int) {
    int jid = gs.next_job_id
    gpu_job j = gpu_job{
        job_id:          jid,
        stream_id:       stream_id,
        kernel_name:     kernel_name,
        grid_x:          grid_x,
        grid_y:          grid_y,
        block_size:      block_size,
        shared_mem_bytes: shared_mem_bytes,
        state:           JOB_PENDING,
        submitted_at_ms: 0,
        completed_at_ms: 0,
        err:             "",
    }
    gs.jobs = append(gs.jobs, j)
    gs.next_job_id = gs.next_job_id + 1
    int i = 0
    while i < len(gs.streams) {
        if gs.streams[i].stream_id == stream_id {
            gs.streams[i].pending_jobs = gs.streams[i].pending_jobs + 1
        }
        i = i + 1
    }
    return (gs, jid)
}

func gpu_record_fence(gs gpu_state, int stream_id) (gpu_state, int) {
    int fid = gs.next_fence_id
    gpu_fence f = gpu_fence{fence_id: fid, stream_id: stream_id, signaled: false}
    gs.fences = append(gs.fences, f)
    gs.next_fence_id = gs.next_fence_id + 1
    return (gs, fid)
}

func gpu_complete_job(gs gpu_state, int job_id) gpu_state {
    int i = 0
    while i < len(gs.jobs) {
        if gs.jobs[i].job_id == job_id {
            gs.jobs[i].state           = JOB_DONE
            gs.jobs[i].completed_at_ms = 0
            int sid = gs.jobs[i].stream_id
            int j = 0
            while j < len(gs.fences) {
                if gs.fences[j].stream_id == sid {
                    gs.fences[j].signaled = true
                }
                j = j + 1
            }
            int k = 0
            while k < len(gs.streams) {
                if gs.streams[k].stream_id == sid {
                    gs.streams[k].pending_jobs   = gs.streams[k].pending_jobs - 1
                    gs.streams[k].completed_jobs = gs.streams[k].completed_jobs + 1
                }
                k = k + 1
            }
        }
        i = i + 1
    }
    return gs
}

func gpu_fence_query(gs gpu_state, int fence_id) bool {
    int i = 0
    while i < len(gs.fences) {
        if gs.fences[i].fence_id == fence_id {
            return gs.fences[i].signaled
        }
        i = i + 1
    }
    return false
}
