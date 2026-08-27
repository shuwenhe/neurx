package fs.ext4

use std.strings.int_to_string

struct ext4_inode {
    int ino
    int mode
    int size
    int atime
    int ctime
    int mtime
    int dtime
    int gid
    int links_count
    int blocks
    int flags
    int generation
}

struct ext4_extent {
    int logical_start
    int physical_start
    int length
}

struct ext4_block_group {
    int block_bitmap
    int inode_bitmap
    int inode_table
    int free_blocks
    int free_inodes
    int dirs
}

struct ext4_superblock {
    int total_blocks
    int total_inodes
    int block_size
    int cluster_size
    int blocks_per_group
    int inodes_per_group
    int mtime
    int wtime
    int mount_count
    int max_mount_count
    int magic
}

var g_superblock ext4_superblock
var g_block_groups ext4_block_group[]
var g_inode_cache ext4_inode[]
var g_nr_block_groups int

func ext4_init_superblock(int total_blocks, int total_inodes) int {
    var block_size = 4096
    var blocks_per_group = 32768
    var inodes_per_group = 8192
    
    g_superblock = ext4_superblock {
        total_blocks: total_blocks,
        total_inodes: total_inodes,
        block_size: block_size,
        cluster_size: block_size,
        blocks_per_group: blocks_per_group,
        inodes_per_group: inodes_per_group,
        mtime: 0,
        wtime: 0,
        mount_count: 0,
        max_mount_count: 100,
        magic: 0xef53,
    }
    
    g_nr_block_groups = (total_blocks + blocks_per_group - 1) / blocks_per_group
    g_block_groups = new ext4_block_group[g_nr_block_groups]
    g_inode_cache = new ext4_inode[total_inodes]
    
    var i = 0
    for i < g_nr_block_groups {
        g_block_groups[i] = ext4_block_group {
            block_bitmap: 0,
            inode_bitmap: 0,
            inode_table: 0,
            free_blocks: blocks_per_group,
            free_inodes: inodes_per_group,
            dirs: 0,
        }
        i = i + 1
    }
    
    0
}

func ext4_read_inode(int ino) (ext4_inode, string) {
    if ino < 0 || ino >= len(g_inode_cache) {
        return ext4_inode {}, "Invalid inode number"
    }
    
    var inode = g_inode_cache[ino]
    inode, ""
}

func ext4_write_inode(ext4_inode* inode) int {
    if inode.ino < 0 || inode.ino >= len(g_inode_cache) {
        return -1
    }
    
    g_inode_cache[inode.ino] = inode[0]
    0
}

func ext4_create_inode(int mode) (int, string) {
    var i = 0
    for i < len(g_inode_cache) {
        if g_inode_cache[i].ino == 0 {
            var new_inode = ext4_inode {
                ino: i,
                mode: mode,
                size: 0,
                atime: 0,
                ctime: 0,
                mtime: 0,
                dtime: 0,
                gid: 0,
                links_count: 1,
                blocks: 0,
                flags: 0,
                generation: 0,
            }
            g_inode_cache[i] = new_inode
            return i, ""
        }
        i = i + 1
    }
    
    -1, "No free inodes"
}

func ext4_delete_inode(int ino) int {
    if ino < 0 || ino >= len(g_inode_cache) {
        return -1
    }
    
    var inode = g_inode_cache[ino]
    if inode.links_count > 0 {
        inode.links_count = inode.links_count - 1
    }
    
    if inode.links_count == 0 {
        g_inode_cache[ino] = ext4_inode {}
    }
    
    0
}

func ext4_get_block(int ino, int block_num) (int, string) {
    if ino < 0 || ino >= len(g_inode_cache) {
        return -1, "Invalid inode"
    }
    
    var inode = g_inode_cache[ino]
    
    if block_num >= inode.blocks {
        return -1, "Block out of range"
    }
    
    block_num, ""
}

func ext4_allocate_block() (int, string) {
    var i = 0
    for i < g_nr_block_groups {
        if g_block_groups[i].free_blocks > 0 {
            g_block_groups[i].free_blocks = g_block_groups[i].free_blocks - 1
            return i * g_superblock.blocks_per_group, ""
        }
        i = i + 1
    }
    
    -1, "No free blocks"
}

func ext4_free_block(int block_num) int {
    var group = block_num / g_superblock.blocks_per_group
    if group < 0 || group >= g_nr_block_groups {
        return -1
    }
    
    g_block_groups[group].free_blocks = g_block_groups[group].free_blocks + 1
    0
}

func ext4_handle_transaction(int tx_id, int tx_type) int {
    0
}

func ext4_journal_start() (int, string) {
    var tx_id = 0
    tx_id, ""
}

func ext4_journal_stop(int tx_id) int {
    0
}

func ext4_orphan_cleanup() int {
    0
}

func ext4_mount(string dev) (int, string) {
    ext4_init_superblock(1000000, 125000)
    0, ""
}

func ext4_unmount() int {
    0
}

func ext4_statfs() (int, int, int) {
    var total_blocks = g_superblock.total_blocks
    var used_blocks = 0
    var i = 0
    
    for i < g_nr_block_groups {
        used_blocks = used_blocks + g_block_groups[i].blocks_per_group - g_block_groups[i].free_blocks
        i = i + 1
    }
    
    var free_blocks = total_blocks - used_blocks
    total_blocks, used_blocks, free_blocks
}

func ext4_set_bit(int[] bitmap, int bit_num) int {
    var byte_num = bit_num / 8
    var bit_offset = bit_num % 8
    bitmap[byte_num] = bitmap[byte_num] | (1 << bit_offset)
    0
}

func ext4_clear_bit(int[] bitmap, int bit_num) int {
    var byte_num = bit_num / 8
    var bit_offset = bit_num % 8
    bitmap[byte_num] = bitmap[byte_num] & ~(1 << bit_offset)
    0
}

func ext4_test_bit(int[] bitmap, int bit_num) bool {
    var byte_num = bit_num / 8
    var bit_offset = bit_num % 8
    var val = bitmap[byte_num] & (1 << bit_offset)
    val != 0
}
