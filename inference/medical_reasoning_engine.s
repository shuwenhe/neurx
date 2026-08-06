package neurx.inference.medical_reasoning_engine

extern "intrinsic" func __host_slice(string text, int start, int end) string

func CATEGORY_UNKNOWN() int { return 0 }

func CATEGORY_TREATMENT() int { return 1 }

func CATEGORY_SYMPTOM() int { return 2 }

func CATEGORY_DIAGNOSIS() int { return 3 }

func CATEGORY_DISEASE() int { return 4 }

func CATEGORY_DRUG() int { return 5 }

func CATEGORY_INFECTION() int { return 6 }

func CATEGORY_HEALTH() int { return 7 }

func CATEGORY_ANATOMY() int { return 8 }

func CATEGORY_PATHOLOGY() int { return 9 }

func to_lower(string text) string {
    string result = ""
    int i = 0
    while i < len(text) {
        int c = text[i]
        if c >= 65 && c <= 90 {
            c = c + 32
        }
        result = result + __host_slice(text, i, i + 1)
        i = i + 1
    }
    result
}

func contains_substr(string text, string substr) bool {
    int text_len = len(text)
    int substr_len = len(substr)
    if substr_len > text_len || substr_len == 0 {
        return false
    }
    int i = 0
    while i <= text_len - substr_len {
        int j = 0
        while j < substr_len {
            if text[i + j] != substr[j] {
                break
            }
            j = j + 1
        }
        if j == substr_len {
            return true
        }
        i = i + 1
    }
    false
}

func contains_any_two(string text, string pattern1, string pattern2) bool {
    if contains_substr(text, pattern1) {
        return true
    }
    contains_substr(text, pattern2)
}

func detect_category(string text) int {
    string lower = to_lower(text)

    if contains_substr(lower, "treatment") || contains_substr(lower, "treat") ||
       contains_substr(lower, "therapy") || contains_substr(lower, "therapeutic") ||
       contains_substr(lower, "治疗") || contains_substr(lower, "疗法") {
        return CATEGORY_TREATMENT()
    }

    if contains_substr(lower, "symptom") || contains_substr(lower, "pain") ||
       contains_substr(lower, "fever") || contains_substr(lower, "sign") ||
       contains_substr(lower, "症状") || contains_substr(lower, "疼痛") ||
       contains_substr(lower, "发热") || contains_substr(lower, "体征") {
        return CATEGORY_SYMPTOM()
    }

    if contains_substr(lower, "diagnos") || contains_substr(lower, "detect") ||
       contains_substr(lower, "identify") || contains_substr(lower, "test") ||
       contains_substr(lower, "诊断") || contains_substr(lower, "检查") {
        return CATEGORY_DIAGNOSIS()
    }

    if contains_substr(lower, "disease") || contains_substr(lower, "disorder") ||
       contains_substr(lower, "condition") || contains_substr(lower, "illness") ||
       contains_substr(lower, "疾病") || contains_substr(lower, "病") {
        return CATEGORY_DISEASE()
    }

    if contains_substr(lower, "medicine") || contains_substr(lower, "drug") ||
       contains_substr(lower, "medication") || contains_substr(lower, "pharma") ||
       contains_substr(lower, "药") || contains_substr(lower, "药物") {
        return CATEGORY_DRUG()
    }

    if contains_substr(lower, "infection") || contains_substr(lower, "infect") ||
       contains_substr(lower, "virus") || contains_substr(lower, "bacteria") ||
       contains_substr(lower, "感染") || contains_substr(lower, "病原") {
        return CATEGORY_INFECTION()
    }

    if contains_substr(lower, "health") || contains_substr(lower, "wellness") ||
       contains_substr(lower, "preventive") || contains_substr(lower, "prevention") ||
       contains_substr(lower, "健康") || contains_substr(lower, "保健") {
        return CATEGORY_HEALTH()
    }

    if contains_substr(lower, "anatomy") || contains_substr(lower, "organ") ||
       contains_substr(lower, "tissue") || contains_substr(lower, "bone") ||
       contains_substr(lower, "解剖") || contains_substr(lower, "器官") {
        return CATEGORY_ANATOMY()
    }

    if contains_substr(lower, "pathology") || contains_substr(lower, "patholog") ||
       contains_substr(lower, "lesion") || contains_substr(lower, "abnormal") ||
       contains_substr(lower, "病理") || contains_substr(lower, "病变") {
        return CATEGORY_PATHOLOGY()
    }

    CATEGORY_UNKNOWN()
}

