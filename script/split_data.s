// S语言实现：数据集分割工具
// 将训练数据分割成train/val/test三个集合

package main

// 配置结构体
struct SplitConfig {
    source_file: string
    output_dir: string
    train_ratio: float
    val_ratio: float
    test_ratio: float
}

// 分割统计
struct SplitStats {
    total_records: int
    train_count: int
    val_count: int
    test_count: int
    train_hash: string
    val_hash: string
    test_hash: string
}

// 初始化配置
func new_config(): SplitConfig {
    return SplitConfig{
        source_file: "data/training_data.jsonl",
        output_dir: "data/training_data_splits",
        train_ratio: 0.8,
        val_ratio: 0.1,
        test_ratio: 0.1,
    }
}

// 验证比例
func validate_ratios(train: float, val: float, test: float): bool {
    total := train + val + test
    // 允许浮点误差
    return total > 0.99 && total < 1.01
}

// 计算分割点
func calculate_split_points(total: int, train_ratio: float, val_ratio: float): (int, int) {
    train_count := int(float(total) * train_ratio)
    val_count := int(float(total) * val_ratio)
    return train_count, val_count
}

// 分配数据到指定集合
func assign_split(line_num: int, train_count: int, val_count: int): string {
    if line_num <= train_count {
        return "train"
    }
    if line_num <= train_count + val_count {
        return "val"
    }
    return "test"
}

// 主函数
func main() {
    println("🔄 开始分割训练数据集...")
    println("")
    
    config := new_config()
    
    // 验证配置
    if !validate_ratios(config.train_ratio, config.val_ratio, config.test_ratio) {
        println("❌ 错误：分割比例不合法")
        return
    }
    
    println("✅ S语言数据分割框架已就绪")
    printf("  源文件: %s\n", config.source_file)
    printf("  输出目录: %s\n", config.output_dir)
    printf("  训练比例: %.1f%%\n", config.train_ratio * 100)
    printf("  验证比例: %.1f%%\n", config.val_ratio * 100)
    printf("  测试比例: %.1f%%\n", config.test_ratio * 100)
}
