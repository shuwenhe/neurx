package neurx.tool_parsers.schema.schema_types

use std.vec

const TYPE_STRING = "string"
const TYPE_NUMBER = "number"
const TYPE_INTEGER = "integer"
const TYPE_BOOLEAN = "boolean"
const TYPE_OBJECT = "object"
const TYPE_ARRAY = "array"
const TYPE_NULL = "null"

struct json_schema {
    title: string
    description: string
    type_name: string

    properties: []json_property
    required: []string
    additional_properties: bool
    min_properties: int
    max_properties: int

    items: &json_schema
    min_items: int
    max_items: int
    unique_items: bool

    pattern: string
    min_length: int
    max_length: int
    enum_values: []string

    minimum: float
    maximum: float
    exclusive_minimum: bool
    exclusive_maximum: bool
    multiple_of: float

    default_value: string
    examples: []string
}

struct json_property {
    name: string
    schema: json_schema
    required: bool
    description: string
}

struct token_constraint {
    allowed_tokens: []int
    forbidden_tokens: []int
    state: int
    context: string
    is_terminal: bool
}

struct dfa_state {
    state_id: int
    transitions: []dfa_transition
    is_accepting: bool
    token_set: []int
}

struct dfa_transition {
    token_id: int
    next_state: int
    condition: string
}

struct parse_context {
    current_path: []string
    current_value: string
    depth: int
    in_string: bool
    in_array: bool
    escape_next: bool
    buffer: string
}

const CONSTRAINT_STRICT = "strict"
const CONSTRAINT_PERMISSIVE = "permissive"
const CONSTRAINT_WARNING = "warning"

struct sampler_state {
    mode: string
    schema: &json_schema
    context: parse_context
    allowed_next: []int
    rejected_count: int
    warnings: []string
}

func is_valid_json_type(type_name: string) bool {
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
    let schema = json_schema{
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
    let ctx = parse_context{
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
    let constraint = token_constraint{
        allowed_tokens: vec_new(),
        forbidden_tokens: vec_new(),
        state: 0,
        context: "root",
        is_terminal: false
    }
    return constraint
}

func create_sampler_state(mode: string, schema: &json_schema) sampler_state {
    let state = sampler_state{
        mode: mode,
        schema: schema,
        context: create_empty_parse_context(),
        allowed_next: vec_new(),
        rejected_count: 0,
        warnings: vec_new()
    }
    return state
}
