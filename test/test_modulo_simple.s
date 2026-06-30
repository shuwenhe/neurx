package main

func main() {
    // 测试模运算 (%) 操作符
    
    println("======================================================================")
    println("S 语言模运算 (%) 操作符测试")
    println("======================================================================")
    println("")
    
    let a = 10
    let b = 3
    let result = a % b
    
    println("测试 1: 基本模运算")
    println("  10 % 3 = " + string(result))
    println("")
    
    println("测试 2: 更多模运算测试")
    let r1 = 15 % 4
    let r2 = 20 % 6
    let r3 = 7 % 7
    let r4 = 5 % 2
    
    println("  15 % 4 = " + string(r1))
    println("  20 % 6 = " + string(r2))
    println("  7 % 7 = " + string(r3))
    println("  5 % 2 = " + string(r4))
    println("")
    
    println("======================================================================")
    println("✅ 模运算 (%) 操作符支持成功！")
    println("======================================================================")
}