func generate_treatment_response(string text) string {
    string lower = to_lower(text)

    if contains_substr(lower, "diabetes") || contains_substr(lower, "diabetic") || contains_substr(lower, "糖尿病") {
        return "糖尿病的治疗通常包括：\n1. 血糖控制（胰岛素或口服药物）\n2. 饮食管理和运动\n3. 定期监测血糖和血压\n4. 预防并发症（眼睛、肾脏、神经）\n建议在内分泌专家指导下进行治疗。"
    }
    if contains_substr(lower, "hypertension") || contains_substr(lower, "blood pressure") || contains_substr(lower, "高血压") {
        return "高血压的治疗方案：\n1. 生活方式调整（低钠饮食、运动、减肥）\n2. 抗高血压药物（ACE抑制剂、利尿剂等）\n3. 定期血压监测\n4. 心血管风险评估\n个性化治疗需咨询心内科医生。"
    }
    if contains_substr(lower, "cancer") || contains_substr(lower, "tumor") || contains_substr(lower, "肿瘤") || contains_substr(lower, "癌") {
        return "肿瘤/癌症的治疗通常包括多学科方案：\n1. 手术切除（如适用）\n2. 化疗和靶向治疗\n3. 放射治疗\n4. 免疫治疗\n5. 支持性治疗和康复\n需在肿瘤中心进行综合评估。"
    }
    if contains_substr(lower, "infection") || contains_substr(lower, "infect") || contains_substr(lower, "感染") {
        return "感染的治疗策略：\n1. 病原体鉴定（细菌、病毒、真菌等）\n2. 针对性抗感染治疗\n3. 支持性治疗（补液、营养支持）\n4. 监测治疗反应\n5. 并发症管理\n抗生素使用需按医嘱规范用药。"
    }
    if contains_substr(lower, "asthma") || contains_substr(lower, "哮喘") {
        return "哮喘的治疗包括：\n1. 长期控制性用药（吸入糖皮质激素）\n2. 急性发作缓解（支气管扩张剂）\n3. 触发因素识别和回避\n4. 肺功能监测\n5. 患者教育和自我管理\n规则用药可以有效控制症状。"
    }

    return "治疗方案的制定需要考虑多个因素：\n1. 明确诊断：准确识别疾病\n2. 病情评估：严重程度、并发症、患者情况\n3. 治疗选择：\n   - 保守治疗：药物、物理治疗、生活方式改变\n   - 手术治疗：适应症明确时\n   - 综合治疗：多学科协作\n4. 预后评估：预期效果和风险\n5. 随访监测：调整治疗方案\n\n最终的治疗决策应由医生根据患者具体情况制定。"
}

