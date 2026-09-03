package neurx.kernel.boot.uefi

func _efi_main(image_handle: int, system_table: int) int {
    
    collect_uefi_memory_map(system_table)
    
    exit_boot_services(image_handle, system_table)
    
    neurx_kernel_entry()
    
    0
}

func collect_uefi_memory_map(system_table: int) {
    
}

func exit_boot_services(image_handle: int, system_table: int) {
    
}

func neurx_kernel_entry() {
    
}
