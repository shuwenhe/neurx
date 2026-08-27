import "types.s"

struct ExecutionScheduler {
    scheduling_policy   i32
    prefill_sequences   []string
    decode_sequences    []string
    pending_sequences   []string
    current_schedule    IterationSchedule
    schedule_count      i64
    total_scheduled     i64
}

func NewExecutionScheduler(policy i32) *ExecutionScheduler {
    return *ExecutionScheduler{
        scheduling_policy: policy,
        schedule_count: 0,
        total_scheduled: 0,
    }
}

func (ExecutionScheduler* es) AddPrefillSequence(sequence_id string) {
    es.prefill_sequences = append(es.prefill_sequences, sequence_id)
}

func (ExecutionScheduler* es) AddDecodeSequence(sequence_id string) {
    es.decode_sequences = append(es.decode_sequences, sequence_id)
}

func (ExecutionScheduler* es) PlanIteration(max_prefill i32, max_decode i32) IterationSchedule {
    schedule := IterationSchedule{
        iteration_id: es.schedule_count,
    }

    match es.scheduling_policy {
    case SCHEDULE_FCFS:
        schedule = es.schedule_fcfs(max_prefill, max_decode)
    case SCHEDULE_PRIORITY:
        schedule = es.schedule_priority(max_prefill, max_decode)
    case SCHEDULE_SJF:
        schedule = es.schedule_sjf(max_prefill, max_decode)
    case SCHEDULE_DYNAMIC:
        schedule = es.schedule_dynamic(max_prefill, max_decode)
    default:
        schedule = es.schedule_fcfs(max_prefill, max_decode)
    }

    es.schedule_count++
    es.total_scheduled += i64(schedule.prefill_count + schedule.decode_count)

    return schedule
}

func (ExecutionScheduler* es) schedule_fcfs(max_prefill i32, max_decode i32) IterationSchedule {
    schedule := IterationSchedule{
        iteration_id: es.schedule_count,
    }

    for i := 0; i < len(es.prefill_sequences) && i < int(max_prefill); i++ {
        schedule.prefill_batch = append(schedule.prefill_batch, es.prefill_sequences[i])
        schedule.prefill_count++
    }

    if schedule.prefill_count > 0 {
        es.prefill_sequences = es.prefill_sequences[schedule.prefill_count:]
    }

    for i := 0; i < len(es.decode_sequences) && i < int(max_decode); i++ {
        schedule.decode_batch = append(schedule.decode_batch, es.decode_sequences[i])
        schedule.decode_count++
    }

    if schedule.decode_count > 0 {
        es.decode_sequences = es.decode_sequences[schedule.decode_count:]
    }

    return schedule
}

func (ExecutionScheduler* es) schedule_priority(max_prefill i32, max_decode i32) IterationSchedule {
    schedule := IterationSchedule{
        iteration_id: es.schedule_count,
    }

    for i := 0; i < len(es.prefill_sequences) && i < int(max_prefill); i++ {
        schedule.prefill_batch = append(schedule.prefill_batch, es.prefill_sequences[i])
        schedule.prefill_count++
    }

    return schedule
}

func (ExecutionScheduler* es) schedule_sjf(max_prefill i32, max_decode i32) IterationSchedule {
    schedule := IterationSchedule{
        iteration_id: es.schedule_count,
    }

    for i := 0; i < len(es.decode_sequences) && i < int(max_decode); i++ {
        schedule.decode_batch = append(schedule.decode_batch, es.decode_sequences[i])
        schedule.decode_count++
    }

    return schedule
}

func (ExecutionScheduler* es) schedule_dynamic(max_prefill i32, max_decode i32) IterationSchedule {
    schedule := IterationSchedule{
        iteration_id: es.schedule_count,
    }

    prefill_ratio := len(es.prefill_sequences) / (len(es.prefill_sequences) + len(es.decode_sequences) + 1)

    if prefill_ratio > 50 {

        for i := 0; i < len(es.prefill_sequences) && i < int(max_prefill * 2); i++ {
            schedule.prefill_batch = append(schedule.prefill_batch, es.prefill_sequences[i])
            schedule.prefill_count++
        }
    } else {

        for i := 0; i < len(es.decode_sequences) && i < int(max_decode); i++ {
            schedule.decode_batch = append(schedule.decode_batch, es.decode_sequences[i])
            schedule.decode_count++
        }
    }

    return schedule
}

func (ExecutionScheduler* es) CombineIterations(max_total i32) IterationSchedule {
    schedule := IterationSchedule{
        iteration_id: es.schedule_count,
    }

    allocated := i32(0)

    for i := 0; i < len(es.prefill_sequences) && allocated < max_total; i++ {
        schedule.prefill_batch = append(schedule.prefill_batch, es.prefill_sequences[i])
        schedule.prefill_count++
        allocated++
    }

    remaining := max_total - allocated
    for i := 0; i < len(es.decode_sequences) && remaining > 0; i++ {
        schedule.decode_batch = append(schedule.decode_batch, es.decode_sequences[i])
        schedule.decode_count++
        remaining--
    }

    return schedule
}

func (ExecutionScheduler* es) GetPendingSequenceCount() i32 {
    return i32(len(es.prefill_sequences) + len(es.decode_sequences))
}

func (ExecutionScheduler* es) GetScheduleStatistics() map[string]i64 {
    stats := make(map[string]i64)
    stats["schedules_created"] = es.schedule_count
    stats["total_scheduled_seqs"] = es.total_scheduled
    stats["pending_prefill"] = i64(len(es.prefill_sequences))
    stats["pending_decode"] = i64(len(es.decode_sequences))

    return stats
}

func (ExecutionScheduler* es) ClearCompleted(completed_ids []string) {
    for i := 0; i < len(completed_ids); i++ {
        completed := completed_ids[i]

        new_prefill := make([]string, 0)
        for j := 0; j < len(es.prefill_sequences); j++ {
            if es.prefill_sequences[j] != completed {
                new_prefill = append(new_prefill, es.prefill_sequences[j])
            }
        }
        es.prefill_sequences = new_prefill

        new_decode := make([]string, 0)
        for j := 0; j < len(es.decode_sequences); j++ {
            if es.decode_sequences[j] != completed {
                new_decode = append(new_decode, es.decode_sequences[j])
            }
        }
        es.decode_sequences = new_decode
    }
}

func (ExecutionScheduler* es) EstimateLatency(schedule IterationSchedule) i32 {

    prefill_latency := schedule.prefill_count * 1
    decode_latency := schedule.decode_count * 1

    total := prefill_latency + decode_latency
    if total > 100 {
        total = 100
    }

    return total
}

func (ExecutionScheduler* es) GetNextBatch(batch_type i32, batch_size i32) []string {
    batch := make([]string, 0)

    if batch_type == PHASE_PREFILL {
        for i := 0; i < len(es.prefill_sequences) && i < int(batch_size); i++ {
            batch = append(batch, es.prefill_sequences[i])
        }
    } else if batch_type == PHASE_DECODE {
        for i := 0; i < len(es.decode_sequences) && i < int(batch_size); i++ {
            batch = append(batch, es.decode_sequences[i])
        }
    }

    return batch
}