func generate_symptom_response(string text) string {
    string lower = to_lower(text)

    if contains_substr(lower, "pain") || contains_substr(lower, "ache") || contains_substr(lower, "疼痛") {
        return "疼痛是一个复杂的症状，可能由多种原因引起：\n\n常见原因：\n1. 肌肉骨骼问题：拉伤、扭伤、关节炎\n2. 神经压迫：坐骨神经痛、脊椎问题\n3. 炎症：感染、自免疾病\n4. 内脏疾病：心脏、消化系统、生殖系统问题\n5. 其他：肿瘤、代谢性疾病\n\n评估重点：\n- 疼痛位置、性质和放射情况\n- 发作频率和持续时间\n- 加重或缓解因素\n- 伴随症状\n\n建议：就医进行全面评估，必要时进行影像学检查。"
    }
    if contains_substr(lower, "fever") || contains_substr(lower, "temperature") || contains_substr(lower, "发热") || contains_substr(lower, "发烧") {
        return "发热症状处理指南：\n\n发热的常见原因：\n1. 感染性疾病：\n   - 细菌感染（肺炎、膀胱炎等）\n   - 病毒感染（流感、COVID-19等）\n   - 真菌或寄生虫感染\n2. 非感染原因：肿瘤、自免疾病、药物反应\n\n危险信号（需要立即就医）：\n- 高热（>39.5°C）持续不退\n- 伴有呼吸困难、胸痛\n- 意识改变或严重头痛\n- 皮肤出血点\n- 婴幼儿或老年人的发热\n\n一般处理：\n1. 物理降温：温水擦浴\n2. 充分补液\n3. 适当休息\n4. 监测体温变化\n\n发热>3天或症状加重应就医。"
    }
    if contains_substr(lower, "cough") || contains_substr(lower, "咳嗽") {
        return "咳嗽症状分析：\n\n常见原因：\n1. 上呼吸道感染：感冒、喉炎\n2. 下呼吸道感染：支气管炎、肺炎\n3. 慢性疾病：哮喘、COPD、肺纤维化\n4. 其他：胃食管反流、心脏病、药物副作用\n\n咳嗽类型：\n- 干咳：无痰，常见于病毒感染初期\n- 湿咳：有痰，提示感染或水肿\n- 阵咳：集中发作\n\n警示信号：\n- 咳血\n- 呼吸困难\n- 胸痛\n- 持续>3周的咳嗽\n- 伴有高热、寒战\n\n建议：咳嗽持续>1周或恶化应就医检查。"
    }

    return "症状评估需要系统分析：\n\n重要信息：\n1. 症状特征：\n   - 发生时间和进展过程\n   - 症状性质和位置\n   - 严重程度和对生活的影响\n\n2. 伴随症状：全身症状、其他部位症状\n\n3. 加重或缓解因素：特定活动、饮食、位置变化\n\n4. 既往史：相关病史、手术、过敏\n\n5. 危险信号识别：\n   - 急性发作的严重症状\n   - 进行性恶化\n   - 生命危险症状\n\n专业评估包括：\n- 详细的病史采集\n- 体格检查\n- 必要的实验室和影像学检查\n\n建议：症状新发或加重时应及时就医评估。"
}

func generate_diagnosis_response(string text) string {
    string lower = to_lower(text)

    return "诊断是医学实践中最重要的步骤：\n\n诊断过程通常包括：\n1. 病史采集（现病史、既往史、家族史、生活史）\n2. 体格检查（全面的临床检查）\n3. 实验室检查：\n   - 血液检查：血球计数、生化指标\n   - 尿液检查\n   - 特异性标志物检查\n4. 影像学检查：\n   - X线成像\n   - 超声检查\n   - CT/MRI检查\n   - 其他专项检查\n5. 特殊检查：\n   - 内镜检查\n   - 病理活检\n   - 功能学检查\n\n诊断思维：\n1. 根据症状和体征构建鉴别诊断清单\n2. 通过检查逐步排除或确认\n3. 综合分析所有信息做出最可能的诊断\n4. 必要时追加检查确诊\n\n重要提醒：\n- 准确诊断是有效治疗的基础\n- 不同疾病的诊断标准不同\n- 某些疾病需要专科医生诊断\n- 遵循循证医学原则\n\n建议：各类症状和体征应由有资质的医疗专业人员进行诊断。"
}

