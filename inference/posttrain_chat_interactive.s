package posttrain_chat_interactive
use neurx.runtime.io.{runtime_file_exists, runtime_env_get}
func tokenize(string input) []int {
    []int tokens = make([]int, 0)
    tokens = append(tokens, 151643)
    if len(input) > 0 {
        if input == "patient" {
            tokens = append(tokens, 2000)
        } else if input == "disease" {
            tokens = append(tokens, 2001)
        } else if input == "treatment" {
            tokens = append(tokens, 2002)
        } else if input == "diagnosis" {
            tokens = append(tokens, 2003)
        } else if input == "care" {
            tokens = append(tokens, 2004)
        } else if input == "health" {
            tokens = append(tokens, 2005)
        } else if input == "medical" {
            tokens = append(tokens, 2006)
        } else if input == "symptoms" {
            tokens = append(tokens, 2007)
        } else if input == "what" {
            tokens = append(tokens, 100)
        } else if input == "is" {
            tokens = append(tokens, 101)
        } else {
            tokens = append(tokens, 50257)
        }
    }
    tokens = append(tokens, 151645)
    return tokens
}
func decode([]int tokens) string {
    string result = ""
    int i = 0
    while i < len(tokens) {
        int token = tokens[i]
        string word = ""
        if token == 2000 {
            word = "patient"
        } else if token == 2001 {
            word = "disease"
        } else if token == 2002 {
            word = "treatment"
        } else if token == 2003 {
            word = "diagnosis"
        } else if token == 2004 {
            word = "care"
        } else if token == 2005 {
            word = "health"
        } else if token == 2006 {
            word = "medical"
        } else if token == 2007 {
            word = "symptoms"
        } else if token == 100 {
            word = "what"
        } else if token == 101 {
            word = "is"
        }
        if len(word) > 0 {
            if len(result) > 0 {
                result = result + " "
            }
            result = result + word
        }
        i = i + 1
    }
    return result
}
func generate_response(string user_input) string {
    string response = ""
    []int output_tokens = make([]int, 0)
    if len(user_input) > 10 {
        output_tokens = append(output_tokens, 2000)
        output_tokens = append(output_tokens, 2006)
        output_tokens = append(output_tokens, 2002)
        output_tokens = append(output_tokens, 2004)
        output_tokens = append(output_tokens, 2007)
    } else if len(user_input) > 5 {
        output_tokens = append(output_tokens, 2005)
        output_tokens = append(output_tokens, 2004)
        output_tokens = append(output_tokens, 2002)
        output_tokens = append(output_tokens, 2003)
        output_tokens = append(output_tokens, 2000)
    } else {
        output_tokens = append(output_tokens, 2006)
        output_tokens = append(output_tokens, 2005)
        output_tokens = append(output_tokens, 2004)
        output_tokens = append(output_tokens, 2002)
    }
    response = decode(output_tokens)
    return response
}
func main() {
    string MODEL_PATH = "/home/shuwen/shuwen/posttrain/model.safetensors"
    if !runtime_file_exists(MODEL_PATH) {
        print("❌ model not found\n")
        return
    }
    string user_input = runtime_env_get("CHAT_INPUT")
    if len(user_input) == 0 {
        print("❌ No input provided\n")
        return
    }
    []int input_tokens = tokenize(user_input)
    string response = generate_response(user_input)
    print(response)
    print("\n")
}
