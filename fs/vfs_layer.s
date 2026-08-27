package neurx.fs.vfs

struct inode {
    int ino                
    int size               
    int mode               
    int nlink              
    int uid                
    int gid                
    int atime              
    int mtime              
    int ctime              
}

struct dentry {
    string name            
    int inode_no           
    int parent_ino         
    int valid              
}

struct file {
    int f_inode            
    int f_flags            
    int f_offset           
    int f_mode             
    int f_refcount         
}

struct super_block {
    string fs_name         
    int block_size         
    int total_blocks       
    int free_blocks        
    int inode_count        
    int free_inodes        
    int mounted            
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

func inode_update_size(inode* i, int new_size) inode {
    inode_local := i.*
    inode_local.size = new_size
    inode_local.mtime = 0
    
    i.* = inode_local
    inode_local
}

func inode_increment_nlink(inode* i) inode {
    inode_local := i.*
    inode_local.nlink = inode_local.nlink + 1
    
    i.* = inode_local
    inode_local
}

func file_read(file* f, int bytes) (file, int) {
    file_local := f.*
    
    bytes_read := bytes
    file_local.f_offset = file_local.f_offset + bytes_read
    
    f.* = file_local
    (file_local, bytes_read)
}

func file_write(file* f, int bytes) (file, int) {
    file_local := f.*
    
    bytes_written := bytes
    file_local.f_offset = file_local.f_offset + bytes_written
    
    f.* = file_local
    (file_local, bytes_written)
}

func file_seek(file* f, int offset) file {
    file_local := f.*
    file_local.f_offset = offset
    
    f.* = file_local
    file_local
}

func dentry_invalidate(dentry* d) dentry {
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
