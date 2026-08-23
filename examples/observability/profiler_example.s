package neurx.examples.observability.profiler

package main

import "observability/profiling"

func example_basic_profiling() {
	config := profiler.create_profiler_config()
	config.device = profiler.device_cuda
	config.max_iterations = 100

	prof := profiler.create_worker_profiler(config)

	prof.start()

	prof.record_operation("linear_layer", 10.5, 25.3)
	prof.record_operation("attention", 20.1, 50.2)
	prof.record_operation("linear_layer", 10.2, 25.1)

	prof.step()
	prof.step()
	prof.step()

	summary := prof.get_summary()

	prof.stop()
}

func example_cuda_profiling() {
	config := profiler.create_profiler_config()
	cuda_prof := profiler.create_cuda_profiler(config)

	cuda_prof.start()

	cuda_prof.record_kernel("matmul_kernel", 15.5)
	cuda_prof.record_kernel("attention_kernel", 25.3)
	cuda_prof.record_kernel("softmax_kernel", 8.2)

	cuda_prof.step()

	kernel_stats := cuda_prof.get_kernel_stats()

	cuda_prof.stop()
}

func example_profiler_manager() {
	manager := profiler.create_profiler_manager()

	config1 := profiler.create_profiler_config()
	prof1 := profiler.create_worker_profiler(config1)
	manager.register_profiler("inference", prof1)

	config2 := profiler.create_profiler_config()
	cuda_prof := profiler.create_cuda_profiler(config2)
	manager.register_profiler("cuda_ops", cuda_prof.base_profiler)

	manager.start_all()

	prof1.record_operation("embedding", 5.0, 10.0)
	prof1.record_operation("forward", 20.0, 50.0)

	manager.step_all()
	manager.step_all()

	summary := manager.get_manager_summary()

	aggregate_stats := manager.aggregate_stats()

	manager.stop_all()
	manager.shutdown()
}

func example_stats_export() {
	prof := profiler.create_worker_profiler(nil)
	prof.start()

	prof.record_operation("op1", 10.0, 20.0)
	prof.record_operation("op2", 15.0, 30.0)
	prof.record_operation("op1", 10.0, 20.0)

	prof.stats.record_memory("gpu_0", 1024.5, 2048.0)
	prof.stats.record_memory("gpu_1", 512.3, 1024.0)

	prof.stats.add_metadata("num_running_seqs", 32)
	prof.stats.add_metadata("model_name", "qwen2.5")

	prof.stop()

	stats_dict := prof.stats.to_dict()
	summary := prof.get_summary()
	memory_summary := prof.stats.get_memory_summary()
	top_ops := prof.stats.get_top_operations(5)
}
