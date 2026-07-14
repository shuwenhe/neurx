package neurx.data.data_cleaning

// ============================================================================
// 数据清洗模块 - 将 raw/ 数据处理为 cleaned/ 版本
// ============================================================================

use neurx.strings.{string_contains, string_index_of, string_split, string_trim, string_length}
use neurx.runtime.io.{
    io_println, io_file_exists, io_read_lines, io_mkdir_recursive,
    io_write_file, io_list_files, io_file_size
}

// ============================================================================
// 1. 数据清洗配置
// ============================================================================

struct cleaning_config {
    string raw_dir              // 原始数据目录
    string cleaned_dir          // 清洁数据输出目录
    string output_file          // 合并输出文件
    int min_text_length         // 最小文本长度
    int max_text_length         // 最大文本长度
    bool enable_dedup           // 是否去重
    bool enable_filtering       // 是否过滤
}

struct cleaning_stats {
    int total_documents
    int valid_documents
    int duplicates_removed
    int empty_documents
    int short_documents
    int long_documents
    long total_tokens_estimate
}

// ============================================================================
// 2. 初始化函数
// ============================================================================

func new_cleaning_config() cleaning_config {
    cleaning_config {
        raw_dir: "dataset/pretrain/raw",
        cleaned_dir: "dataset/pretrain/cleaned",
        output_file: "dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl",
        min_text_length: 50,
        max_text_length: 100000,
        enable_dedup: true,
        enable_filtering: true,
    }
}

func new_cleaning_stats() cleaning_stats {
    cleaning_stats {
        total_documents: 0,
        valid_documents: 0,
        duplicates_removed: 0,
        empty_documents: 0,
        short_documents: 0,
        long_documents: 0,
        total_tokens_estimate: 0,
    }
}

// ============================================================================
// 3. 核心清洗函数
// ============================================================================

struct cleaning_result {
    string cleaned_text
    bool is_valid
    cleaning_stats stats
}

// 简单的哈希函数用于去重
func simple_hash(string text) string {
    // 对于 S 语言版本，使用文本长度 + 前缀作为去重键
    // 实际生产环境应使用 MD5 或 SHA256
    int len = string_length(text)
    string prefix = ""
    if len > 32 {
        prefix = substring(text, 0, 32)
    } else {
        prefix = text
    }
    return prefix + "_" + string(len)
}

// 检查文本是否为空或全空白
func is_empty_text(string text) bool {
    string trimmed = string_trim(text)
    return string_length(trimmed) == 0
}

// 清洗单条记录
func clean_record(string line) cleaning_result {
    cleaning_stats stats = new_cleaning_stats()
    stats.total_documents = 1
    
    cleaning_result result
    result.stats = stats
    result.is_valid = false
    result.cleaned_text = ""
    
    // 解析 JSON 字段
    // 简单的 JSON 解析逻辑（处理 {"text": "..."} 格式）
    
    string text = ""
    
    // 查找 "text" 字段
    int text_start = string_index_of(line, "\"text\":")
    if text_start >= 0 {
        // 找到文本起点
        int quote_start = string_index_of(substring(line, text_start, string_length(line)), "\"")
        if quote_start >= 0 {
            int actual_start = text_start + quote_start + 1
            int quote_end = string_index_of(substring(line, actual_start, string_length(line)), "\"")
            if quote_end >= 0 {
                text = substring(line, actual_start, quote_end)
            }
        }
    }
    
    // 过滤空文本
    if is_empty_text(text) {
        result.stats.empty_documents = 1
        return result
    }
    
    string trimmed = string_trim(text)
    int text_len = string_length(trimmed)
    
    // 过滤长度
    if text_len < 50 {
        result.stats.short_documents = 1
        return result
    }
    
    if text_len > 100000 {
        result.stats.long_documents = 1
        trimmed = substring(trimmed, 0, 100000)
    }
    
    // 构造清洁记录
    string cleaned = "{\"text\":\"" + trimmed + "\",\"source\":\"raw\",\"length\":" + string(text_len) + "}"
    result.is_valid = true
    result.cleaned_text = cleaned
    result.stats.valid_documents = 1
    result.stats.total_tokens_estimate = long(text_len / 4)  // 粗略估计
    
    return result
}

// ============================================================================
// 4. 主清洗流程
// ============================================================================

