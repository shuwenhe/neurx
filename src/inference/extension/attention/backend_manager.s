package attention
    cuda_sm_70
    cuda_sm_80
    cuda_sm_90
    rocm_mi100
    rocm_mi200
    cpu
    unknown
}

struct backend_capability {
    string backend_name
    []string supported_dtypes
    hardware_type[] supported_hardware
    int min_batch_size
    int max_seq_length
    int estimated_flops_per_token
    bool supports_paged_cache
    bool supports_sparse
}

struct attention_backend_manager {
    map[string, attention_backend] backends
    string default_backend
    string current_backend
    hardware_type detected_hardware
    map[string, backend_capability] capabilities
}

func detect_hardware() hardware_type {
    hardware_type_unknown
}

func get_backend_capability(attention_backend_type backend_type) backend_capability {
    switch backend_type {
        attention_backend_type_standard : backend_capability {
            backend_name: "standard",
            supported_dtypes: []string{"float32", "float16", "bfloat16"},
            supported_hardware: hardware_type[]{hardware_type_cpu, hardware_type_unknown},
            min_batch_size: 1,
            max_seq_length: 8192,
            estimated_flops_per_token: 0,
            supports_paged_cache: false,
            supports_sparse: false,
        },
        attention_backend_type_flash_attention : backend_capability {
            backend_name: "flash_attention",
            supported_dtypes: []string{"float16", "bfloat16"},
            supported_hardware: hardware_type[]{hardware_type_cuda_sm_70, hardware_type_cuda_sm_80, hardware_type_cuda_sm_90},
            min_batch_size: 1,
            max_seq_length: 16384,
            estimated_flops_per_token: 1000000,
            supports_paged_cache: true,
            supports_sparse: false,
        },
        attention_backend_type_dsa : backend_capability {
            backend_name: "dsa",
            supported_dtypes: []string{"float16", "bfloat16"},
            supported_hardware: hardware_type[]{hardware_type_cuda_sm_80, hardware_type_cuda_sm_90},
            min_batch_size: 1,
            max_seq_length: 32768,
            estimated_flops_per_token: 1200000,
            supports_paged_cache: true,
            supports_sparse: true,
        },
        attention_backend_type_paged_attention : backend_capability {
            backend_name: "paged_attention",
            supported_dtypes: []string{"float16", "bfloat16", "int8"},
            supported_hardware: hardware_type[]{hardware_type_cuda_sm_70, hardware_type_cuda_sm_80, hardware_type_cuda_sm_90},
            min_batch_size: 1,
            max_seq_length: 32768,
            estimated_flops_per_token: 900000,
            supports_paged_cache: true,
            supports_sparse: false,
        },
        attention_backend_type_sparse_attention : backend_capability {
            backend_name: "sparse_attention",
            supported_dtypes: []string{"float16", "bfloat16"},
            supported_hardware: hardware_type[]{hardware_type_cuda_sm_80, hardware_type_cuda_sm_90},
            min_batch_size: 1,
            max_seq_length: 1000000,
            estimated_flops_per_token: 300000,
            supports_paged_cache: true,
            supports_sparse: true,
        },
    }
}

func new_attention_backend_manager() attention_backend_manager {
    hw := detect_hardware()
    attention_backend_manager {
        backends: map[string, attention_backend]{},
        default_backend: "standard",
        current_backend: "standard",
        detected_hardware: hw,
        capabilities: map[string, backend_capability]{},
    }
}

func (attention_backend_manager* mgr) register_backend(string backend_name, attention_backend backend) bool {
    mgr.backends[backend_name] = backend
    true
}

func (attention_backend_manager* mgr) has_backend(string backend_name) bool {
    backend_name in mgr.backends
}

func (attention_backend_manager* mgr) get_backend(string backend_name) attention_backend {
    if backend_name in mgr.backends {
        mgr.backends[backend_name]
    }
    config := new_attention_config(8, 64)
    new_attention_backend(attention_backend_type_standard, config)
}

func (attention_backend_manager* mgr) set_current_backend(string backend_name) bool {
    if !mgr.has_backend(backend_name) {
        false
    }
    mgr.current_backend = backend_name
    true
}

func (attention_backend_manager* mgr) get_current_backend() attention_backend {
    mgr.get_backend(mgr.current_backend)
}

func (attention_backend_manager* mgr) auto_select_backend(int seq_length, string precision) string {
    if mgr.detected_hardware == hardware_type_cuda_sm_90 {
        if seq_length > 16384 && precision == "float16" {
            "dsa"
        } else {
            "flash_attention"
        }
    } else if mgr.detected_hardware == hardware_type_cuda_sm_80 {
        "flash_attention"
    } else {
        "standard"
    }
}

func (attention_backend_manager* mgr) initialize_all() bool {
    for name in mgr.backends.keys() {
        backend := mgr.get_backend(name)
        if !backend.initialize() {
            false
        }
    }
    true
}

func (attention_backend_manager* mgr) finalize_all() bool {
    for name in mgr.backends.keys() {
        backend := mgr.get_backend(name)
        if !backend.finalize() {
            false
        }
    }
    true
}

func (attention_backend_manager* mgr) list_backends() []string {
    result := []string{}
    for name in mgr.backends.keys() {
        result = append(result, name)
    }
    result
}

func (attention_backend_manager* mgr) get_detected_hardware() string {
    switch mgr.detected_hardware {
        hardware_type_cuda_sm_70 : "cuda_sm_70",
        hardware_type_cuda_sm_80 : "cuda_sm_80",
        hardware_type_cuda_sm_90 : "cuda_sm_90",
        hardware_type_rocm_mi100 : "rocm_mi100",
        hardware_type_rocm_mi200 : "rocm_mi200",
        hardware_type_cpu : "cpu",
        hardware_type_unknown : "unknown",
    }
}
