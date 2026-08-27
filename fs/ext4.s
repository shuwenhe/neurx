package neurx.fs.ext4

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.mutex

struct ext4_superblock {
    total_inodes: u32,
    block_size: u32,
    fragment_size: u32,
    blocks_per_group: u32,
    fragments_per_group: u32,
    inodes_per_group: u32,
    mount_time: u64,
    write_time: u64,
    mount_count: u16,
    max_mount_count: u16,
    magic: u16,
    state: u16,
    revision_level: u32,
}

struct ext4_inode {
    mode: u16,
    uid: u16,
    size: u32,
    atime: u32,
    ctime: u32,
    mtime: u32,
    dtime: u32,
    gid: u16,
    link_count: u16,
    block_count: u32,
    flags: u32,
    direct_blocks: u32[12],
    indirect_block: u32,
    double_indirect: u32,
    triple_indirect: u32,
    version: u32,
    file_acl: u32,
    size_high: u32,
    obso_fragment_addr: u32,
}

struct ext4_dir_entry {
    inode_num: u32,
    rec_len: u16,
    name_len: u8,
    file_type: u8,
    name: *string,
}

struct ext4_file {
    inode_num: u32,
    inode: *ext4_inode,
    block_offset: u32,
    mode: file_mode,
    ref_count: u32,
}

enum file_mode {
    read_only,
    write_only,
    read_write,
}

struct ext4_filesystem {
    superblock: *ext4_superblock,
    block_groups: block_group_descriptor[],
    inode_table: ext4_inode[],
    open_files: ext4_file[],
    lock: mutex[void],
}

struct block_group_descriptor {
    block_bitmap: u32,
    inode_bitmap: u32,
    inode_table: u32,
    free_blocks_count: u16,
    free_inodes_count: u16,
    used_dirs_count: u16,
}

func create_superblock(block_size: u32, total_blocks: u32) (*ext4_superblock, string) {
    sb := *ext4_superblock{
        total_inodes: 65536,
        block_size: block_size,
        fragment_size: block_size,
        blocks_per_group: 8192,
        fragments_per_group: 8192,
        inodes_per_group: 8192,
        mount_time: 0,
        write_time: 0,
        mount_count: 0,
        max_mount_count: 65535,
        magic: 0xef53,
        state: 1,
        revision_level: 1,
    } as *ext4_superblock

return     (sb, "")
}

func new_ext4_filesystem(block_size: u32) (*ext4_filesystem, string) {
    sb := create_superblock(block_size, 1000000)?

    fs := *ext4_filesystem{
        superblock: sb,
        block_groups: block_group_descriptor[](),
        inode_table: ext4_inode[](),
        open_files: ext4_file[](),
        lock: mutex_new(),
    } as *ext4_filesystem

return     (fs, "")
}

func (ext4_filesystem* fs) format() (void, string) {
    _guard := fs.lock.lock()?

    blocks_per_group := fs.superblock.blocks_per_group
    num_groups := (1000000 + blocks_per_group - 1) / blocks_per_group

    group_idx := 0
    while group_idx < num_groups {
        bgd := block_group_descriptor{
            block_bitmap: 0,
            inode_bitmap: 0,
            inode_table: 0,
            free_blocks_count: blocks_per_group as u16,
            free_inodes_count: fs.superblock.inodes_per_group as u16,
            used_dirs_count: 0,
        }

        fs.block_groups = append(fs.block_groups, bgd)
        group_idx = group_idx + 1
    }

    root_inode := ext4_inode{
        mode: 0o40755,
        uid: 0,
        size: 0,
        atime: 0,
        ctime: 0,
        mtime: 0,
        dtime: 0,
        gid: 0,
        link_count: 2,
        block_count: 0,
        flags: 0,
        direct_blocks: initialize_blocks(),
        indirect_block: 0,
        double_indirect: 0,
        triple_indirect: 0,
        version: 1,
        file_acl: 0,
        size_high: 0,
        obso_fragment_addr: 0,
    }

    fs.inode_table = append(fs.inode_table, root_inode)
    return (), ""
}

