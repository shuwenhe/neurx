package neurx.tests.paged_continuous_batch_test
import "neurx.attention.paged_attention_memory"
import "neurx.scheduler.continuous_batch_scheduler"

func test_paged_kv_allocation() bool {
    mgr := paged_attention_memory.new_paged_kv_cache_manager(
        100,
        16,
        24,
        32,
        4096,
    )
    mgr, blocks := paged_attention_memory.allocate_blocks(mgr, 0, 64)
    if len(blocks) != 4 {
        return false
    }
    if mgr.allocated_blocks != 4 {
        return false
    }
    i := 0
    for i < len(blocks) {
        if blocks[i] < 0 || blocks[i] >= 100 {
            return false
        }
        i = i + 1
    }
    true
}

func test_paged_kv_multiple_sequences() bool {
    mgr := paged_attention_memory.new_paged_kv_cache_manager(200, 16, 24, 32, 4096)
    mgr, blocks1 := paged_attention_memory.allocate_blocks(mgr, 0, 64)
    mgr, blocks2 := paged_attention_memory.allocate_blocks(mgr, 1, 128)
    mgr, blocks3 := paged_attention_memory.allocate_blocks(mgr, 2, 32)
    if len(blocks1) != 4 {
        return false
    }
    if len(blocks2) != 8 {
        return false
    }
    if len(blocks3) != 2 {
        return false
    }
    if mgr.allocated_blocks != 14 {
        return false
    }
    true
}

func test_paged_kv_free() bool {
    mgr := paged_attention_memory.new_paged_kv_cache_manager(100, 16, 24, 32, 4096)
    mgr, _ := paged_attention_memory.allocate_blocks(mgr, 0, 64)
    if mgr.allocated_blocks != 4 {
        return false
    }
    mgr = paged_attention_memory.free_sequence_blocks(mgr, 0)
    if mgr.allocated_blocks != 0 {
        return false
    }
    if mgr.freed_blocks != 4 {
        return false
    }
    true
}

func test_paged_kv_block_copy() bool {
    mgr := paged_attention_memory.new_paged_kv_cache_manager(100, 16, 24, 32, 4096)
    src_blocks := []int{0, 1, 2, 3}
    dst_blocks := []int{10, 11, 12, 13}
    mgr = paged_attention_memory.copy_blocks(mgr, src_blocks, dst_blocks)
    if mgr.cache_hits != 4 {
        return false
    }
    true
}

func test_paged_kv_utilization() bool {
    mgr := paged_attention_memory.new_paged_kv_cache_manager(100, 16, 24, 32, 4096)
    mgr, _ := paged_attention_memory.allocate_blocks(mgr, 0, 800)
    if mgr.allocated_blocks <= 0 {
        return false
    }
    stats := paged_attention_memory.get_cache_stats(mgr)
    if len(stats) == 0 {
        return false
    }
    true
}

func test_continuous_batch_creation() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    if sched.batch_capacity != 32 {
        return false
    }
    if sched.active_requests != 0 {
        return false
    }
    true
}

func test_continuous_batch_add_request() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input_ids := []int{1, 2, 3, 4, 5}
    sched = continuous_batch_scheduler.add_request(
        sched,
        0,
        input_ids,
        50,
        0.7,
        0.9,
        40,
    )
    if sched.queued_requests != 1 {
        return false
    }
    if sched.total_prefill_tokens != 5 {
        return false
    }
    true
}

func test_continuous_batch_schedule() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input1 := []int{1, 2, 3, 4, 5}
    sched = continuous_batch_scheduler.add_request(sched, 0, input1, 50, 0.7, 0.9, 40)
    input2 := []int{10, 11, 12}
    sched = continuous_batch_scheduler.add_request(sched, 1, input2, 40, 0.8, 0.85, 50)
    sched = continuous_batch_scheduler.schedule_batch(sched)
    prefill := continuous_batch_scheduler.get_prefill_batch(sched)
    if prefill.num_requests != 2 {
        return false
    }
    if prefill.total_tokens != 8 {
        return false
    }
    true
}

func test_continuous_batch_decode_step() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input := []int{1, 2, 3}
    sched = continuous_batch_scheduler.add_request(sched, 0, input, 50, 0.7, 0.9, 40)
    sched = continuous_batch_scheduler.schedule_batch(sched)
    sched = continuous_batch_scheduler.record_decode_step(sched, 0, 100)
    sched = continuous_batch_scheduler.record_decode_step(sched, 0, 101)
    req := continuous_batch_scheduler.get_request(sched, 0)
    if len(req.output_ids) != 2 {
        return false
    }
    if req.num_decode_steps != 2 {
        return false
    }
    if sched.total_tokens_generated != 2 {
        return false
    }
    true
}

func test_continuous_batch_multiple_requests() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(64)
    i := 0
    for i < 5 {
        input := []int{i + 1, i + 2, i + 3}
        sched = continuous_batch_scheduler.add_request(
            sched,
            i,
            input,
            50,
            0.7,
            0.9,
            40,
        )
        i = i + 1
    }
    if sched.queued_requests != 5 {
        return false
    }
    sched = continuous_batch_scheduler.schedule_batch(sched)
    prefill := continuous_batch_scheduler.get_prefill_batch(sched)
    if prefill.num_requests != 5 {
        return false
    }
    true
}

