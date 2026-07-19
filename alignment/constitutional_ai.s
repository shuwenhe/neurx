package neurx.alignment.constitutional_ai

// ============================================================================
// Constitutional AI (CAI) — RLAIF self-critique & revision loop
//
// NeurX-style alignment technique. Instead of relying solely on human
// preference labels, the model critiques and revises its own responses against
// a set of written principles ("a constitution"), then learns from the
// (revised ≻ original) preference pairs (RLAIF — RL from AI Feedback).
//
// Pipeline:
//   1. Generate an initial response to a (potentially harmful) prompt.
//   2. Self-critique: ask the model to identify how the response violates a
//      principle.
//   3. Revise: ask the model to rewrite the response to comply.
//   4. Emit preference pair: revised (chosen) ≻ original (rejected).
//   5. These pairs train the reward model / DPO — no human labels required.
//
// This module operates on the concrete language_model via its generation API and
// produces preference pairs consumable by posttrain.reward.reward_model.
// ============================================================================

use neurx.model.llm.gpt.{
    model_config, language_model,
    gpt_generate_greedy, gpt_generate_topk
}

// ============================================================================
// 1. Constitution (principles)
// ============================================================================

struct constitutional_principle {
    string id
    string critique_request    // English textmodelcritiqueEnglish textprompt
    string revision_request    // English textmodelrevisionEnglish textprompt
    int severity               // 1-5, English textseverityweight
}

struct constitution {
    []constitutional_principle principles
    int num_principles
}

// NeurX English textprincipleEnglish text (helpful, harmless, honest)
func default_constitution() constitution {
    []constitutional_principle ps = []constitutional_principle{cap: 8}

    ps[0] = constitutional_principle {
        id: "harmlessness",
        critique_request: "English textharmful, English textcontent.",
        revision_request: "English text, English textharmfulcontent, English texthelpful.",
        severity: 5,
    }
    ps[1] = constitutional_principle {
        id: "honesty",
        critique_request: "English texttruthful, English text.",
        revision_request: "English text, English text, English textexplanation.",
        severity: 4,
    }
    ps[2] = constitutional_principle {
        id: "helpfulness",
        critique_request: "English text.",
        revision_request: "English text, English text, English text.",
        severity: 3,
    }
    ps[3] = constitutional_principle {
        id: "non_discrimination",
        critique_request: "English text, English textcontent.",
        revision_request: "English text, English text, English text, English text.",
        severity: 5,
    }
    ps[4] = constitutional_principle {
        id: "privacy",
        critique_request: "English textprivacyEnglish textprivacyEnglish textcontent.",
        revision_request: "English text, English textprivacy, English textinformation.",
        severity: 4,
    }
    ps[5] = constitutional_principle {
        id: "no_illegal_advice",
        critique_request: "English textillegalEnglish textcontent.",
        revision_request: "English text, English textillegalEnglish text.",
        severity: 5,
    }
    ps[6] = constitutional_principle {
        id: "child_safety",
        critique_request: "English textminorsafetyEnglish textcontent.",
        revision_request: "English text, English textminorEnglish text.",
        severity: 5,
    }
    ps[7] = constitutional_principle {
        id: "transparency",
        critique_request: "English text AI identityEnglish textcontent.",
        revision_request: "English text, English text AI identity.",
        severity: 2,
    }

    constitution { principles: ps, num_principles: 8 }
}

// ============================================================================
// 2. preferenceEnglish textoutput
// ============================================================================

// English text CAI generateEnglish textpreferenceEnglish text
struct cai_preference_pair {
    []int prompt_tokens        // English textprompt
    []int chosen_tokens        // revisionEnglish text (English text)
    []int rejected_tokens      // English text (English text)
    string principle_id        // English textrevisionEnglish textprinciple
    int severity
    float critique_strength    // critiqueEnglish text (0-1)
}

struct cai_batch {
    []cai_preference_pair pairs
    int num_pairs
    int num_revised            // actualEnglish textrevisionEnglish textcount
}

// ============================================================================
// 3. English text token (English texttruthfulsystemEnglish text tokenizer English text; English text ID)
// ============================================================================

// English text CAI English text"English text"English text token.English text token English text.
func cai_token_prompt_start() int { 50001 }
func cai_token_response_start() int { 50002 }
func cai_token_critique_start() int { 50003 }
func cai_token_revision_start() int { 50004 }
func cai_token_principle_base() int { 50100 }   // + principle index

// English text token English text
func cai_concat([]int a, []int b) []int {
    int n = len(a) + len(b)
    []int out = []int{cap: n}
    int i = 0
    while i < len(a) { out[i] = a[i]; i = i + 1 }
    int j = 0
    while j < len(b) { out[len(a) + j] = b[j]; j = j + 1 }
    out
}

func cai_single(int tok) []int {
    []int out = []int{cap: 1}
    out[0] = tok
    out
}

// ============================================================================
// 4. English text CAI English text: generate → critique → revision
// ============================================================================

