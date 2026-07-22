// ============================================================
// NEURX LONGWRITER - English text
// completeimplementation: English textgenerate + English textoutput + English text + English text
// support: English text / English text / English text / English text / English text English textgenerate
// English text: NEURX-4-LongWriter / LongFormaLLM / Plan-and-Write English text
// ============================================================

module longwriter_engine

// ==================== English textconfigurationEnglish text ====================

struct long_writer_config {
    // English textgenerateparameter
    max_total_tokens: int = 32000                 # English text token English text (supportEnglish textoutput)
    max_section_tokens: int = 4096                # English textsectionEnglish text token English text
    min_section_length: int = 200                 # English textsectionEnglish text (English text)
    target_word_count?: int                       # English text (English text, English textmodelgenerateEnglish text)

    // English text
    writing_mode: string = "outline_driven"       # outline_driven | continuous | iterative_refinement | plan_and_write
    outline_detail_level: string = "detailed"     # brief | detailed | very_detailed

    // English text
    quality_check_enabled: bool = true            # English text
    quality_model: string = "neurx-4-plus"          # English textmodel
    coherence_check: bool = true                  # sectionEnglish text
    consistency_check: bool = true               # English text (English text, English text)

    // English textoutput
    output_format: string = "markdown"            # markdown | html | docx | plain_text | json
    include_toc: bool = true                      # English textdirectory
    section_numbering: bool = true               # sectionEnglish text
    heading_style: string = "atx"                 # atx (#) or setext (===)

    // English textoptimize
    max_revision_rounds: int = 3                  # English textrevisionEnglish text
    revision_threshold: float = 0.7              # English textrevision
    auto_expand_sections: bool = true             # English textsection
    auto_merge_short_sections: bool = true        # English textsection

    // English textconfiguration (English text)
    domain?: string                               # academic | technical | creative | business | legal
    style_guide_path?: string                     # English textpath
    tone: string = "professional"                 # formal | casual | professional | academic | creative
    language: string = "zh-CN"                    # mainEnglish textlanguage

    // advancedEnglish text
    enable_citations: bool = false                # supportEnglish text
    enable_footnotes: bool = false               # English textsupport
    enable_cross_references: bool = false         # English text (English text, English text)
    template_id?: string                          # useEnglish text ID
}

struct outline_node {
    id: string                                     # English text ID (English text "1.2.3")
    title: string                                  # sectiontitle
    level: int                                     # English text (1=H1, 2=H2, ...)
    description?: string                           # English textDescription/English textprompt
    estimated_words?: int                          # English text
    keywords?: list<string>                        # keywords/mainEnglish text
    must_include?: list<string>                   # English textcontentEnglish text
    children: list<outline_node>                    # English text (English textsection)

    // generateEnglish text
    content?: string                               # generateEnglish textcontent
    word_count?: int                               # actualEnglish text
    quality_score?: float                          # English text
    status: SectionStatus = SectionStatus.PENDING  # English textstate
    revisions: int = 0                             # English textrevisionEnglish text
}

enum SectionStatus {
    PENDING                                       # English textgenerate
    GENERATING                                     # English textgenerate
    COMPLETED                                      # English text
    REVISION_NEEDED                                # Requiredrevision
    REVISED                                        # English textrevision
}

struct writing_plan {
    topic: string                                  # English textmainEnglish text/title
    outline: outline_node                           # English text
    total_estimated_words: int                     # English text
    sections_count: int                            # English textsectionEnglish text
    max_depth: int                                 # English text
    metadata: plan_metadata                         # English textdata
    constraints: writing_constraints?              # English text
}

struct plan_metadata {
    created_at: float                              # English texttime
    model_used: string                             # useEnglish textmodel
    planning_time_ms: float                        # English text
    version: int = 1                               # English text (English textrevisionEnglish text)
}

struct writing_constraints {
    min_total_words: int?                          # English text
    max_total_words: int?                          # English text
    forbidden_topics: list<string>?               # English textmainEnglish text
    required_sections: list<string>?              # English textsectionName
    style_requirements: list<string>?             # English text (English text"useEnglish text", "English text")
    audience_level: string = "general"            # beginner | intermediate | expert
}

struct long_document {
    title: string
    plan: writing_plan
    sections: list<outline_node>                    # English textsectionEnglish text (English text)
    full_text: string                              # completeEnglish text
    toc: table_of_contents?                         # directoryEnglish text
    statistics: document_statistics                 # statisticsinformation
    generation_metadata: generation_metadata        # generateEnglish textdata
}