func test_continuous_batch_prefill_decode_separation() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input1 := []int{1, 2, 3}
    sched = continuous_batch_scheduler.add_request(sched, 0, input1, 50, 0.7, 0.9, 40)
    sched = continuous_batch_scheduler.schedule_batch(sched)
    prefill := continuous_batch_scheduler.get_prefill_batch(sched)
    if prefill.num_requests != 1 {
        return false
    }
    sched = continuous_batch_scheduler.record_decode_step(sched, 0, 100)
    input2 := []int{10, 11, 12, 13}
    sched = continuous_batch_scheduler.add_request(sched, 1, input2, 40, 0.8, 0.85, 50)
    sched = continuous_batch_scheduler.schedule_batch(sched)
    prefill = continuous_batch_scheduler.get_prefill_batch(sched)
    decode := continuous_batch_scheduler.get_decode_batch(sched)
    if prefill.num_requests != 1 {
        return false
    }
    if decode.num_requests != 1 {
        return false
    }
    true
}

func test_continuous_batch_max_tokens_limit() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input := []int{1, 2}
    sched = continuous_batch_scheduler.add_request(sched, 0, input, 5, 0.7, 0.9, 40)
    sched = continuous_batch_scheduler.schedule_batch(sched)
    i := 0
    for i < 5 {
        sched = continuous_batch_scheduler.record_decode_step(sched, 0, 100 + i)
        i = i + 1
    }
    req := continuous_batch_scheduler.get_request(sched, 0)
    if req.status != 3 {
        return false
    }
    true
}

func test_continuous_batch_stats() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input := []int{1, 2, 3}
    sched = continuous_batch_scheduler.add_request(sched, 0, input, 50, 0.7, 0.9, 40)
    sched = continuous_batch_scheduler.schedule_batch(sched)
    stats := continuous_batch_scheduler.get_scheduler_stats(sched)
    if len(stats) == 0 {
        return false
    }
    true
}

func test_continuous_batch_reset() bool {
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(32)
    input := []int{1, 2}
    sched = continuous_batch_scheduler.add_request(sched, 0, input, 50, 0.7, 0.9, 40)
    if sched.total_prefill_tokens != 2 {
        return false
    }
    sched = continuous_batch_scheduler.reset_scheduler(sched)
    if sched.total_prefill_tokens != 0 {
        return false
    }
    if len(sched.requests) != 0 {
        return false
    }
    true
}

func test_paged_attention_with_scheduling() bool {
    mgr := paged_attention_memory.new_paged_kv_cache_manager(200, 16, 24, 32, 4096)
    sched := continuous_batch_scheduler.new_continuous_batch_scheduler(64)
    i := 0
    for i < 3 {
        input := make([]int, i + 2)
        j := 0
        for j < i + 2 {
            input[j] = j + 1
            j = j + 1
        }
        sched = continuous_batch_scheduler.add_request(sched, i, input, 50, 0.7, 0.9, 40)
        i = i + 1
    }
    sched = continuous_batch_scheduler.schedule_batch(sched)
    prefill := continuous_batch_scheduler.get_prefill_batch(sched)
    i = 0
    for i < prefill.num_requests {
        req_id := prefill.request_ids[i]
        req := continuous_batch_scheduler.get_request(sched, req_id)
        mgr, blocks := paged_attention_memory.allocate_blocks(
            mgr,
            req_id,
            req.num_prefill_tokens,
        )
        if len(blocks) == 0 {
            return false
        }
        i = i + 1
    }
    if mgr.allocated_blocks <= 0 {
        return false
    }
    true
}

func run_all_tests() bool {
    tests := []string{
        "test_paged_kv_allocation",
        "test_paged_kv_multiple_sequences",
        "test_paged_kv_free",
        "test_paged_kv_block_copy",
        "test_paged_kv_utilization",
        "test_continuous_batch_creation",
        "test_continuous_batch_add_request",
        "test_continuous_batch_schedule",
        "test_continuous_batch_decode_step",
        "test_continuous_batch_multiple_requests",
        "test_continuous_batch_prefill_decode_separation",
        "test_continuous_batch_max_tokens_limit",
        "test_continuous_batch_stats",
        "test_continuous_batch_reset",
        "test_paged_attention_with_scheduling",
    }
    passed := 0
    failed := 0
    if test_paged_kv_allocation() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_paged_kv_multiple_sequences() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_paged_kv_free() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_paged_kv_block_copy() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_paged_kv_utilization() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_creation() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_add_request() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_schedule() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_decode_step() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_multiple_requests() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_prefill_decode_separation() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_max_tokens_limit() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_stats() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_continuous_batch_reset() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    if test_paged_attention_with_scheduling() {
        passed = passed + 1
    } else {
        failed = failed + 1
    }
    printf("========== Test Results ==========\n")
    printf("Passed: %d/%d\n", passed, len(tests))
    printf("Failed: %d/%d\n", failed, len(tests))
    printf("==================================\n")
    failed == 0
}

func main() {
    success := run_all_tests()
    if success {
        printf("✅ All tests passed!\n")
    } else {
        printf("❌ Some tests failed!\n")
    }
}
