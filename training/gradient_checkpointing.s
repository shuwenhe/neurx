package neurx.training

import "neurx.autodiff"

struct checkpoint_config {
    enabled: bool
    checkpoints_per_layer: int
    preserve_inputs: bool
    recomputation_strategy: int
}

struct checkpoint_state {
    saved_tensors: [][]autodiff.tensor
    recomputation_count: int
    memory_saved: float
}

struct checkpoint_layer {
    layer_fn: func([][]autodiff.tensor) [][]autodiff.tensor
    inputs: [][]autodiff.tensor
    outputs: [][]autodiff.tensor
    needs_recompute: bool
}

func new_checkpoint_config(bool enabled) checkpoint_config {
    checkpoint_config config {
        enabled: enabled,
        checkpoints_per_layer: 1,
        preserve_inputs: true,
        recomputation_strategy: 0,
    }
    config
}

func new_checkpoint_state() checkpoint_state {
    checkpoint_state state {
        saved_tensors: [][]autodiff.tensor{},
        recomputation_count: 0,
        memory_saved: 0.0,
    }
    state
}

func checkpoint_wrapper(func layer_fn, []autodiff.tensor inputs, checkpoint_config config) []autodiff.tensor {
    if !config.enabled {
        return layer_fn(inputs...)
    }
    
    autodiff.disable_grad()
    
    []autodiff.tensor outputs = layer_fn(inputs...)
    
    autodiff.enable_grad()
    
    for i := 0; i < len(inputs); i += 1 {
        autodiff.retain_grad(inputs[i])
    }
    
    []autodiff.tensor detached_outputs = []autodiff.tensor{cap: len(outputs)}
    for i := 0; i < len(outputs); i += 1 {
        detached_outputs.push(autodiff.tensor_detach(outputs[i]))
    }
    
    func backward_fn([]autodiff.tensor grads) []autodiff.tensor {
        autodiff.enable_grad()
        
        []autodiff.tensor recomputed_outputs = layer_fn(inputs...)
        
        []autodiff.tensor result_grads = []autodiff.tensor{cap: len(inputs)}
        
        for i := 0; i < len(recomputed_outputs); i += 1 {
            autodiff.backward_with_grad(recomputed_outputs[i], grads[i])
        }
        
        for i := 0; i < len(inputs); i += 1 {
            result_grads.push(inputs[i].grad)
        }
        
        autodiff.disable_grad()
        
        result_grads
    }
    
    for i := 0; i < len(detached_outputs); i += 1 {
        autodiff.register_backward_hook(detached_outputs[i], backward_fn)
    }
    
    detached_outputs
}

func checkpoint_module(pointer module, []autodiff.tensor inputs, checkpoint_config config) []autodiff.tensor {
    if !config.enabled {
        return module.forward(inputs...)
    }
    
    autodiff.disable_grad()
    
    []autodiff.tensor outputs = module.forward(inputs...)
    
    autodiff.enable_grad()
    
    for i := 0; i < len(inputs); i += 1 {
        autodiff.retain_grad(inputs[i])
    }
    
    []autodiff.tensor detached_outputs = []autodiff.tensor{cap: len(outputs)}
    for i := 0; i < len(outputs); i += 1 {
        detached_outputs.push(autodiff.tensor_detach(outputs[i]))
    }
    
    func recompute_fn() []autodiff.tensor {
        autodiff.enable_grad()
        []autodiff.tensor result = module.forward(inputs...)
        autodiff.disable_grad()
        result
    }
    
    for i := 0; i < len(detached_outputs); i += 1 {
        autodiff.register_backward_hook(detached_outputs[i], func(grads) []autodiff.tensor {
            []autodiff.tensor recomputed = recompute_fn()
            []autodiff.tensor input_grads = []autodiff.tensor{cap: len(inputs)}
            
            for j := 0; j < len(recomputed); j += 1 {
                autodiff.backward_with_grad(recomputed[j], grads[j])
            }
            
            for j := 0; j < len(inputs); j += 1 {
                input_grads.push(inputs[j].grad)
            }
            
            input_grads
        })
    }
    
    detached_outputs
}