struct table_of_contents {
    entries: list<toc_entry>                       # directoryEnglish text
    format: string                                 # English text
}

struct toc_entry {
    level: int
    number: string                                 # English text "1.2.3"
    title: string
    page_ref?: string                              # English text
    word_count?: int
}

struct document_statistics {
    total_words: int
    total_characters: int
    total_sections: int
    avg_section_words: float
    min_section_words: int
    max_section_words: int
    reading_time_minutes: float
    generation_time_seconds: float
    revision_count: int
    quality_scores: map<string, float>             # English text
}

struct generation_metadata {
    model_name: string
    total_tokens_generated: int
    total_prompt_tokens: int
    generation_time_seconds: float
    sections_revised: int
    quality_checks_passed: int
    quality_checks_failed: int
    api_calls_made: int
    errors_encountered: int
}

// ==================== English text ====================

class OutlinePlanner {
    config: long_writer_config
    llm_client: any

    init(config: long_writer_config, llm_client: any) {
        this.config = config
        this.llm_client = llm_client
    }

    async create_plan(topic: string, requirements?: string, existing_outline?: outline_node) {
        start_time = current_time_millis()

        print(f"📋 Creating outline for: {topic}")

        # Build planning prompt
        prompt = this._build_planning_prompt(topic, requirements, existing_outline)

        # Generate structured outline using LLM with JSON mode if available
        response = await this.llm_client.generate(
            prompt,
            temperature=0.7,           # Moderate creativity for diverse outlines
            max_tokens=4096,
            response_format="json_object" if supports_json_mode else null
        )

        # Parse the outline structure from LLM response
        root_node = this._parse_outline(response.text, topic)

        # Calculate statistics
        flat_sections = flatten_outline(root_node)
        total_words = estimate_total_words(root_node)

        plan = writing_plan{
            topic=topic,
            outline=root_node,
            total_estimated_words=total_words,
            sections_count=len(flat_sections),
            max_depth=get_max_depth(root_node),
            metadata=plan_metadata{
                created_at=current_timestamp(),
                model_used=this.config.quality_model,
                planning_time_ms=current_time_millis() - start_time
            }
        }

        print(f"   ✓ Outline created: {len(flat_sections)} sections, ~{total_words} words estimated")

        return plan
    }

    _build_planning_prompt(topic: string, requirements?: string, existing_outline?: outline_node) {
        detail_instructions = match this.config.outline_detail_level {
            "brief" => """
Provide a high-level outline with main sections only (2-3 levels deep).
Each section should have a clear title and a brief 1-sentence description of its purpose.
"""
            "detailed" => """
Create a comprehensive outline that is 3-4 levels deep.
Each section needs:
- A descriptive title
- A detailed paragraph describing what this section should cover
- Key points or subtopics to address
- Estimated word count for each major section
"""
            "very_detailed" => """
Create an extremely detailed outline going 4+ levels deep where appropriate.
Each section must include:
- Clear hierarchical numbering (1, 1.1, 1.1.1, etc.)
- Descriptive title
- Comprehensive description (2-3 paragraphs) explaining:
  * The scope and boundaries of this section
  * Key arguments, data, or examples to include
  * How it connects to adjacent sections
- Bullet-point list of MUST-COVER topics
- Suggested transitions to next/previous sections
- Word count estimates at each level
"""
            _ => ""
        }

        domain_instruction = ""
        if this.config.domain != None {
            domain_instruction = f"""
This document is in the {this.config.domain} domain.
Ensure the outline follows conventions and standards appropriate for {this.config.domain} writing.
"""
        }

        constraint_instruction = ""
        if this.config.target_word_count != None {
            constraint_instruction += f"\nTarget total length: approximately {this.config.target_word_count} words.\n"
        }
        constraint_instruction += f"\nTone: {this.config.tone}\n"
        constraint_instruction += f"Language: {this.config.language}\n"

        existing_context = ""
        if existing_outline != None:
            existing_context = f"""

The following is an existing outline that should be EXPANDED and IMPROVED upon:
{serialize_outline_to_text(existing_outline)}

Please expand it with more detail while preserving the overall structure.
"""

        return f"""You are an expert outline planner for long-form content creation.

TASK: Create a comprehensive, well-structured writing outline for the following topic:

**Topic**: {topic}
{f'**Requirements/Special Instructions**: {requirements}' if requirements != None else ''}

{domain_instruction}{constraint_instruction}{existing_context}
## Output Format Requirements

{detail_instructions}

Respond with a valid JSON object representing the outline tree structure. Use this schema:
{{
  "title": "Main Title",
  "sections": [{{
    "id": "1",
    "title": "Section Title",
    "level": 1,
    "description": "Detailed description...",
    "estimated_words": 500,
    "keywords": ["key", "terms"],
    "must_include": ["point 1", "point 2"],
    "children": [...subsections...]
  }}]
}}

IMPORTANT:
- Ensure logical flow between sections
- Balance depth and breadth appropriately
- Make sure the outline covers the topic comprehensively
- Include both introduction and conclusion sections
- Consider the reader's knowledge level: {this.config.constraints?.audience_level ?? "general"}

Now create the outline:"""
    }

