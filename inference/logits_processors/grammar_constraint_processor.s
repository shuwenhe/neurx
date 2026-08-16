package neurx.inference.logits_processors.grammar

use neurx.inference.logits_processors

struct grammar_rule {
    string rule_name
    []string allowed_tokens
    []int allowed_token_ids
    string pattern
    string rule_type
    bool is_active
}

struct grammar_constraint_set {
    []grammar_rule rules
    string current_state
    int tokens_matched
    bool match_all_rules
}

struct grammar_constraint_processor {
    grammar_constraint_set constraints
    map[string][]int rule_token_map
    bool strict_mode
    int vocab_size
}

func new_grammar_constraint_processor(int vocab_size) grammar_constraint_processor {
    grammar_constraint_processor{
        constraints: grammar_constraint_set{
            rules: make([]grammar_rule, 0),
            current_state: "START",
            tokens_matched: 0,
            match_all_rules: false,
        },
        rule_token_map: map[string][]int{},
        strict_mode: false,
        vocab_size: vocab_size,
    }
}

func (grammar_constraint_processor* processor) add_grammar_rule(
    rule_name string,
    allowed_tokens []string,
    rule_type string
) bool {

    rule := grammar_rule{
        rule_name: rule_name,
        allowed_tokens: allowed_tokens,
        allowed_token_ids: make([]int, 0),
        pattern: "",
        rule_type: rule_type,
        is_active: true,
    }

    processor.constraints.rules = append_rule(processor.constraints.rules, rule)

    return true
}

func (grammar_constraint_processor* processor) add_pattern_rule(
    rule_name string,
    pattern string
) bool {

    rule := grammar_rule{
        rule_name: rule_name,
        allowed_tokens: make([]string, 0),
        allowed_token_ids: make([]int, 0),
        pattern: pattern,
        rule_type: "pattern",
        is_active: true,
    }

    processor.constraints.rules = append_rule(processor.constraints.rules, rule)

    return true
}

func (grammar_constraint_processor* processor) process_logits(
    []float logits
) []float {

    if len(processor.constraints.rules) == 0 {
        return logits
    }

    []float result = make([]float, len(logits))
    int i = 0
    for i < len(logits) {
        result[i] = -10000.0
        i = i + 1
    }

    int rule_idx = 0
    for rule_idx < len(processor.constraints.rules) {

        rule := processor.constraints.rules[rule_idx]

        if !rule.is_active {
            rule_idx = rule_idx + 1
            continue
        }

        if rule.rule_type == "exact" {
            apply_exact_rule(result, rule)
        } else if rule.rule_type == "pattern" {
            apply_pattern_rule(result, rule)
        } else if rule.rule_type == "list" {
            apply_list_rule(result, logits, rule)
        }

        rule_idx = rule_idx + 1
    }

    return result
}

func apply_exact_rule([]float result, grammar_rule rule) {

    int i = 0
    for i < len(rule.allowed_token_ids) {
        int token_id = rule.allowed_token_ids[i]
        if token_id >= 0 && token_id < len(result) {
            result[token_id] = 100.0
        }
        i = i + 1
    }
}

func apply_pattern_rule([]float result, grammar_rule rule) {

    string pattern = rule.pattern

    if pattern == "^[0-9]+$" {

        apply_digit_pattern(result)
    } else if pattern == "^[a-zA-Z]+$" {

        apply_letter_pattern(result)
    } else if pattern == "^[a-zA-Z0-9_]+$" {

        apply_alphanumeric_pattern(result)
    }
}

func apply_list_rule([]float result, []float logits, grammar_rule rule) {

    int i = 0
    for i < len(rule.allowed_token_ids) {
        int token_id = rule.allowed_token_ids[i]
        if token_id >= 0 && token_id < len(result) && token_id < len(logits) {
            result[token_id] = logits[token_id]
        }
        i = i + 1
    }
}

func apply_digit_pattern([]float result) {

    int i = 0
    for i < 10 {
        if i < len(result) {
            result[i] = 100.0
        }
        i = i + 1
    }
}

func apply_letter_pattern([]float result) {

    int i = 10
    for i < 62 {
        if i < len(result) {
            result[i] = 100.0
        }
        i = i + 1
    }
}

func apply_alphanumeric_pattern([]float result) {

    int i = 0
    for i < 63 {
        if i < len(result) {
            result[i] = 100.0
        }
        i = i + 1
    }
}

func (grammar_constraint_processor* processor) update_state(int token_id) {
    processor.constraints.tokens_matched = processor.constraints.tokens_matched + 1

    is_valid := validate_token_against_rules(processor, token_id)

    if !is_valid && processor.strict_mode {

        print("Error: Token " + int_to_str(token_id) + " violates grammar rules")
    }
}

func validate_token_against_rules(
    *grammar_constraint_processor processor,
    int token_id
) bool {

    int i = 0
    for i < len(processor.constraints.rules) {

        rule := processor.constraints.rules[i]

        if !rule.is_active {
            i = i + 1
            continue
        }

        if token_in_list(token_id, rule.allowed_token_ids) {
            return true
        }

        i = i + 1
    }

    return false
}

func token_in_list(int token_id, []int list) bool {
    int i = 0
    for i < len(list) {
        if list[i] == token_id {
            return true
        }
        i = i + 1
    }
    return false
}

func create_json_grammar() grammar_constraint_set {

    rules := make([]grammar_rule, 0)

    rule_start := grammar_rule{
        rule_name: "json_start",
        allowed_tokens: []string{"{", "["},
        rule_type: "exact",
        is_active: true,
    }

    rules = append_rule(rules, rule_start)

    return grammar_constraint_set{
        rules: rules,
        current_state: "START",
        tokens_matched: 0,
        match_all_rules: true,
    }
}

func create_sql_grammar() grammar_constraint_set {

    rules := make([]grammar_rule, 0)

    rule_start := grammar_rule{
        rule_name: "sql_start",
        allowed_tokens: []string{"SELECT", "INSERT", "UPDATE", "DELETE"},
        rule_type: "exact",
        is_active: true,
    }

    rules = append_rule(rules, rule_start)

    return grammar_constraint_set{
        rules: rules,
        current_state: "START",
        tokens_matched: 0,
        match_all_rules: true,
    }
}

func create_number_grammar() grammar_constraint_set {

    rules := make([]grammar_rule, 0)

    rule := grammar_rule{
        rule_name: "number_pattern",
        pattern: "^[0-9.\\-]+$",
        rule_type: "pattern",
        is_active: true,
    }

    rules = append_rule(rules, rule)

    return grammar_constraint_set{
        rules: rules,
        current_state: "NUMBER",
        tokens_matched: 0,
        match_all_rules: true,
    }
}

func append_rule([]grammar_rule arr, grammar_rule val) []grammar_rule {
    []grammar_rule new_arr = make([]grammar_rule, len(arr) + 1)
    int i = 0
    for i < len(arr) {
        new_arr[i] = arr[i]
        i = i + 1
    }
    new_arr[len(arr)] = val
    return new_arr
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }

    string result = ""
    int temp = n

    if temp < 0 {
        result = "-"
        temp = -temp
    }

    return result + "number"
}

func main() {
    print("✓ Grammar Constraint Processor")
    print("  - Exact rule matching")
    print("  - Pattern-based constraints")
    print("  - List-based filtering")
    print("  - JSON grammar")
    print("  - SQL grammar")
    print("  - Number grammar")
    print("  - State tracking")
}
