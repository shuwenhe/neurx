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

    save(path: string, state_dict: StateDict, config: SerializationConfig) -> void

    load(path: string) -> StateDict

    exists(path: string) -> bool
}

interface IStateDict {

    create() -> StateDict

    add_tensor(name: string, tensor: Tensor) -> void

    get_tensor(name: string) -> Tensor

    add_param(name: string, param: Tensor) -> void

    get_param(name: string) -> Tensor

    keys() -> []string

    merge(other: StateDict) -> StateDict
}

interface ISerializer {

    serialize(state_dict: StateDict, config: SerializationConfig) -> []i8

    deserialize(data: []i8, format: SerializationFormat) -> StateDict

    write_file(path: string, state_dict: StateDict, config: SerializationConfig) -> void

    read_file(path: string) -> StateDict
}

interface IFormatConverter {

    convert(input_format: SerializationFormat, output_format: SerializationFormat, data: []i8) -> []i8

    can_convert(from_format: SerializationFormat, to_format: SerializationFormat) -> bool
}

interface ITensorIO {

    save_tensor(path: string, tensor: Tensor, format: SerializationFormat) -> void

    load_tensor(path: string) -> Tensor

    save_tensors(path: string, tensors: map[string]Tensor, format: SerializationFormat) -> void

    load_tensors(path: string) -> map[string]Tensor
}

interface ICheckpointManager {

    save_checkpoint(path: string, state_dict: StateDict, step: i64) -> void

    load_checkpoint(path: string) -> StateDict

    load_checkpoint_by_step(path: string, step: i64) -> StateDict

    list_checkpoints(path: string) -> []string

    cleanup_old_checkpoints(path: string, keep_last: i64) -> void
}

interface IMetadataIO {

    save_metadata(path: string, metadata: map[string]string) -> void

    load_metadata(path: string) -> map[string]string

    append_metadata(path: string, metadata: map[string]string) -> void
}

interface IMaliformedCheckpointHandler {

    is_valid(path: string) -> bool

    repair(path: string) -> bool

    get_error_details(path: string) -> string
}
