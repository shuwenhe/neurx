package neurx.observability.profiling
func create_default_config() profiler_config* {
	return create_profiler_config()
}

func create_default_profiler() worker_profiler* {
	return create_worker_profiler(create_profiler_config())
}

func create_default_cuda_profiler() cuda_profiler* {
	return create_cuda_profiler(create_profiler_config())
}

func create_default_manager() profiler_manager* {
	return create_profiler_manager()
}
