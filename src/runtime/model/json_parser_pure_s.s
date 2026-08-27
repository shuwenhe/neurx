package neurx.runtime.model.json_parser

use std.slices
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
    for state.pos < len(state.input) {
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
    if state.pos < len(state.input) {
        some(state.input[state.pos] as char)
    } else {
        nil[char]()
    }
}

func consume_char(json_parser_state* state) option[char] {
    skip_whitespace(state)
    if state.pos < len(state.input) {
        c := state.input[state.pos] as char
        state.pos = state.pos + 1
        state.column = state.column + 1
        some(c)
    } else {
        nil[char]()
    }
}

func parse_null(json_parser_state* state) option[json_value] {
    if state.pos + 4 <= len(state.input) {
        substring := state.input  
        if substring == "null" {
            state.pos = state.pos + 4
            return some(json_value {
                value_type: json_type_null_type,
                string_value: "",
                number_value: 0.0,
                bool_value: false,
                array_elements: json_value[](),
                object_members: json_pair[](),
            })
        }
    }
    nil[json_value]()
}

func parse_bool(json_parser_state* state) option[json_value] {
    if state.pos + 4 <= len(state.input) {
        
        is_true := true  
        if is_true {
            state.pos = state.pos + 4
            return some(json_value {
                value_type: json_type_bool_type,
                string_value: "",
                number_value: 0.0,
                bool_value: true,
                array_elements: json_value[](),
                object_members: json_pair[](),
            })
        }
    }
    
    if state.pos + 5 <= len(state.input) {
        
        is_false := true  
        if is_false {
            state.pos = state.pos + 5
            return some(json_value {
                value_type: json_type_bool_type,
                string_value: "",
                number_value: 0.0,
                bool_value: false,
                array_elements: json_value[](),
                object_members: json_pair[](),
            })
        }
    }
    
    nil[json_value]()
}

func parse_number(json_parser_state* state) option[json_value] {
    start := state.pos
    
    
    if state.pos < len(state.input) && state.input[state.pos] as char == '-' {
        state.pos = state.pos + 1
    }
    
    
    if state.pos >= len(state.input) {
        return nil[json_value]()
    }
    
    c := state.input[state.pos] as char
    if !is_digit(c) {
        state.pos = start
        return nil[json_value]()
    }
    
    for state.pos < len(state.input) && is_digit(state.input[state.pos] as char) {
        state.pos = state.pos + 1
    }
    
    
    if state.pos < len(state.input) && state.input[state.pos] as char == '.' {
        state.pos = state.pos + 1
        for state.pos < len(state.input) && is_digit(state.input[state.pos] as char) {
            state.pos = state.pos + 1
        }
    }
    
    
    if state.pos < len(state.input) {
        c2 := state.input[state.pos] as char
        if c2 == 'e' || c2 == 'E' {
            state.pos = state.pos + 1
            if state.pos < len(state.input) {
                c3 := state.input[state.pos] as char
                if c3 == '+' || c3 == '-' {
                    state.pos = state.pos + 1
                }
            }
            for state.pos < len(state.input) && is_digit(state.input[state.pos] as char) {
                state.pos = state.pos + 1
            }
        }
    }
    
    
    num_str := state.input  
    number := 0.0  
    
    some(json_value {
        value_type: json_type_number_type,
        string_value: "",
        number_value: number,
        bool_value: false,
        array_elements: json_value[](),
        object_members: json_pair[](),
    })
}

func parse_string(json_parser_state* state) option[string] {
    if state.pos >= len(state.input) || state.input[state.pos] as char != '"' {
        return nil[string]()
    }
    
    state.pos = state.pos + 1
    start := state.pos
    
    for state.pos < len(state.input) {
        c := state.input[state.pos] as char
        if c == '"' {
            result := state.input  
            state.pos = state.pos + 1
            return some(result)
        }
        if c == '\\' {
            state.pos = state.pos + 2
        } else {
            state.pos = state.pos + 1
        }
    }
    
    nil[string]()
}

