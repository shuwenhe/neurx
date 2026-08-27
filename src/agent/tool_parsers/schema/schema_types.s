package neurx.tool_parsers.schema.schema_types

use std.slices

const TYPE_STRING = "string"
const TYPE_NUMBER = "number"
const TYPE_INTEGER = "integer"
const TYPE_BOOLEAN = "boolean"
const TYPE_OBJECT = "object"
const TYPE_ARRAY = "array"
const TYPE_NULL = "null"

struct json_schema {
    string title
    string description
    string type_name

    properties: []json_property
    required: []string
    bool additional_properties
    int min_properties
    int max_properties

    *json_schema items
    int min_items
    int max_items
    bool unique_items

    string pattern
    int min_length
    int max_length
    enum_values: []string

    float minimum
    float maximum
    bool exclusive_minimum
    bool exclusive_maximum
    float multiple_of

    string default_value
    examples: []string
}

struct json_property {
    string name
    json_schema schema
    bool required
    string description
}

struct token_constraint {
    allowed_tokens: []int
    forbidden_tokens: []int
    int state
    string context
    bool is_terminal
}

struct dfa_state {
    int state_id
    transitions: []dfa_transition
    bool is_accepting
    token_set: []int
}

struct dfa_transition {
    int token_id
    int next_state
    string condition
}

struct parse_context {
    current_path: []string
    string current_value
    int depth
    bool in_string
    bool in_array
    bool escape_next
    string buffer
}

const CONSTRAINT_STRICT = "strict"
const CONSTRAINT_PERMISSIVE = "permissive"
const CONSTRAINT_WARNING = "warning"

struct sampler_state {
    string mode
    *json_schema schema
    parse_context context
    allowed_next: []int
    int rejected_count
    warnings: []string
}

func is_valid_json_type(string type_name) bool {
    if type_name == TYPE_STRING {
        return true
    } else if type_name == TYPE_NUMBER {
        return true
    } else if type_name == TYPE_INTEGER {
        return true
    } else if type_name == TYPE_BOOLEAN {
        return true
    } else if type_name == TYPE_OBJECT {
        return true
    } else if type_name == TYPE_ARRAY {
        return true
    } else if type_name == TYPE_NULL {
        return true
    }
    return false
}

func create_empty_schema() json_schema {
    schema := json_schema{
        title: "",
        description: "",
        type_name: TYPE_OBJECT,
        properties: vec_new(),
        required: vec_new(),
        additional_properties: false,
        min_properties: 0,
        max_properties: 999,
        items: nil,
        min_items: 0,
        max_items: 999,
        unique_items: false,
        pattern: "",
        min_length: 0,
        max_length: 10000,
        enum_values: vec_new(),
        minimum: -1000000.0,
        maximum: 1000000.0,
        exclusive_minimum: false,
        exclusive_maximum: false,
        multiple_of: 0.0,
        default_value: "",
        examples: vec_new()
    }
    return schema
}

func create_empty_parse_context() parse_context {
    ctx := parse_context{
        current_path: vec_new(),
        current_value: "",
        depth: 0,
        in_string: false,
        in_array: false,
        escape_next: false,
        buffer: ""
    }
    return ctx
}

func create_empty_constraint() token_constraint {
    constraint := token_constraint{
        allowed_tokens: vec_new(),
        forbidden_tokens: vec_new(),
        state: 0,
        context: "root",
        false is_terminal
    }
    return constraint
}

func create_sampler_state(string mode, *json_schema schema) sampler_state {
    state := sampler_state{
        mode: mode,
        schema: schema,
        context: create_empty_parse_context(),
        allowed_next: vec_new(),
        rejected_count: 0,
        warnings: vec_new()
    }
    return state
}
