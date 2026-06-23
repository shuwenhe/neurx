package neurx.logging

// ============================================================================
// Number Formatting Utilities
// ========================================================================

// Format a percentage with specified width and decimals
func format_percent(float value, int width, int decimals) string {
    string formatted = format_float(value, width, decimals) + "%"
    
    // Pad with spaces on left if needed
    while len(formatted) < width {
        formatted = " " + formatted
    }
    
    // Truncate if too long (shouldn't happen normally)
    if len(formatted) > width + 1 {
        formatted = substring(formatted, 0, width + 1)
    }
    
    formatted
}

// Format float to fixed-point string with width and decimal places
func format_float(float value, int width, int decimals) string {
    string s = float_to_string_with_decimals(value, decimals)
    
    // Pad/truncate to desired width
    if len(s) < width {
        for i in 0..(width - len(s)) {
            s = " " + s
        }
    } else if len(s) > width {
        s = substring(s, 0, width)
    }
    
    s
}

// Convert float to string with exact number of decimal places
func float_to_string_with_decimals(float value, int decimals) string {
    if value == 0.0 {
        return "0." + repeat_char('0', decimals)
    }
    
    bool negative = false
    if value < 0.0 {
        negative = true
        value = -value
    }
    
    // Separate integer and fractional parts
    int integer_part = int(value)
    float fractional = value - float(integer_part)
    
    string result = ""
    if negative { result = "-" }
    result = result + int_to_string(integer_part) + "."
    
    // Convert fractional part
    for i in 0..decimals {
        fractional = fractional * 10.0
        int digit = int(fractional)
        
        if digit <= 9 {
            result = result + char_to_string(byte('0' + byte(digit)))
        } else {
            result = result + "0"  // Handle edge cases
        }
        
        fractional = fractional - float(digit)
    }
    
    result
}
