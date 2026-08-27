package neurx.security

use std.slices

// 用户结构
struct user {
    int uid
    string username
    string home_directory
    int gid
    int shell_id  // shell 类型
}

// 用户组结构
struct user_group {
    int gid
    string group_name
    int[] members  // 用户 UID 列表
}

// 文件权限结构
struct file_permission {
    int file_id
    int owner_uid
    int owner_gid
    int mode  // rwxrwxrwx (3 位一组)
    int acl_enabled  // 是否启用 ACL
}

// 访问控制列表项
struct acl_entry {
    int entry_id
    int subject_id  // UID 或 GID
    int subject_type  // 0=user, 1=group
    int permission  // r/w/x 权限
}

// 用户管理器
struct user_manager {
    user[] users
    user_group[] groups
    int next_uid
    int next_gid
}

// 初始化用户管理器
func (user_manager* um) init() (int, string) {
    um.users = user[]{}
    um.groups = user_group[]{}
    um.next_uid = 1000  // 普通用户从 1000 开始
    um.next_gid = 1000
    
    // 创建 root 用户 (UID 0)
    root := user{
        uid: 0,
        username: "root",
        home_directory: "/root",
        gid: 0,
        shell_id: 0
    }
    um.users = append(um.users, root)
    
    // 创建 root 用户组 (GID 0)
    root_group := user_group{
        gid: 0,
        group_name: "root",
        members: int[]{}"
    }
    um.groups = append(um.groups, root_group)
    
    return 0, ""
}

// 创建用户
func (user_manager* um) create_user(string username, string home_dir, int gid) (user, string) {
    new_user := user{
        uid: um.next_uid,
        username: username,
        home_directory: home_dir,
        gid: gid,
        shell_id: 0
    }
    
    um.users = append(um.users, new_user)
    um.next_uid = um.next_uid + 1
    
    return new_user, ""
}

// 删除用户
func (user_manager* um) delete_user(int uid) (int, string) {
    if uid == 0 {
        return -1, "Cannot delete root user"
    }
    
    i := 0
    for i < len(um.users) {
        u := um.users[i]
        if u.uid == uid {
            // 从用户向量中移除
            j := i
            for j < len(um.users) - 1 {
                um.users[j] = um.users[j + 1]
                j = j + 1
            }
            return 0, ""
        }
        i = i + 1
    }
    
    return -1, "User not found"
}

// 创建用户组
func (user_manager* um) create_group(string group_name) (user_group, string) {
    new_group := user_group{
        gid: um.next_gid,
        group_name: group_name,
        members: int[]{}"
    }
    
    um.groups = append(um.groups, new_group)
    um.next_gid = um.next_gid + 1
    
    return new_group, ""
}

// 添加用户到组
func (user_manager* um) add_user_to_group(int uid, int gid) (int, string) {
    // 检查用户是否存在
    user_exists := 0
    i := 0
    for i < len(um.users) {
        u := um.users[i]
        if u.uid == uid {
            user_exists = 1
            break
        }
        i = i + 1
    }
    
    if user_exists == 0 {
        return -1, "User not found"
    }
    
    // 查找组并添加用户
    i = 0
    for i < len(um.groups) {
        g := um.groups[i]
        if g.gid == gid {
            g.members = append(g.members, uid)
            um.groups[i] = g
            return 0, ""
        }
        i = i + 1
    }
    
    return -1, "Group not found"
}

// 从组中移除用户
func (user_manager* um) remove_user_from_group(int uid, int gid) (int, string) {
    i := 0
    for i < len(um.groups) {
        g := um.groups[i]
        if g.gid == gid {
            j := 0
            for j < len(g.members) {
                member_uid := g.members[j]
                if member_uid == uid {
                    // 移除用户
                    k := j
                    for k < len(g.members) - 1 {
                        g.members[k] = g.members[k + 1]
                        k = k + 1
                    }
                    um.groups[i] = g
                    return 0, ""
                }
                j = j + 1
            }
        }
        i = i + 1
    }
    
    return -1, "User not in group"
}

// 获取用户信息
func (user_manager um) get_user(int uid) (user, string) {
    i := 0
    for i < len(um.users) {
        u := um.users[i]
        if u.uid == uid {
            return u, ""
        }
        i = i + 1
    }
    
    return user{}, "User not found"
}

// 获取组信息
func (user_manager um) get_group(int gid) (user_group, string) {
    i := 0
    for i < len(um.groups) {
        g := um.groups[i]
        if g.gid == gid {
            return g, ""
        }
        i = i + 1
    }
    
    return user_group{}, "Group not found"
}

// 文件权限管理器
struct file_permission_manager {
    vec permissions
    vec acl_entries
    int next_acl_id
}

// 初始化文件权限管理器
func (file_permission_manager* fpm) init() (int, string) {
    fpm.permissions = file_permission[]{}
    fpm.acl_entries = acl_entry[]{}
    fpm.next_acl_id = 0
    return 0, ""
}

// 设置文件权限
func (file_permission_manager* fpm) set_file_permission(int file_id, int owner_uid, int owner_gid, int mode) (file_permission, string) {
    perm := file_permission{
        file_id: file_id,
        owner_uid: owner_uid,
        owner_gid: owner_gid,
        mode: mode,
        acl_enabled: 0
    }
    
    fpm.permissions = append(fpm.permissions, perm)
    return perm, ""
}

// 添加 ACL 条目
func (file_permission_manager* fpm) add_acl_entry(int file_id, int subject_id, int subject_type, int permission) (int, string) {
    entry := acl_entry{
        entry_id: fpm.next_acl_id,
        subject_id: subject_id,
        subject_type: subject_type,
        permission permission
    }
    
    fpm.acl_entries = append(fpm.acl_entries, entry)
    fpm.next_acl_id = fpm.next_acl_id + 1
    
    // 启用该文件的 ACL
    i := 0
    for i < len(fpm.permissions) {
        perm := fpm.permissions[i]
        if perm.file_id == file_id {
            perm.acl_enabled = 1
            fpm.permissions[i] = perm
            break
        }
        i = i + 1
    }
    
    return entry.entry_id, ""
}

// 检查用户是否有权限访问文件
func (file_permission_manager fpm) check_permission(int file_id, int uid, int operation) (int, string) {
    // operation: 0=read, 1=write, 2=execute
    
    i := 0
    for i < len(fpm.permissions) {
        perm := fpm.permissions[i]
        if perm.file_id == file_id {
            // 如果是所有者
            if uid == perm.owner_uid {
                owner_perm := (perm.mode >> 6) & 7  // 提取所有者权限
                if operation <= 2 && owner_perm & (1 << (2 - operation)) != 0 {
                    return 1, "Allowed"
                }
            }
            
            // 检查 ACL
            if perm.acl_enabled == 1 {
                j := 0
                for j < len(fpm.acl_entries) {
                    entry := fpm.acl_entries[j]
                    if entry.subject_id == uid && entry.subject_type == 0 {
                        if entry.permission & (1 << operation) != 0 {
                            return 1, "Allowed by ACL"
                        }
                    }
                    j = j + 1
                }
            }
            
            return 0, "Permission denied"
        }
        i = i + 1
    }
    
    return -1, "File not found"
}

// 获取用户统计
func (user_manager um) get_user_stats() (int, int) {
    return len(um.users), len(um.groups)
}