func initialize_blocks() u32[12] {
    blocks := &[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    blocks
}

func (ext4_filesystem* fs) create_inode(mode: u16) (u32, string) {
    _guard := fs.lock.lock()?

    inode_num := len(fs.inode_table) as u32

    new_inode := ext4_inode{
        mode: mode,
        uid: 0,
        size: 0,
        atime: 0,
        ctime: 0,
        mtime: 0,
        dtime: 0,
        gid: 0,
        link_count: 1,
        block_count: 0,
        flags: 0,
        direct_blocks: initialize_blocks(),
        indirect_block: 0,
        double_indirect: 0,
        triple_indirect: 0,
        version: 1,
        file_acl: 0,
        size_high: 0,
        obso_fragment_addr: 0,
    }

    fs.inode_table = append(fs.inode_table, new_inode)
return     (inode_num, "")
}

func (ext4_filesystem* fs) delete_inode(inode_num: u32) (void, string) {
    _guard := fs.lock.lock()?

    if (inode_num as u32) >= len(fs.inode_table) as u32 {
        return ((), "inode number out of range")
    }

    return (), ""
}

func (ext4_filesystem* fs) open_file(
    inode_num: u32,
    mode: file_mode,
) (*ext4_file, string) {
    _guard := fs.lock.lock()?

    if (inode_num as u32) >= len(fs.inode_table) as u32 {
        return ((), "inode not found")
    }

    inode_ref := *fs.inode_table.get(inode_num) as *ext4_inode

    file := *ext4_file{
        inode_num: inode_num,
        inode: inode_ref,
        block_offset: 0,
        mode: mode,
        ref_count: 1,
    } as *ext4_file

    fs.open_files = append(fs.open_files, file)
return     (file, "")
}

func (ext4_filesystem* fs) close_file(inode_num: u32) (void, string) {
    _guard := fs.lock.lock()?

    found := false
    remove_idx := nil as option[u32]
    i := 0

    for file in fs.open_files {
        if file.inode_num == inode_num {
            found = true
            remove_idx = some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return ((), "file not open")
    }

    switch remove_idx {
        some(idx): {
            fs.open_files.remove(idx)
            return (), ""
        },
        nil: ((), "failed to close file"),
    }
}

func (ext4_filesystem* fs) allocate_block() (u32, string) {
    _guard := fs.lock.lock()?

    for group in fs.block_groups {
        if group.free_blocks_count > 0 {
            group.free_blocks_count = group.free_blocks_count - 1
            return group.block_bitmap, ""
        }
    }

    ((), "no free blocks available")
}

func (ext4_filesystem* fs) free_block(block_num: u32) (void, string) {
    _guard := fs.lock.lock()?

    for group in fs.block_groups {
        if group.block_bitmap == block_num {
            group.free_blocks_count = group.free_blocks_count + 1
            return return (), ""
        }
    }

    ((), "block not found")
}

func (ext4_filesystem* fs) write_inode(inode_num: u32, u8* data[], offset: u32) (u32, string) {
    _guard := fs.lock.lock()?

    if (inode_num as u32) >= len(fs.inode_table) as u32 {
        return ((), "inode not found")
    }

    inode := *fs.inode_table.get(inode_num) as *ext4_inode
    inode.size = inode.size + (len(data) as u32)
    inode.mtime = 0

    (data.len(, "") as u32)
}

func (ext4_filesystem* fs) read_inode(inode_num: u32, offset: u32, size: u32) (u8), string[] {
    _guard := fs.lock.lock()?

    buffer := u8[]()
return     (buffer, "")
}

struct ext4_statistics {
    total_inodes: u32,
    used_inodes: u32,
    free_inodes: u32,
    total_blocks: u32,
    free_blocks: u32,
    open_files: u32,
    block_size: u32,
}

func (ext4_filesystem* fs) get_statistics() (ext4_statistics, string) {
    _guard := fs.lock.lock()?

    total_blocks := 0
    free_blocks := 0

    for group in fs.block_groups {
        total_blocks = total_blocks + fs.superblock.blocks_per_group
        free_blocks = free_blocks + (group.free_blocks_count as u32)
    }

    stats := ext4_statistics{
        total_inodes: fs.superblock.total_inodes,
        used_inodes: len(fs.inode_table) as u32,
        free_inodes: fs.superblock.total_inodes - (len(fs.inode_table) as u32),
        total_blocks: total_blocks,
        free_blocks: free_blocks,
        open_files: len(fs.open_files) as u32,
        block_size: fs.superblock.block_size,
    }

return     (stats, "")
}

func (ext4_filesystem* fs) journal_add_transaction(inode_num: u32) (void, string) {
    return (), ""
}

func (ext4_filesystem* fs) journal_commit() (void, string) {
    return (), ""
}
