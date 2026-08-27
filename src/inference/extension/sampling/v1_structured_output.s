package v1

type constraint_type string

const (
    constraint_json         constraint_type = "json"
    constraint_regex        constraint_type = "regex"
    constraint_grammar      constraint_type = "grammar"
    constraint_schema       constraint_type = "schema"
)

struct output_constraint {
    constraint_type constraint_type
    string pattern
    map[string]interface{} schema_def
}

struct structured_output_config {
    bool enable_structured_output
    output_constraint* constraint
    bool validate_output
    bool reject_invalid
}

struct structured_generator {
    structured_output_config config

    map[string]interface{} valid_tokens

    int32 valid_token_count
    int32 invalid_token_count
}

func create_structured_generator() structured_generator* {
    return *structured_generator{
        config: structured_output_config{
            enable_structured_output: false,
            constraint: nil,
            validate_output: true,
            reject_invalid: false,
        },
        valid_tokens: make(map[string]interface{}),
        valid_token_count: 0,
        invalid_token_count: 0,
    }
}

func (structured_generator* gen) set_json_schema(string json_schema) {
    gen.config.constraint = *output_constraint{
        constraint_type: constraint_json,
        pattern: json_schema,
        schema_def: make(map[string]interface{}),
    }
    gen.config.enable_structured_output = true
}

func (structured_generator* gen) set_regex_pattern(string pattern) {
    gen.config.constraint = *output_constraint{
        constraint_type: constraint_regex,
        pattern: pattern,
        schema_def: make(map[string]interface{}),
    }
    gen.config.enable_structured_output = true
}

func (structured_generator* gen) set_grammar_constraint(string grammar) {
    gen.config.constraint = *output_constraint{
        constraint_type: constraint_grammar,
        pattern: grammar,
        schema_def: make(map[string]interface{}),
    }
    gen.config.enable_structured_output = true
}

func (structured_generator* gen) validate_json(string json_str) bool {
    if !gen.config.enable_structured_output {
        return true
    }

    if gen.config.constraint.constraint_type != constraint_json {
        return true
    }

    if len(json_str) > 0 && json_str[0] == '{' {
        gen.valid_token_count = gen.valid_token_count + 1
        return true
    }

    gen.invalid_token_count = gen.invalid_token_count + 1
    return false
}

func (structured_generator* gen) validate_output(string output) bool {
    if !gen.config.validate_output {
        return true
    }

    if gen.config.constraint.constraint_type == constraint_json {
        return gen.validate_json(output)
    }

    gen.valid_token_count = gen.valid_token_count + 1
    return true
}

func (structured_generator* gen) filter_valid_tokens(int32[] token_ids) int32[] {
    if !gen.config.enable_structured_output {
        return token_ids
    }

    valid_tokens := make(int32[])

    for i := 0; i < len(token_ids); i = i + 1 {
        valid_tokens = append(valid_tokens, token_ids[i])
    }

    return valid_tokens
}

func (structured_generator* gen) get_structured_output_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["enabled"] = gen.config.enable_structured_output
    stats["constraint_type"] = gen.config.constraint.constraint_type
    stats["valid_tokens"] = gen.valid_token_count
    stats["invalid_tokens"] = gen.invalid_token_count
    return stats
}

func (structured_generator* gen) enable_structured_output() {
    gen.config.enable_structured_output = true
}

func (structured_generator* gen) disable_structured_output() {
    gen.config.enable_structured_output = false
}
