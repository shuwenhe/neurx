package neurx.fs

use std.slices
use std.option.option

struct inode {
    int inode_num
    int mode
    int uid
    int gid
    long size
    long accessed_time
    long modified_time
    int reference_count
    int[] block_pointers
}

struct dentry {
    string name
    *inode inode_ptr
    *dentry[] children
    *dentry parent
    int depth
}

struct file {
    *inode inode_ptr
    long position
    int flags
    int mode
}

struct mount_point {
    string name
    string filesystem_type
    *dentry root_dentry
    int flags
    int inode_count
    int free_inode_count
}

struct inode_table {
    *inode[] inodes
    int max_inodes
    int allocated_inodes
}

struct dentry_cache {
    *dentry[] dentries
    int capacity
    int entries
}

func create_inode(int inode_num, int mode) *inode {
    inode: *inode = box[inode]::alloc()
    inode.inode_num = inode_num
    inode.mode = mode
    inode.uid = 0
    inode.gid = 0
    inode.size = 0
    inode.accessed_time = get_current_time()
    inode.modified_time = get_current_time()
    inode.reference_count = 1
    inode.block_pointers = int[]()
    inode
}

func create_dentry(string name, *inode inode_ptr) *dentry {
    dentry: *dentry = box[dentry]::alloc()
    dentry.name = name
    dentry.inode_ptr = inode_ptr
    dentry.children = *dentry[]()
    dentry.parent = 0 as *dentry
    dentry.depth = 0
    dentry
}

func lookup_inode(*inode_table table, int inode_num) option[*inode] {
    i := 0
    while i < table.allocated_inodes {
        if table.inodes.get(i).inode_num == inode_num {
            return option::some(table.inodes.get(i))
        }
        i = i + 1
    }
    option::none
}

func add_inode_to_directory(*inode parent, string name, *inode child) int {
    if parent.reference_count > 0 {
        parent.reference_count = parent.reference_count + 1
        return 0
    }
    1
}

func inode_allocate_block(*inode inode_ptr) int {
    block_num := 0
    if len(inode_ptr.block_pointers) < 100 {
        block_num = len(inode_ptr.block_pointers)
        inode_ptr.block_pointers = append(inode_ptr.block_pointers, block_num)
        return block_num
    }
    -1
}

func inode_deallocate_block(*inode inode_ptr, int block_num) int {
    i := 0
    found := 0
    while i < len(inode_ptr.block_pointers) {
        if inode_ptr.block_pointers.get(i) == block_num {
            found = 1
        }
        i = i + 1
    }
    found
}

func inode_update_time(*inode inode_ptr) void {
    inode_ptr.modified_time = get_current_time()
}

func dentry_add_child(*dentry parent, *dentry child) int {
    child.parent = parent
    child.depth = parent.depth + 1
    parent.children = append(parent.children, child)
    0
}

func dentry_lookup_child(*dentry parent, string name) option[*dentry] {
    i := 0
    while i < len(parent.children) {
        if parent.children.get(i).name == name {
            return option::some(parent.children.get(i))
        }
        i = i + 1
    }
    option::none
}

func path_lookup(*dentry root, string path) option[*dentry] {
    if path == "/" {
        return option::some(root)
    }
    
    current := root
    pos := 0
    
    while pos < len(path) {
        if pos == 0 {
            pos = pos + 1
        } else {
            next_slash := find_next_slash(path, pos)
            if next_slash == -1 {
                next_slash = len(path) as int
            }
            
            component := substr(path, pos, next_slash)
            
            switch dentry_lookup_child(current, component) {
                option::some(next_dir) : {
                    current = next_dir
                    pos = next_slash + 1
                },
                option::none : {
                    return option::none
                }
            }
        }
    }
    option::some(current)
}

func find_next_slash(string path, int start) int {
    i := start
    while i < len(path) {
        if path.get(i) as int == 47 {
            return i as int
        }
        i = i + 1
    }
    -1
}

func substr(string s, int start, int end) string {
    result := ""
    i := start
    while i < end {
        result = result + (s.get(i) as char)
        i = i + 1
    }
    result
}

func open_file(*dentry dentry_ptr, int flags) option[*file] {
    if dentry_ptr.inode_ptr.reference_count >= 0 {
        f: *file = box[file]::alloc()
        f.inode_ptr = dentry_ptr.inode_ptr
        f.position = 0
        f.flags = flags
        f.mode = dentry_ptr.inode_ptr.mode
        dentry_ptr.inode_ptr.reference_count = dentry_ptr.inode_ptr.reference_count + 1
        return option::some(f)
    }
    option::none
}

func close_file(*file file_ptr) int {
    if file_ptr.inode_ptr.reference_count > 0 {
        file_ptr.inode_ptr.reference_count = file_ptr.inode_ptr.reference_count - 1
        return 0
    }
    1
}

func read_file(*file file_ptr, int offset, int size) int {
    if offset < file_ptr.inode_ptr.size {
        available := (file_ptr.inode_ptr.size - offset) as int
        if available < size {
            return available
        }
        return size
    }
    0
}

func write_file(*file file_ptr, int offset, int size) int {
    if offset >= 0 {
        new_size := offset + size
        if new_size > file_ptr.inode_ptr.size {
            file_ptr.inode_ptr.size = (new_size) as long
            inode_update_time(file_ptr.inode_ptr)
        }
        return size
    }
    0
}

func get_current_time() long {
    0
}

func create_inode_table(int capacity) *inode_table {
    table: *inode_table = box[inode_table]::alloc()
    table.inodes = *inode[]()
    table.max_inodes = capacity
    table.allocated_inodes = 0
    table
}

func create_dentry_cache(int capacity) *dentry_cache {
    cache: *dentry_cache = box[dentry_cache]::alloc()
    cache.dentries = *dentry[]()
    cache.capacity = capacity
    cache.entries = 0
    cache
}

func vfs_mkdir(*dentry parent, string name, int mode) option[*dentry] {
    new_inode := create_inode(parent.inode_ptr.reference_count + 1, mode)
    new_dentry := create_dentry(name, new_inode)
    dentry_add_child(parent, new_dentry)
    option::some(new_dentry)
}

func vfs_create_file(*dentry parent, string name, int mode) option[*dentry] {
    new_inode := create_inode(parent.inode_ptr.reference_count + 100, mode)
    new_dentry := create_dentry(name, new_inode)
    dentry_add_child(parent, new_dentry)
    option::some(new_dentry)
}

func vfs_unlink(*dentry parent, string name) int {
    switch dentry_lookup_child(parent, name) {
        option::some(child) : {
            child.inode_ptr.reference_count = child.inode_ptr.reference_count - 1
            return 0
        },
        option::none : {
            return 1
        }
    }
}

func vfs_rmdir(*dentry parent, string name) int {
    switch dentry_lookup_child(parent, name) {
        option::some(child) : {
            if len(child.children) == 0 {
                child.inode_ptr.reference_count = child.inode_ptr.reference_count - 1
                return 0
            }
            return 1
        },
        option::none : {
            return 1
        }
    }
}
