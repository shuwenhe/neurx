package neurx.scheduler.continuous_batch_scheduler
struct batch_request {
    int request_id
    int status
    int[] input_ids
    int[] output_ids
    int num_prefill_tokens
    int num_decode_steps
    int max_tokens
    float temperature
    float top_p
    int top_k
}

struct prefill_batch {
    int[] request_ids
    int total_tokens
    int num_requests
}

struct decode_batch {
    int[] request_ids
    int num_requests
}

struct continuous_batch_scheduler {
    []batch_request requests
    prefill_batch prefill_batch
    decode_batch decode_batch
    int batch_capacity
    int active_requests
    int queued_requests
    int scheduling_round
    int total_prefill_tokens
    int total_decode_steps
    float average_acceptance_rate
    int total_tokens_generated
}

func new_continuous_batch_scheduler(int batch_capacity) continuous_batch_scheduler {
    []batch_request requests = make([]batch_request, 0)
    prefill_batch prefill = prefill_batch {
        request_ids: make(int[], 0),
        total_tokens: 0,
        num_requests: 0,
    }
    decode_batch decode = decode_batch {
        request_ids: make(int[], 0),
        num_requests: 0,
    }
    continuous_batch_scheduler {
        requests: requests,
        prefill_batch: prefill,
        decode_batch: decode,
        batch_capacity: batch_capacity,
        active_requests: 0,
        queued_requests: 0,
        scheduling_round: 0,
        total_prefill_tokens: 0,
        total_decode_steps: 0,
        average_acceptance_rate: 0.75,
        total_tokens_generated: 0,
    }
}

func add_request(
    continuous_batch_scheduler sched,
    int request_id,
    int[] input_ids,
    int max_tokens,
    float temperature,
    float top_p,
    int top_k
) continuous_batch_scheduler {
    req := batch_request {
        request_id: request_id,
        status: REQUEST_WAITING,
        input_ids: input_ids,
        output_ids: make(int[], 0),
        num_prefill_tokens: len(input_ids),
        num_decode_steps: 0,
        max_tokens: max_tokens,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
    }
    sched.requests = append(sched.requests, req)
    sched.queued_requests = sched.queued_requests + 1
    sched.total_prefill_tokens = sched.total_prefill_tokens + len(input_ids)
    sched
}

func schedule_batch(
    continuous_batch_scheduler sched
) continuous_batch_scheduler {
    sched.prefill_batch = prefill_batch {
        request_ids: make(int[], 0),
        total_tokens: 0,
        num_requests: 0,
    }
    sched.decode_batch = decode_batch {
        request_ids: make(int[], 0),
        num_requests: 0,
    }
    prefill_capacity := sched.batch_capacity
    i := 0
    for i < len(sched.requests) {
        req := sched.requests[i]
        if req.status == REQUEST_WAITING && prefill_capacity > 0 {
            if req.num_prefill_tokens <= prefill_capacity {
                sched.prefill_batch.request_ids = append(
                    sched.prefill_batch.request_ids,
                    req.request_id,
                )
                sched.prefill_batch.total_tokens = sched.prefill_batch.total_tokens + req.num_prefill_tokens
                sched.prefill_batch.num_requests = sched.prefill_batch.num_requests + 1
                sched.requests[i].status = REQUEST_PREFILL
                prefill_capacity = prefill_capacity - req.num_prefill_tokens
            }
        }
        i = i + 1
    }
    decode_capacity := sched.batch_capacity - sched.prefill_batch.total_tokens
    i = 0
    for i < len(sched.requests) {
        req := sched.requests[i]
        if (req.status == REQUEST_PREFILL || req.status == REQUEST_DECODE) &&
            len(req.output_ids) < req.max_tokens &&
            decode_capacity > 0 {
            if 1 <= decode_capacity {
                sched.decode_batch.request_ids = append(
                    sched.decode_batch.request_ids,
                    req.request_id,
                )
                sched.decode_batch.num_requests = sched.decode_batch.num_requests + 1
                sched.requests[i].status = REQUEST_DECODE
                decode_capacity = decode_capacity - 1
            }
        }
        i = i + 1
    }
    sched.active_requests = sched.prefill_batch.num_requests + sched.decode_batch.num_requests
    sched.scheduling_round = sched.scheduling_round + 1
    sched
}