    _parse_outline(llm_response_text: string, topic: string) {
        # Extract JSON from response (handle potential markdown code blocks)
        json_str = extract_json_from_text(llm_response_text)

        try {
            data = json_parse(json_str)
            return parse_outline_data(data, topic)
        } catch Exception as e:
            print(f"Warning: Failed to parse outline JSON, falling back to text parsing: {e.message}")
            return this._fallback_parse_outline(llm_response_text, topic)
    }

    _fallback_parse_outline(text: string, topic: string) {
        # Parse text-based outline (markdown-style headings)
        lines = text.split("\n")
        root = outline_node{
            id="root",
            title=topic,
            level=0,
            children=[],
            status=SectionStatus.COMPLETED  # Root is always done
        }

        node_stack: list<tuple<outline_node, int>> = [(root, 0)]

        for line in lines:
            stripped = line.strip()

            # Detect heading pattern (# ## ### etc.) or numbered (1., 1.1, etc.)
            heading_match = regex.match(r'^(#{1,6})\s+(.+)$', stripped)
            num_match = regex.match(r'^(\d+(?:\.\d+)*)\.\s*(.+)$', stripped)

            current_depth = len(node_stack) - 1

            if heading_match != None:
                level = len(heading_match.group(1))
                title = heading_match.group(2).trim()

            elif num_match != None:
                level = num_match.group(1).count(".") + 1
                title = num_match.group(2).trim()

            else:
                continue

            # Pop stack until we find correct parent
            while node_stack.length > 1 && node_stack[-1][1] >= level:
                node_stack.pop()

            parent, _ = node_stack[-1]

            new_node = outline_node{
                id=f"{parent.id}.{len(parent.children) + 1}" if parent.id != "root" else str(len(parent.children) + 1),
                title=title,
                level=level,
                children=[],
                status=SectionStatus.PENDING
            }

            parent.children.append(new_node)
            node_stack.append((new_node, level))

        return root
    }
}

// ==================== contentgenerateEnglish text ====================

class ContentGenerator {
    config: long_writer_config
    llm_client: any
    quality_checker: QualityChecker?

    init(config: long_writer_config, llm_client: any) {
        this.config = config
        this.llm_client = llm_client

        if config.quality_check_enabled:
            this.quality_checker = new QualityChecker(config=config, llm_client=llm_client)
    }

