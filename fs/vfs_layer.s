package neurx.fs.vfs

struct inode {
    int ino                // Inode number
    int size               // File size in bytes
    int mode               // File type and permissions
    int nlink              // Hard link count
    int uid                // User ID
    int gid                // Group ID
    int atime              // Access time
    int mtime              // Modification time
    int ctime              // Change time
}

struct dentry {
    string name            // Directory entry name
    int inode_no           // Inode number
    int parent_ino         // Parent inode number
    int valid              // 1 if valid, 0 if invalid
}

struct file {
    int f_inode            // Inode number
    int f_flags            // File open flags
    int f_offset           // Current file offset
    int f_mode             // File mode
    int f_refcount         // Reference count
}

struct super_block {
    string fs_name         // Filesystem name (ext4, etc)
    int block_size         // Block size in bytes
    int total_blocks       // Total blocks in filesystem
    int free_blocks        // Free blocks
    int inode_count        // Total inode count
    int free_inodes        // Free inode count
    int mounted            // 1 if mounted, 0 otherwise
}

func create_inode(int ino, int size, int mode) inode {
    inode {
        ino: ino,
        size: size,
        mode: mode,
        nlink: 1,
        uid: 0,
        gid: 0,
        atime: 0,
        mtime: 0,
        ctime: 0
    }
}

func create_dentry(string name, int inode_no) dentry {
    dentry {
        name: name,
        inode_no: inode_no,
        parent_ino: 0,
        valid: 1
    }
}

func create_file(int inode_no, int flags) file {
    file {
        f_inode: inode_no,
        f_flags: flags,
        f_offset: 0,
        f_mode: 0,
        f_refcount: 1
    }
}

func create_super_block(string fs_name, int block_size, int total_blocks) super_block {
    super_block {
        fs_name: fs_name,
        block_size: block_size,
        total_blocks: total_blocks,
        free_blocks: total_blocks,
        inode_count: total_blocks / 4,
        free_inodes: total_blocks / 4,
        mounted: 0
    }
}

func inode_update_size(mut i: &inode, int new_size) inode {
    inode_local := i.*
    inode_local.size = new_size
    inode_local.mtime = 0
    
    i.* = inode_local
    inode_local
}

func inode_increment_nlink(mut i: &inode) inode {
    inode_local := i.*
    inode_local.nlink = inode_local.nlink + 1
    
    i.* = inode_local
    inode_local
}

func file_read(mut f: &file, int bytes) (file, int) {
    file_local := f.*
    
    bytes_read := bytes
    file_local.f_offset = file_local.f_offset + bytes_read
    
    f.* = file_local
    (file_local, bytes_read)
}

func file_write(mut f: &file, int bytes) (file, int) {
    file_local := f.*
    
    bytes_written := bytes
    file_local.f_offset = file_local.f_offset + bytes_written
    
    f.* = file_local
    (file_local, bytes_written)
}

func file_seek(mut f: &file, int offset) file {
    file_local := f.*
    file_local.f_offset = offset
    
    f.* = file_local
    file_local
}

func dentry_invalidate(mut d: &dentry) dentry {
    dentry_local := d.*
    dentry_local.valid = 0
    
    d.* = dentry_local
    dentry_local
}

func print_inode_info(inode i) {
    print("   • Inode #")
    print(i.ino)
    print(" | Size: ")
    print(i.size)
    print(" | Links: ")
    print(i.nlink)
}

func print_vfs_info(super_block sb) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║              NeurX VFS Layer - Status Report               ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Filesystem: ")
    print(sb.fs_name)
    print("   • Block Size: ")
    print(sb.block_size)
    print("   • Total Blocks: ")
    print(sb.total_blocks)
    print("   • Free Blocks: ")
    print(sb.free_blocks)
    print("")
    print("   • Total Inodes: ")
    print(sb.inode_count)
    print("   • Free Inodes: ")
    print(sb.free_inodes)
    print("")
    if sb.mounted == 1 {
        print("   • Mounted: 🟢 Yes")
    } else {
        print("   • Mounted: 🔴 No")
    }
    print("")
    print("✅ VFS layer operational!")
    print("")
}
