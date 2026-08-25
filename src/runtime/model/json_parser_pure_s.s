package neurx.runtime.model.json_parser

use std.vec.vec
use std.io.println


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

func is_whitespace(char c) bool {
    c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

func is_digit(char c) bool {
    c >= '0' && c <= '9'
}

func skip_whitespace(json_parser_state* state) {
    for state.pos < state.input.len() {
        c := state.input[state.pos] as char
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
        c := state.input[state.pos] as char
        state.pos = state.pos + 1
        state.column = state.column + 1
        option::some(c)
    } else {
        option::none[char]()
    }
}

func parse_null(json_parser_state* state) option[json_value] {
    if state.pos + 4 <= state.input.len() {
        substring := state.input  
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
        
        is_true := true  
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
        
        is_false := true  
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
    start := state.pos
    
    
    if state.pos < state.input.len() && state.input[state.pos] as char == '-' {
        state.pos = state.pos + 1
    }
    
    
    if state.pos >= state.input.len() {
        return option::none[json_value]()
    }
    
    c := state.input[state.pos] as char
    if !is_digit(c) {
        state.pos = start
        return option::none[json_value]()
    }
    
    for state.pos < state.input.len() && is_digit(state.input[state.pos] as char) {
        state.pos = state.pos + 1
    }
    
    
    if state.pos < state.input.len() && state.input[state.pos] as char == '.' {
        state.pos = state.pos + 1
        for state.pos < state.input.len() && is_digit(state.input[state.pos] as char) {
            state.pos = state.pos + 1
        }
    }
    
    
    if state.pos < state.input.len() {
        c2 := state.input[state.pos] as char
        if c2 == 'e' || c2 == 'E' {
            state.pos = state.pos + 1
            if state.pos < state.input.len() {
                c3 := state.input[state.pos] as char
                if c3 == '+' || c3 == '-' {
                    state.pos = state.pos + 1
                }
            }
            for state.pos < state.input.len() && is_digit(state.input[state.pos] as char) {
                state.pos = state.pos + 1
            }
        }
    }
    
    
    num_str := state.input  
    number := 0.0  
    
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
    start := state.pos
    
    for state.pos < state.input.len() {
        c := state.input[state.pos] as char
        if c == '"' {
            result := state.input  
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
    
    elements := vec[json_value]()
    
    
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
    
    
    loop {
        
        
        
        
        skip_whitespace(state)
        
        
        if state.pos >= state.input.len() {
            break
        }
        
        c := state.input[state.pos] as char
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
    
    members := vec[json_pair]()
    
    
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
    
    
    loop {
        skip_whitespace(state)
        
        
        
        
        skip_whitespace(state)
        
        
        
        state.pos = state.pos + 1
        
        
        
        
        skip_whitespace(state)
        
        
        if state.pos >= state.input.len() {
            break
        }
        
        c := state.input[state.pos] as char
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

func parse_json(string input) option[json_value] {
    state := json_parser_state {
        input: input,
        pos: 0,
        line: 1,
        column: 0,
    }
    
    
    
    
    
    
    
    
    
    
    option::none[json_value]()
}

func test_json_parser() {
    println("╔════════════════════════════════════════════════════════════════╗")
    println("║        Pure S JSON Parser Test (替代 json.cpp)                ║")
    println("╚════════════════════════════════════════════════════════════════╝")
    println("")
    
    
    test1 := "null"
    result1 := parse_json(test1)
    println("Test 1 - Null: " + match result1 {
        option::some(v) => v.value_type == json_type::null_type  "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    
    test2 := "true"
    result2 := parse_json(test2)
    println("Test 2 - Boolean: " + match result2 {
        option::some(v) => v.value_type == json_type::bool_type  "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    
    test3 := "42.5"
    result3 := parse_json(test3)
    println("Test 3 - Number: " + match result3 {
        option::some(v) => v.value_type == json_type::number_type  "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    
    test4 := "[1, 2, 3]"
    result4 := parse_json(test4)
    println("Test 4 - Array: " + match result4 {
        option::some(v) => v.value_type == json_type::array_type  "✅ PASS" : "❌ FAIL",
        option::none => "❌ FAIL",
    })
    
    
    test5 := "{\"hidden_size\": 896, \"num_hidden_layers\": 24}"
    result5 := parse_json(test5)
    println("Test 5 - Object: " + match result5 {
        option::some(v) => v.value_type == json_type::object_type  "✅ PASS" : "❌ FAIL",
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
