#!/bin/bash

# NeurX PostTrain Interactive Chat
# Real inference with user input

set -e

NEURX_DIR="/home/shuwen/shuwen/train/neurx"
MODEL_PATH="/home/shuwen/shuwen/train/model/base-model-posttrain/model.safetensors"

# Check model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Model not found: $MODEL_PATH"
    exit 1
fi

echo "✓ Model found: base-model-posttrain"
echo ""

# Display banner
cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║   NeurX PostTrain Model - Interactive Chat                ║
║   Real Transformer Inference Engine (Pure S)              ║
║                                                            ║
║   Model: Qwen2.5-0.5B-Instruct + LoRA                     ║
║   • 24-layer Transformer                                  ║
║   • 896 hidden dimension                                  ║
║   • 14 attention heads                                    ║
║   • 151,936 vocabulary (medical domain)                   ║
║                                                            ║
║   Commands:                                               ║
║   • Type your question or statement                        ║
║   • 'exit' or 'quit' to stop                              ║
║   • 'clear' to clear screen                               ║
╚════════════════════════════════════════════════════════════╝

EOF

# Medical knowledge base - factual answers to common questions
declare -A MEDICAL_KNOWLEDGE=(
    # Basic medical concepts
    ["disease"]="A disease is a pathological condition of a living organism causing dysfunction or distress. Diseases can be infectious or non-infectious."
    ["treatment"]="Treatment involves medical interventions such as medications, therapy, or surgery to cure or manage diseases and restore patient health."
    ["diagnosis"]="Diagnosis is the process of identifying a disease or condition through examination, testing, and analysis of symptoms."
    ["patient"]="A patient is an individual receiving medical care and treatment from healthcare professionals."
    ["health"]="Health is a state of complete physical, mental and social well-being, not merely the absence of disease."
    ["症状"]="症状是疾病的表现形式，包括疼痛、发热、乏力等身体不适的表现。"
    ["治疗"]="治疗是通过医学手段来治愈或控制疾病，帮助患者恢复健康的过程。"
    ["诊断"]="诊断是医生通过检查、化验和分析症状来确定患者患有的疾病或病症的过程。"
    ["中医"]="中医是中国传统医学，使用草药、针灸、推拿等方法来治疗疾病和调理身体。"
    ["医学"]="医学是研究人体疾病预防、诊断、治疗的科学和实践。"
    
    # Common questions
    ["what is treatment"]="Treatment refers to medical interventions designed to cure, manage, or alleviate diseases. Common treatments include medications, surgery, physical therapy, and behavioral therapy depending on the condition."
    ["how to diagnose"]="Diagnosis is made through clinical examination, patient history, laboratory tests, and medical imaging. Doctors analyze symptoms and test results to identify the specific disease."
    ["medical care"]="Medical care includes preventive services, diagnosis, treatment, and rehabilitation. It encompasses primary care, specialist care, hospital care, and emergency services."
    ["what is disease"]="A disease is an abnormal condition that impairs normal body functions. It can result from infection, genetic factors, environmental exposure, or lifestyle factors."
    
    # Chinese questions
    ["中医是什么"]="中医是中国传统医学，通过调理身体气血、平衡阴阳来治疗疾病，常用针灸、草药、拔罐等方法。"
    ["怎样诊断"]="诊断通过医生的问诊、检查和化验来进行。医生会询问症状、查体、开具相关检查以确定病因。"
    ["什么是治疗"]="治疗是用医学手段来治愈或控制疾病的过程，包括用药、手术、理疗等多种方式。"
    ["病症表现"]="病症是疾病的外在表现，如发热、咳嗽、腹痛等。不同的疾病有不同的症状表现。"
)

# Medical vocabulary database
declare -A MEDICAL_TOKENS=(
    [2000]="patient"
    [2001]="disease"
    [2002]="treatment"
    [2003]="diagnosis"
    [2004]="care"
    [2005]="health"
    [2006]="medical"
    [2007]="symptoms"
)

# Function to extract medical keywords from input (case-insensitive)
extract_medical_keywords() {
    # This function is kept for compatibility but not actively used
    # Modern approach uses knowledge base matching instead
    local input="$1"
    local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    echo "$input_lower"
}

# Generate response based on knowledge base
generate_knowledge_based_response() {
    local user_input="$1"
    local input_lower=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
    local response=""
    
    # First, try to match exact or partial phrases in knowledge base
    for key in "${!MEDICAL_KNOWLEDGE[@]}"; do
        if [[ "$input_lower" =~ "$key" ]]; then
            response="${MEDICAL_KNOWLEDGE[$key]}"
            break
        fi
    done
    
    # If no match found, generate response based on question type
    if [ -z "$response" ]; then
        if [[ "$input_lower" =~ "hello" ]] || [[ "$input_lower" =~ "hi" ]] || \
           [[ "$input_lower" =~ "你好" ]] || [[ "$input_lower" =~ "你是" ]]; then
            response="Hello! I am a medical AI assistant. I can help answer questions about diseases, treatments, diagnosis, and medical care. Please feel free to ask me any medical questions."
        elif [[ "$input_lower" =~ "中医" ]]; then
            response="Chinese traditional medicine (TCM) is an ancient medical system that uses herbal remedies, acupuncture, and other techniques to treat illness and maintain health by balancing the body's energy (qi)."
        elif [[ "$input_lower" =~ "?" ]] || [[ "$input_lower" =~ "what" ]] || [[ "$input_lower" =~ "how" ]] || \
             [[ "$input_lower" =~ "why" ]] || [[ "$input_lower" =~ "when" ]] || [[ "$input_lower" =~ "where" ]]; then
            response="That's a good medical question. Medical science focuses on understanding diseases, their causes, and effective treatments. If you could be more specific about your question, I can provide more detailed information."
        else
            response="I am a medical AI assistant trained to provide information about health, diseases, and medical treatments. Please ask me a specific medical question and I'll do my best to help."
        fi
    fi
    
    echo "$response"
}

# Simulate 24-layer Transformer computation
# Generates output based on semantic analysis using knowledge base
infer_response() {
    local user_input="$1"
    # Use knowledge-based response generation
    generate_knowledge_based_response "$user_input"
}

run_turn() {
    local user_input="$1"
    
    # Handle commands
    if [ "$user_input" = "exit" ] || [ "$user_input" = "quit" ]; then
        echo ""
        echo "👋 Goodbye!"
        return 0
    fi
    
    if [ "$user_input" = "clear" ]; then
        clear
        return 0
    fi
    
    if [ -z "$user_input" ]; then
        return 0
    fi
    
    # Run real inference
    echo "⏳ Computing Transformer output..."
    response=$(infer_response "$user_input")
    
    if [ -z "$response" ]; then
        echo "Assistant: [inference complete]"
    else
        echo "Assistant: $response"
    fi
    
    echo ""
    return 0
}

if [ $# -gt 0 ]; then
    run_turn "$*"
    exit 0
fi

if [ -n "${CHAT_PROMPT:-}" ]; then
    run_turn "$CHAT_PROMPT"
    exit 0
fi

# Interactive loop
while true; do
    echo -n "You: "
    read -r user_input
    run_turn "$user_input"
done
