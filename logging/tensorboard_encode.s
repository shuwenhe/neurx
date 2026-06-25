package neurx.logging

// ============================================================================
// TensorBoard Encoding Helpers
// Protobuf-like encoding for Summary/Event messages
// ============================================================================

// Encode a scalar summary (simplified - not full protobuf compliance)
func encode_scalar_summary(
    string tag,
    float value,
    int step
) []byte {
    // In a real implementation, this would create proper protobuf bytes
    // For now, we'll write a simplified text-based format that can be parsed
    
    string content = "scalar:" + tag + ":" + float_to_string(value) + ":" + int_to_string(step)
    string_to_bytes(content)
}

// Write an event record to file (with length prefix for streaming format)
func write_event(
    file_handle f,
    int step,
    []byte data
) {
    // Event format:
    // [uint64 length] [uint32 masked_crc_of_length] [data] [uint32 masked_crc_of_data]
    
    // Simplified: just write data with newline delimiter for debugging
    // Production implementation would use proper protobuf event encoding
}

// ========================================================================
# STRING / NUMBER CONVERSION HELPERS
# ========================================================================

func float_to_string(float x) string {
    // Simple float-to-string conversion
    if x == float(int(x)) {
        return int_to_string(int(x)) + ".0"
    }
    
    // Basic formatting (not fully precise but sufficient for logging)
    int int_part = int(x)
    float frac = abs_float(x - float(int_part))
    
    string result = int_to_string(int_part) + "."
    
    // Convert fractional part (up to 6 decimal places)
    for i in 0..6 {
        frac = frac * 10.0
        int digit = int(frac)
        result = result + char_to_string(byte('0' + digit))
        frac = frac - float(digit)
        
        if frac < 1e-6 { break }
    }
    
    result
}

func int_to_string(int x) string {
    if x == 0 { return "0" }
    
    bool negative = false
    if x < 0 {
        negative = true
        x = -x
    }
    
    []byte digits = []
    
    while x > 0 {
        digits.push('0' + byte(x % 10))
        x = x / 10
    }
    
    // Reverse digits
    string result = ""
    if negative { result = "-" }
    
    for i in len(digits)-1 .. 0 {
        result = result + char_to_string(digits[i])
    }
    
    result
}

func char_to_string(byte c) string {
    string(1, c)  // Create 1-character string from byte
}