// English textpromptEnglish textcomplete critique-revise English text
func cai_critique_revise(
    language_model model,
    []int prompt_tokens,
    constitutional_principle principle,
    int principle_index,
    int max_response_tokens,
    int seed
) cai_preference_pair {
    // 1. English text: prompt → response
    []int gen_input = cai_concat(prompt_tokens, cai_single(cai_token_response_start()))
    []int original_response = gpt_generate_topk(model, gen_input, max_response_tokens, 50, 0.8, seed)

    // 2. English textcritique: [prompt][response][critique_marker][principle] → critique
    []int critique_context = cai_concat(prompt_tokens, original_response)
    critique_context = cai_concat(critique_context, cai_single(cai_token_critique_start()))
    critique_context = cai_concat(critique_context, cai_single(cai_token_principle_base() + principle_index))
    []int critique = gpt_generate_topk(model, critique_context, max_response_tokens / 2, 40, 0.7, seed + 1)

    // 3. revision: [prompt][response][critique][revision_marker] → revised response
    []int revision_context = cai_concat(critique_context, critique)
    revision_context = cai_concat(revision_context, cai_single(cai_token_revision_start()))
    []int revised_response = gpt_generate_topk(model, revision_context, max_response_tokens, 50, 0.7, seed + 2)

    // 4. critiqueEnglish text: English textcritiqueEnglish text (English textcritiqueEnglish text)
    float critique_strength = cai_estimate_critique_strength(critique, max_response_tokens / 2)

    cai_preference_pair {
        prompt_tokens: prompt_tokens,
        chosen_tokens: revised_response,
        rejected_tokens: original_response,
        principle_id: principle.id,
        severity: principle.severity,
        critique_strength: critique_strength,
    }
}

// critiqueEnglish text (0=English text, 1=English text)
func cai_estimate_critique_strength([]int critique, int max_len) float {
    if max_len <= 0 {
        return 0.0
    }
    float ratio = (len(critique) * 1.0) / (max_len * 1.0)
    if ratio > 1.0 {
        ratio = 1.0
    }
    ratio
}

// ============================================================================
// 5. English text CAI: English textpromptgeneratepreferencedata
// ============================================================================

func cai_generate_preferences(
    language_model model,
    [][]int prompts,
    constitution consti,
    int max_response_tokens,
    int base_seed
) cai_batch {
    int n = len(prompts)
    []cai_preference_pair pairs = []cai_preference_pair{cap: n}
    int num_revised = 0

    int i = 0
    while i < n {
        // English textprinciple (English textcontentEnglish textprinciple)
        int pidx = i - (i / consti.num_principles) * consti.num_principles
        constitutional_principle principle = consti.principles[pidx]

        cai_preference_pair pair = cai_critique_revise(
            model,
            prompts[i],
            principle,
            pidx,
            max_response_tokens,
            base_seed + i * 7
        )
        pairs[i] = pair

        // English textcritiqueEnglish text, English text"English textrevision"
        if pair.critique_strength > 0.15 {
            num_revised = num_revised + 1
        }

        i = i + 1
    }

    cai_batch {
        pairs: pairs,
        num_pairs: n,
        num_revised: num_revised,
    }
}

// ============================================================================
// 6. English textrewardmodelEnglish textpreferencebatch
//
//   English text cai_preference_pair English text chosen/rejected English text token English text
//   (prompt + response, padding/truncate English text seq_len), English text reward_model training.
// ============================================================================

struct cai_flat_batch {
    []int chosen_ids           // [batch * seq_len]
    []int rejected_ids         // [batch * seq_len]
    int batch_size
    int seq_len
}

func cai_pad_sequence([]int prompt, []int response, int seq_len, int pad_id) []int {
    []int seq = []int{cap: seq_len}
    int idx = 0
    // prompt
    int i = 0
    while i < len(prompt) && idx < seq_len {
        seq[idx] = prompt[i]
        idx = idx + 1
        i = i + 1
    }
    // response
    int j = 0
    while j < len(response) && idx < seq_len {
        seq[idx] = response[j]
        idx = idx + 1
        j = j + 1
    }
    // padding
    while idx < seq_len {
        seq[idx] = pad_id
        idx = idx + 1
    }
    seq
}

func cai_to_flat_batch(cai_batch batch, int seq_len, int pad_id) cai_flat_batch {
    int n = batch.num_pairs
    []int chosen_ids = []int{cap: n * seq_len}
    []int rejected_ids = []int{cap: n * seq_len}

    int b = 0
    while b < n {
        cai_preference_pair pair = batch.pairs[b]
        []int chosen_seq = cai_pad_sequence(pair.prompt_tokens, pair.chosen_tokens, seq_len, pad_id)
        []int rejected_seq = cai_pad_sequence(pair.prompt_tokens, pair.rejected_tokens, seq_len, pad_id)

        int t = 0
        while t < seq_len {
            chosen_ids[b * seq_len + t] = chosen_seq[t]
            rejected_ids[b * seq_len + t] = rejected_seq[t]
            t = t + 1
        }
        b = b + 1
    }

    cai_flat_batch {
        chosen_ids: chosen_ids,
        rejected_ids: rejected_ids,
        batch_size: n,
        seq_len: seq_len,
    }
}

// ============================================================================
// 7. CAI statistics / English text
// ============================================================================

struct cai_stats {
    int total_prompts
    int revised_count
    float revision_rate
    float avg_critique_strength
    float weighted_severity      // English text severity English textcritiqueEnglish text
}

func cai_compute_stats(cai_batch batch) cai_stats {
    int n = batch.num_pairs
    if n == 0 {
        return cai_stats {
            total_prompts: 0,
            revised_count: 0,
            revision_rate: 0.0,
            avg_critique_strength: 0.0,
            weighted_severity: 0.0,
        }
    }

    float sum_strength = 0.0
    float sum_weighted = 0.0
    int i = 0
    while i < n {
        cai_preference_pair pair = batch.pairs[i]
        sum_strength = sum_strength + pair.critique_strength
        sum_weighted = sum_weighted + pair.critique_strength * (pair.severity * 1.0)
        i = i + 1
    }

    cai_stats {
        total_prompts: n,
        revised_count: batch.num_revised,
        revision_rate: (batch.num_revised * 1.0) / (n * 1.0),
        avg_critique_strength: sum_strength / (n * 1.0),
        weighted_severity: sum_weighted / (n * 1.0),
    }
}