func generate_disease_response(string text) string {
    string lower = to_lower(text)

    if contains_substr(lower, "heart") || contains_substr(lower, "cardiac") || contains_substr(lower, "心脏") {
        return "心脏病的医学知识：\n\n心脏病类型：\n1. 冠心病：冠状动脉粥样硬化\n   - 表现：心绞痛、心肌梗死\n   - 危险因素：吸烟、高血压、高脂血症、糖尿病\n\n2. 心律不齐：心脏电传导异常\n   - 常见类型：房颤、室速、心动过缓\n   - 症状：心悸、晕厥、乏力\n\n3. 心力衰竭：心脏泵血功能减退\n   - 分类：收缩期/舒张期、急性/慢性\n   - 症状：呼吸困难、浮肿、乏力\n\n4. 瓣膜病：心脏瓣膜结构或功能异常\n\n危险信号：\n- 突然胸痛\n- 严重呼吸困难\n- 晕厥\n- 快速无规律心跳\n\n预防：控制危险因素、规律锻炼、健康饮食、定期体检。"
    }
    if contains_substr(lower, "lung") || contains_substr(lower, "respiratory") || contains_substr(lower, "肺") {
        return "肺部疾病概述：\n\n常见肺部疾病：\n1. 肺炎：肺部感染\n   - 症状：咳嗽、发热、呼吸困难\n   - 分类：细菌性、病毒性、真菌性、吸入性\n\n2. 慢性阻塞性肺病（COPD）：\n   - 主要病因：吸烟、职业暴露\n   - 症状：慢性咳嗽、气短、喘息\n\n3. 哮喘：气道炎症和可逆性梗阻\n   - 症状：喘息、胸闷、呼吸困难\n   - 触发因素：过敏原、冷空气、运动\n\n4. 肺纤维化：肺间质纤维化\n   - 症状：进行性呼吸困难、干咳\n\n5. 肺癌：肺部恶性肿瘤\n   - 危险因素：吸烟、职业暴露、遗传因素\n\n保护肺部：\n- 戒烟是最有效的预防措施\n- 避免空气污染\n- 定期体检和筛查\n- 防止呼吸道感染"
    }
    if contains_substr(lower, "liver") || contains_substr(lower, "hepatic") || contains_substr(lower, "肝") {
        return "肝脏疾病知识：\n\n常见肝脏疾病：\n1. 病毒性肝炎：\n   - 甲型肝炎：粪口途径传播\n   - 乙型肝炎：血液/体液传播，可慢性化\n   - 丙型肝炎：主要通过血液传播\n\n2. 脂肪肝：肝细胞脂肪堆积\n   - 非酒精性脂肪肝：代谢相关\n   - 酒精性脂肪肝：饮酒引起\n\n3. 肝硬化：肝脏结构和功能的终末改变\n   - 常见病因：乙肝、酒精滥用\n   - 并发症：门脉高压、腹水、食管静脉曲张\n\n4. 肝癌：原发性肝细胞癌\n   - 高危人群：肝硬化患者、乙肝患者\n\n症状提示：\n- 黄疸（皮肤黄染）\n- 腹痛和腹胀\n- 乏力和厌食\n- 尿色深、大便浅色\n\n预防措施：\n- 乙肝疫苗接种\n- 戒酒\n- 健康饮食\n- 定期肝功能检查"
    }

    return "疾病是人体在一定条件下因各种病因引起的生理功能和代谢异常，导致身体不适。\n\n疾病的基本要素：\n1. 病因：导致疾病的原因\n   - 传染性病因：病原微生物\n   - 非传染性病因：遗传、代谢、环境、生活方式\n\n2. 发病机制：疾病发展的过程\n   - 损伤程度\n   - 代偿机制\n   - 临床表现产生\n\n3. 临床表现：患者主观感受和客观体征\n   - 症状：患者感觉到的不适\n   - 体征：医生检查发现的异常\n\n4. 预后：疾病的发展结果和恢复情况\n\n疾病的预防：\n- 一级预防：预防疾病发生（健康教育、环境改善）\n- 二级预防：早期发现、早期治疗\n- 三级预防：防止并发症、康复治疗\n\n了解具体疾病需咨询医学专业人士。"
}

func generate_drug_response(string text) string {
    return "药物治疗的重要原则：\n\n1. 用药基础：\n   - 明确诊断后选择合适的药物\n   - 根据病情严重程度调整用药方案\n   - 考虑患者年龄、肝肾功能、其他疾病\n\n2. 常见药物类别：\n   - 抗感染药：抗生素、抗病毒、抗真菌\n   - 心血管药：降压药、降脂药、强心药\n   - 神经系统药：镇静剂、止痛剂、抗癫痫\n   - 消化系统药：制酸剂、促动力药\n   - 激素类：糖皮质激素、甲状腺激素\n\n3. 合理用药原则：\n   - 准确的用法用量：按医嘱服用\n   - 疗程：完成足够的治疗疗程\n   - 时间间隔：按规定时间服用\n   - 食物相互作用：某些药物需空腹或饭后服用\n\n4. 不良反应和禁忌：\n   - 了解常见的不良反应\n   - 避免禁忌药物组合\n   - 过敏患者需特别注意\n\n5. 特殊人群用药：\n   - 肝肾功能不全者：需要减量\n   - 孕妇和哺乳期妇女：药物安全性更严格\n   - 老年患者：易发生药物相互作用\n   - 儿童：剂量需根据体重调整\n\n重要提醒：\n- 所有药物都应在医生或药师指导下使用\n- 不要自行改变用药方案\n- 报告任何不寻常的症状\n- 保存好用药记录"
}

