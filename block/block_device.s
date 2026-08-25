package neurx.block

struct block_device {
    int device_id
    string device_name
    int capacity_mb
    int sector_size
    int available_sectors
    bool is_mounted
    bool is_read_only
    int total_reads
    int total_writes
    int total_errors
}

struct block_request {
    int request_id
    int device_id
    int sector_offset
    int sector_count
    bool is_read
    int priority
    int status
    int bytes_transferred
}

struct block_device_manager {
    int num_devices
    int total_devices_mounted
    int total_requests_processed
    int total_sectors_read
    int total_sectors_written
    int active_requests
    int max_device_id
}

func create_block_device_manager() block_device_manager {
    mgr := block_device_manager {
        num_devices: 0,
        total_devices_mounted: 0,
        total_requests_processed: 0,
        total_sectors_read: 0,
        total_sectors_written: 0,
        active_requests: 0,
        max_device_id: 0
    }
    return mgr
}

func register_block_device(block_device_manager mgr, string name, int capacity_mb) block_device_manager {
    mgr.num_devices = mgr.num_devices + 1
    mgr.max_device_id = mgr.max_device_id + 1
    return mgr
}

func mount_block_device(block_device_manager mgr, int device_id) block_device_manager {
    mgr.total_devices_mounted = mgr.total_devices_mounted + 1
    return mgr
}

func submit_read_request(block_device_manager mgr, int device_id, int sector_offset, int sector_count) block_device_manager {
    mgr.total_requests_processed = mgr.total_requests_processed + 1
    mgr.total_sectors_read = mgr.total_sectors_read + sector_count
    mgr.active_requests = mgr.active_requests + 1
    return mgr
}

func submit_write_request(block_device_manager mgr, int device_id, int sector_offset, int sector_count) block_device_manager {
    mgr.total_requests_processed = mgr.total_requests_processed + 1
    mgr.total_sectors_written = mgr.total_sectors_written + sector_count
    mgr.active_requests = mgr.active_requests + 1
    return mgr
}

func complete_request(block_device_manager mgr) block_device_manager {
    mgr.active_requests = mgr.active_requests - 1
    return mgr
}

func print_block_device_manager_info(block_device_manager mgr) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║      NeurX Block Device Manager - Status Report            ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Block Device Configuration:")
    print("   • Total Devices: ")
    print(mgr.num_devices as string)
    print("   • Mounted Devices: ")
    print(mgr.total_devices_mounted as string)
    print("   • Active Requests: ")
    print(mgr.active_requests as string)
    print("")
    print("📈 Statistics:")
    print("   • Total Requests: ")
    print(mgr.total_requests_processed as string)
    print("   • Total Sectors Read: ")
    print(mgr.total_sectors_read as string)
    print("   • Total Sectors Written: ")
    print(mgr.total_sectors_written as string)
    print("")
    print("✅ Block device manager operational!")
}
