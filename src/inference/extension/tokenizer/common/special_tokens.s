import "./types"
import "std/string"
import "std/vector"

struct SpecialTokenManager {
    tokens: map[string]i32,
    token_to_name: map[i32]string,
    special_tokens_list: vec[string],
    reserved_tokens: vec[i32],
    user_defined_special_tokens: map[string]i32,
}

func NewSpecialTokenManager() &SpecialTokenManager {
    mgr := new(SpecialTokenManager)
    mgr.tokens = make(map[string]i32)
    mgr.token_to_name = make(map[i32]string)
    mgr.special_tokens_list = make(vec[string], 0)
    mgr.reserved_tokens = make(vec[i32], 0)
    mgr.user_defined_special_tokens = make(map[string]i32)

    mgr.register_standard_tokens()

    return mgr
}

func (SpecialTokenManager* m) register_standard_tokens() {

    m.register_special_token("[BOS]", 0, "Beginning of Sequence")
    m.register_special_token("[EOS]", 1, "End of Sequence")
    m.register_special_token("[CLS]", 2, "Classification Token")
    m.register_special_token("[SEP]", 3, "Separator Token")

    m.register_special_token("[PAD]", 4, "Padding Token")
    m.register_special_token("[UNK]", 5, "Unknown Token")
    m.register_special_token("[MASK]", 6, "Mask Token")

    m.register_special_token("[INST]", 7, "Instruction Start")
    m.register_special_token("[/INST]", 8, "Instruction End")
    m.register_special_token("[SYS]", 9, "System Prompt")
    m.register_special_token("[USER]", 10, "User Turn")
    m.register_special_token("[ASSISTANT]", 11, "Assistant Turn")

    m.register_special_token("[TOOL_USE]", 12, "Tool Usage Start")
    m.register_special_token("[TOOL_RESULT]", 13, "Tool Result")
    m.register_special_token("[TOOLS]", 14, "Tools List")

    m.register_special_token("[THOUGHT]", 15, "Internal Thought")
    m.register_special_token("[ACTION]", 16, "Action Token")
    m.register_special_token("[OBSERVATION]", 17, "Observation Token")

    m.register_special_token("[IMAGE]", 18, "Image Token")
    m.register_special_token("[AUDIO]", 19, "Audio Token")
    m.register_special_token("[VIDEO]", 20, "Video Token")
}

func (SpecialTokenManager* m) RegisterSpecialToken(token_str: string, token_id: i32, description: string) bool {
    if _, exists := m.tokens[token_str]; exists {
        return false
    }

    m.register_special_token(token_str, token_id, description)
    m.user_defined_special_tokens[token_str] = token_id
    return true
}

func (SpecialTokenManager* m) register_special_token(token_str: string, token_id: i32, description: string) {
    m.tokens[token_str] = token_id
    m.token_to_name[token_id] = token_str
    m.special_tokens_list = append(m.special_tokens_list, token_str)
    m.reserved_tokens = append(m.reserved_tokens, token_id)
}

func (SpecialTokenManager* m) GetTokenId(token_str: string) i32 {
    if id, ok := m.tokens[token_str]; ok {
        return id
    }
    return -1
}

func (SpecialTokenManager* m) GetTokenName(token_id: i32) string {
    if name, ok := m.token_to_name[token_id]; ok {
        return name
    }
    return "[UNKNOWN]"
}

func (SpecialTokenManager* m) IsSpecialToken(token_id: i32) bool {
    _, exists := m.token_to_name[token_id]
    return exists
}

func (SpecialTokenManager* m) IsSpecialTokenStr(token_str: string) bool {
    _, exists := m.tokens[token_str]
    return exists
}

func (SpecialTokenManager* m) GetTokenType(token_id: i32) string {
    name := m.GetTokenName(token_id)

    if contains_string(name, "BOS") || contains_string(name, "EOS") || contains_string(name, "CLS") {
        return "boundary"
    }

    if contains_string(name, "PAD") || contains_string(name, "UNK") || contains_string(name, "MASK") {
        return "control"
    }

    if contains_string(name, "INST") || contains_string(name, "USER") || contains_string(name, "ASSISTANT") {
        return "instruction"
    }

    if contains_string(name, "TOOL") {
        return "tool"
    }

    if contains_string(name, "IMAGE") || contains_string(name, "AUDIO") || contains_string(name, "VIDEO") {
        return "multimodal"
    }

    return "unknown"
}

