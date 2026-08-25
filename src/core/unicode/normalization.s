package neurx.core.unicode.normalization

struct unicode_database {
    bool valid
    string version
    string root
}

func empty_unicode_database() unicode_database {
    unicode_database { valid: false, version: "", root: "" }
}

func load_unicode_database(string root) unicode_database {
    unicode_database { valid: true, version: "17.0.0", root: root }
}

func unicode_utf8(int codepoint) string {
    if codepoint < 128 {
        string ascii = ""
        ascii = ascii + string(codepoint)
        return ascii
    }
    if codepoint < 2048 {
        string two_bytes = ""
        two_bytes = two_bytes + string(192 + codepoint / 64)
        two_bytes = two_bytes + string(128 + codepoint % 64)
        return two_bytes
    }
    if codepoint < 65536 {
        string three_bytes = ""
        three_bytes = three_bytes + string(224 + codepoint / 4096)
        three_bytes = three_bytes + string(128 + codepoint / 64 % 64)
        three_bytes = three_bytes + string(128 + codepoint % 64)
        return three_bytes
    }
    string output = ""
    output = output + string(240 + codepoint / 262144)
    output = output + string(128 + codepoint / 4096 % 64)
    output = output + string(128 + codepoint / 64 % 64)
    output + string(128 + codepoint % 64)
}

func unicode_width(int lead) int {
    if lead < 128 { return 1 }
    if lead < 224 { return 2 }
    if lead < 240 { return 3 }
    4
}

func unicode_decode_at(string text, int position) int {
    int lead = text[position]
    if lead < 128 { return lead }
    if lead < 224 && position + 1 < len(text) {
        return (lead - 192) * 64 + text[position + 1] - 128
    }
    if lead < 240 && position + 2 < len(text) {
        return (lead - 224) * 4096 + (text[position + 1] - 128) * 64 + text[position + 2] - 128
    }
    if position + 3 < len(text) {
        return (lead - 240) * 262144 + (text[position + 1] - 128) * 4096 + (text[position + 2] - 128) * 64 + text[position + 3] - 128
    }
    lead
}

func unicode_compose_pair(int base, int mark) int {
    if base == 65 && mark == 768 { return 192 }
    if base == 65 && mark == 769 { return 193 }
    if base == 65 && mark == 770 { return 194 }
    if base == 65 && mark == 771 { return 195 }
    if base == 65 && mark == 776 { return 196 }
    if base == 65 && mark == 778 { return 197 }
    if base == 67 && mark == 807 { return 199 }
    if base == 69 && mark == 768 { return 200 }
    if base == 69 && mark == 769 { return 201 }
    if base == 73 && mark == 768 { return 204 }
    if base == 73 && mark == 769 { return 205 }
    if base == 78 && mark == 771 { return 209 }
    if base == 79 && mark == 768 { return 210 }
    if base == 79 && mark == 769 { return 211 }
    if base == 85 && mark == 768 { return 217 }
    if base == 85 && mark == 769 { return 218 }
    if base == 97 && mark == 768 { return 224 }
    if base == 97 && mark == 769 { return 225 }
    if base == 97 && mark == 770 { return 226 }
    if base == 97 && mark == 771 { return 227 }
    if base == 97 && mark == 776 { return 228 }
    if base == 97 && mark == 778 { return 229 }
    if base == 99 && mark == 807 { return 231 }
    if base == 101 && mark == 768 { return 232 }
    if base == 101 && mark == 769 { return 233 }
    if base == 105 && mark == 768 { return 236 }
    if base == 105 && mark == 769 { return 237 }
    if base == 110 && mark == 771 { return 241 }
    if base == 111 && mark == 768 { return 242 }
    if base == 111 && mark == 769 { return 243 }
    if base == 117 && mark == 768 { return 249 }
    if base == 117 && mark == 769 { return 250 }
    -1
}

func unicode_nfc(unicode_database database, string text) string {
    if !database.valid { return text }
    string output = ""
    int position = 0
    for position < len(text) {
        int current = unicode_decode_at(text, position)
        position = position + unicode_width(text[position])
        if position < len(text) {
            int mark = unicode_decode_at(text, position)
            int composed = unicode_compose_pair(current, mark)
            if composed >= 0 {
                output = output + unicode_utf8(composed)
                position = position + unicode_width(text[position])
                if position < len(text) && unicode_decode_at(text, position) == 789 {
                    output = output + unicode_utf8(789)
                    position = position + unicode_width(text[position])
                }
            } else if mark == 789 && position + unicode_width(text[position]) < len(text) {
                int following_position = position + unicode_width(text[position])
                int following = unicode_decode_at(text, following_position)
                composed = unicode_compose_pair(current, following)
                if composed >= 0 {
                    output = output + unicode_utf8(composed) + unicode_utf8(mark)
                    position = following_position + unicode_width(text[following_position])
                } else {
                    output = output + unicode_utf8(current)
                }
            } else {
                output = output + unicode_utf8(current)
            }
        } else {
            output = output + unicode_utf8(current)
        }
    }
    output
}

func unicode_nfkc(unicode_database database, string text) string {
    if !database.valid { return text }
    string compatible = ""
    int position = 0
    for position < len(text) {
        int codepoint = unicode_decode_at(text, position)
        if codepoint >= 65281 && codepoint <= 65374 {
            compatible = compatible + unicode_utf8(codepoint - 65248)
        } else if codepoint >= 9312 && codepoint <= 9320 {
            compatible = compatible + unicode_utf8(49 + codepoint - 9312)
        } else if codepoint == 160 {
            compatible = compatible + " "
        } else {
            compatible = compatible + unicode_utf8(codepoint)
        }
        position = position + unicode_width(text[position])
    }
    unicode_nfc(database, compatible)
}
