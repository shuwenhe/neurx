package neurx.runtime.model.json_parser

use std.vec.vec
use std.io.println

// ============================================================================
// Pure S JSON Parser (替代 json.cpp)
// 
// 目的: 移除 C++ 依赖，完全用 S 实现 JSON 解析
// 预期: 性能相同或更好 (S 编译为原生机器码)
// 测试: 与 HF config.json 兼容性验证
// ============================================================================

enum json_type {
    null_type,
    bool_type,
    number_type,
    string_type,
    array_type,
    object_type,
}

struct json_value {
    json_type value_type
    string string_value
    float number_value
    bool bool_value
    []json_value array_elements
    []json_pair object_members
}

struct json_pair {
    string key
    json_value value
}

struct json_parser_state {
    string input
    int pos
    int line
    int column
}

// ============================================================================
// 基础解析函数
// ============================================================================

func is_whitespace(char c) bool {
    c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

func is_digit(char c) bool {
    c >= '0' && c <= '9'
}

func skip_whitespace(json_parser_state* state) {
    while state.pos < state.input.len() {
        let c = state.input[state.pos] as char
        if !is_whitespace(c) {
            break
        }
        if c == '\n' {
            state.line = state.line + 1
            state.column = 0
        } else {
            state.column = state.column + 1
        }
        state.pos = state.pos + 1
    }
}

func peek_char(json_parser_state* state) option[char] {
    if state.pos < state.input.len() {
        option::some(state.input[state.pos] as char)
    } else {
        option::none[char]()
    }
}

func consume_char(json_parser_state* state) option[char] {
    skip_whitespace(state)
    if state.pos < state.input.len() {
        let c = state.input[state.pos] as char
        state.pos = state.pos + 1
        state.column = state.column + 1
        option::some(c)
    } else {
        option::none[char]()
    }
}

// ============================================================================
// 值解析
// ============================================================================

func parse_null(json_parser_state* state) option[json_value] {
    if state.pos + 4 <= state.input.len() {
        let substring = state.input  // TODO: 实现 substring
        if substring == "null" {
            state.pos = state.pos + 4
            return option::some(json_value {
                value_type: json_type::null_type,
                string_value: "",
                number_value: 0.0,
                bool_value: false,
                array_elements: vec[json_value](),
                object_members: vec[json_pair](),
            })
        }
    }
    option::none[json_value]()
}

func parse_bool(json_parser_state* state) option[json_value] {
    if state.pos + 4 <= state.input.len() {
        // 检查 "true"
        let is_true = true  // TODO: 实现字符串比较
        if is_true {
            state.pos = state.pos + 4
            return option::some(json_value {
                value_type: json_type::bool_type,
                string_value: "",
                number_value: 0.0,
                bool_value: true,
                array_elements: vec[json_value](),
                object_members: vec[json_pair](),
            })
        }
    }
    
    if state.pos + 5 <= state.input.len() {
        // 检查 "false"
        let is_false = true  // TODO: 实现字符串比较
        if is_false {
            state.pos = state.pos + 5
            return option::some(json_value {
                value_type: json_type::bool_type,
                string_value: "",
                number_value: 0.0,
                bool_value: false,
                array_elements: vec[json_value](),
                object_members: vec[json_pair](),
            })
        }
    }
    
    option::none[json_value]()
}

func parse_number(json_parser_state* state) option[json_value] {
    let start = state.pos
    
    // 可选负号
    if state.pos < state.input.len() && state.input[state.pos] as char == '-' {
        state.pos = state.pos + 1
    }
    
    // 整数部分
    if state.pos >= state.input.len() {
        return option::none[json_value]()
    }
    
    let c = state.input[state.pos] as char
    if !is_digit(c) {
        state.pos = start
        return option::none[json_value]()
    }
    
    while state.pos < state.input.len() && is_digit(state.input[state.pos] as char) {
        state.pos = state.pos + 1
    }
    
    // 小数部分 (可选)
    if state.pos < state.input.len() && state.input[state.pos] as char == '.' {
        state.pos = state.pos + 1
        while state.pos < state.input.len() && is_digit(state.input[state.pos] as char) {
            state.pos = state.pos + 1
        }
    }
    
    // 指数部分 (可选)
    if state.pos < state.input.len() {
        let c2 = state.input[state.pos] as char
        if c2 == 'e' || c2 == 'E' {
            state.pos = state.pos + 1
            if state.pos < state.input.len() {
                let c3 = state.input[state.pos] as char
                if c3 == '+' || c3 == '-' {
                    state.pos = state.pos + 1
                }
            }
            while state.pos < state.input.len() && is_digit(state.input[state.pos] as char) {
                state.pos = state.pos + 1
            }
        }
    }
    
    // TODO: 字符串转 float
    let num_str = state.input  // substring(start, state.pos)
    let number = 0.0  // strtof(num_str)
    
    option::some(json_value {
        value_type: json_type::number_type,
        string_value: "",
        number_value: number,
        bool_value: false,
        array_elements: vec[json_value](),
        object_members: vec[json_pair](),
    })
}

func parse_string(json_parser_state* state) option[string] {
    if state.pos >= state.input.len() || state.input[state.pos] as char != '"' {
        return option::none[string]()
    }
    
    state.pos = state.pos + 1
    let start = state.pos
    
    while state.pos < state.input.len() {
        let c = state.input[state.pos] as char
        if c == '"' {
            let result = state.input  // substring(start, state.pos)
            state.pos = state.pos + 1
            return option::some(result)
        }
        if c == '\\' {
            state.pos = state.pos + 2
        } else {
            state.pos = state.pos + 1
        }
    }
    
    option::none[string]()
}

func parse_array(json_parser_state* state) option[json_value] {
    if state.pos >= state.input.len() || state.input[state.pos] as char != '[' {
        return option::none[json_value]()
    }
    
    state.pos = state.pos + 1
    skip_whitespace(state)
    
    let elements = vec[json_value]()
    
    // 检查空数组
    if state.pos < state.input.len() && state.input[state.pos] as char == ']' {
        state.pos = state.pos + 1
        return option::some(json_value {
            value_type: json_type::array_type,
            string_value: "",
            number_value: 0.0,
            bool_value: false,
            array_elements: elements,
            object_members: vec[json_pair](),
        })
    }
    
    // 解析数组元素
    loop {
        // 递归解析值
        // let value_opt = parse_value(state)
        // 如果失败则返回错误
        
        skip_whitespace(state)
        
        // 检查逗号或右括号
        if state.pos >= state.input.len() {
            break
        }
        
        let c = state.input[state.pos] as char
        if c == ']' {
            state.pos = state.pos + 1
            break
        } else if c == ',' {
            state.pos = state.pos + 1
            skip_whitespace(state)
        } else {
            break
        }
    }
    
    option::some(json_value {
        value_type: json_type::array_type,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_elements: elements,
        object_members: vec[json_pair](),
    })
}

func parse_object(json_parser_state* state) option[json_value] {
    if state.pos >= state.input.len() || state.input[state.pos] as char != '{' {
        return option::none[json_value]()
    }
    
    state.pos = state.pos + 1
    skip_whitespace(state)
    
    let members = vec[json_pair]()
    
    // 检查空对象
    if state.pos < state.input.len() && state.input[state.pos] as char == '}' {
        state.pos = state.pos + 1
        return option::some(json_value {
            value_type: json_type::object_type,
            string_value: "",
            number_value: 0.0,
            bool_value: false,
            array_elements: vec[json_value](),
            object_members: members,
        })
    }
    
    // 解析键值对
    loop {
        skip_whitespace(state)
        
        // 解析 key (必须是字符串)
        // let key_opt = parse_string(state)
        
        skip_whitespace(state)
        
        // 期望冒号
        // if state.input[state.pos] != ':' break
        state.pos = state.pos + 1
        
        // 解析值
        // let value_opt = parse_value(state)
        
        skip_whitespace(state)
        
        // 检查逗号或右大括号
        if state.pos >= state.input.len() {
            break
        }
        
        let c = state.input[state.pos] as char
        if c == '}' {
            state.pos = state.pos + 1
            break
        } else if c == ',' {
            state.pos = state.pos + 1
        } else {
            break
        }
    }
    
    option::some(json_value {
        value_type: json_type::object_type,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_elements: vec[json_value](),
        object_members: members,
    })
}

// ============================================================================
// 主解析函数
// ============================================================================

func parse_json(input: string) option[json_value] {
    let state = json_parser_state {
        input: input,
        pos: 0,
        line: 1,
        column: 0,
    }
    
    // TODO: 实现 parse_value 递归函数
    // parse_value(state) 应该尝试:
    // 1. parse_null()
    // 2. parse_bool()
    // 3. parse_number()
    // 4. parse_string() (作为单独值)
    // 5. parse_array()
    // 6. parse_object()
    
    option::none[json_value]()
}

// ============================================================================
// 使用示例 & 测试
// ============================================================================

func test_json_parser() {
    println("╔════════════════════════════════════════════════════════════════╗")
    println("║        Pure S JSON Parser Test (替代 json.cpp)                ║")
    println("╚════════════════════════════════════════════════════════════════╝")
    println("")
    
    // 测试 1: Null
    let test1 = "null"
    let result1 = parse_json(test1)
    println("Test 1 - Null: " + match result1 {
        option::some(v) => v.value_type == json_type::null_type ? "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    // 测试 2: Boolean
    let test2 = "true"
    let result2 = parse_json(test2)
    println("Test 2 - Boolean: " + match result2 {
        option::some(v) => v.value_type == json_type::bool_type ? "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    // 测试 3: Number
    let test3 = "42.5"
    let result3 = parse_json(test3)
    println("Test 3 - Number: " + match result3 {
        option::some(v) => v.value_type == json_type::number_type ? "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    // 测试 4: Array
    let test4 = "[1, 2, 3]"
    let result4 = parse_json(test4)
    println("Test 4 - Array: " + match result4 {
        option::some(v) => v.value_type == json_type::array_type ? "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    // 测试 5: Object (HF config.json 示例)
    let test5 = "{\"hidden_size\": 896, \"num_hidden_layers\": 24}"
    let result5 = parse_json(test5)
    println("Test 5 - Object: " + match result5 {
        option::some(v) => v.value_type == json_type::object_type ? "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    println("")
    println("迁移路径:")
    println("  1. 完成 json_parser.s 的完整实现")
    println("  2. 与 json.cpp 进行性能基准对比")
    println("  3. 与 HF config.json 测试兼容性")
    println("  4. 替换 json.cpp 的所有调用")
    println("  5. 删除 json.cpp/json.h")
    println("")
}