func (SpecialTokenManager* m) RemoveSpecialTokens(tokens: vec[i32]) vec[i32] {
    result := make(vec[i32], 0)
    for i := 0; i < len(tokens); i += 1 {
        if !m.IsSpecialToken(tokens[i]) {
            result = append(result, tokens[i])
        }
    }
    return result
}

func (SpecialTokenManager* m) KeepOnlySpecialTokens(tokens: vec[i32]) vec[i32] {
    result := make(vec[i32], 0)
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            result = append(result, tokens[i])
        }
    }
    return result
}

func (SpecialTokenManager* m) GetSpecialTokenPositions(tokens: vec[i32]) vec[i32] {
    positions := make(vec[i32], 0)
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            positions = append(positions, i32(i))
        }
    }
    return positions
}

func (SpecialTokenManager* m) CreateSpecialTokenMask(tokens: vec[i32]) vec[i32] {
    mask := make(vec[i32], len(tokens))
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            mask[i] = 1
        } else {
            mask[i] = 0
        }
    }
    return mask
}

func (SpecialTokenManager* m) ReplaceSpecialTokens(tokens: vec[i32], substitute_id: i32) vec[i32] {
    result := make(vec[i32], len(tokens))
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            result[i] = substitute_id
        } else {
            result[i] = tokens[i]
        }
    }
    return result
}

func (SpecialTokenManager* m) ReplaceSpecialTokensByType(tokens: vec[i32], token_type: string, substitute_id: i32) vec[i32] {
    result := make(vec[i32], len(tokens))
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) && m.GetTokenType(tokens[i]) == token_type {
            result[i] = substitute_id
        } else {
            result[i] = tokens[i]
        }
    }
    return result
}

func (SpecialTokenManager* m) InsertSpecialToken(tokens: vec[i32], token_id: i32, position: i32) vec[i32] {
    if position < 0 || position > i32(len(tokens)) {
        return tokens
    }

    result := make(vec[i32], 0)
    pos := int(position)

    for i := 0; i < pos; i += 1 {
        result = append(result, tokens[i])
    }

    result = append(result, token_id)

    for i := pos; i < len(tokens); i += 1 {
        result = append(result, tokens[i])
    }

    return result
}

func (SpecialTokenManager* m) AddBeginSpecialToken(tokens: vec[i32], token_id: i32) vec[i32] {
    result := make(vec[i32], 1 + len(tokens))
    result[0] = token_id
    for i := 0; i < len(tokens); i += 1 {
        result[i+1] = tokens[i]
    }
    return result
}

func (SpecialTokenManager* m) AddEndSpecialToken(tokens: vec[i32], token_id: i32) vec[i32] {
    result := append(tokens, token_id)
    return result
}

func (SpecialTokenManager* m) GetAllSpecialTokens() vec[string] {
    return m.special_tokens_list
}

func (SpecialTokenManager* m) GetAllSpecialTokenIds() vec[i32] {
    return m.reserved_tokens
}

func (SpecialTokenManager* m) GetSpecialTokenCount() i32 {
    return i32(len(m.special_tokens_list))
}

func (SpecialTokenManager* m) CountSpecialTokensInSequence(tokens: vec[i32]) i32 {
    count := 0
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            count += 1
        }
    }
    return i32(count)
}

func (SpecialTokenManager* m) CountSpecialTokensByType(tokens: vec[i32], token_type: string) i32 {
    count := 0
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) && m.GetTokenType(tokens[i]) == token_type {
            count += 1
        }
    }
    return i32(count)
}

func (SpecialTokenManager* m) ValidateSpecialTokens(tokens: vec[i32]) bool {
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {

            _ = m.GetTokenName(tokens[i])
        }
    }
    return true
}

func (SpecialTokenManager* m) IsValidTokenId(token_id: i32) bool {
    return m.IsSpecialToken(token_id)
}

func contains_string(s: string, substring: string) bool {
    for i := 0; i <= len(s) - len(substring); i += 1 {
        match := true
        for j := 0; j < len(substring); j += 1 {
            if s[i+j] != substring[j] {
                match = false
                break
            }
        }
        if match {
            return true
        }
    }
    return false
}
