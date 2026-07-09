package neurx.posttrain.reward.examples

use neurx.posttrain.reward.factual_consistency_reward.*

// ════════════════════════════════════════════════════════════════════════════════
// Factual Consistency Reward 示例
// 
// 展示如何使用事实一致性奖励进行评估
// ════════════════════════════════════════════════════════════════════════════════

// 创建默认配置
func create_factual_config() factual_config {
    factual_config {
        // 提取参数
        max_facts_per_doc: 20,
        extract_temporal: true,
        extract_location: true,
        
        // 验证参数
        similarity_threshold: 0.7,
        confidence_threshold: 0.5,
        
        // 幻觉检测
        detect_hallucinations: true,
        hallucination_threshold: 0.3,
        
        // 引用处理
        require_citations: false,
        check_citation_accuracy: false,
        
        // 权重 (总和应该 = 1.0)
        accuracy_weight: 0.4,      // 生成事实的准确度
        hallucination_weight: 0.3,  // 避免幻觉
        coverage_weight: 0.2,       // 覆盖参考事实
        citation_weight: 0.1,       // 引用覆盖
    }
}

// 示例 1: 基础事实一致性评估
func example_basic_factual_consistency() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic Factual Consistency Evaluation          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    string reference = "Paris is the capital of France. France is located in Europe. " +
                      "Paris has a population of approximately 2 million people."
    
    string generated = "Paris is the capital of France. It is located in Europe. " +
                      "The city has around 2 million inhabitants."
    
    factual_config config = create_factual_config()
    
    print("Reference Text:")
    print("  " + reference)
    print("")
    print("Generated Text:")
    print("  " + generated)
    print("")
    
    float reward = compute_factual_consistency_reward(reference, generated, config)
    
    print("Factual Consistency Reward: " + float_to_string_example(reward))
    print("")
}

// 示例 2: 检测幻觉
func example_hallucination_detection() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: Hallucination Detection                       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    string reference = "Albert Einstein won the Nobel Prize in Physics in 1921. " +
                      "He developed the theory of relativity."
    
    // 包含幻觉的生成文本
    string generated_with_hallucination = "Albert Einstein won the Nobel Prize in Physics in 1921. " +
                                         "He also won the Nobel Prize in Chemistry in 1925. " +
                                         "He developed the theory of relativity and invented the telephone."
    
    factual_config config = create_factual_config()
    config.detect_hallucinations = true
    
    print("Reference:")
    print("  " + reference)
    print("")
    print("Generated (with hallucinations):")
    print("  " + generated_with_hallucination)
    print("")
    
    // 提取事实
    factual_content ref_facts = extract_facts(reference, config)
    factual_content gen_facts = extract_facts(generated_with_hallucination, config)
    
    // 验证一致性
    consistency_report report = verify_factual_consistency(ref_facts, gen_facts, config)
    
    print("Analysis:")
    print("  Reference Facts: " + string_int(report.total_reference_facts))
    print("  Generated Facts: " + string_int(report.total_generated_facts))
    print("  Consistent: " + string_int(report.consistent_facts))
    print("  Hallucinated: " + string_int(len(report.hallucinated_facts)))
    print("")
    
    if len(report.hallucinated_facts) > 0 {
        print("Detected Hallucinations:")
        int i = 0
        while i < len(report.hallucinated_facts) {
            print("  - " + report.hallucinated_facts[i])
            i = i + 1
        }
    }
    print("")
}

// 示例 3: 医学文本事实检查
func example_medical_fact_checking() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: Medical Text Fact Checking                    ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    string reference = "Aspirin is used to treat pain and inflammation. " +
                      "It was discovered in 1897. " +
                      "The typical dose is 500mg to 1000mg every 4-6 hours."
    
    string generated = "Aspirin is a pain reliever discovered in 1897. " +
                      "It is used for treating various types of pain and inflammation. " +
                      "The normal dose is between 500mg and 1000mg."
    
    factual_config config = create_factual_config()
    
    print("Reference Medical Text:")
    print("  " + reference)
    print("")
    print("Generated Medical Summary:")
    print("  " + generated)
    print("")
    
    float reward = compute_factual_consistency_reward(reference, generated, config)
    
    print("Medical Factual Accuracy: " + float_to_string_example(reward))
    
    if reward > 0.8 {
        print("✅ High factual accuracy - safe for medical use")
    } else if reward > 0.6 {
        print("⚠️ Moderate accuracy - review before use")
    } else {
        print("❌ Low accuracy - do not use for medical guidance")
    }
    print("")
}

