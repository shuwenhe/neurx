package main
use neurx.inference.runtime.production_batch_runtime.{production_batch_config, production_batch_runtime, production_batch_selection, production_admission_result, new_production_batch_runtime, production_admit, production_schedule, production_mark_prefill_complete, production_record_decode, production_cancel, production_request_decode, production_request_finished, production_free_page_count}

func require(bool condition, string message) {
    if !condition { print("FAIL: " + message + "\n"); return }
}

func main() {
    production_batch_runtime runtime = new_production_batch_runtime(production_batch_config {request_capacity: 4, page_capacity: 16, page_size: 4, maximum_pages_per_request: 8, maximum_batch_sequences: 4, maximum_batch_tokens: 16})
    production_admission_result first = production_admit(runtime, 101, 1001, 5, 3)
    runtime = first.runtime
    production_admission_result second = production_admit(runtime, 102, 1002, 4, 4)
    runtime = second.runtime
    require(first.accepted && second.accepted, "two sessions admitted")
    require(runtime.allocated_pages == 4, "paged KV admission")
    production_batch_selection prefill = production_schedule(runtime)
    runtime = prefill.runtime
    require(prefill.prefill_count == 2 && prefill.prefill_tokens == 9, "continuous prefill batch")
    runtime = production_mark_prefill_complete(runtime, prefill.prefill_slot, prefill.prefill_count)
    require(runtime.status[first.slot] == production_request_decode() && runtime.status[second.slot] == production_request_decode(), "prefill to decode transition")
    production_batch_selection decode = production_schedule(runtime)
    runtime = decode.runtime
    require(decode.decode_count == 2 && decode.decode_tokens == 2, "continuous decode batch")
    runtime = production_record_decode(runtime, first.slot, 3, false)
    require(runtime.status[first.slot] == production_request_finished(), "maximum token completion")
    runtime = production_cancel(runtime, 102)
    require(runtime.active_requests == 0 && production_free_page_count(runtime) == 16, "cancel releases paged KV")
    print("PASS: unified S Session + Continuous Batch + Paged KV runtime\n")
}
