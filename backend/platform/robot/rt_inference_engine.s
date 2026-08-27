package neurx.backend.platform.robot

use std.slices
use std.io.println

struct rt_inference_request {
    string model_name
    []float observations
    int request_id
    int deadline_us
}

struct rt_inference_result {
    int request_id
    []float actions
    bool success
    int latency_us
    int compute_time_us
}

struct rt_inference_engine {
    string device
    int max_batch_size
    int inference_latency_budget_us
    bool preload_models
    []string loaded_models
    int total_inferences
    int successful_inferences
    int missed_deadlines
}

func new_rt_inference_engine(string device, int latency_budget_us) rt_inference_engine {
    return rt_inference_engine{
        device: device,
        max_batch_size: 1,
        inference_latency_budget_us: latency_budget_us,
        preload_models: true,
        loaded_models: vec[string](),
        total_inferences: 0,
        successful_inferences: 0,
        missed_deadlines: 0,
    }
}

func (rt_inference_engine* engine) load_model(string model_name) bool {    for i in 0..engine.loaded_models.len() {
        if engine.loaded_models[i] == model_name {
            return true
        }
    }
    
    engine.loaded_models.push(model_name)
    println("✅ Loaded model: " + model_name)
    true
}

func (rt_inference_engine* engine) preload_all_models([]string model_names) {
    for i in 0..model_names.len() {
        _ := engine.load_model(model_names[i])
    }
}

func (rt_inference_engine* engine) run_inference(rt_inference_request request) rt_inference_result {    engine.total_inferences = engine.total_inferences + 1
    
    actions := vec[float]()
    result := rt_inference_result{
        request_id: request.request_id,
        actions: actions,
        success: true,
        latency_us: 0,
        compute_time_us: 0,
    }
    
    if result.latency_us > request.deadline_us {
        engine.missed_deadlines = engine.missed_deadlines + 1
        return rt_inference_result{
            request_id: request.request_id,
            actions: actions,
            success: false,
            latency_us: result.latency_us,
            compute_time_us: result.compute_time_us,
        }
    }
    
    engine.successful_inferences = engine.successful_inferences + 1
    result
}

func (rt_inference_engine* engine) get_stats() (int, int, int) {
    (engine.total_inferences, engine.successful_inferences, engine.missed_deadlines)
}

func (rt_inference_engine* engine) get_loaded_model_count() int {    engine.loaded_models.len()
}

func (rt_inference_engine* engine) get_latency_budget_us() int {    engine.inference_latency_budget_us
}