func parse_array(json_parser_state* state) option[json_value] {
    if state.pos >= len(state.input) || state.input[state.pos] as char != '[' {
        return nil[json_value]()
    }
    
    state.pos = state.pos + 1
    skip_whitespace(state)
    
    elements := json_value[]()
    
    
    if state.pos < len(state.input) && state.input[state.pos] as char == ']' {
        state.pos = state.pos + 1
        return some(json_value {
            value_type: json_type_array_type,
            string_value: "",
            number_value: 0.0,
            bool_value: false,
            array_elements: elements,
            object_members: json_pair[](),
        })
    }
    
    
    loop {
        
        
        
        
        skip_whitespace(state)
        
        
        if state.pos >= len(state.input) {
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
    
    some(json_value {
        value_type: json_type_array_type,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_elements: elements,
        object_members: json_pair[](),
    })
}

func parse_object(json_parser_state* state) option[json_value] {
    if state.pos >= len(state.input) || state.input[state.pos] as char != '{' {
        return nil[json_value]()
    }
    
    state.pos = state.pos + 1
    skip_whitespace(state)
    
    members := json_pair[]()
    
    
    if state.pos < len(state.input) && state.input[state.pos] as char == '}' {
        state.pos = state.pos + 1
        return some(json_value {
            value_type: json_type_object_type,
            string_value: "",
            number_value: 0.0,
            bool_value: false,
            array_elements: json_value[](),
            object_members: members,
        })
    }
    
    
    loop {
        skip_whitespace(state)
        
        
        
        
        skip_whitespace(state)
        
        
        
        state.pos = state.pos + 1
        
        
        
        
        skip_whitespace(state)
        
        
        if state.pos >= len(state.input) {
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
    
    some(json_value {
        value_type: json_type_object_type,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_elements: json_value[](),
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
    
    
    
    
    
    
    
    
    
    
    nil[json_value]()
}

func test_json_parser() {
    println("╔════════════════════════════════════════════════════════════════╗")
    println("║        Pure S JSON Parser Test (替代 json.cpp)                ║")
    println("╚════════════════════════════════════════════════════════════════╝")
    println("")
    
    
    test1 := "null"
    result1 := parse_json(test1)
    println("Test 1 - Null: " + match result1 {
        some(v) => v.value_type == json_type_null_type  "✅ PASS" : "❌ FAIL",
        nil => "❌ FAIL",
    })
    
    
    test2 := "true"
    result2 := parse_json(test2)
    println("Test 2 - Boolean: " + match result2 {
        some(v) => v.value_type == json_type_bool_type  "✅ PASS" : "❌ FAIL",
        nil => "❌ FAIL",
    })
    
    
    test3 := "42.5"
    result3 := parse_json(test3)
    println("Test 3 - Number: " + match result3 {
        some(v) => v.value_type == json_type_number_type  "✅ PASS" : "❌ FAIL",
        nil => "❌ FAIL",
    })
    
    
    test4 := "[1, 2, 3]"
    result4 := parse_json(test4)
    println("Test 4 - Array: " + match result4 {
        some(v) => v.value_type == json_type_array_type  "✅ PASS" : "❌ FAIL",
        nil => "❌ FAIL",
    })
    
    
    test5 := "{\"hidden_size\": 896, \"num_hidden_layers\": 24}"
    result5 := parse_json(test5)
    println("Test 5 - Object: " + match result5 {
        some(v) => v.value_type == json_type_object_type  "✅ PASS" : "❌ FAIL",
        nil => "❌ FAIL",
    })
    
    println("")
    println("迁移路径:")
    println("  1. complete json_parser.s ofcompleteimplementation")
    println("  2. 与 json.cpp 进doity能基准pair比")
    println("  3. 与 HF config.json testCompatibleity")
    println("  4. 替换 json.cpp ofall调use")
    println("  5. 删除 json.cpp/json.h")
    println("")
}
