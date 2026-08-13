package neurx.inference.speech.speech_to_text

func speech_task_transcribe() int { 1 }
func speech_task_translate() int { 2 }

struct speech_to_text_config {
    string model
    int task
    string language
    int sample_rate
    int channels
    int chunk_seconds
    bool streaming
    bool word_timestamps
}

struct speech_to_text_state {
    speech_to_text_config config
    int samples_received
    int chunks_processed
    int audio_duration_ms
    string transcript
    string detected_language
    bool initialized
    bool complete
    string error_message
}

struct speech_chunk {
    int sequence_id
    []float samples
    int start_ms
    int end_ms
    bool final_chunk
}

struct speech_chunk_result {
    speech_to_text_state state
    string text
    int start_ms
    int end_ms
    bool final_chunk
    bool success
}

struct speech_native_job {
    int64 samples_pointer
    int sample_count
    int sample_rate
    int channels
    int task
    int64 output_pointer
    int output_capacity
}

extern func neurx_speech_transcribe_f32(int64 samples_pointer, int sample_count, int sample_rate, int channels, int task, int64 output_pointer, int output_capacity) int

func speech_config_valid(speech_to_text_config config) bool {
    if config.model == "" { return false }
    if config.task != speech_task_transcribe() && config.task != speech_task_translate() { return false }
    if config.sample_rate <= 0 || config.channels <= 0 || config.chunk_seconds <= 0 { return false }
    true
}

func init_speech_to_text(speech_to_text_config config) speech_to_text_state {
    bool initialized = speech_config_valid(config)
    string error_message = ""
    if !initialized { error_message = "invalid speech-to-text configuration" }
    speech_to_text_state {
        config: config,
        samples_received: 0,
        chunks_processed: 0,
        audio_duration_ms: 0,
        transcript: "",
        detected_language: config.language,
        initialized: initialized,
        complete: false,
        error_message: error_message,
    }
}

func speech_chunk_duration_ms(speech_to_text_config config, int sample_count) int {
    if config.sample_rate <= 0 || config.channels <= 0 { return 0 }
    sample_count * 1000 / (config.sample_rate * config.channels)
}

func speech_append_text(string transcript, string text) string {
    if text == "" { return transcript }
    if transcript == "" { return text }
    transcript + " " + text
}

func speech_int_string(int value) string {
    if value == 0 { return "0" }
    int current = value
    string prefix = ""
    if current < 0 { prefix = "-"; current = 0 - current }
    string digits = ""
    while current > 0 {
        int digit = current - (current / 10) * 10
        digits = string(byte(48 + digit)) + digits
        current = current / 10
    }
    prefix + digits
}

func speech_consume_chunk(speech_to_text_state state, speech_chunk chunk, string decoded_text, string detected_language) speech_chunk_result {
    if !state.initialized || state.complete {
        return speech_chunk_result {state: state, text: "", start_ms: chunk.start_ms, end_ms: chunk.end_ms, final_chunk: chunk.final_chunk, success: false}
    }
    int duration_ms = speech_chunk_duration_ms(state.config, len(chunk.samples))
    string language = state.detected_language
    if detected_language != "" { language = detected_language }
    speech_to_text_state updated = speech_to_text_state {
        config: state.config,
        samples_received: state.samples_received + len(chunk.samples),
        chunks_processed: state.chunks_processed + 1,
        audio_duration_ms: state.audio_duration_ms + duration_ms,
        transcript: speech_append_text(state.transcript, decoded_text),
        detected_language: language,
        initialized: state.initialized,
        complete: chunk.final_chunk,
        error_message: "",
    }
    speech_chunk_result {state: updated, text: decoded_text, start_ms: chunk.start_ms, end_ms: chunk.end_ms, final_chunk: chunk.final_chunk, success: true}
}

func speech_native_execute(speech_native_job job) int {
    if job.samples_pointer == i64(0) || job.output_pointer == i64(0) || job.sample_count <= 0 || job.output_capacity <= 0 { return 0 - 1 }
    neurx_speech_transcribe_f32(job.samples_pointer, job.sample_count, job.sample_rate, job.channels, job.task, job.output_pointer, job.output_capacity)
}

func speech_openai_json(speech_to_text_state state, bool verbose) string {
    if !verbose { return "{\"text\":\"" + anthropic_safe_json(state.transcript) + "\"}" }
    "{\"task\":\"transcribe\",\"language\":\"" + anthropic_safe_json(state.detected_language) + "\",\"duration\":" + speech_int_string(state.audio_duration_ms) + ",\"text\":\"" + anthropic_safe_json(state.transcript) + "\"}"
}

func anthropic_safe_json(string value) string {
    string output = ""
    int i = 0
    while i < len(value) {
        int ch = int(value[i])
        if ch == 34 { output = output + "\\\"" }
        else if ch == 92 { output = output + "\\\\" }
        else if ch == 10 { output = output + "\\n" }
        else { output = output + string(value[i]) }
        i = i + 1
    }
    output
}
