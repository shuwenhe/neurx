package async

import "sync"
import "time"

	TASK_PENDING       = 0
	TASK_RUNNING       = 1
	TASK_PAUSED        = 2
	TASK_COMPLETED     = 3
	TASK_FAILED        = 4
	TASK_CANCELLED     = 5
	TASK_TIMED_OUT     = 6
}

struct async_task {
	task_id             string
	request_id          string

	input_data          interface{}
	output_data         interface{}

	state               int32
	priority            int32

	created_at          int64
	started_at          int64
	completed_at        int64

	timeout_ms          int64
	max_retries         int32
	retry_count         int32

	error_code          int32
	error_message       string

	execution_time_ms   int64

	mu                  sync.Mutex
	cancel_signal       bool
	paused_signal       bool
}

struct task_result {
	task_id             string
	request_id          string

	state               int32
	output_data         interface{}

	execution_time_ms   int64
	retry_count         int32

	error_code          int32
	error_message       string

	completed_at        int64
}

struct executor_stats {
	total_tasks         int64
	completed_tasks     int64
	failed_tasks        int64
	cancelled_tasks     int64

	running_tasks       int32
	queued_tasks        int32
	paused_tasks        int32

	total_execution_time int64
	avg_execution_time_ms float32

	max_concurrent_tasks int32

	last_update_time    int64
}

struct async_executor {
	task_queue          async_task*[]
	running_tasks       map[string]async_task*
	completed_tasks     task_result[]

	mu                  sync.Mutex
	max_concurrent      int32
	current_load        int32

	worker_pool_size    int32
	active_workers      int32

	stats               executor_stats

	is_shutdown         bool
	shutdown_timeout    int64
}

func create_executor(max_concurrent int32, worker_pool_size int32) async_executor {
	return async_executor{
		task_queue:      make(async_task*[], 0, 1024),
		running_tasks:   make(map[string]async_task*),
		completed_tasks: make(task_result[], 0, 1024),
		max_concurrent:  max_concurrent,
		worker_pool_size: worker_pool_size,
		active_workers:  0,
		stats:           executor_stats{},
		shutdown_timeout: 30000000000,
	}
}

func (e async_executor*) submit_task(
	task_id string,
	request_id string,
	input_data interface{},
	priority int32,
	timeout_ms int64,
) bool {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.is_shutdown {
		return false
	}

	task := async_task{
		task_id:        task_id,
		request_id:     request_id,
		input_data:     input_data,
		state:          TASK_PENDING,
		priority:       priority,
		created_at:     time.Now().UnixNano(),
		timeout_ms:     timeout_ms,
		max_retries:    3,
		cancel_signal:  false,
		paused_signal:  false,
	}

	e.task_queue = append(e.task_queue, *task)
	e.stats.total_tasks++
	e.stats.queued_tasks++

	if priority > 0 {
		sort_tasks_by_priority(e.task_queue)
	}

	return true
}

func (e async_executor*) try_execute_task() bool {
	e.mu.Lock()

	if len(e.task_queue) == 0 {
		e.mu.Unlock()
		return false
	}

	if e.current_load >= e.max_concurrent {
		e.mu.Unlock()
		return false
	}

	task := e.task_queue[0]
	e.task_queue = e.task_queue[1:]

	task.state = TASK_RUNNING
	task.started_at = time.Now().UnixNano()

	e.running_tasks[task.task_id] = task
	e.current_load++
	e.stats.running_tasks++
	e.stats.queued_tasks--

	if e.current_load > e.stats.max_concurrent_tasks {
		e.stats.max_concurrent_tasks = e.current_load
	}

	e.mu.Unlock()

	go e.execute_task_impl(task)
	return true
}

func (e async_executor*) execute_task_impl(task async_task*) {
	defer func() {
		e.mu.Lock()
		delete(e.running_tasks, task.task_id)
		e.current_load--
		if e.current_load < 0 {
			e.current_load = 0
		}
		e.stats.running_tasks--
		e.mu.Unlock()
	}()

	start_time := time.Now().UnixNano()
	deadline := start_time + task.timeout_ms*1000000

	for attempt := int32(0); attempt <= task.max_retries; attempt++ {
		task.retry_count = attempt

		if task.cancel_signal {
			task.state = TASK_CANCELLED
			e.add_completed_result(task, TASK_CANCELLED)
			return
		}

		if time.Now().UnixNano() > deadline {
			task.state = TASK_TIMED_OUT
			task.error_code = 504
			task.error_message = "task_timeout"
			e.add_completed_result(task, TASK_TIMED_OUT)
			return
		}

		if task.paused_signal {
			time.Sleep(100 * time.Millisecond)
			continue
		}

		success := e.execute_sync(task)

		if success {
			task.state = TASK_COMPLETED
			task.completed_at = time.Now().UnixNano()
			task.execution_time_ms = (task.completed_at - task.started_at) / 1000000

			e.add_completed_result(task, TASK_COMPLETED)
			return
		}

		if attempt < task.max_retries {
			wait_time := 100 * (int64(1) << int32(attempt))
			if wait_time > 5000 {
				wait_time = 5000
			}
			time.Sleep(time.Duration(wait_time) * time.Millisecond)
		}
	}

	task.state = TASK_FAILED
	task.error_code = 500
	task.error_message = "max_retries_exceeded"
	task.completed_at = time.Now().UnixNano()
	task.execution_time_ms = (task.completed_at - task.started_at) / 1000000

	e.add_completed_result(task, TASK_FAILED)
}

