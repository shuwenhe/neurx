import "tensor_api"
enum serialization_format {
    py_torch_pickle
    safe_tensor
    ONNX
    GGUF
    message_pack
    protocol_2
    custom
}
struct serialization_config {
    format: SerializationFormat
    version: string
    metadata: map[string]string
    compression: bool
    compression_level: i64
}
struct state_dict {
    tensors: map[string]tensor
    hyperparams: map[string]string
    metadata: map[string]string
}
interface i_checkpoint {
    save(path: string, state_dict: state_dict, config: serialization_config) -> void
    load(path: string) -> state_dict
    exists(path: string) -> bool
}
interface i_state_dict {
    create() -> state_dict
    add_tensor(name: string, tensor: tensor) -> void
    get_tensor(name: string) -> tensor
    add_param(name: string, param: tensor) -> void
    get_param(name: string) -> tensor
    keys() -> []string
    merge(other: state_dict) -> state_dict
}
interface i_serializer {
    serialize(state_dict: state_dict, config: serialization_config) -> []i8
    deserialize(data: []i8, format: SerializationFormat) -> state_dict
    write_file(path: string, state_dict: state_dict, config: serialization_config) -> void
    read_file(path: string) -> state_dict
}
interface i_format_converter {
    convert(input_format: SerializationFormat, output_format: SerializationFormat, data: []i8) -> []i8
    can_convert(from_format: SerializationFormat, to_format: SerializationFormat) -> bool
}
interface i_tensor_io {
    save_tensor(path: string, tensor: tensor, format: SerializationFormat) -> void
    load_tensor(path: string) -> tensor
    save_tensors(path: string, tensors: map[string]tensor, format: SerializationFormat) -> void
    load_tensors(path: string) -> map[string]tensor
}
interface i_checkpoint_manager {
    save_checkpoint(path: string, state_dict: state_dict, step: i64) -> void
    load_checkpoint(path: string) -> state_dict
    load_checkpoint_by_step(path: string, step: i64) -> state_dict
    list_checkpoints(path: string) -> []string
    cleanup_old_checkpoints(path: string, keep_last: i64) -> void
}
interface i_metadata_io {
    save_metadata(path: string, metadata: map[string]string) -> void
    load_metadata(path: string) -> map[string]string
    append_metadata(path: string, metadata: map[string]string) -> void
}
interface i_maliformed_checkpoint_handler {
    is_valid(path: string) -> bool
    repair(path: string) -> bool
    get_error_details(path: string) -> string
}
