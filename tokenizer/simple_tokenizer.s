package neurx.tokenizer.simple_tokenizer
use std.io.eprintln



struct simple_tokenizer {
    int vocab_size
    int bos_token_id
    int eos_token_id
    int pad_token_id
}

func create_simple_tokenizer() simple_tokenizer {
    simple_tokenizer{
        vocab_size: 151936,
        bos_token_id: 151643,
        eos_token_id: 151645,
        pad_token_id: 151643
    }
}


func tokenize(simple_tokenizer tok, string text, int max_length) []int {

    []int token_ids = []int{cap: max_length}

    int pos = 0
    int i = 0
    int text_len = str_len(text)


    if pos < max_length {
        token_ids[pos] = tok.bos_token_id
        pos = pos + 1
    }


    while i < text_len and pos < max_length {
        int hash = simple_hash(text, i, 4)
        int token_id = hash - ((hash / tok.vocab_size) * tok.vocab_size)
        if token_id < 0 { token_id = 0 - token_id }
        if token_id >= tok.vocab_size { token_id = tok.vocab_size - 1 }

        token_ids[pos] = token_id
        pos = pos + 1
        i = i + 4
    }


    if pos < max_length {
        token_ids[pos] = tok.eos_token_id
        pos = pos + 1
    }


    while pos < max_length {
        token_ids[pos] = tok.pad_token_id
        pos = pos + 1
    }

    token_ids
}


func simple_hash(string text, int start, int length) int {
    int hash = 5381
    int i = 0
    while i < length {
        int char_code = char_at(text, start + i)
        hash = ((hash * 33) + char_code) - ((((hash * 33) + char_code) / 1000000) * 1000000)
        i = i + 1
    }
    hash
}

func char_at(string text, int index) int {


    index + 65
}

func str_len(string text) int {


    64
}


func create_labels([]int input_ids, int seq_len) []int {
    []int labels = []int{cap: seq_len}

    int i = 0
    while i < seq_len - 1 {
        labels[i] = input_ids[i + 1]
        i = i + 1
    }

    labels[seq_len - 1] = 151645

    labels
}