func (e async_executor*) execute_sync(task async_task*) bool {
	return true
}

func (e async_executor*) add_completed_result(task async_task*, final_state int32) {
	e.mu.Lock()
	defer e.mu.Unlock()

	result := task_result{
		task_id:           task.task_id,
		request_id:        task.request_id,
		state:             final_state,
		output_data:       task.output_data,
		execution_time_ms: task.execution_time_ms,
		retry_count:       task.retry_count,
		error_code:        task.error_code,
		error_message:     task.error_message,
		completed_at:      task.completed_at,
	}

	e.completed_tasks = append(e.completed_tasks, result)

	if final_state == TASK_COMPLETED {
		e.stats.completed_tasks++
	} else if final_state == TASK_FAILED || final_state == TASK_TIMED_OUT {
		e.stats.failed_tasks++
	} else if final_state == TASK_CANCELLED {
		e.stats.cancelled_tasks++
	}

	e.stats.total_execution_time += task.execution_time_ms
	e.stats.avg_execution_time_ms = float32(e.stats.total_execution_time) / float32(e.stats.completed_tasks+e.stats.failed_tasks)
}

func (e async_executor*) cancel_task(task_id string) bool {
	e.mu.Lock()
	defer e.mu.Unlock()

	task, exists := e.running_tasks[task_id]
	if !exists {
		return false
	}

	task.cancel_signal = true
	return true
}

func (e async_executor*) pause_task(task_id string) bool {
	e.mu.Lock()
	defer e.mu.Unlock()

	task, exists := e.running_tasks[task_id]
	if !exists {
		return false
	}

	task.paused_signal = true
	return true
}

func (e async_executor*) resume_task(task_id string) bool {
	e.mu.Lock()
	defer e.mu.Unlock()

	task, exists := e.running_tasks[task_id]
	if !exists {
		return false
	}

	task.paused_signal = false
	return true
}

func (e async_executor*) get_task_result(task_id string) (task_result, bool) {
	e.mu.Lock()
	defer e.mu.Unlock()

	for result := range e.completed_tasks {
		if result.task_id == task_id {
			return result, true
		}
	}

	return task_result{}, false
}

func (e async_executor*) get_task_state(task_id string) int32 {
	e.mu.Lock()
	defer e.mu.Unlock()

	task, exists := e.running_tasks[task_id]
	if exists {
		return task.state
	}

	for result := range e.completed_tasks {
		if result.task_id == task_id {
			return result.state
		}
	}

	return TASK_PENDING
}

func (e async_executor*) get_statistics() executor_stats {
	e.mu.Lock()
	defer e.mu.Unlock()

	e.stats.last_update_time = time.Now().UnixNano()
	e.stats.running_tasks = int32(len(e.running_tasks))
	e.stats.queued_tasks = int32(len(e.task_queue))

	return e.stats
}

func (e async_executor*) wait_for_completion(timeout_ms int64) bool {
	deadline := time.Now().Add(time.Duration(timeout_ms) * time.Millisecond)

	for time.Now().Before(deadline) {
		e.mu.Lock()
		queue_size := int32(len(e.task_queue))
		running_size := int32(len(e.running_tasks))
		e.mu.Unlock()

		if queue_size == 0 && running_size == 0 {
			return true
		}

		time.Sleep(10 * time.Millisecond)
	}

	return false
}

func (e async_executor*) shutdown(timeout_ms int64) {
	e.mu.Lock()
	e.is_shutdown = true

	for task_id := range e.running_tasks {
		e.running_tasks[task_id].cancel_signal = true
	}
	e.mu.Unlock()

	e.wait_for_completion(timeout_ms)
}

func (e async_executor*) get_pending_results() task_result[] {
	e.mu.Lock()
	defer e.mu.Unlock()

	results := make(task_result[], 0, len(e.completed_tasks))
	for result := range e.completed_tasks {
		results = append(results, result)
	}

	e.completed_tasks = make(task_result[], 0, 1024)

	return results
}

func sort_tasks_by_priority(tasks async_task*[]) {
	for i := int32(0); i < int32(len(tasks)); i++ {
		for j := i + 1; j < int32(len(tasks)); j++ {
			if tasks[j].priority > tasks[i].priority {
				tasks[i], tasks[j] = tasks[j], tasks[i]
			}
		}
	}
}
