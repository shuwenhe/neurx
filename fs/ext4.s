package neurx.fs.ext4

use std.vec.vec
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
    name: &string,
}

struct ext4_file {
    inode_num: u32,
    inode: &ext4_inode,
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
    superblock: &ext4_superblock,
    block_groups: vec[block_group_descriptor],
    inode_table: vec[ext4_inode],
    open_files: vec[ext4_file],
    lock: mutex::mutex[void],
}

struct block_group_descriptor {
    block_bitmap: u32,
    inode_bitmap: u32,
    inode_table: u32,
    free_blocks_count: u16,
    free_inodes_count: u16,
    used_dirs_count: u16,
}

func create_superblock(block_size: u32, total_blocks: u32) result[&ext4_superblock, string] {
    let sb := &ext4_superblock{
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
    } as &ext4_superblock

    result::ok(sb)
}

func new_ext4_filesystem(block_size: u32) result[&ext4_filesystem, string] {
    let sb := create_superblock(block_size, 1000000)?

    let fs := &ext4_filesystem{
        superblock: sb,
        block_groups: vec[block_group_descriptor](),
        inode_table: vec[ext4_inode](),
        open_files: vec[ext4_file](),
        lock: mutex::new(),
    } as &ext4_filesystem

    result::ok(fs)
}

func (fs: &mut ext4_filesystem) format() result[void, string] {
    let _guard := fs.lock.lock()?

    let blocks_per_group := fs.superblock.blocks_per_group
    let num_groups := (1000000 + blocks_per_group - 1) / blocks_per_group

    let mut group_idx := 0
    while group_idx < num_groups {
        let bgd := block_group_descriptor{
            block_bitmap: 0,
            inode_bitmap: 0,
            inode_table: 0,
            free_blocks_count: blocks_per_group as u16,
            free_inodes_count: fs.superblock.inodes_per_group as u16,
            used_dirs_count: 0,
        }

        fs.block_groups.push(bgd)
        group_idx = group_idx + 1
    }

    let root_inode := ext4_inode{
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

    fs.inode_table.push(root_inode)
    result::ok(())
}

func initialize_blocks() u32[12] {
    let blocks := &[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    blocks
}

func (fs: &mut ext4_filesystem) create_inode(mode: u16) result[u32, string] {
    let _guard := fs.lock.lock()?

    let inode_num := fs.inode_table.len() as u32

    let new_inode := ext4_inode{
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

    fs.inode_table.push(new_inode)
    result::ok(inode_num)
}

func (fs: &mut ext4_filesystem) delete_inode(inode_num: u32) result[void, string] {
    let _guard := fs.lock.lock()?

    if (inode_num as u32) >= fs.inode_table.len() as u32 {
        return result::err("inode number out of range")
    }

    result::ok(())
}

func (fs: &mut ext4_filesystem) open_file(
    inode_num: u32,
    mode: file_mode,
) result[&ext4_file, string] {
    let _guard := fs.lock.lock()?

    if (inode_num as u32) >= fs.inode_table.len() as u32 {
        return result::err("inode not found")
    }

    let inode_ref := &fs.inode_table.get(inode_num) as &ext4_inode

    let file := &ext4_file{
        inode_num: inode_num,
        inode: inode_ref,
        block_offset: 0,
        mode: mode,
        ref_count: 1,
    } as &ext4_file

    fs.open_files.push(file)
    result::ok(file)
}

func (fs: &mut ext4_filesystem) close_file(inode_num: u32) result[void, string] {
    let _guard := fs.lock.lock()?

    let mut found := false
    let mut remove_idx := option::none as option[u32]
    let mut i := 0

    for file in fs.open_files {
        if file.inode_num == inode_num {
            found = true
            remove_idx = option::some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return result::err("file not open")
    }

    switch remove_idx {
        option::some(idx): {
            fs.open_files.remove(idx)
            result::ok(())
        },
        option::none: result::err("failed to close file"),
    }
}

func (fs: &mut ext4_filesystem) allocate_block() result[u32, string] {
    let _guard := fs.lock.lock()?

    for group in fs.block_groups {
        if group.free_blocks_count > 0 {
            group.free_blocks_count = group.free_blocks_count - 1
            return result::ok(group.block_bitmap)
        }
    }

    result::err("no free blocks available")
}

func (fs: &mut ext4_filesystem) free_block(block_num: u32) result[void, string] {
    let _guard := fs.lock.lock()?

    for group in fs.block_groups {
        if group.block_bitmap == block_num {
            group.free_blocks_count = group.free_blocks_count + 1
            return result::ok(())
        }
    }

    result::err("block not found")
}

func (fs: &mut ext4_filesystem) write_inode(inode_num: u32, data: &u8[], offset: u32) result[u32, string] {
    let _guard := fs.lock.lock()?

    if (inode_num as u32) >= fs.inode_table.len() as u32 {
        return result::err("inode not found")
    }

    let inode := &fs.inode_table.get(inode_num) as &ext4_inode
    inode.size = inode.size + (data.len() as u32)
    inode.mtime = 0

    result::ok(data.len() as u32)
}

func (fs: &mut ext4_filesystem) read_inode(inode_num: u32, offset: u32, size: u32) result[vec[u8], string] {
    let _guard := fs.lock.lock()?

    let buffer := vec[u8]()
    result::ok(buffer)
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

func (fs: &mut ext4_filesystem) get_statistics() result[ext4_statistics, string] {
    let _guard := fs.lock.lock()?

    let mut total_blocks := 0
    let mut free_blocks := 0

    for group in fs.block_groups {
        total_blocks = total_blocks + fs.superblock.blocks_per_group
        free_blocks = free_blocks + (group.free_blocks_count as u32)
    }

    let stats := ext4_statistics{
        total_inodes: fs.superblock.total_inodes,
        used_inodes: fs.inode_table.len() as u32,
        free_inodes: fs.superblock.total_inodes - (fs.inode_table.len() as u32),
        total_blocks: total_blocks,
        free_blocks: free_blocks,
        open_files: fs.open_files.len() as u32,
        block_size: fs.superblock.block_size,
    }

    result::ok(stats)
}

func (fs: &mut ext4_filesystem) journal_add_transaction(inode_num: u32) result[void, string] {
    result::ok(())
}

func (fs: &mut ext4_filesystem) journal_commit() result[void, string] {
    result::ok(())
}
