// NeurX Tokenizers - Special Tokens Management
// Comprehensive special token handling and management

import "./types"
import "std/string"
import "std/vector"

// ============================================================================
// Special Token Manager
// ============================================================================

struct SpecialTokenManager {
    tokens: map[string]i32,
    token_to_name: map[i32]string,
    special_tokens_list: vec[string],
    reserved_tokens: vec[i32],
    user_defined_special_tokens: map[string]i32,
}

// NewSpecialTokenManager - Create a new special token manager
func NewSpecialTokenManager() &SpecialTokenManager {
    mgr := new(SpecialTokenManager)
    mgr.tokens = make(map[string]i32)
    mgr.token_to_name = make(map[i32]string)
    mgr.special_tokens_list = make(vec[string], 0)
    mgr.reserved_tokens = make(vec[i32], 0)
    mgr.user_defined_special_tokens = make(map[string]i32)
    
    // Register standard special tokens
    mgr.register_standard_tokens()
    
    return mgr
}

// ============================================================================
// Registration Functions
// ============================================================================

// register_standard_tokens - Register standard special tokens
func (m: &SpecialTokenManager) register_standard_tokens() {
    // Sentence delimiters
    m.register_special_token("[BOS]", 0, "Beginning of Sequence")
    m.register_special_token("[EOS]", 1, "End of Sequence")
    m.register_special_token("[CLS]", 2, "Classification Token")
    m.register_special_token("[SEP]", 3, "Separator Token")
    
    // Padding and masking
    m.register_special_token("[PAD]", 4, "Padding Token")
    m.register_special_token("[UNK]", 5, "Unknown Token")
    m.register_special_token("[MASK]", 6, "Mask Token")
    
    // Control tokens for instruction tuning
    m.register_special_token("[INST]", 7, "Instruction Start")
    m.register_special_token("[/INST]", 8, "Instruction End")
    m.register_special_token("[SYS]", 9, "System Prompt")
    m.register_special_token("[USER]", 10, "User Turn")
    m.register_special_token("[ASSISTANT]", 11, "Assistant Turn")
    
    // Tool and function calling
    m.register_special_token("[TOOL_USE]", 12, "Tool Usage Start")
    m.register_special_token("[TOOL_RESULT]", 13, "Tool Result")
    m.register_special_token("[TOOLS]", 14, "Tools List")
    
    // Reasoning and chain-of-thought
    m.register_special_token("[THOUGHT]", 15, "Internal Thought")
    m.register_special_token("[ACTION]", 16, "Action Token")
    m.register_special_token("[OBSERVATION]", 17, "Observation Token")
    
    // Multimodal tokens
    m.register_special_token("[IMAGE]", 18, "Image Token")
    m.register_special_token("[AUDIO]", 19, "Audio Token")
    m.register_special_token("[VIDEO]", 20, "Video Token")
}

// RegisterSpecialToken - Register a custom special token
func (m: &SpecialTokenManager) RegisterSpecialToken(token_str: string, token_id: i32, description: string) bool {
    if _, exists := m.tokens[token_str]; exists {
        return false  // Token already registered
    }
    
    m.register_special_token(token_str, token_id, description)
    m.user_defined_special_tokens[token_str] = token_id
    return true
}

// register_special_token - Internal registration
func (m: &SpecialTokenManager) register_special_token(token_str: string, token_id: i32, description: string) {
    m.tokens[token_str] = token_id
    m.token_to_name[token_id] = token_str
    m.special_tokens_list = append(m.special_tokens_list, token_str)
    m.reserved_tokens = append(m.reserved_tokens, token_id)
}

// ============================================================================
// Token Query Functions
// ============================================================================

// GetTokenId - Get token ID from string representation
func (m: &SpecialTokenManager) GetTokenId(token_str: string) i32 {
    if id, ok := m.tokens[token_str]; ok {
        return id
    }
    return -1  // Token not found
}

// GetTokenName - Get token name/string from ID
func (m: &SpecialTokenManager) GetTokenName(token_id: i32) string {
    if name, ok := m.token_to_name[token_id]; ok {
        return name
    }
    return "[UNKNOWN]"
}

// IsSpecialToken - Check if token ID is special
func (m: &SpecialTokenManager) IsSpecialToken(token_id: i32) bool {
    _, exists := m.token_to_name[token_id]
    return exists
}

// IsSpecialTokenStr - Check if token string is special
func (m: &SpecialTokenManager) IsSpecialTokenStr(token_str: string) bool {
    _, exists := m.tokens[token_str]
    return exists
}

// ============================================================================
// Token Type Classification
// ============================================================================