func generate_infection_response(string text) string {
    string lower = to_lower(text)

    return "感染性疾病的医学知识：\n\n感染的基本概念：\n病原体成功入侵机体，克服防御机制，在组织内繁殖引起的病理过程。\n\n主要病原体类型：\n1. 细菌感染：\n   - 常见细菌：金黄色葡萄球菌、链球菌、大肠杆菌\n   - 感染部位：皮肤、呼吸道、泌尿道、血液\n   - 治疗：抗生素\n\n2. 病毒感染：\n   - 常见病毒：流感、COVID-19、疱疹病毒\n   - 症状：通常为自限性\n   - 治疗：主要是支持性治疗\n\n3. 真菌感染：\n   - 常见真菌：念珠菌、曲霉菌\n   - 易发人群：免疫低下者\n   - 治疗：抗真菌药\n\n4. 寄生虫感染：\n   - 常见寄生虫：蠕虫、原虫\n   - 治疗：相应的抗寄生虫药\n\n感染的进展阶段：\n1. 局部感染：局限于特定部位\n2. 全身感染/败血症：病原体进入血液，引起全身性炎症反应\n\n感染的临床表现：\n- 局部：红肿热痛\n- 全身：发热、寒战、头痛、肌肉酸痛\n\n预防感染：\n- 个人卫生：洗手、清洁伤口\n- 疫苗接种\n- 避免与感染者接触\n- 食品卫生和安全\n- 安全医疗操作\n\n抗感染原则：\n- 早期诊断和治疗\n- 选择合适的抗感染药物\n- 完成完整疗程\n- 监测治疗效果"
}

func generate_health_response(string text) string {
    return "健康维护的综合指南：\n\n健康是身体、心理和社会适应的完整状态，而不仅仅是没有疾病。\n\n健康的四大支柱：\n\n1. 营养饮食：\n   - 均衡饮食：蛋白质、碳水化合物、脂肪的合理比例\n   - 微量营养素：维生素和矿物质的充分摄入\n   - 食物多样性：不同颜色和来源的食物\n   - 限制有害物质：减少盐、糖、饱和脂肪摄入\n   - 水合状态：每日充分饮水\n\n2. 规律运动：\n   - 有氧运动：每周至少150分钟中等强度运动\n   - 力量训练：每周2-3次肌肉锻炼\n   - 柔韧性训练：改善活动范围\n   - 运动益处：\n     * 维持健康体重\n     * 改善心血管功能\n     * 增强肌肉和骨骼\n     * 改善心理健康\n     * 降低疾病风险\n\n3. 充足睡眠：\n   - 推荐睡眠：成人7-9小时\n   - 睡眠质量：规律作息时间\n   - 睡眠环境：舒适、黑暗、安静\n   - 睡眠卫生：避免咖啡因和屏幕刺激\n   - 睡眠的益处：\n     * 免疫功能恢复\n     * 认知功能改善\n     * 情绪调节\n     * 体重管理\n\n4. 心理健康：\n   - 压力管理：识别和处理压力源\n   - 社交联系：维持健康的人际关系\n   - 心理平衡：乐观心态、应对能力\n   - 寻求帮助：需要时接受心理咨询\n\n预防性检查：\n- 定期体检：根据年龄和风险因素制定计划\n- 疾病筛查：癌症、心脏病、糖尿病等\n- 生活方式评估：吸烟、饮酒等\n- 免疫接种：按推荐时间表接种\n\n特殊人群的健康维护：\n- 儿童：生长发育监测、营养需求\n- 孕妇：产前检查、营养、运动注意事项\n- 老年人：跌倒预防、慢病管理、认知健康\n- 慢性病患者：病情控制、并发症预防\n\n健康生活方式的长期效益：\n- 提高生活质量\n- 延长健康寿命\n- 减少医疗成本\n- 改善工作和学习表现\n\n记住：健康是一种生活方式的选择，而不是目标。需要持续的努力和承诺。"
}

