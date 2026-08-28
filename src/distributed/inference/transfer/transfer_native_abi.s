package neurx.distributed.inference.transfer.transfer_native_abi
extern func neurx_mooncake_register(int pointer_low, int byte_count) int
extern func neurx_mooncake_transfer(int source_ptr_low, int destination_ptr_low, int byte_count, int source_rank, int destination_rank) int
extern func neurx_nixl_register(int pointer_low, int byte_count, int device_id) int
extern func neurx_nixl_transfer(int source_ptr_low, int destination_ptr_low, int byte_count, int source_rank, int destination_rank) int
extern func neurx_mori_register(int pointer_low, int byte_count, int device_id) int
extern func neurx_mori_transfer(int source_ptr_low, int destination_ptr_low, int byte_count, int room_id, int shard_index) int
func transfer_native_register(int backend_type, int pointer_low, int byte_count, int device_id) int {
    if pointer_low == 0 || byte_count <= 0 { return 400 }
    if backend_type == 1 { return neurx_mooncake_register(pointer_low, byte_count) }
    if backend_type == 2 { return neurx_nixl_register(pointer_low, byte_count, device_id) }
    if backend_type == 3 { return neurx_mori_register(pointer_low, byte_count, device_id) }
    404
}

func transfer_native_execute(int backend_type, int source_ptr_low, int destination_ptr_low, int byte_count, int source_rank, int destination_rank, int room_id, int shard_index) int {
    if source_ptr_low == 0 || destination_ptr_low == 0 || byte_count <= 0 { return 400 }
    if backend_type == 1 { return neurx_mooncake_transfer(source_ptr_low, destination_ptr_low, byte_count, source_rank, destination_rank) }
    if backend_type == 2 { return neurx_nixl_transfer(source_ptr_low, destination_ptr_low, byte_count, source_rank, destination_rank) }
    if backend_type == 3 { return neurx_mori_transfer(source_ptr_low, destination_ptr_low, byte_count, room_id, shard_index) }
    404
}