// GetTokenType - Classify token type
func (m: &SpecialTokenManager) GetTokenType(token_id: i32) string {
    name := m.GetTokenName(token_id)
    
    // Classify by name
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

// ============================================================================
// Special Token Sequence Processing
// ============================================================================

// RemoveSpecialTokens - Remove special tokens from sequence
func (m: &SpecialTokenManager) RemoveSpecialTokens(tokens: vec[i32]) vec[i32] {
    result := make(vec[i32], 0)
    for i := 0; i < len(tokens); i += 1 {
        if !m.IsSpecialToken(tokens[i]) {
            result = append(result, tokens[i])
        }
    }
    return result
}

// KeepOnlySpecialTokens - Keep only special tokens from sequence
func (m: &SpecialTokenManager) KeepOnlySpecialTokens(tokens: vec[i32]) vec[i32] {
    result := make(vec[i32], 0)
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            result = append(result, tokens[i])
        }
    }
    return result
}

// GetSpecialTokenPositions - Get positions of special tokens
func (m: &SpecialTokenManager) GetSpecialTokenPositions(tokens: vec[i32]) vec[i32] {
    positions := make(vec[i32], 0)
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            positions = append(positions, i32(i))
        }
    }
    return positions
}

// CreateSpecialTokenMask - Create mask for special tokens
func (m: &SpecialTokenManager) CreateSpecialTokenMask(tokens: vec[i32]) vec[i32] {
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

// ============================================================================
// Special Token Replacement
// ============================================================================

// ReplaceSpecialTokens - Replace special token IDs with substitutes
func (m: &SpecialTokenManager) ReplaceSpecialTokens(tokens: vec[i32], substitute_id: i32) vec[i32] {
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

// ReplaceSpecialTokensByType - Replace specific type of special tokens
func (m: &SpecialTokenManager) ReplaceSpecialTokensByType(tokens: vec[i32], token_type: string, substitute_id: i32) vec[i32] {
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

// ============================================================================
// Special Token Insertion
// ============================================================================

// InsertSpecialToken - Insert special token at position
func (m: &SpecialTokenManager) InsertSpecialToken(tokens: vec[i32], token_id: i32, position: i32) vec[i32] {
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

// AddBeginSpecialToken - Add special token at the beginning
func (m: &SpecialTokenManager) AddBeginSpecialToken(tokens: vec[i32], token_id: i32) vec[i32] {
    result := make(vec[i32], 1 + len(tokens))
    result[0] = token_id
    for i := 0; i < len(tokens); i += 1 {
        result[i+1] = tokens[i]
    }
    return result
}

// AddEndSpecialToken - Add special token at the end
func (m: &SpecialTokenManager) AddEndSpecialToken(tokens: vec[i32], token_id: i32) vec[i32] {
    result := append(tokens, token_id)
    return result
}

// ============================================================================
// Token Statistics
// ============================================================================

// GetAllSpecialTokens - Get all registered special tokens
func (m: &SpecialTokenManager) GetAllSpecialTokens() vec[string] {
    return m.special_tokens_list
}

// GetAllSpecialTokenIds - Get all registered special token IDs
func (m: &SpecialTokenManager) GetAllSpecialTokenIds() vec[i32] {
    return m.reserved_tokens
}

// GetSpecialTokenCount - Get total count of special tokens
func (m: &SpecialTokenManager) GetSpecialTokenCount() i32 {
    return i32(len(m.special_tokens_list))
}

// CountSpecialTokensInSequence - Count special tokens in sequence
func (m: &SpecialTokenManager) CountSpecialTokensInSequence(tokens: vec[i32]) i32 {
    count := 0
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            count += 1
        }
    }
    return i32(count)
}

// CountSpecialTokensByType - Count specific type of special tokens
func (m: &SpecialTokenManager) CountSpecialTokensByType(tokens: vec[i32], token_type: string) i32 {
    count := 0
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) && m.GetTokenType(tokens[i]) == token_type {
            count += 1
        }
    }
    return i32(count)
}

// ============================================================================
// Token Validation
// ============================================================================

// ValidateSpecialTokens - Validate all special tokens in sequence
func (m: &SpecialTokenManager) ValidateSpecialTokens(tokens: vec[i32]) bool {
    for i := 0; i < len(tokens); i += 1 {
        if m.IsSpecialToken(tokens[i]) {
            // Token is valid (exists in mapping)
            _ = m.GetTokenName(tokens[i])
        }
    }
    return true
}

// IsValidTokenId - Check if token ID is valid
func (m: &SpecialTokenManager) IsValidTokenId(token_id: i32) bool {
    return m.IsSpecialToken(token_id)
}

// ============================================================================
// Utility Functions
// ============================================================================

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
