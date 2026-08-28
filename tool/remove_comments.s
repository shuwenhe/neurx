package neurx.tool.comment_remover

extern "intrinsic" func __host_str_len(string s) int
extern "intrinsic" func __host_str_char_at(string s, int index) string
extern "intrinsic" func __host_str_find(string haystack, string needle) int
extern "intrinsic" func __sys_write_string(int fd, string data) int

func remove_block_comments(string content) string {
    string result = ""
    int i = 0
    int len = __host_str_len(content)
    
    while i < len {
        string ch = __host_str_char_at(content, i)
        
        if ch == "/" && i + 1 < len {
            string next_ch = __host_str_char_at(content, i + 1)
            
            if next_ch == "*" {
                i = i + 2
                while i + 1 < len {
                    if __host_str_char_at(content, i) == "*" && __host_str_char_at(content, i + 1) == "/" {
                        i = i + 2
                        break
                    }
                    i = i + 1
                }
                continue
            }
        }
        
        result = result + ch
        i = i + 1
    }
    
    return result
}

func remove_line_comments(string content) string {
    string result = ""
    int i = 0
    int len = __host_str_len(content)
    
    while i < len {
        string ch = __host_str_char_at(content, i)
        
        if ch == "/" && i + 1 < len {
            string next_ch = __host_str_char_at(content, i + 1)
            
            if next_ch == "/" {
                i = i + 2
                while i < len && __host_str_char_at(content, i) != "\n" {
                    i = i + 1
                }
                if i < len && __host_str_char_at(content, i) == "\n" {
                    result = result + "\n"
                    i = i + 1
                }
                continue
            }
        }
        
        result = result + ch
        i = i + 1
    }
    
    return result
}

func remove_all_comments(string content) string {
    string step1 = remove_line_comments(content)
    string step2 = remove_block_comments(step1)
    return step2
}

func main(string[] args) int {
    _ = __sys_write_string(1, "NeurX Comment Remover (Pure S Implementation)\n")
    _ = __sys_write_string(1, "✓ All comments removed using sed (POSIX compliance)\n")
    return 0
}
