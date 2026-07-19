#pragma once

#include <algorithm>
#include <cstddef>
#include <vector>

namespace neurx_training {

inline void append_document_tokens(std::vector<int>& pending,
                                   const std::vector<int>& document) {
    pending.insert(pending.end(), document.begin(), document.end());
}

// Produces inputs plus the one-token-shifted final target. The final token is
// retained as the first input of the next sequence, so a packed token stream is
// consumed exactly once without dropping document tails.
inline bool take_training_window(std::vector<int>& pending,
                                 std::size_t sequence_length,
                                 std::vector<int>& window) {
    if (sequence_length == 0 || pending.size() < sequence_length + 1) {
        return false;
    }
    window.resize(sequence_length + 1);
    std::copy_n(pending.begin(), sequence_length + 1, window.begin());
    pending.erase(pending.begin(), pending.begin() + sequence_length);
    return true;
}

}  // namespace neurx_training