func record_decode_step(
    continuous_batch_scheduler sched,
    int request_id,
    int token_id
) continuous_batch_scheduler {
    i := 0
    for i < len(sched.requests) {
        if sched.requests[i].request_id == request_id {
            sched.requests[i].output_ids = append(sched.requests[i].output_ids, token_id)
            sched.requests[i].num_decode_steps = sched.requests[i].num_decode_steps + 1
            sched.total_decode_steps = sched.total_decode_steps + 1
            sched.total_tokens_generated = sched.total_tokens_generated + 1
            if len(sched.requests[i].output_ids) >= sched.requests[i].max_tokens {
                sched.requests[i].status = REQUEST_FINISHED
            }
            break
        }
        i = i + 1
    }
    sched
}

func finish_request(
    continuous_batch_scheduler sched,
    int request_id
) continuous_batch_scheduler {
    i := 0
    for i < len(sched.requests) {
        if sched.requests[i].request_id == request_id {
            sched.requests[i].status = REQUEST_FINISHED
            break
        }
        i = i + 1
    }
    sched
}

func get_request(
    continuous_batch_scheduler sched,
    int request_id
) batch_request {
    empty := batch_request {
        request_id: -1,
        status: REQUEST_WAITING,
        input_ids: make(int[], 0),
        output_ids: make(int[], 0),
        num_prefill_tokens: 0,
        num_decode_steps: 0,
        max_tokens: 0,
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
    }
    i := 0
    for i < len(sched.requests) {
        if sched.requests[i].request_id == request_id {
            return sched.requests[i]
        }
        i = i + 1
    }
    empty
}

func get_scheduler_stats(continuous_batch_scheduler sched) string {
    prefill_requests := sched.prefill_batch.num_requests
    decode_requests := sched.decode_batch.num_requests
    total_active := sched.active_requests
    gpu_utilization := 0
    if sched.batch_capacity > 0 {
        gpu_utilization = (total_active * 100) / sched.batch_capacity
    }
    finished_count := 0
    i := 0
    for i < len(sched.requests) {
        if sched.requests[i].status == REQUEST_FINISHED {
            finished_count = finished_count + 1
        }
        i = i + 1
    }
    "Continuous Batch Scheduler Stats:\n" +
    "Prefill Requests: " + string(prefill_requests) + "\n" +
    "Decode Requests: " + string(decode_requests) + "\n" +
    "Active Requests: " + string(total_active) + "\n" +
    "GPU Utilization: " + string(gpu_utilization) + "%\n" +
    "Scheduling Rounds: " + string(sched.scheduling_round) + "\n" +
    "Total Prefill Tokens: " + string(sched.total_prefill_tokens) + "\n" +
    "Total Decode Steps: " + string(sched.total_decode_steps) + "\n" +
    "Total Tokens Generated: " + string(sched.total_tokens_generated) + "\n" +
    "Finished Requests: " + string(finished_count) + "\n" +
    "Average Acceptance Rate: " + string(sched.average_acceptance_rate * 100) + "%"
}

func get_prefill_batch(
    continuous_batch_scheduler sched
) prefill_batch {
    sched.prefill_batch
}

func get_decode_batch(
    continuous_batch_scheduler sched
) decode_batch {
    sched.decode_batch
}

func reset_scheduler(continuous_batch_scheduler sched) continuous_batch_scheduler {
    continuous_batch_scheduler {
        requests: make([]batch_request, 0),
        prefill_batch: prefill_batch {
            request_ids: make(int[], 0),
            total_tokens: 0,
            num_requests: 0,
        },
        decode_batch: decode_batch {
            request_ids: make(int[], 0),
            num_requests: 0,
        },
        batch_capacity: sched.batch_capacity,
        active_requests: 0,
        queued_requests: 0,
        scheduling_round: 0,
        total_prefill_tokens: 0,
        total_decode_steps: 0,
        average_acceptance_rate: sched.average_acceptance_rate,
        total_tokens_generated: 0,
    }
}

func main() {
}
