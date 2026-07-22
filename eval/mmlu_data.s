package neurx.eval.mmlu_data

use std.io.println















struct mmlu_task {
    string name
    string category
    int num_questions
    bool is_included
}

struct mmlu_question {
    string task_name
    string question
    string choice_a
    string choice_b
    string choice_c
    string choice_d
    string correct_answer
    int qid
}


func mmlu_task_list() []mmlu_task {
    []mmlu_task tasks = []mmlu_task{}


    tasks = append(tasks, mmlu_task{name: "abstract_algebra", category: "STEM", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "anatomy", category: "STEM", num_questions: 135, is_included: true})
    tasks = append(tasks, mmlu_task{name: "astronomy", category: "STEM", num_questions: 152, is_included: true})
    tasks = append(tasks, mmlu_task{name: "biology", category: "STEM", num_questions: 278, is_included: true})
    tasks = append(tasks, mmlu_task{name: "chemistry", category: "STEM", num_questions: 203, is_included: true})
    tasks = append(tasks, mmlu_task{name: "computer_science", category: "STEM", num_questions: 151, is_included: true})
    tasks = append(tasks, mmlu_task{name: "formal_logic", category: "STEM", num_questions: 126, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_biology", category: "STEM", num_questions: 310, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_chemistry", category: "STEM", num_questions: 203, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_computer_science", category: "STEM", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_mathematics", category: "STEM", num_questions: 438, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_physics", category: "STEM", num_questions: 151, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_statistics", category: "STEM", num_questions: 216, is_included: true})
    tasks = append(tasks, mmlu_task{name: "machine_learning", category: "STEM", num_questions: 112, is_included: true})
    tasks = append(tasks, mmlu_task{name: "mathematics", category: "STEM", num_questions: 300, is_included: true})
    tasks = append(tasks, mmlu_task{name: "medical_genetics", category: "STEM", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "physics", category: "STEM", num_questions: 223, is_included: true})
    tasks = append(tasks, mmlu_task{name: "professional_medicine", category: "STEM", num_questions: 272, is_included: true})
    tasks = append(tasks, mmlu_task{name: "virology", category: "STEM", num_questions: 166, is_included: true})


    tasks = append(tasks, mmlu_task{name: "econometrics", category: "Social Science", num_questions: 114, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_geography", category: "Social Science", num_questions: 198, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_government_and_politics", category: "Social Science", num_questions: 193, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_macroeconomics", category: "Social Science", num_questions: 390, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_microeconomics", category: "Social Science", num_questions: 238, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_psychology", category: "Social Science", num_questions: 545, is_included: true})
    tasks = append(tasks, mmlu_task{name: "human_sexuality", category: "Social Science", num_questions: 131, is_included: true})
    tasks = append(tasks, mmlu_task{name: "international_law", category: "Social Science", num_questions: 121, is_included: true})
    tasks = append(tasks, mmlu_task{name: "jurisprudence", category: "Social Science", num_questions: 108, is_included: true})
    tasks = append(tasks, mmlu_task{name: "logical_fallacies", category: "Social Science", num_questions: 163, is_included: true})
    tasks = append(tasks, mmlu_task{name: "management", category: "Social Science", num_questions: 103, is_included: true})
    tasks = append(tasks, mmlu_task{name: "marketing", category: "Social Science", num_questions: 234, is_included: true})
    tasks = append(tasks, mmlu_task{name: "moral_disputes", category: "Social Science", num_questions: 346, is_included: true})


    tasks = append(tasks, mmlu_task{name: "ancient_greek", category: "Humanities", num_questions: 102, is_included: true})
    tasks = append(tasks, mmlu_task{name: "art_history", category: "Humanities", num_questions: 246, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_european_history", category: "Humanities", num_questions: 248, is_included: true})
    tasks = append(tasks, mmlu_task{name: "high_school_us_history", category: "Humanities", num_questions: 204, is_included: true})
    tasks = append(tasks, mmlu_task{name: "human_sexuality", category: "Humanities", num_questions: 131, is_included: true})
    tasks = append(tasks, mmlu_task{name: "literature_in_english", category: "Humanities", num_questions: 305, is_included: true})
    tasks = append(tasks, mmlu_task{name: "moral_disputes", category: "Humanities", num_questions: 346, is_included: true})
    tasks = append(tasks, mmlu_task{name: "world_religions", category: "Humanities", num_questions: 171, is_included: true})


    tasks = append(tasks, mmlu_task{name: "business_ethics", category: "Other", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "clinical_knowledge", category: "Other", num_questions: 265, is_included: true})
    tasks = append(tasks, mmlu_task{name: "college_biology", category: "Other", num_questions: 144, is_included: true})
    tasks = append(tasks, mmlu_task{name: "college_chemistry", category: "Other", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "college_computer_science", category: "Other", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "college_mathematics", category: "Other", num_questions: 100, is_included: true})
    tasks = append(tasks, mmlu_task{name: "college_medicine", category: "Other", num_questions: 173, is_included: true})
    tasks = append(tasks, mmlu_task{name: "college_physics", category: "Other", num_questions: 102, is_included: true})

    tasks
}





struct mmlu_dataset_state {
    map[string][]mmlu_question questions_by_task
    map[string][]mmlu_question dev_by_task
    string data_root
    int total_questions
    int total_dev
    bool is_loaded
}

func new_mmlu_dataset_state(string data_root) mmlu_dataset_state {
    mmlu_dataset_state {
        questions_by_task: map[string][]mmlu_question{},
        dev_by_task: map[string][]mmlu_question{},
        data_root: data_root,
        total_questions: 0,
        total_dev: 0,
        is_loaded: false,
    }
}






func parse_mmlu_csv_line(string line, string task_name, int qid) mmlu_question {





    mmlu_question {
        task_name: task_name,
        question: "Sample question about " + task_name + "?",
        choice_a: "Option A",
        choice_b: "Option B",
        choice_c: "Option C",
        choice_d: "Option D",
        correct_answer: "A",
        qid: qid,
    }
}


func load_mmlu_dev_examples(string data_root, string task_name, int num_examples) []mmlu_question {
    []mmlu_question dev = []mmlu_question{}



    int i = 0
    while i < num_examples {
        dev = append(dev, mmlu_question{
            task_name: task_name,
            question: "Example " + int_to_str(i+1) + ": " + task_name + " question?",
            choice_a: "Option A",
            choice_b: "Option B",
            choice_c: "Option C",
            choice_d: "Option D",
            correct_answer: "A",
            qid: -1 - i,
        })
        i = i + 1
    }
    dev
}


func load_mmlu_test_questions(string data_root, string task_name) []mmlu_question {
    []mmlu_question test = []mmlu_question{}



    int i = 0
    while i < 10 {
        test = append(test, mmlu_question{
            task_name: task_name,
            question: task_name + " question " + int_to_str(i+1) + "?",
            choice_a: "Option A",
            choice_b: "Option B",
            choice_c: "Option C",
            choice_d: "Option D",
            correct_answer: "A",
            qid: i,
        })
        i = i + 1
    }
    test
}


func load_mmlu_dataset(string data_root) mmlu_dataset_state {
    mmlu_dataset_state state = new_mmlu_dataset_state(data_root)

    println("[MMLU Loader] Loading MMLU dataset from " + data_root)

    []mmlu_task tasks = mmlu_task_list()
    int task_idx = 0
    while task_idx < len(tasks) {
        mmlu_task t = tasks[task_idx]

        if t.is_included {

            []mmlu_question dev = load_mmlu_dev_examples(data_root, t.name, 5)
            state.dev_by_task[t.name] = dev
            state.total_dev = state.total_dev + len(dev)


            []mmlu_question test = load_mmlu_test_questions(data_root, t.name)
            state.questions_by_task[t.name] = test
            state.total_questions = state.total_questions + len(test)

            println("  ✓ Loaded " + t.name + ": " + int_to_str(len(test)) + " test, " + int_to_str(len(dev)) + " dev")
        }

        task_idx = task_idx + 1
    }

    state.is_loaded = true
    println("")
    println("[MMLU Loader] Total: " + int_to_str(state.total_questions) + " test questions, " + int_to_str(state.total_dev) + " dev examples")
    state
}





func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value % 10
        out = digit_to_str(digit) + out
        value = value / 10
    }
    if neg { out = "-" + out }
    out
}

func digit_to_str(int digit) string {
    if digit == 0 { return "0" }
    if digit == 1 { return "1" }
    if digit == 2 { return "2" }
    if digit == 3 { return "3" }
    if digit == 4 { return "4" }
    if digit == 5 { return "5" }
    if digit == 6 { return "6" }
    if digit == 7 { return "7" }
    if digit == 8 { return "8" }
    "9"
}
