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
    save(string path, state_dict: state_dict, config: serialization_config) -> void
    load(string path) -> state_dict
    exists(string path) -> bool
}
interface i_state_dict {
    create() -> state_dict
    add_tensor(string name, tensor: tensor) -> void
    get_tensor(string name) -> tensor
    add_param(string name, param: tensor) -> void
    get_param(string name) -> tensor
    keys() -> []string
    merge(other: state_dict) -> state_dict
}
interface i_serializer {
    serialize(state_dict: state_dict, config: serialization_config) -> []i8
    deserialize(data: []i8, format: SerializationFormat) -> state_dict
    write_file(string path, state_dict: state_dict, config: serialization_config) -> void
    read_file(string path) -> state_dict
}
interface i_format_converter {
    convert(input_format: SerializationFormat, output_format: SerializationFormat, data: []i8) -> []i8
    can_convert(from_format: SerializationFormat, to_format: SerializationFormat) -> bool
}
interface i_tensor_io {
    save_tensor(string path, tensor: tensor, format: SerializationFormat) -> void
    load_tensor(string path) -> tensor
    save_tensors(string path, map tensors[string]tensor, format: SerializationFormat) -> void
    load_tensors(string path) -> map[string]tensor
}
interface i_checkpoint_manager {
    save_checkpoint(string path, state_dict: state_dict, i64 step) -> void
    load_checkpoint(string path) -> state_dict
    load_checkpoint_by_step(string path, i64 step) -> state_dict
    list_checkpoints(string path) -> []string
    cleanup_old_checkpoints(string path, i64 keep_last) -> void
}
interface i_metadata_io {
    save_metadata(string path, map metadata[string]string) -> void
    load_metadata(string path) -> map[string]string
    append_metadata(string path, map metadata[string]string) -> void
}
interface i_maliformed_checkpoint_handler {
    is_valid(string path) -> bool
    repair(string path) -> bool
    get_error_details(string path) -> string
}
