package neurx.inference.engine.medical_reasoning_engine
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
    for i < len(text) {
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
    for i <= text_len - substr_len {
        int j = 0
        for j < substr_len {
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
       contains_substr(lower, "Treatment") || contains_substr(lower, "疗法") {
        return CATEGORY_TREATMENT()
    }
    if contains_substr(lower, "symptom") || contains_substr(lower, "pain") ||
       contains_substr(lower, "fever") || contains_substr(lower, "sign") ||
       contains_substr(lower, "Symptoms") || contains_substr(lower, "疼痛") ||
       contains_substr(lower, "fever") || contains_substr(lower, "体征") {
        return CATEGORY_SYMPTOM()
    }
    if contains_substr(lower, "diagnos") || contains_substr(lower, "detect") ||
       contains_substr(lower, "identify") || contains_substr(lower, "test") ||
       contains_substr(lower, "Diagnosis") || contains_substr(lower, "check") {
        return CATEGORY_DIAGNOSIS()
    }
    if contains_substr(lower, "disease") || contains_substr(lower, "disorder") ||
       contains_substr(lower, "condition") || contains_substr(lower, "illness") ||
       contains_substr(lower, "Disease") || contains_substr(lower, "disease") {
        return CATEGORY_DISEASE()
    }
    if contains_substr(lower, "medicine") || contains_substr(lower, "drug") ||
       contains_substr(lower, "medication") || contains_substr(lower, "pharma") ||
       contains_substr(lower, "medicine") || contains_substr(lower, "medicine") {
        return CATEGORY_DRUG()
    }
    if contains_substr(lower, "infection") || contains_substr(lower, "infect") ||
       contains_substr(lower, "virus") || contains_substr(lower, "bacteria") ||
       contains_substr(lower, "infection") || contains_substr(lower, "disease原") {
        return CATEGORY_INFECTION()
    }
    if contains_substr(lower, "health") || contains_substr(lower, "wellness") ||
       contains_substr(lower, "preventive") || contains_substr(lower, "prevention") ||
       contains_substr(lower, "health") || contains_substr(lower, "保健") {
        return CATEGORY_HEALTH()
    }
    if contains_substr(lower, "anatomy") || contains_substr(lower, "organ") ||
       contains_substr(lower, "tissue") || contains_substr(lower, "bone") ||
       contains_substr(lower, "解剖") || contains_substr(lower, "器官") {
        return CATEGORY_ANATOMY()
    }
    if contains_substr(lower, "pathology") || contains_substr(lower, "patholog") ||
       contains_substr(lower, "lesion") || contains_substr(lower, "abnormal") ||
       contains_substr(lower, "diseasemanage") || contains_substr(lower, "disease变") {
        return CATEGORY_PATHOLOGY()
    }
    CATEGORY_UNKNOWN()
}
func generate_treatment_response(string text) string {
    string lower = to_lower(text)
    if contains_substr(lower, "diabetes") || contains_substr(lower, "diabetic") || contains_substr(lower, "diabetesdisease") {
        return "diabetesdiseaseofTreatment通常包括：\n1. 血糖控制（胰岛素or口服medicine）\n2. 饮食managementand运动\n3. set期监测血糖and血压\n4. Preventioncomplications（眼睛、肾脏、神经）\nRecommendationat内分泌专家指导down进doTreatment。"
    }
    if contains_substr(lower, "hypertension") || contains_substr(lower, "blood pressure") || contains_substr(lower, "hypertension") {
        return "hypertensionofTreatmentsolution：\n1. 生活method调整（low钠饮食、运动、减肥）\n2. antihypertensionmedicine（ACE抑制剂、利尿剂等）\n3. set期血压监测\n4. 心血管风险评估\nitemityizationTreatment需咨询心内科Doctor。"
    }
    if contains_substr(lower, "cancer") || contains_substr(lower, "tumor") || contains_substr(lower, "tumor") || contains_substr(lower, "cancer") {
        return "tumor/cancer症ofTreatment通常包括more学科solution：\n1. 手术切除（如适use）\n2. ization疗and靶towardsTreatment\n3. 放射Treatment\n4. 免疫Treatment\n5. supportityTreatmentand康复\n需attumormiddle心进do综合评估。"
    }
    if contains_substr(lower, "infection") || contains_substr(lower, "infect") || contains_substr(lower, "infection") {
        return "infectionofTreatment策略：\n1. disease原体鉴set（细菌、diseasetoxic、true菌等）\n2. 针pairityantiinfectionTreatment\n3. supportityTreatment（补液、营养support）\n4. 监测Treatment反应\n5. complicationsmanagement\nanti生素使use需按医嘱规范usemedicine。"
    }
    if contains_substr(lower, "asthma") || contains_substr(lower, "asthma") {
        return "asthmaofTreatment包括：\n1. long期控制ityusemedicine（吸入糖皮质激素）\n2. 急itydevelop作缓解（支气管扩张剂）\n3. Trigger factors识categoryand回避\n4. Lung功能监测\n5. Patient教育and自我management\n规thenusemedicinecan有效控制Symptoms。"
    }
    return "Treatmentsolutionof制setneed考虑moreitembecause素：\n1. brightsureDiagnosis：准sure识categoryDisease\n2. Condition评估：严重程度、complications、Patient情况\n3. Treatment选择：\n   - 保守Treatment：medicine、物manageTreatment、生活method改变\n   - 手术Treatment：适应症brightsure时\n   - 综合Treatment：more学科协作\n4. 预back评估：预期效果and风险\n5. 随访监测：调整Treatmentsolution\n\n最终ofTreatment决策应由Doctorbased onPatientspecific情况制set。"
}
func generate_symptom_response(string text) string {
    string lower = to_lower(text)
    if contains_substr(lower, "pain") || contains_substr(lower, "ache") || contains_substr(lower, "疼痛") {
        return "疼痛isoneitem复杂ofSymptoms，possible由moretypereason引起：\n\ncommonreason：\n1. 肌肉骨骼issue：拉伤、扭伤、关节inflammation\n2. 神经压迫：坐骨神经痛、脊椎issue\n3. inflammation症：infection、自免Disease\n4. 内脏Disease：Heart、Digestive system、Reproductive system issues\n5. other：tumor、代谢ityDisease\n\nAssessment focus：\n- Pain location、Nature and radiation\n- Frequency and duration of onset\n- Aggravating or relieving factors\n- 伴随Symptoms\n\nRecommendation：Medical consultation进doComprehensive assessment，Imaging examination when necessary。"
    }
    if contains_substr(lower, "fever") || contains_substr(lower, "temperature") || contains_substr(lower, "fever") || contains_substr(lower, "Fever") {
        return "feverSymptomsprocessing指南：\n\nCommon causes of fever：\n1. infectionityDisease：\n   - Bacterial infection（Pneumonia、Cystitis etc.）\n   - Viral infection（流感、COVID-19等）\n   - true菌orParasitic infection\n2. notinfectionreason：tumor、自免Disease、medicine反应\n\n危险信号（need立即Medical consultation）：\n- high热（>39.5°C）持续不退\n- 伴有dyspnea、胸痛\n- 意识改变or严重头痛\n- 皮肤出血点\n- 婴幼儿or老year人offever\n\none般processing：\n1. 物manage降温：温水擦浴\n2. 充分补液\n3. 适when休息\n4. 监测体温变ization\n\nfever>3天orSymptoms加重应Medical consultation。"
    }
    if contains_substr(lower, "cough") || contains_substr(lower, "cough") {
        return "coughSymptomsAnalysis：\n\ncommonreason：\n1. up呼吸道infection：感冒、喉inflammation\n2. down呼吸道infection：支气管inflammation、Pneumonia\n3. slowityDisease：asthma、COPD、Lung纤维ization\n4. other：胃食管反流、Heartdisease、medicinepair作use\n\ncoughclass型：\n- 干咳：无痰，common于Viral infection初期\n- 湿咳：有痰，promptinfectionor水肿\n- 阵咳：集middledevelop作\n\n警示信号：\n- 咳血\n- dyspnea\n- 胸痛\n- 持续>3周ofcough\n- 伴有high热、寒战\n\nRecommendation：cough持续>1周or恶ization应Medical consultationcheck。"
    }
    return "Symptoms评估need系统Analysis：\n\n重要信息：\n1. Symptoms特征：\n   - develop生时betweenand进展process\n   - Symptomsity质andlocation\n   - 严重程度andpair生活of影响\n\n2. 伴随Symptoms：systemicSymptoms、otherpartpositionSymptoms\n\n3. Aggravating or relieving factors：特set活动、饮食、location变ization\n\n4. 既往history：相关diseasehistory、手术、allergy\n\n5. 危险信号识category：\n   - 急itydevelop作of严重Symptoms\n   - 进doity恶ization\n   - 生命危险Symptoms\n\n专业评估包括：\n- 详细ofdiseasehistory采集\n- 体格check\n- 必要of实验室and影像学check\n\nRecommendation：Symptomsnewdevelopor加重时应及时Medical consultation评估。"
}
func generate_diagnosis_response(string text) string {
    string lower = to_lower(text)
    return "Diagnosisis医学实践middle最重要of步骤：\n\nDiagnosisprocess通常包括：\n1. diseasehistory采集（showdiseasehistory、既往history、家族history、生活history）\n2. 体格check（全面of临床check）\n3. 实验室check：\n   - Bloodcheck：血球计数、生ization指标\n   - 尿液check\n   - 特异ity标志物check\n4. 影像学check：\n   - X线成像\n   - 超声check\n   - CT/MRIcheck\n   - other专itemscheck\n5. specialcheck：\n   - 内镜check\n   - diseasemanage活检\n   - 功能学check\n\nDiagnosis思维：\n1. based onSymptomsand体征构建鉴categoryDiagnosisclear单\n2. 通passcheck逐步排除orsure认\n3. 综合Analysisall信息做出最possibleofDiagnosis\n4. 必要时追加checksure诊\n\n重要提醒：\n- 准sureDiagnosisis有效Treatmentoffoundation\n- 不同DiseaseofDiagnosis标准不同\n- 某someDiseaseneed专科DoctorDiagnosis\n- 遵循循证医学原then\n\nRecommendation：各classSymptomsand体征应由有资质of医疗专业人员进doDiagnosis。"
}
func generate_disease_response(string text) string {
    string lower = to_lower(text)
    if contains_substr(lower, "heart") || contains_substr(lower, "cardiac") || contains_substr(lower, "Heart") {
        return "Heartdiseaseof医学知识：\n\nHeartdiseaseclass型：\n1. 冠心disease：冠状动脉粥like硬ization\n   - tableshow：心绞痛、心肌梗死\n   - 危险because素：smoking、hypertension、high脂血症、diabetesdisease\n\n2. 心律不齐：Heart电传导异常\n   - commonclass型：房颤、室速、心动pass缓\n   - Symptoms：心悸、晕厥、乏力\n\n3. 心力衰竭：Heart泵血功能减退\n   - 分class：收缩期/舒张期、急ity/slowity\n   - Symptoms：dyspnea、浮肿、乏力\n\n4. 瓣膜disease：Heart瓣膜结构or功能异常\n\n危险信号：\n- 突然胸痛\n- 严重dyspnea\n- 晕厥\n- fast速无规律心跳\n\nPrevention：控制危险because素、Regular exercise、Healthy diet、Regular checkup。"
    }
    if contains_substr(lower, "lung") || contains_substr(lower, "respiratory") || contains_substr(lower, "Lung") {
        return "LungpartDisease概述：\n\ncommonLungpartDisease：\n1. Pneumonia：Lungpartinfection\n   - Symptoms：cough、fever、dyspnea\n   - 分class：Bacterial、Viral、Fungal、Inhalational\n\n2. slowity阻塞ityLungdisease（COPD）：\n   - Main cause：smoking、Occupational exposure\n   - Symptoms：Chronic cough、Shortness of breath、Wheezing\n\n3. asthma：Airway inflammation and reversible obstruction\n   - Symptoms：Wheezing、Chest tightness、dyspnea\n   - Trigger factors：Allergens、Cold air、运动\n\n4. Lung纤维ization：Lungbetween质纤维ization\n   - Symptoms：Progressive dyspnea、干咳\n\n5. Lungcancer：LungpartMalignant neoplasm\n   - 危险because素：smoking、Occupational exposure、Genetic factors\n\n保护Lungpart：\n- 戒烟is最有效ofPrevention措施\n- Avoid air pollution\n- Regular checkupand筛查\n- Prevent respiratory infection"
    }
    if contains_substr(lower, "liver") || contains_substr(lower, "hepatic") || contains_substr(lower, "Liver") {
        return "Liver脏Disease知识：\n\ncommonLiver脏Disease：\n1. ViralLiverinflammation：\n   - 甲型Liverinflammation：Fecal-oral transmission\n   - b型Liverinflammation：Blood/Body fluid transmission，Can become chronic\n   - 丙型Liverinflammation：主要通passBlood传播\n\n2. 脂肪Liver：Liver细胞脂肪堆积\n   - not酒精ity脂肪Liver：Metabolism related\n   - 酒精ity脂肪Liver：Caused by alcohol consumption\n\n3. Liver硬ization：Liver脏结构and功能of终末改变\n   - Common causes：bLiver、Alcohol abuse\n   - complications：Portal hypertension、Ascites、Esophageal varices\n\n4. Livercancer：原developityLiver细胞cancer\n   - High-risk population：Liver硬izationPatient、bLiverPatient\n\nSymptomsprompt：\n- Jaundice（Skin yellowing）\n- 腹痛and腹胀\n- 乏力and厌食\n- 尿色deep、big便shallow色\n\nPrevention措施：\n- bLiver疫苗接type\n- 戒酒\n- Healthy diet\n- set期Liver功能check"
    }
    return "Diseaseis人体atoneset条piecedownbecause各typediseasebecause引起of生manage功能and代谢异常，cause身体不适。\n\nDiseaseof基本要素：\n1. diseasebecause：causeDiseaseofreason\n   - 传染itydiseasebecause：disease原微生物\n   - not传染itydiseasebecause：遗传、代谢、environment、生活method\n\n2. developdiseasemechanism：Diseasedevelop展ofprocess\n   - 损伤程度\n   - 代偿mechanism\n   - 临床tableshow产生\n\n3. 临床tableshow：Patient主观感受and客观体征\n   - Symptoms：Patient感觉到of不适\n   - 体征：Doctorcheckdevelopshowof异常\n\n4. 预back：Diseaseofdevelop展结果and恢复情况\n\nDiseaseofPrevention：\n- one级Prevention：PreventionDiseasedevelop生（health教育、environment改善）\n- 二级Prevention：early期developshow、early期Treatment\n- 三级Prevention：防止complications、康复Treatment\n\ned解specificDisease需咨询医学专业人士。"
}
func generate_drug_response(string text) string {
    return "medicineTreatmentof重要原then：\n\n1. usemedicinefoundation：\n   - brightsureDiagnosisback选择合适ofmedicine\n   - based onCondition严重程度调整usemedicinesolution\n   - 考虑Patientyear龄、Liver肾功能、otherDisease\n\n2. commonmedicineclasscategory：\n   - antiinfectionmedicine：anti生素、antidiseasetoxic、antitrue菌\n   - 心血管medicine：降压medicine、降脂medicine、强心medicine\n   - 神经系统medicine：镇静剂、止痛剂、anti癫痫\n   - Digestive systemmedicine：制酸剂、促动力medicine\n   - 激素class：糖皮质激素、甲状腺激素\n\n3. 合manageusemedicine原then：\n   - 准sureofuse法use量：按医嘱服use\n   - 疗程：complete足够ofTreatment疗程\n   - 时betweenbetween隔：按规set时between服use\n   - 食物相互作use：某somemedicine需空腹or饭back服use\n\n4. 不良反应and禁忌：\n   - ed解commonof不良反应\n   - 避免禁忌medicine组合\n   - allergyPatient需特category注意\n\n5. special人groupusemedicine：\n   - Liver肾功能不全者：need减量\n   - 孕妇and哺乳期妇女：medicine安全ity更严格\n   - 老yearPatient：易develop生medicine相互作use\n   - 儿童：剂量需based on体重调整\n\n重要提醒：\n- allmedicine都应atDoctorormedicine师指导down使use\n- 不要自do改变usemedicinesolution\n- 报告任何不寻常ofSymptoms\n- 保存goodusemedicine记录"
}
func generate_infection_response(string text) string {
    string lower = to_lower(text)
    return "infectionityDiseaseof医学知识：\n\ninfectionof基本概念：\ndisease原体成功入侵机体，克服防御mechanism，at组织内繁殖引起ofdiseasemanageprocess。\n\n主要disease原体class型：\n1. Bacterial infection：\n   - common细菌：金黄色葡萄球菌、链球菌、big肠杆菌\n   - infectionpartposition：皮肤、呼吸道、泌尿道、Blood\n   - Treatment：anti生素\n\n2. Viral infection：\n   - commondiseasetoxic：流感、COVID-19、疱疹diseasetoxic\n   - Symptoms：通常为自限ity\n   - Treatment：主要issupportityTreatment\n\n3. Fungal infection：\n   - commontrue菌：念珠菌、曲霉菌\n   - 易develop人group：免疫lowdown者\n   - Treatment：antitrue菌medicine\n\n4. Parasitic infection：\n   - common寄生虫：蠕虫、原虫\n   - Treatment：相应ofanti寄生虫medicine\n\ninfectionof进展stage：\n1. 局partinfection：局限于特setpartposition\n2. systemicinfection/败血症：disease原体进入Blood，引起systemicityinflammation症反应\n\ninfectionof临床tableshow：\n- 局part：红肿热痛\n- systemic：fever、寒战、头痛、肌肉酸痛\n\nPreventioninfection：\n- item人卫生：洗手、clear洁伤口\n- 疫苗接type\n- 避免与infection者接触\n- 食品卫生and安全\n- 安全医疗操作\n\nantiinfection原then：\n- early期DiagnosisandTreatment\n- 选择合适ofantiinfectionmedicine\n- completecomplete疗程\n- 监测Treatment效果"
}
func generate_health_response(string text) string {
    return "health维护of综合指南：\n\nhealthis身体、心manageand社will适应ofcompletestatus，而不仅仅is没有Disease。\n\nhealthof四big支柱：\n\n1. 营养饮食：\n   - 均衡饮食：蛋white质、碳水ization合物、脂肪of合manageratio\n   - 微量营养素：维生素and矿物质of充分摄入\n   - 食物morelikeity：不同颜色and来源of食物\n   - 限制有害物质：减less盐、糖、饱and脂肪摄入\n   - 水合status：每日充分饮水\n\n2. 规律运动：\n   - 有氧运动：每周至less150分钟middle等强度运动\n   - 力量训练：每周2-3次肌肉锻炼\n   - 柔韧ity训练：改善活动范围\n   - 运动益处：\n     * 维持health体重\n     * 改善心血管功能\n     * 增强肌肉and骨骼\n     * 改善心managehealth\n     * 降lowDisease风险\n\n3. 充足睡眠：\n   - recommendation睡眠：成人7-9small时\n   - 睡眠质量：规律作息时between\n   - 睡眠environment：舒适、黑dark、安静\n   - 睡眠卫生：避免咖啡becauseand屏幕刺激\n   - 睡眠of益处：\n     * 免疫功能恢复\n     * 认知功能改善\n     * 情绪调节\n     * 体重management\n\n4. 心managehealth：\n   - 压力management：识categoryandprocessing压力源\n   - 社交联系：维持healthof人际关系\n   - 心manage平衡：乐观心态、应pair能力\n   - 寻求帮助：need时接受心manage咨询\n\nPreventionitycheck：\n- Regular checkup：based onyear龄and风险because素制set计划\n- Disease筛查：cancer症、Heartdisease、diabetesdisease等\n- 生活method评估：smoking、饮酒等\n- 免疫接type：按recommendation时betweentable接type\n\nspecial人groupofhealth维护：\n- 儿童：生longdevelop育监测、营养需求\n- 孕妇：产frontcheck、营养、运动注意事items\n- 老year人：跌倒Prevention、slowdiseasemanagement、认知health\n- slowitydiseasePatient：Condition控制、complicationsPrevention\n\nhealth生活methodoflong期效益：\n- 提high生活质量\n- 延longhealth寿命\n- 减less医疗cost\n- 改善工作and学习tableshow\n\n记住：healthisonetype生活methodof选择，而不istarget。need持续of努力and承诺。"
}
func reason_medical_response(string prompt) string {
    if len(prompt) == 0 {
        return "请提供您of医学issueorSymptoms。"
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
        return "解剖学知识is医学offoundation。人体由moreitem系统组成，包括：\n1. 骨骼系统：支撑and保护\n2. 肌肉系统：运动and力量\n3. 神经系统：信息processingand控制\n4. 循环系统：Blood运输\n5. 呼吸系统：氧气交换\n6. Digestive system：营养吸收\n7. 泌尿系统：代谢废物clear除\n8. 内分泌系统：激素调节\n9. 免疫系统：防御and保护\n10. 生殖系统：繁殖功能\n\n每item器官and系统都有特setof结构and功能。specificof解剖知识need医学教科书or专家指导。"
    } else if category == CATEGORY_PATHOLOGY() {
        return "diseasemanage学isresearchDiseaseof本质、reasonandmechanismof学科。\n\ndiseasemanage改变of层次：\n1. 分子水平：基because突变、蛋white质异常\n2. 细胞水平：细胞disease变、凋亡、bad死\n3. 组织水平：inflammation症、纤维ization、tumor\n4. 器官水平：功能障碍、结构破bad\n5. 整体水平：系统itytableshow\n\n基本diseasemanageprocess：\n- inflammation症反应：红肿热痛andsystemic反应\n- 修复andagain生：组织愈合process\n- tumordevelop生：异常细胞增殖\n- 适应process：代偿ity改变\n\ndeep入ed解diseasemanage变izationneeddiseasemanagecheckand医学专业知识。"
    }
    return "thank youofissue。thisisoneitem有趣of医学话题。基于医学原manage，您似乎at询问关于生物学、生manage学or临床医学ofissue。\n\n为ed给您更准sureof回答，我need：\n1. 更specificofSymptomsorissue描述\n2. 相关of背景信息\n3. 您想ed解ofspecific方面\n\n如果您能提供更more细节，我can提供更有针pairityof医学解释。同时，pair于specificof诊疗Recommendation，Recommendation咨询专业医疗人员。"
}
func main() {
    string test1 = "usec++写oneitemfast速排序"
    string test2 = "diabetesdiseaseofTreatmentmethodis什么"
    string test3 = "我头痛怎么办"
    string test4 = "Heartdisease有whichsomeSymptoms"
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