// 示例 4: 新闻事实核查
func example_news_fact_checking() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: News Fact Checking                            ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    string reference = "The 2024 Olympics were held in Paris, France from July to August. " +
                      "It was the third time Paris hosted the Olympics. " +
                      "Over 10,000 athletes participated."
    
    string generated = "The 2024 Olympics took place in Paris. " +
                      "Paris hosted the Olympics for the third time. " +
                      "Approximately 10,000 athletes competed from around the world."
    
    factual_config config = create_factual_config()
    config.require_citations = false
    
    print("Reference News:")
    print("  " + reference)
    print("")
    print("Generated News Summary:")
    print("  " + generated)
    print("")
    
    // 提取和验证
    factual_content ref_facts = extract_facts(reference, config)
    factual_content gen_facts = extract_facts(generated, config)
    consistency_report report = verify_factual_consistency(ref_facts, gen_facts, config)
    
    print("[Coverage Analysis]")
    print("  Reference Facts Covered: " + float_to_string_example(report.coverage_score * 100.0) + "%")
    print("  Accuracy: " + float_to_string_example(report.factual_accuracy * 100.0) + "%")
    print("")
}

// 示例 5: 比较不同质量的生成
func example_quality_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 5: Quality Comparison                            ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    string reference = "Python is a high-level programming language created by Guido van Rossum " +
                      "in 1989. It emphasizes code readability. Python 3.0 was released in 2008."
    
    string good_generation = "Python is a high-level language created by Guido van Rossum in 1989. " +
                            "The language focuses on readability. Python 3.0 came out in 2008."
    
    string poor_generation = "Python was created in 1990 by Guido van Rossum. " +
                            "It is used for web development and AI. " +
                            "Java is similar to Python in every way."
    
    factual_config config = create_factual_config()
    
    float good_reward = compute_factual_consistency_reward(reference, good_generation, config)
    float poor_reward = compute_factual_consistency_reward(reference, poor_generation, config)
    
    print("Reference:")
    print("  " + reference)
    print("")
    
    print("Good Generation:")
    print("  " + good_generation)
    print("  Score: " + float_to_string_example(good_reward))
    print("")
    
    print("Poor Generation:")
    print("  " + poor_generation)
    print("  Score: " + float_to_string_example(poor_reward))
    print("")
    
    print("Difference: " + float_to_string_example((good_reward - poor_reward) * 100.0) + " points")
    print("")
}

// 示例 6: 用于 GRPO/DPO 训练的奖励
func example_reward_for_alignment() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Factual Reward in Alignment Training          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    print("Integration with GRPO/DPO training:")
    print("")
    print("1. Compute base reward from factual consistency")
    print("2. Combine with other reward signals (format, length, etc.)")
    print("3. Use weighted sum for total reward")
    print("")
    
    string reference = "Water boils at 100 degrees Celsius at sea level."
    string response1 = "Water boils at 100°C at sea level."
    string response2 = "Water boils at 50°C at sea level."
    
    factual_config config = create_factual_config()
    
    float reward1 = compute_factual_consistency_reward(reference, response1, config)
    float reward2 = compute_factual_consistency_reward(reference, response2, config)
    
    print("Response 1: \"" + response1 + "\"")
    print("  Factual Reward: " + float_to_string_example(reward1))
    print("")
    
    print("Response 2: \"" + response2 + "\"")
    print("  Factual Reward: " + float_to_string_example(reward2))
    print("")
    
    print("In GRPO training, R1 would be strongly preferred over R2")
    print("This guides the model towards factually accurate responses")
    print("")
}

// Main 函数
func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX Factual Consistency Reward Examples                  ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    
    example_basic_factual_consistency()
    example_hallucination_detection()
    example_medical_fact_checking()
    example_news_fact_checking()
    example_quality_comparison()
    example_reward_for_alignment()
    
    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

// 辅助函数
func float_to_string_example(float f) string {
    int i_part = int(f)
    int f_part = int((f - float(i_part)) * 1000.0)
    string(i_part) + "." + string(f_part)
}

func string_int(int i) string {
    string(i)
}
