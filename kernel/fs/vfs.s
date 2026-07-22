



















int INODE_FILE      = 0
int INODE_DIR       = 1
int INODE_TENSOR    = 2
int INODE_KV_PAGE   = 3
int INODE_TOOL      = 4
int INODE_MEMORY    = 5
int INODE_VECTOR    = 6

struct inode {
    int    ino
    string path
    int    inode_type
    int    size_bytes
    bool   loaded
    bool   dirty
    int    ref_count
    string backend
}

struct dentry {
    int    dino
    string name
    int    ino
    int    parent_dino
}

struct vfs_state {
    []inode  inodes
    []dentry dentries
    int      next_ino
    int      next_dino
}

func new_vfs() vfs_state {
    return vfs_state{
        inodes:    [],
        dentries:  [],
        next_ino:  1,
        next_dino: 1,
    }
}


func vfs_create(vfs vfs_state, path string, inode_type int, size_bytes int, backend string) (vfs_state, int) {
    inode n = inode{
        ino:        vfs.next_ino,
        path:       path,
        inode_type: inode_type,
        size_bytes: size_bytes,
        loaded:     false,
        dirty:      false,
        ref_count:  0,
        backend:    backend,
    }
    vfs.inodes = append(vfs.inodes, n)
    int ino = vfs.next_ino
    vfs.next_ino = vfs.next_ino + 1
    return (vfs, ino)
}


func vfs_lookup(vfs vfs_state, path string) (inode, bool) {
    int i = 0
    while i < len(vfs.inodes) {
        if vfs.inodes[i].path == path {
            return (vfs.inodes[i], true)
        }
        i = i + 1
    }
    return (inode{}, false)
}


func vfs_open(vfs vfs_state, ino int) vfs_state {
    int i = 0
    while i < len(vfs.inodes) {
        if vfs.inodes[i].ino == ino {
            vfs.inodes[i].ref_count = vfs.inodes[i].ref_count + 1
        }
        i = i + 1
    }
    return vfs
}


func vfs_close(vfs vfs_state, ino int) vfs_state {
    int i = 0
    while i < len(vfs.inodes) {
        if vfs.inodes[i].ino == ino && vfs.inodes[i].ref_count > 0 {
            vfs.inodes[i].ref_count = vfs.inodes[i].ref_count - 1
        }
        i = i + 1
    }
    return vfs
}