func reason_medical_response(string prompt) string {
    if len(prompt) == 0 {
        return "请提供您的医学问题或症状。"
    }

    int category = detect_category(prompt)

    if category == CATEGORY_TREATMENT() {
        return generate_treatment_response(prompt)
    } else if category == CATEGORY_SYMPTOM() {
        return generate_symptom_response(prompt)
    } else if category == CATEGORY_DIAGNOSIS() {
        return generate_diagnosis_response(prompt)
    } else if category == CATEGORY_DISEASE() {
        return generate_disease_response(prompt)
    } else if category == CATEGORY_DRUG() {
        return generate_drug_response(prompt)
    } else if category == CATEGORY_INFECTION() {
        return generate_infection_response(prompt)
    } else if category == CATEGORY_HEALTH() {
        return generate_health_response(prompt)
    } else if category == CATEGORY_ANATOMY() {
        return "解剖学知识是医学的基础。人体由多个系统组成，包括：\n1. 骨骼系统：支撑和保护\n2. 肌肉系统：运动和力量\n3. 神经系统：信息处理和控制\n4. 循环系统：血液运输\n5. 呼吸系统：氧气交换\n6. 消化系统：营养吸收\n7. 泌尿系统：代谢废物清除\n8. 内分泌系统：激素调节\n9. 免疫系统：防御和保护\n10. 生殖系统：繁殖功能\n\n每个器官和系统都有特定的结构和功能。具体的解剖知识需要医学教科书或专家指导。"
    } else if category == CATEGORY_PATHOLOGY() {
        return "病理学是研究疾病的本质、原因和机制的学科。\n\n病理改变的层次：\n1. 分子水平：基因突变、蛋白质异常\n2. 细胞水平：细胞病变、凋亡、坏死\n3. 组织水平：炎症、纤维化、肿瘤\n4. 器官水平：功能障碍、结构破坏\n5. 整体水平：系统性表现\n\n基本病理过程：\n- 炎症反应：红肿热痛和全身反应\n- 修复和再生：组织愈合过程\n- 肿瘤发生：异常细胞增殖\n- 适应过程：代偿性改变\n\n深入了解病理变化需要病理检查和医学专业知识。"
    }

    return "感谢您的问题。这是一个有趣的医学话题。基于医学原理，您似乎在询问关于生物学、生理学或临床医学的问题。\n\n为了给您更准确的回答，我需要：\n1. 更具体的症状或问题描述\n2. 相关的背景信息\n3. 您想了解的具体方面\n\n如果您能提供更多细节，我可以提供更有针对性的医学解释。同时，对于具体的诊疗建议，建议咨询专业医疗人员。"
}

func main() {
    string test1 = "用c++写一个快速排序"
    string test2 = "糖尿病的治疗方法是什么"
    string test3 = "我头痛怎么办"
    string test4 = "心脏病有哪些症状"

    print("Medical Reasoning Engine Test\n")
    print("═════════════════════════════════════════\n\n")

    print("Test 1: \"" + test1 + "\"\n")
    string response1 = reason_medical_response(test1)
    print("Response:\n" + response1 + "\n\n")

    print("Test 2: \"" + test2 + "\"\n")
    string response2 = reason_medical_response(test2)
    print("Response:\n" + response2 + "\n\n")

    print("Test 3: \"" + test3 + "\"\n")
    string response3 = reason_medical_response(test3)
    print("Response:\n" + response3 + "\n\n")

    print("Test 4: \"" + test4 + "\"\n")
    string response4 = reason_medical_response(test4)
    print("Response:\n" + response4 + "\n\n")
}

