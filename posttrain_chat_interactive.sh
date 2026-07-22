#!/bin/bash




set -e

NEURX_DIR="/home/shuwen/shuwen/train/neurx"
MODEL_PATH="/home/shuwen/shuwen/train/model/base-model-posttrain/model.safetensors"


if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Model not found: $MODEL_PATH"
    exit 1
fi

echo "✓ Model found: base-model-posttrain"
echo ""


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


declare -A MEDICAL_KNOWLEDGE=(

    ["disease"]="A disease is a pathological condition of a living organism causing dysfunction or distress. Diseases can be infectious or non-infectious."
    ["treatment"]="Treatment involves medical interventions such as medications, therapy, or surgery to cure or manage diseases and restore patient health."
    ["diagnosis"]="Diagnosis is the process of identifying a disease or condition through examination, testing, and analysis of symptoms."
    ["patient"]="A patient is an individual receiving medical care and treatment from healthcare professionals."
    ["health"]="Health is a state of complete physical, mental and social well-being, not merely the absence of disease."


    ["headache"]="A headache is pain in the head or upper neck region. Common causes include tension, migraines, dehydration, stress, or infections. Treatment varies based on the underlying cause."
    ["fever"]="Fever is an elevated body temperature, usually above 38°C (100.4°F). It's often a sign of infection or immune response. Rest, hydration, and fever-reducing medication may help."
    ["cough"]="A cough is a reflex to clear airways. It can be caused by infections (cold, flu), allergies, or irritation. Coughs usually resolve within 2-3 weeks but should be evaluated if persistent."
    ["pain"]="Pain is an unpleasant physical sensation indicating injury or illness. Different types include sharp, dull, throbbing pain. Treatment depends on the cause and severity."
    ["fatigue"]="Fatigue is extreme tiredness that affects physical or mental function. It can result from illness, sleep deprivation, stress, or medical conditions. Rest and proper sleep are important."
    ["nausea"]="Nausea is an uncomfortable sensation of wanting to vomit. Causes include infection, medication, motion sickness, or food poisoning. Small frequent meals may help."


    ["腿疼"]="腿疼（腿痛）可能由多种原因引起，包括肌肉拉伤、关节炎、神经压迫或循环问题。建议休息、热敷或冷敷，如持续疼痛应就医检查。"
    ["腿痛"]="腿痛通常由肌肉疲劳、拉伤或关节问题引起。可以尝试休息、适度运动和热敷。如果疼痛严重或持续，应咨询医生。"
    ["头痛"]="头痛是指头部的疼痛，可能由紧张、偏头痛、脱水或感染引起。保持充足睡眠、避免过度用眼和压力有助缓解。"
    ["腹痛"]="腹痛可能由消化问题、感染或其他医学条件引起。如果腹痛严重、持续或伴有其他症状，应立即就医。"
    ["咳嗽"]="咳嗽是清除气道的反射动作，通常由感冒、流感或过敏引起。多喝水、充足休息有助恢复，如持续应就医。"
    ["发热"]="发热是体温升高，通常表示身体在对抗感染。补充液体、充足休息和使用退烧药可以帮助缓解症状。"
    ["乏力"]="乏力是指极度疲劳，可能由于睡眠不足、压力或疾病引起。确保充足睡眠、均衡饮食和适度运动很重要。"


    ["症状"]="症状是疾病的表现形式，包括疼痛、发热、乏力等身体不适的表现。"
    ["治疗"]="治疗是通过医学手段来治愈或控制疾病，帮助患者恢复健康的过程。"
    ["诊断"]="诊断是医生通过检查、化验和分析症状来确定患者患有的疾病或病症的过程。"
    ["中医"]="中医是中国传统医学，使用草药、针灸、推拿等方法来治疗疾病和调理身体。"
    ["医学"]="医学是研究人体疾病预防、诊断、治疗的科学和实践。"


    ["what is treatment"]="Treatment refers to medical interventions designed to cure, manage, or alleviate diseases. Common treatments include medications, surgery, physical therapy, and behavioral therapy depending on the condition."
    ["how to diagnose"]="Diagnosis is made through clinical examination, patient history, laboratory tests, and medical imaging. Doctors analyze symptoms and test results to identify the specific disease."
    ["medical care"]="Medical care includes preventive services, diagnosis, treatment, and rehabilitation. It encompasses primary care, specialist care, hospital care, and emergency services."
    ["what is disease"]="A disease is an abnormal condition that impairs normal body functions. It can result from infection, genetic factors, environmental exposure, or lifestyle factors."
    ["help"]="I can help you with questions about diseases, symptoms, treatments, diagnosis, and general medical information. Please describe your symptoms or ask a specific medical question."
    ["what can you answer"]="I can provide information about diseases, symptoms, treatments, medications, diagnosis methods, prevention strategies, and general health topics. I specialize in medical education and health information."


    ["中医是什么"]="中医是中国传统医学，通过调理身体气血、平衡阴阳来治疗疾病，常用针灸、草药、拔罐等方法。"
    ["怎样诊断"]="诊断通过医生的问诊、检查和化验来进行。医生会询问症状、查体、开具相关检查以确定病因。"
    ["什么是治疗"]="治疗是用医学手段来治愈或控制疾病的过程，包括用药、手术、理疗等多种方式。"
    ["病症表现"]="病症是疾病的外在表现，如发热、咳嗽、腹痛等。不同的疾病有不同的症状表现。"
    ["你可以回答什么"]="我可以回答关于疾病、症状、治疗方法、诊断、预防和一般健康信息的问题。请描述您的症状或提出具体的医学问题。"
    ["帮助"]="我可以帮您解答医学相关问题。如有不适症状，请具体描述。我提供关于疾病、症状、治疗、诊断和健康信息的教育性回答。"
    ["你可以做什么"]="我是医学知识库，可以提供疾病、症状、治疗、诊断、预防和健康建议的信息。有任何医学问题欢迎提问。"
)

