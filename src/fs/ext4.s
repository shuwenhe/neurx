package neurx.fs

use std.vec.vec
use std.string.string

// 文件系统 inode 结构
struct inode {
    int inode_num
    int file_size
    int mode  // 文件类型和权限
    int uid
    int gid
    int atime  // 访问时间
    int mtime  // 修改时间
    int ctime  // 创建时间
    int block_count
    int[] block_pointers
}

// 目录项
struct dentry {
    string name
    int inode_num
    int type  // 1=file, 2=directory
}

// ext4 文件系统实现
struct ext4_fs {
    int block_size  // 通常 4096
    int total_blocks
    int free_blocks
    inode[] inode_table
    vec dentries
}

// 初始化文件系统
func (ext4_fs* fs) init(int total_size) (int, string) {
    fs.block_size = 4096
    fs.total_blocks = total_size / fs.block_size
    fs.free_blocks = fs.total_blocks
    fs.inode_table = new inode[fs.total_blocks / 8]
    fs.dentries = vec()
    return 0, ""
}

// 创建文件
func (ext4_fs* fs) create_file(string filename, int mode) (inode, string) {
    inode_num := 0
    i := 0
    for i < len(fs.inode_table) {
        if fs.inode_table[i].inode_num == 0 {
            inode_num = i
            break
        }
        i = i + 1
    }
    
    new_inode := inode{
        inode_num: inode_num,
        file_size: 0,
        mode: mode,
        uid: 0,
        gid: 0,
        atime: 0,
        mtime: 0,
        ctime: 0,
        block_count: 0,
        block_pointers: new int[12]
    }
    
    fs.inode_table[inode_num] = new_inode
    
    dentry := dentry{
        name: filename,
        inode_num: inode_num,
        type: 1
    }
    fs.dentries.push(dentry)
    
    return new_inode, ""
}

// 创建目录
func (ext4_fs* fs) create_directory(string dirname) (inode, string) {
    inode_num := 0
    i := 0
    for i < len(fs.inode_table) {
        if fs.inode_table[i].inode_num == 0 {
            inode_num = i
            break
        }
        i = i + 1
    }
    
    new_inode := inode{
        inode_num: inode_num,
        file_size: 0,
        mode: 16877,  // 目录权限
        uid: 0,
        gid: 0,
        atime: 0,
        mtime: 0,
        ctime: 0,
        block_count: 0,
        block_pointers: new int[12]
    }
    
    fs.inode_table[inode_num] = new_inode
    
    dentry := dentry{
        name: dirname,
        inode_num: inode_num,
        type: 2
    }
    fs.dentries.push(dentry)
    
    return new_inode, ""
}

// 分配块
func (ext4_fs* fs) allocate_block() (int, string) {
    if fs.free_blocks <= 0 {
        return -1, "No free blocks"
    }
    
    block_num := fs.total_blocks - fs.free_blocks
    fs.free_blocks = fs.free_blocks - 1
    return block_num, ""
}

// 释放块
func (ext4_fs* fs) free_block(int block_num) (int, string) {
    fs.free_blocks = fs.free_blocks + 1
    return 0, ""
}

// 写文件
func (ext4_fs* fs) write_file(int inode_num, int* data, int size) (int, string) {
    if inode_num >= len(fs.inode_table) {
        return -1, "Invalid inode"
    }
    
    inode_ptr := &fs.inode_table[inode_num]
    blocks_needed := size / fs.block_size
    
    if size % fs.block_size != 0 {
        blocks_needed = blocks_needed + 1
    }
    
    i := 0
    for i < blocks_needed {
        block_num, err := fs.allocate_block()
        if err != "" {
            return -1, err
        }
        
        if i < 12 {
            inode_ptr.block_pointers[i] = block_num
        }
        i = i + 1
    }
    
    inode_ptr.file_size = size
    return size, ""
}

// 读文件
func (ext4_fs fs) read_file(int inode_num) (int, string) {
    if inode_num >= len(fs.inode_table) {
        return -1, "Invalid inode"
    }
    
    inode_data := fs.inode_table[inode_num]
    return inode_data.file_size, ""
}

// 删除文件
func (ext4_fs* fs) delete_file(int inode_num) (int, string) {
    if inode_num >= len(fs.inode_table) {
        return -1, "Invalid inode"
    }
    
    inode_ptr := &fs.inode_table[inode_num]
    i := 0
    for i < inode_ptr.block_count {
        if i < 12 {
            fs.free_block(inode_ptr.block_pointers[i])
        }
        i = i + 1
    }
    
    inode_ptr.inode_num = 0
    return 0, ""
}

// 获取文件系统统计
func (ext4_fs fs) get_stats() (int, int, int) {
    used_blocks := fs.total_blocks - fs.free_blocks
    inode_count := len(fs.inode_table)
    return used_blocks, fs.free_blocks, inode_count
}
