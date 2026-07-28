// Serialization API - Model and checkpoint persistence
//
// Centralized serialization system (not scattered everywhere)
// Supports multiple formats: PyTorch, SafeTensor, ONNX, GGUF, etc.
//
// Checkpoint -> StateDict -> Serializer -> Format -> File

import "tensor_api"

enum SerializationFormat {
    PyTorchPickle
    SafeTensor
    ONNX
    GGUF
    MessagePack
    Protocol2
    Custom
}

struct SerializationConfig {
    format: SerializationFormat
    version: string
    metadata: map[string]string
    compression: bool
    compression_level: i64
}

struct StateDict {
    tensors: map[string]Tensor
    hyperparams: map[string]string
    metadata: map[string]string
}

interface ICheckpoint {
    // Save checkpoint
    save(path: string, state_dict: StateDict, config: SerializationConfig) -> void
    
    // Load checkpoint
    load(path: string) -> StateDict
    
    // Check if checkpoint exists
    exists(path: string) -> bool
}

interface IStateDict {
    // Create empty state dict
    create() -> StateDict
    
    // Add tensor to state dict
    add_tensor(name: string, tensor: Tensor) -> void
    
    // Get tensor from state dict
    get_tensor(name: string) -> Tensor
    
    // Add parameter
    add_param(name: string, param: Tensor) -> void
    
    // Get parameter
    get_param(name: string) -> Tensor
    
    // List all keys
    keys() -> []string
    
    // Merge state dicts
    merge(other: StateDict) -> StateDict
}

interface ISerializer {
    // Serialize to bytes
    serialize(state_dict: StateDict, config: SerializationConfig) -> []i8
    
    // Deserialize from bytes
    deserialize(data: []i8, format: SerializationFormat) -> StateDict
    
    // Write to file
    write_file(path: string, state_dict: StateDict, config: SerializationConfig) -> void
    
    // Read from file
    read_file(path: string) -> StateDict
}

interface IFormatConverter {
    // Convert between formats
    convert(input_format: SerializationFormat, output_format: SerializationFormat, data: []i8) -> []i8
    
    // Check if conversion is supported
    can_convert(from_format: SerializationFormat, to_format: SerializationFormat) -> bool
}

interface ITensorIO {
    // Save tensor
    save_tensor(path: string, tensor: Tensor, format: SerializationFormat) -> void
    
    // Load tensor
    load_tensor(path: string) -> Tensor
    
    // Save multiple tensors
    save_tensors(path: string, tensors: map[string]Tensor, format: SerializationFormat) -> void
    
    // Load multiple tensors
    load_tensors(path: string) -> map[string]Tensor
}

interface ICheckpointManager {
    // Save checkpoint with versioning
    save_checkpoint(path: string, state_dict: StateDict, step: i64) -> void
    
    // Load checkpoint
    load_checkpoint(path: string) -> StateDict
    
    // Load checkpoint by step
    load_checkpoint_by_step(path: string, step: i64) -> StateDict
    
    // List checkpoints
    list_checkpoints(path: string) -> []string
    
    // Delete old checkpoints (keep last N)
    cleanup_old_checkpoints(path: string, keep_last: i64) -> void
}

interface IMetadataIO {
    // Save metadata
    save_metadata(path: string, metadata: map[string]string) -> void
    
    // Load metadata
    load_metadata(path: string) -> map[string]string
    
    // Append metadata
    append_metadata(path: string, metadata: map[string]string) -> void
}

interface IMaliformedCheckpointHandler {
    // Check if checkpoint is valid
    is_valid(path: string) -> bool
    
    // Repair checkpoint (if possible)
    repair(path: string) -> bool
    
    // Get error details
    get_error_details(path: string) -> string
}