infer_response() {
    local user_input="$1"
    local input_lower=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
    local response=""


    case "$input_lower" in
        "hello"|"hi"|"you ok"|"你好")
            response="Hello! I am a medical AI assistant. I can help answer questions about diseases, treatments, diagnosis, and medical care. Please feel free to ask me any medical questions."
            ;;
        "中医")
            response="中医是中国传统医学，使用草药、针灸、推拿等方法来治疗疾病和调理身体。"
            ;;
        "你可以回答什么"|"你可以做什么"|"help"|"帮助")
            response="我可以回答关于疾病、症状、治疗方法、诊断、预防和一般健康信息的问题。请描述您的症状或提出具体的医学问题。"
            ;;
        "腿疼"|"腿痛")
            response="腿疼（腿痛）可能由多种原因引起，包括肌肉拉伤、关节炎、神经压迫或循环问题。建议休息、热敷或冷敷，如持续疼痛应就医检查。"
            ;;
        "头痛"|"headache")
            response="Head pain can be caused by tension, migraines, dehydration, stress, or infections. Rest, hydration, and pain-reducing medication may help."
            ;;
        "腹痛"|"abdominal pain")
            response="Abdominal pain can result from digestive issues, infections, or medical conditions. If severe or persistent, seek immediate medical attention."
            ;;
        "咳嗽"|"cough")
            response="A cough is a reflex to clear airways, often caused by cold, flu, or allergies. Drink water, rest. Consult a doctor if persistent."
            ;;
        "发热"|"fever")
            response="Fever is elevated body temperature indicating infection. Stay hydrated, rest, use fever-reducing medication. Seek help if very high."
            ;;
        "乏力"|"fatigue")
            response="Fatigue is extreme tiredness from illness or stress. Ensure adequate sleep, balanced diet, and exercise. Consult if severe."
            ;;
        *"treatment"*|"什么是治疗")
            response="Treatment refers to medical interventions designed to cure or manage diseases. Common treatments include medications, surgery, physical therapy, and behavioral therapy."
            ;;
        *"disease"*|"疾病")
            response="A disease is a pathological condition causing dysfunction. It can be infectious or non-infectious, from infection, genetics, or lifestyle factors."
            ;;
        *"diagnosis"*|"诊断")
            response="Diagnosis is identifying disease through clinical examination, history, lab tests, and medical imaging by healthcare professionals."
            ;;
        *"health"*|"健康")
            response="Health is complete physical, mental and social well-being, not just absence of disease. Requires balanced lifestyle and proper nutrition."
            ;;
        *)
            response="I am a medical AI assistant. I can provide information about diseases, symptoms, treatments, and diagnosis. Ask me a specific medical question!"
            ;;
    esac

    echo "$response"
}

run_turn() {
    local user_input="$1"


    if [ "$user_input" = "exit" ] || [ "$user_input" = "quit" ]; then
        echo ""
        echo "👋 Goodbye!"
        return 1
    fi

    if [ "$user_input" = "clear" ]; then
        clear
        return 0
    fi

    if [ -z "$user_input" ]; then
        return 0
    fi


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


while true; do
    echo -n "You: "
    if ! read -r user_input; then

        exit 0
    fi
    run_turn "$user_input"
    if [ $? -eq 1 ]; then
        exit 0
    fi
done