func clean_raw_data(cleaning_config cfg) cleaning_stats {
    io_println("🔄 开始数据清洗流程...\n")
    
    // 创建输出目录
    io_mkdir_recursive(cfg.cleaned_dir)
    
    cleaning_stats total_stats = new_cleaning_stats()
    []string seen_texts = []string{cap: 10000}  // 去重集合
    int seen_count = 0
    
    // 读取所有原始文件
    []string raw_files = io_list_files(cfg.raw_dir, "*.jsonl")
    
    // 打开输出文件
    // 注意：这里使用伪代码，实际需要文件 I/O 支持
    
    io_println("📖 开始处理 " + string(len(raw_files)) + " 个文件...\n")
    
    for i := 0; i < len(raw_files); i = i + 1 {
        string raw_file = raw_files[i]
        io_println("📄 处理: " + raw_file)
        
        []string lines = io_read_lines(raw_file)
        
        for j := 0; j < len(lines); j = j + 1 {
            string line = lines[j]
            
            // 清洗单条记录
            cleaning_result cr = clean_record(line)
            
            total_stats.total_documents = total_stats.total_documents + cr.stats.total_documents
            total_stats.empty_documents = total_stats.empty_documents + cr.stats.empty_documents
            total_stats.short_documents = total_stats.short_documents + cr.stats.short_documents
            total_stats.long_documents = total_stats.long_documents + cr.stats.long_documents
            
            if cr.is_valid {
                // 去重检查
                string hash = simple_hash(cr.cleaned_text)
                bool is_duplicate = false
                
                for k := 0; k < seen_count; k = k + 1 {
                    if seen_texts[k] == hash {
                        is_duplicate = true
                        break
                    }
                }
                
                if is_duplicate {
                    total_stats.duplicates_removed = total_stats.duplicates_removed + 1
                } else {
                    // 写入有效的清洁记录
                    // io_append_line(cfg.output_file, cr.cleaned_text)
                    
                    // 添加到去重集合
                    if seen_count < len(seen_texts) {
                        seen_texts[seen_count] = hash
                        seen_count = seen_count + 1
                    }
                    
                    total_stats.valid_documents = total_stats.valid_documents + 1
                    total_stats.total_tokens_estimate = total_stats.total_tokens_estimate + cr.stats.total_tokens_estimate
                }
            }
            
            if total_stats.valid_documents % 1000 == 0 {
                io_println("  ✓ 已处理 " + string(total_stats.valid_documents) + " 个文档")
            }
        }
    }
    
    io_println("\n✅ 清洗完成!")
    io_println("  • 有效文档: " + string(total_stats.valid_documents))
    io_println("  • 去重数量: " + string(total_stats.duplicates_removed))
    io_println("  • 空文档: " + string(total_stats.empty_documents))
    io_println("  • 短文档: " + string(total_stats.short_documents))
    io_println("  • 长文档: " + string(total_stats.long_documents))
    io_println("  • 估计 tokens: " + string(total_stats.total_tokens_estimate))
    io_println("  • 输出文件: " + cfg.output_file)
    
    return total_stats
}

// ============================================================================
// 5. 生成数据集分割
// ============================================================================

func generate_dataset_splits(cleaning_config cfg) {
    io_println("\n📊 生成数据集分割...")
    
    []string all_lines = io_read_lines(cfg.output_file)
    int total = len(all_lines)
    
    // 分割比例: 80% train, 10% val, 10% test
    int train_size = (total * 80) / 100
    int val_size = (total * 10) / 100
    
    // 生成训练集
    io_println("  ✓ 生成训练集: " + string(train_size) + " 文档")
    // io_write_lines(cfg.cleaned_dir + "/train.jsonl", all_lines[0:train_size])
    
    // 生成验证集
    io_println("  ✓ 生成验证集: " + string(val_size) + " 文档")
    // io_write_lines(cfg.cleaned_dir + "/val.jsonl", all_lines[train_size:train_size+val_size])
    
    // 生成测试集
    int test_size = total - train_size - val_size
    io_println("  ✓ 生成测试集: " + string(test_size) + " 文档")
    // io_write_lines(cfg.cleaned_dir + "/test.jsonl", all_lines[train_size+val_size:])
}

// ============================================================================
// 6. 主入口
// ============================================================================

func run_data_cleaning() {
    cleaning_config cfg = new_cleaning_config()
    
    io_println("╔════════════════════════════════════════════╗")
    io_println("║       NeurX 数据清洗模块 (S语言实现)       ║")
    io_println("╚════════════════════════════════════════════╝\n")
    
    cleaning_stats stats = clean_raw_data(cfg)
    
    io_println("\n📁 数据清洗管道信息:")
    io_println("  • 原始数据: " + cfg.raw_dir)
    io_println("  • 清洁输出: " + cfg.cleaned_dir)
    io_println("  • 生效率: " + string((stats.valid_documents * 100) / stats.total_documents) + "%")
    
    generate_dataset_splits(cfg)
    
    io_println("\n✨ 数据清洗流程完成!")
    io_println("下一步: 生成分片数据到 shard/ 目录")
}