func apply_checkpointing_to_transformer(pointer transformer, checkpoint_config config) pointer {
    if !config.enabled {
        return transformer
    }
    
    int num_layers = len(transformer.layers)
    
    for i := 0; i < num_layers; i += 1 {
        pointer layer = transformer.layers[i]
        
        func wrapped_forward([]autodiff.tensor inputs) []autodiff.tensor {
            checkpoint_wrapper(layer.forward, inputs, config)
        }
        
        layer.forward = wrapped_forward
    }
    
    transformer
}

func gradient_checkpointing_step(
    pointer model,
    []autodiff.tensor inputs,
    func loss_fn,
    checkpoint_config config,
) float {
    autodiff.zero_grad(model.parameters())
    
    []autodiff.tensor outputs
    
    if config.enabled {
        outputs = apply_checkpointing_to_transformer(model, config).forward(inputs)
    } else {
        outputs = model.forward(inputs)
    }
    
    float loss = loss_fn(outputs)
    
    autodiff.backward(loss)
    
    loss
}

func estimate_memory_savings(checkpoint_config config, int num_layers, int layer_memory_mb) float {
    if !config.enabled {
        return 0.0
    }
    
    float baseline = num_layers * layer_memory_mb
    float with_checkpointing = layer_memory_mb + (num_layers / config.checkpoints_per_layer) * layer_memory_mb
    
    baseline - with_checkpointing
}

func checkpoint_save_tensor(autodiff.tensor tensor, checkpoint_state state) checkpoint_state {
    state.saved_tensors.push([tensor])
    state
}

func checkpoint_save_tensors([][]autodiff.tensor tensors, checkpoint_state state) checkpoint_state {
    state.saved_tensors.push(tensors)
    state
}

func checkpoint_clear(checkpoint_state state) checkpoint_state {
    state.saved_tensors = [][]autodiff.tensor{}
    state.recomputation_count = 0
    state
}

func get_checkpoint_stats(checkpoint_state state) string {
    "Checkpoint Stats: Recomputations=" + string(state.recomputation_count) +
    ", Memory Saved=" + string(state.memory_saved) + "MB"
}

func create_checkpoint_layer(func layer_fn) checkpoint_layer {
    checkpoint_layer layer {
        layer_fn: layer_fn,
        inputs: [][]autodiff.tensor{},
        outputs: [][]autodiff.tensor{},
        needs_recompute: false,
    }
    layer
}

func checkpoint_layer_forward(checkpoint_layer layer, []autodiff.tensor inputs) []autodiff.tensor {
    layer.inputs = [inputs]
    layer.outputs = [layer.layer_fn(inputs...)]
    layer.needs_recompute = true
    
    []autodiff.tensor detached = []autodiff.tensor{cap: len(layer.outputs[0])}
    for i := 0; i < len(layer.outputs[0]); i += 1 {
        detached.push(autodiff.tensor_detach(layer.outputs[0][i]))
    }
    
    detached
}

func checkpoint_layer_backward(checkpoint_layer layer, []autodiff.tensor grads) []autodiff.tensor {
    if !layer.needs_recompute {
        return []autodiff.tensor{}
    }
    
    autodiff.enable_grad()
    
    []autodiff.tensor recomputed = layer.layer_fn(layer.inputs[0]...)
    
    []autodiff.tensor input_grads = []autodiff.tensor{cap: len(layer.inputs[0])}
    
    for i := 0; i < len(recomputed); i += 1 {
        autodiff.backward_with_grad(recomputed[i], grads[i])
    }
    
    for i := 0; i < len(layer.inputs[0]); i += 1 {
        input_grads.push(layer.inputs[0][i].grad)
    }
    
    autodiff.disable_grad()
    
    layer.needs_recompute = false
    
    input_grads
}