    async generate_section(section: outline_node, context: generation_context) {
        start_time = current_time_millis()

        print(f"✍️ Generating: {section.title} ({section.id})")

        # Build context-aware prompt
        prompt = this._build_generation_prompt(section, context)

        # Generate content
        response = await this.llm_client.generate(
            prompt,
            temperature=this._get_temperature_for_section(section),
            max_tokens=min(this.config.max_section_tokens, get_token_limit() - context.tokens_used_so_far),
            stop_sequences=["\n\n# ", "\n\n## ", "\n### "]  # Stop at next heading
        )

        raw_content = response.text.strip()

        # Post-process content
        processed = this._post_process(raw_content, section)

        # Update section
        section.content = processed.text
        section.word_count = count_words(processed.text)
        section.status = SectionStatus.COMPLETED

        elapsed = current_time_millis() - start_time

        generated = generated_section{
            section=section,
            raw_text=raw_content,
            processed_text=processed.text,
            formatting_applied=processed.formatting_changes,
            generation_time_ms=elapsed,
            tokens_used=response.usage.completion_tokens
        }

        # Quality check (if enabled)
        if this.quality_checker != None {
            quality_result = await this.quality_checker!.check(generated, context)
            generated.quality_score = quality_result.overall_score
            generated.quality_feedback = quality_result.feedback

            if quality_result.needs_revision && section.revisions < this.config.max_revision_rounds:
                generated.revision_suggested = True
                section.status = SectionStatus.REVISION_NEEDED

        print(f"   ✓ {section.id}: {section.word_count} words ({elapsed:.0f}ms, score: {generated.quality_score ?? 'N/A'})")

        return generated
    }

    _build_generation_prompt(section: outline_node, context: generation_context) {
        # Get previous and next sibling sections for continuity
        prev_context = get_previous_sibling_content(context.full_outline, section.id)
        next_hint = get_next_sibling_title(context.full_outline, section.id)

        parent_context = get_parent_description(context.full_outline, section.id)

        # Build system instructions based on config
        style_instruction = f"""
Writing Style:
- Tone: {this.config.tone}
- Language: {this.config.language}
- Format: {this.config.output_format} (use {'#' * section.level} headings)
"""

        length_instruction = ""
        if section.estimated_words != None {
            length_instruction = f"\nTarget length for this section: approximately {section.estimated_words} words."
        } elif this.config.target_word_count != None:
            # Proportionally assign word budget
            proportion_estimate = int(this.config.target_word_count! / context.total_sections)
            length_instruction = f"\nAim for approximately {proportion_estimate}-{int(proportion_estimate * 1.5)} words."

        constraints = ""
        if this.config.constraints != None {
            c = this.config.constraints!
            if c.style_requirements != None && c.style_requirements!.length > 0:
                constraints = "\nStyle requirements:\n" + "- " + "\n- ".join(c.style_requirements!) + "\n"
            if c.forbidden_topics != None && c.forbidden_topics!.length > 0:
                constraints += f"\nAvoid discussing: {', '.join(c.forbidden_topics!)}\n"

        citation_instruction = ""
        if this.config.enable_citations:
            citation_instruction = """

Citation Guidelines (when referencing facts, data, or sources):
- Use inline citations like [source_key] or [Author, Year]
- For statistics, cite the original source
- If uncertain about a fact, indicate it as approximate or use cautious language
"""

        return f"""You are an expert writer creating a specific section of a longer document.

## Your task
Write section **{section.id}: {section.title}**

## Context
**Overall document Topic**: {context.document_topic}
**Current Position**: This is section {get_section_position(context.full_outline, section.id)} of {context.total_sections} total sections.

**Parent Section**: {parent_context}
{"**Previous Section Summary**:\n" + prev_context if prev_context != None else ""}
{"**Upcoming Next**: " + next_hint if next_hint != None else ""}

## Section Requirements
{f'Description:\n{section.description}\n' if section.description != None else ''}{f'Key Points to Cover:\n- ' + '\n- '.join(section.must_include!) + '\n' if section.must_include != None && section.must_include!.length > 0 else ''}
{f'Relevant Keywords/Topics: ' + ', '.join(section.keywords!) if section.keywords != None && section.keywords!.length > 0 else ''}

{style_instruction}
{length_instruction}
{constraints}
{citation_instruction}

## Important Instructions

1. Write ONLY the content for this section. Do NOT include the section title as a heading (it will be added automatically).
2. Maintain consistency with previous sections in terminology, tone, and style.
3. Ensure smooth transitions - the last paragraph should naturally lead into what comes next.
4. Use appropriate depth for this level ({'high-level overview' if section.level <= 2 else 'detailed discussion'}).
5. If this section has subsections, write comprehensive content covering them all.

Now write the content for "{section.title}":
"""
    }

    _get_temperature_for_section(section: outline_node) {
        # Adjust creativity based on section type
        lower_title = section.title.to_lower()

        if any(term in lower_title for term in ["conclusion", "summary", "abstract"]):
            return 0.3  # Low temperature for conclusions
        elif any(term in lower_title for term in ["introduction", "background", "overview"]):
            return 0.5  # Medium-low for intros
        elif any(term in lower_title for term in ["creative", "story", "example", "case study"]):
            return 0.9  # High for creative parts
        else:
            return 0.7  # Default moderate creativity
    }

    _post_process(raw_text: string, section: outline_node) {
        changes: list<string> = []
        processed = raw_text

        # Remove leading heading markers if model included them despite instructions
        heading_pattern = regex.match(r'^#{1,6}\s+.+\n*', processed)
        if heading_pattern != None:
            processed = processed[heading_pattern.end():].lstrip("\n")
            changes.append("Removed leading heading marker")

        # Normalize whitespace
        processed = normalize_whitespace(processed)
        changes.append("Normalized whitespace")

        # Ensure proper paragraph breaks
        processed = ensure_paragraph_breaks(processed)
        changes.append("Ensured proper paragraph breaks")

        return post_process_result{text=processed, formatting_changes=changes}
    }
}

struct generation_context {
    document_topic: string
    full_outline: outline_node
    total_sections: int
    tokens_used_so_far: int
    completed_sections: list<string>  # IDs of already-completed sections
    global_constraints: map<string, string>  # Key facts/terms established in earlier sections
}

struct generated_section {
    section: outline_node
    raw_text: string
    processed_text: string
    formatting_changes: list<string>
    generation_time_ms: float
    tokens_used: int
    quality_score?: float
    quality_feedback?: string
    revision_suggested: bool = false
}

struct post_process_result {
    text: string
    formatting_changes: list<string>
}

// ==================== English text ====================

class QualityChecker {
    config: long_writer_config
    llm_client: any

    init(config: long_writer_config, llm_client: any) {
        this.config = config
        this.llm_client = llm_client
    }

    async check(generated: generated_section, context: generation_context) {
        prompt = f"""You are a strict editor evaluating the quality of a written document section.

## Section to Evaluate
**Title**: {generated.section.title} (Level {generated.section.level})
**Content**:
{generated.processed_text[:3000]}  # Truncate for evaluation context window

## Evaluation Criteria (score 0.0 - 1.0 for each):

1. **Completeness** (weight 25%):
   - Does it cover all expected topics for this section?
   - Is there sufficient detail and depth?
   - Are important aspects missing?

2. **Clarity & Readability** (weight 20%):
   - Is the writing clear and easy to understand?
   - Are sentences well-structured?
   - Is jargon used appropriately (defined if needed)?

3. **Coherence** (weight 20%):
   - Does it flow logically within itself?
   - Are ideas well-connected?
   - Is there a clear progression of thought?

4. **Relevance & Focus** (weighted 15%):
   - Does it stay on-topic?
   - Is all content relevant to the section's purpose?
   - Is there unnecessary repetition or digression?

5. **Style Consistency** (weighted 10%):
   - Does it match the expected tone ({this.config.tone})?
   - Is language consistent throughout?
   - Are formatting conventions followed correctly?

6. **Length Appropriateness** (weighted 10%):
   - Is the length suitable for the section's importance?
   - Neither too short (superficial) nor too long (verbose)?

## Response Format (JSON):
{{
  "scores": {{
    "completeness": <float 0-1>,
    "clarity": <float 0-1>,
    "coherence": <float 0-1>,
    "relevance": <float 0-1>,
    "style": <float 0-1>,
    "length": <float 0-1>
  }},
  "overall_score": <weighted average>,
  "needs_revision": <bool>,
  "strengths": [<list of strings>],
  "weaknesses": [<list of strings>],
  "specific_improvements": [<actionable suggestions>]
}}"""

        response = await this.llm_client.generate(
            prompt,
            temperature=0.1,  # Low temp for consistent evaluation
            max_tokens=1000,
            response_format="json_object"
        )

        result = parse_quality_response(response.text)

        return result
    }

    async check_coherence_between_sections(prev: generated_section?, curr: generated_section, next_preview?: string) {
        # Check transition quality between consecutive sections

        prev_summary = summarize_section(prev.processed_text, max_words=50) if prev != None else "[START OF DOCUMENT]"
        curr_intro = extract_first_paragraph(curr.processed_text)
        next_expectation = next_preview ?: "[END]"

        prompt = f"""Evaluate the transition quality between these two consecutive document sections:

**Previous Section** ({prev?.section.title ?? 'Introduction'}):
Summary: {prev_summary}

**Current Section** ({curr.section.title}):
First ~100 words: {curr_intro}

**Next Section Preview**: {next_expectation}

Evaluate:
1. Does the current section begin smoothly after the previous one? (yes/partially/no)
2. Is there a clear transitional phrase or concept linking them?
3. Does the ending of the current section set up what comes next?
4. Any suggestions for improving the flow?

Respond briefly in 3-4 sentences."""

        response = await this.llm_client.generate(prompt, temperature=0.3, max_tokens=200)

        return coherence_check_result{
            feedback=response.text,
            smooth_transition="yes" in response.text.to_lower(),
            has_bridge_phrase="transition" in response.text.to_lower() or "connect" in response.text.to_lower()
        }
    }
}

struct quality_check_result {
    scores: map<string, float>
    overall_score: float
    needs_revision: bool
    strengths: list<string>
    weaknesses: list<string>
    specific_improvements: list<string>
    feedback: string  # Human-readable summary
}

struct coherence_check_result {
    feedback: string
    smooth_transition: bool
    has_bridge_phrase: bool
}

// ==================== Long Writer mainsystem ====================

class LongWriterEngine {
    config: long_writer_config
    llm_client: any
    planner: OutlinePlanner
    generator: ContentGenerator
    documents_history: list<long_document>

    init(config: long_writer_config, llm_client: any) {
        this.config = config
        this.llm_client = llm_client
        this.planner = new OutlinePlanner(config=config, llm_client=llm_client)
        this.generator = new ContentGenerator(config=config, llm_client=llm_client)
        this.documents_history = []
    }

    async write_document(topic: string, requirements?: string) {
        total_start = current_time_millis()
        api_calls = 0
        errors = []

        print(f"\n{'='*60}")
        print(f"📝 NEURX LONGWRITER Engine")
        print(f"Topic: {topic}")
        print(f"Mode: {config.writing_mode}")
        print(f"{'='*60}\n")

        # Phase 1: Planning
        print("--- PHASE 1: OUTLINE PLANNING ---\n")
        plan = await this.planner.create_plan(topic, requirements)
        api_calls += 1

        # Display outline summary
        display_outline(plan.outline)

        # Phase 2: Sequential Content Generation
        print(f"\n--- PHASE 2: CONTENT GENERATION ---\n")

        flat_sections = flatten_outline(plan.outline).filter(s => s.level > 0)  # Exclude root
        generated_sections: list<generated_section> = []
        tokens_used = 0
        revised_count = 0
        quality_passes = 0
        quality_fails = 0

        global_constraints: map<string, string> = {}

        for i, section in enumerate(flat_sections) {
            context = generation_context{
                document_topic=topic,
                full_outline=plan.outline,
                total_sections=len(flat_sections),
                tokens_used_so_far=tokens_used,
                completed_sections=[s.id for s in generated_sections],
                global_constraints=global_constraints
            }

            # Retry logic for failed generations
            max_attempts = 3
            last_error = null

            for attempt in range(max_attempts) {
                try {
                    result = await this.generator.generate_section(section, context)

                    # Extract key terms/constraints for future sections
                    key_terms = extract_key_terms(result.processed_text)
                    for term in key_terms:
                        if term not in global_constraints:
                            global_constraints[term] = result.section.title

                    generated_sections.append(result)
                    tokens_used += result.tokens_used
                    api_calls += 1

                    if result.quality_score != null {
                        if result.quality_score! >= this.config.revision_threshold:
                            quality_passes += 1
                        else:
                            quality_fails += 1

                    if result.revision_suggested && section.revisions < this.config.max_revision_rounds:
                        revised_count += 1

                    break  # Success, exit retry loop

                } catch Exception as e:
                    last_error = e
                    errors.append(str(e))
                    if attempt < max_attempts - 1:
                        print(f"   ⚠️ Attempt {attempt + 1} failed, retrying...")
                        await sleep(1)  # Brief delay before retry

            if last_error != null and (generated_sections.length == 0 or generated_sections[-1].section.id != section.id):
                print(f"   ❌ Failed to generate section {section.id} after {max_attempts} attempts")
                section.content = f"[Error: Unable to generate this section. {last_error.message}]"
                section.status = SectionStatus.REVISION_NEEDED

        # Phase 3: Post-processing & Assembly
        print(f"\n--- PHASE 3: POST-PROCESSING ---\n")

        # Assemble full document
        full_text = assemble_full_text(generated_sections, this.config)

        # Generate table of contents
        toc = generate_toc(generated_sections, this.config)

        # Add TOC to beginning if configured
        if this.config.include_toc:
            toc_markdown = format_toc_as_markdown(toc)
            full_text = "# " + topic + "\n\n" + toc_markdown + "\n\n" + full_text

        # Compute statistics
        stats = compute_long_doc_statistics(generated_sections, full_text, total_start)

        doc = long_document{
            title=topic,
            plan=plan,
            sections=flatten_outline(plan.outline).filter(s => s.level > 0),
            full_text=full_text,
            toc=toc,
            statistics=stats,
            generation_metadata=generation_metadata{
                model_name=this.config.quality_model,
                total_tokens_generated=tokens_used,
                total_prompt_tokens=sum(s.tokens_used for s in generated_sections),  # Approximation
                generation_time_seconds=(current_time_millis() - total_start) / 1000.0,
                sections_revised=revised_count,
                quality_checks_passed=quality_passes,
                quality_checks_failed=quality_fails,
                api_calls_made=api_calls,
                errors_encountered=len(errors)
            }
        }

        this.documents_history.append(doc)

        # Print summary
        print_generation_summary(doc)

        return doc
    }

    async revise_section(document: long_document, section_id: string, feedback?: string) {
        """Revise a specific section of an existing document."""
        section_to_revise = find_section_by_id(document.plan.outline, section_id)

        if section_to_revise == None:
            raise error(f"Section {section_id} not found in document")

        if section_to_revise.revisions >= this.config.max_revision_rounds:
            raise error(f"Maximum revision rounds ({this.config.max_revision_rounds}) reached for section {section_id}")

        print(f"🔄 Revising section: {section_id} - {section_to_revise.title}")

        # Get surrounding context
        context = build_revision_context(document, section_to_revise, feedback)

        # Regenerate
        old_generated = find_generated_for_section(document.sections, section_id)
        new_result = await this.generator.generate_section(section_to_revise, context)

        # Update document
        update_section_in_document(document, section_to_revise, new_result)

        # Reassemble
        document.full_text = reassemble_document(document)
        document.generation_metadata.sections_revised += 1

        return document
    }

    export(document: long_document, output_format?: string, file_path?: string) {
        fmt = output_format ?? this.config.output_format

        match fmt {
            "markdown" => { return document.full_text }
            "html" => { return convert_markdown_to_html(document.full_text) }
            "json" => { return serialize_document_to_json(document) }
            "plain_text" => { return strip_markdown(document.full_text) }
            "docx" => { return export_to_docx(document, file_path) }
            _ => throw error(f"Unsupported export format: {fmt}")
        }
    }
}

// ==================== helperfunction ====================

function flatten_outline(root: outline_node) {
    result: list<outline_node> = []

    def traverse(node: outline_node) {
        if node.id != "root" or node.children.empty():  # Include root only if no children
            result.append(node)
        for child in node.children:
            traverse(child)
    }

    traverse(root)
    return result
}

function get_max_depth(root: outline_node) {
    if root.children.empty():
        return root.level
    return max(get_max_depth(c) for c in root.children)

function estimate_total_words(root: outline_node) {
    if root.estimated_words != None:
        base = root.estimated_words!
    else:
        base = 200 * (root.level + 1)  # Rough heuristic

    child_sum = sum(estimate_total_words(c) for c in root.children)
    return base + child_sum

function display_outline(root: outline_node, indent: int = 0) {
    prefix = "  " * indent
    icon = match root.level {
        0 => "📚"
        1 => "📑"
        2 => "📄"
        3 => "📝"
        _ => "•"
    }

    info_parts: list<string> = [f"{icon} {root.title}"]
    if root.estimated_words != None:
        info_parts.append(f"(~{root.estimated_words} words)")

    print(prefix + " ".join(info_parts))

    if root.description != None && indent == 0:
        print(prefix + f"   └─ {root.description}")

    for child in root.children:
        display_outline(child, indent + 1)

function print_generation_summary(doc: long_document) {
    s = doc.statistics
    m = doc.generation_metadata

    print(f"\n{'='*60}")
    print(f"✅ document Generation Complete!")
    print(f"{'='*60}")
    print(f"Title: {doc.title}")
    print(f"Total Words: {s.total_words:,}")
    print(f"Total Characters: {s.total_characters:,}")
    print(f"Sections: {s.total_sections}")
    print(f"Avg Words/Section: {s.avg_section_words:.0f}")
    print(f"Reading Time: ~{s.reading_time_minutes:.1f} minutes")
    print(f"Generation Time: {m.generation_time_seconds:.1f}s")
    print(f"API Calls: {m.api_calls_made}")
    print(f"Revisions: {m.sections_revised}")
    print(f"Quality Checks: ✅{m.quality_checks_passed} ❌{m.quality_checks_failed}")
    print(f"{'='*60}\n")

// ==================== English textfunctionEnglish texttest ====================

function create_long_writer(config?: long_writer_config, llm_client: any) {
    return new LongWriterEngine(config=config ?? new long_writer_config(), llm_client=llm_client)
}

async function test_long_writer() {
    print("🧪 Testing NEURX LONGWRITER Engine...")

    cfg = long_writer_config(
        max_section_tokens=512,
        quality_check_enabled=false,  # Disable for test speed
        output_format="markdown",
        include_toc=true
    )

    # Mock LLM client for testing
    mock_llm = MockLLMClient()

    engine = create_long_writer(cfg, mock_llc)

    # Test 1: Outline creation
    print("  ✓ Test 1: Outline Planning")
    plan = await engine.planner.create_plan("Benefits of Artificial Intelligence in Healthcare", "Focus on diagnostics, treatment, and patient care")
    assert plan.topic.contains("Artificial Intelligence"), "Topic mismatch"
    assert plan.sections_count >= 3, f"Too few sections: {plan.sections_count}"
    assert plan.total_estimated_words > 0, "Word estimation should be positive"
    assert get_max_depth(plan.outline) >= 2, "Should have multi-level outline"

    # Test 2: Flatten and verify structure
    print("  ✓ Test 2: Outline Structure Verification")
    flat = flatten_outline(plan.outline)
    levels = [s.level for s in flat]
    assert all(l > 0 for l in levels), "All non-root sections should have level > 0"
    assert sorted(levels) == levels, "Sections should be in order by DFS traversal"

    # Test 3: Content generation (single section)
    print("  ✓ Test 3: Single Section Generation")
    first_section = flat[0]
    gen_context = generation_context{
        document_topic=plan.topic,
        full_outline=plan.outline,
        total_sections=len(flat),
        tokens_used_so_far=0,
        completed_sections=[],
        global_constraints={}
    }

    generated = await engine.generator.generate_section(first_section, gen_context)
    assert generated.section.id == first_section.id, "Generated wrong section"
    assert generated.processed_text.length > 50, "Content too short"
    assert generated.word_count > 10, "Word count seems incorrect"
    assert generated.tokens_used > 0, "Should track token usage"

    # Test 4: Statistics computation
    print("  ✓ Test 4: document Statistics")
    all_generated = [generated]  # In real scenario would have many more
    dummy_full = "Test document content for statistics calculation. "
    stats = compute_long_doc_statistics(all_generated, dummy_full * 100, current_time_millis())
    assert stats.total_words > 0, "Total words should be > 0"
    assert stats.reading_time_minutes > 0, "Reading time should be calculated"
    assert stats.total_sections == 1, "Should have 1 section"

    # Test 5: TOC generation
    print("  ✓ Test 5: Table of Contents Generation")
    toc = generate_toc([generated], cfg)
    assert toc.entries.length == 1, "TOC should have 1 entry"
    assert toc.entries[0].title == first_section.title, "TOC entry title mismatch"

    print("\n✅ All LongWriter Tests Passed!")
    return true
}

class MockLLMClient {
    async generate(prompt: string, temperature?: float, max_tokens?: int,
                   response_format?: string, stop_sequences?: list<string>) {
        # Return deterministic mock content for testing
        content_length = min(max_tokens ?? 256, 300)

        # Generate plausible-looking content based on prompt
        if "outline" in prompt.to_lower():
            return llm_response(text=json.dumps({
                "title": "AI in Healthcare Overview",
                "sections": [
                    {"id": "1", "title": "Introduction", "level": 1, "description": "Overview of AI in healthcare", "estimated_words": 400, "children": []},
                    {"id": "2", "title": "Diagnostic Applications", "level": 1, "description": "AI-powered diagnostic tools", "estimated_words": 600, "children": []},
                    {"id": "3", "title": "Treatment Optimization", "level": 1, "description": "Personalized treatment plans using AI", "estimated_words": 550, "children": []},
                    {"id": "4", "title": "Conclusion", "level": 1, "description": "Future outlook and challenges", "estimated_words": 300, "children": []}
                ]
            }), usage=usage_info(prompt_tokens=len(prompt.split()), completion_tokens=200))
        else:
            # Generate generic content
            paragraphs: list<string> = []
            words_written = 0
            while words_written < content_length:
                para = f"This is sample generated content for testing purposes. It demonstrates the LongWriter's ability to produce coherent text. The content discusses relevant topics in detail. Each paragraph adds value to the overall document structure. "
                paragraphs.append(para.trim())
                words_written += len(para.split())

            return llm_response(
                text="\n\n".join(paragraphs)[:content_length],
                usage=usage_info(prompt_tokens=100, completion_tokens=min(content_length, 300))
            )
    }
}

struct usage_info {
    prompt_tokens: int
    completion_tokens: int
}

struct llm_response {
    text: string
    usage: usage_info
}

// Export public API
export {
    long_writer_config, outline_node, SectionStatus, writing_plan, plan_metadata,
    writing_constraints, long_document, table_of_contents, toc_entry,
    document_statistics, generation_metadata,
    ContentGenerator, generated_section, post_process_result,
    QualityChecker, quality_check_result, coherence_check_result,
    LongWriterEngine,
    create_long_writer, test_long_writer
}
