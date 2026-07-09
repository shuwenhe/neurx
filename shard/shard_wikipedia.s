// ============================================================================
// NeurX Wikipedia Shard Processing
//
// S-language entry point for Wikipedia dump sharding.
// This version keeps the implementation self-contained and shell-driven so it
// can compile to IR and be used by `make shard` / `shard.sh` directly.
// ============================================================================

package neurx.shard.shard_wikipedia

use std.os.{command, getenv}

// ============================================================================
// Configuration
// ============================================================================

struct WikipediaConfig {
    string input_bz2_file
    string output_dir
    string manifest_file
    int docs_per_shard
    int max_pages
}

struct ShardMetadata {
    string shard_id
    string file_path
    int num_documents
    int size_bytes
}

// ============================================================================
// Small helpers
// ============================================================================

func string_char(int c) string {
    string(c)
}

func trim(string s) string {
    int begin = 0
    while begin < len(s) {
        string ch = string_char(s[begin])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            begin = begin + 1
        } else {
            break
        }
    }

    int end = len(s)
    while end > begin {
        string ch = string_char(s[end - 1])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            end = end - 1
        } else {
            break
        }
    }

    string out = ""
    int i = begin
    while i < end {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if len(text) == 0 {
        return fallback
    }

    int sign = 1
    int i = 0
    if string_char(text[0]) == "-" {
        sign = -1
        i = 1
    } else if string_char(text[0]) == "+" {
        i = 1
    }

    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }

    sign * value
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }

    bool negative = n < 0
    if negative {
        n = 0 - n
    }

    string out = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        out = string_char(digit + 48) + out
        n = n / 10
    }

    if negative {
        out = "-" + out
    }

    out
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    while i < len(s) {
        string ch = string_char(s[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "'"
    out
}

func basename(string path) string {
    int last = -1
    int i = 0
    while i < len(path) {
        if string_char(path[i]) == "/" {
            last = i
        }
        i = i + 1
    }
    if last < 0 {
        return path
    }
    if last + 1 >= len(path) {
        return ""
    }
    string out = ""
    i = last + 1
    while i < len(path) {
        out = out + string_char(path[i])
        i = i + 1
    }
    out
}

func parent_dir(string path) string {
    int last = -1
    int i = 0
    while i < len(path) {
        if string_char(path[i]) == "/" {
            last = i
        }
        i = i + 1
    }
    if last <= 0 {
        return "."
    }
    string out = ""
    i = 0
    while i < last {
        out = out + string_char(path[i])
        i = i + 1
    }
    out
}

func file_exists(string path) bool {
    let (_, code) = command("test -f " + shell_escape(path))
    code == 0
}

func dir_exists(string path) bool {
    let (_, code) = command("test -d " + shell_escape(path))
    code == 0
}

func make_dir(string path) bool {
    let (_, code) = command("mkdir -p " + shell_escape(path))
    code == 0
}

func write_text_file(string path, string content) bool {
    let (_, code) = command("printf %s " + shell_escape(content) + " > " + shell_escape(path))
    code == 0
}

func read_command_output(string cmd) string {
    let (out, _) = command(cmd)
    trim(out)
}

func shard_name(int index) string {
    string s = int_to_str(index)
    while len(s) < 5 {
        s = "0" + s
    }
    "shard_" + s + ".jsonl"
}

func json_escape(string s) string {
    string out = "\""
    int i = 0
    while i < len(s) {
        string ch = string_char(s[i])
        if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\\" {
            out = out + "\\\\"
        } else if ch == "\n" {
            out = out + "\\n"
        } else if ch == "\r" {
            out = out + "\\r"
        } else if ch == "\t" {
            out = out + "\\t"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "\""
    out
}

func generate_manifest_json(WikipediaConfig config, int total_pages, int total_shards, []ShardMetadata shards) string {
    string json = "{\n"
    json = json + "  \"dataset_name\": \"neurx-wikipedia\",\n"
    json = json + "  \"source_file\": " + json_escape(config.input_bz2_file) + ",\n"
    json = json + "  \"shard_dir\": " + json_escape(config.output_dir) + ",\n"
    json = json + "  \"manifest_file\": " + json_escape(config.manifest_file) + ",\n"
    json = json + "  \"docs_per_shard\": " + int_to_str(config.docs_per_shard) + ",\n"
    json = json + "  \"max_pages\": " + int_to_str(config.max_pages) + ",\n"
    json = json + "  \"total_pages\": " + int_to_str(total_pages) + ",\n"
    json = json + "  \"total_shards\": " + int_to_str(total_shards) + ",\n"
    json = json + "  \"shards\": [\n"

    int i = 0
    while i < len(shards) {
        json = json + "    {\n"
        json = json + "      \"shard_id\": " + json_escape(shards[i].shard_id) + ",\n"
        json = json + "      \"file_path\": " + json_escape(shards[i].file_path) + ",\n"
        json = json + "      \"num_documents\": " + int_to_str(shards[i].num_documents) + ",\n"
        json = json + "      \"size_bytes\": " + int_to_str(shards[i].size_bytes) + "\n"
        json = json + "    }"
        if i + 1 < len(shards) {
            json = json + ","
        }
        json = json + "\n"
        i = i + 1
    }

    json = json + "  ]\n"
    json = json + "}\n"
    json
}

// ============================================================================
// Core processing
// ============================================================================

func process_wikipedia(WikipediaConfig config) int {
    println("")
    println("╔══════════════════════════════════════════════════════════╗")
    println("║    NeurX Wikipedia Shard Processing (S Language)        ║")
    println("╚══════════════════════════════════════════════════════════╝")
    println("")
    println("Input      : " + config.input_bz2_file)
    println("Output dir : " + config.output_dir)
    println("Manifest   : " + config.manifest_file)
    println("Docs/shard : " + int_to_str(config.docs_per_shard))
    println("Max pages  : " + int_to_str(config.max_pages))
    println("")

    if !file_exists(config.input_bz2_file) {
        println("[-] Input file not found: " + config.input_bz2_file)
        return 1
    }

    if !make_dir(config.output_dir) {
        println("[-] Failed to create output directory: " + config.output_dir)
        return 1
    }
    if !make_dir(parent_dir(config.manifest_file)) {
        println("[-] Failed to create manifest directory")
        return 1
    }

    // Clean up previous outputs.
    let _ = command("rm -f " + shell_escape(config.output_dir + "/shard_*.jsonl") + " " + shell_escape(config.output_dir + "/.wikipedia_dump.xml"))

    string temp_xml = config.output_dir + "/.wikipedia_dump.xml"
    println("[*] Decompressing Wikipedia dump...")
    let (_, decompress_code) = command(
        "bzip2 -dc " + shell_escape(config.input_bz2_file) + " > " + shell_escape(temp_xml)
    )
    if decompress_code != 0 {
        println("[-] Failed to decompress input file")
        return 1
    }

    string count_cmd = "grep -c '<page>' " + shell_escape(temp_xml) + " 2>/dev/null || printf 0"
    int total_pages = parse_int(read_command_output(count_cmd), 0)
    if config.max_pages > 0 && total_pages > config.max_pages {
        total_pages = config.max_pages
    }

    int total_shards = 0
    if config.docs_per_shard > 0 {
        total_shards = (total_pages + config.docs_per_shard - 1) / config.docs_per_shard
    }
    if total_shards < 1 {
        total_shards = 1
    }

    println("[*] Pages to shard: " + int_to_str(total_pages))
    println("[*] Planned shards : " + int_to_str(total_shards))
    println("")

    // The heavy lifting is done in Perl so the S entry remains compact and
    // compilation-friendly while still producing JSONL shards.
    string perl_script = ""
    perl_script = perl_script + "use strict; use warnings; use JSON::PP qw(encode_json);\n"
    perl_script = perl_script + "my ($input, $out_dir, $docs_per_shard, $max_pages) = @ARGV;\n"
    perl_script = perl_script + "open my $fh, '<', $input or die $!;\n"
    perl_script = perl_script + "local $/ = undef;\n"
    perl_script = perl_script + "my $xml = <$fh>;\n"
    perl_script = perl_script + "my @pages = ($xml =~ m{<page>(.*?)</page>}sg);\n"
    perl_script = perl_script + "my $page_limit = int($max_pages);\n"
    perl_script = perl_script + "my $docs_limit = int($docs_per_shard);\n"
    perl_script = perl_script + "my $count = 0;\n"
    perl_script = perl_script + "my $shard = 0;\n"
    perl_script = perl_script + "my $out;\n"
    perl_script = perl_script + "sub open_shard {\n"
    perl_script = perl_script + "  my $path = sprintf('%s/shard_%05d.jsonl', $out_dir, $shard);\n"
    perl_script = perl_script + "  open($out, '>', $path) or die $!;\n"
    perl_script = perl_script + "}\n"
    perl_script = perl_script + "sub esc { my ($v) = @_; $v =~ s/\\\\/\\\\\\\\/g; $v =~ s/\"/\\\\\"/g; $v =~ s/\\n/\\\\n/g; $v =~ s/\\r/\\\\r/g; $v =~ s/\\t/\\\\t/g; return $v; }\n"
    perl_script = perl_script + "open_shard();\n"
    perl_script = perl_script + "for my $page (@pages) {\n"
    perl_script = perl_script + "  last if $page_limit > 0 && $count >= $page_limit;\n"
    perl_script = perl_script + "  my ($title) = $page =~ m{<title>(.*?)</title>}s;\n"
    perl_script = perl_script + "  my ($page_id) = $page =~ m{<id>(.*?)</id>}s;\n"
    perl_script = perl_script + "  my ($text) = $page =~ m{<text[^>]*>(.*?)</text>}s;\n"
    perl_script = perl_script + "  $title = '' unless defined $title;\n"
    perl_script = perl_script + "  $page_id = '' unless defined $page_id;\n"
    perl_script = perl_script + "  $text = '' unless defined $text;\n"
    perl_script = perl_script + "  my $json = encode_json({title => esc($title), page_id => esc($page_id), text => esc($text), source => 'enwiki'});\n"
    perl_script = perl_script + "  print {$out} $json, \"\\n\";\n"
    perl_script = perl_script + "  $count++;\n"
    perl_script = perl_script + "  if ($docs_limit > 0 && ($count % $docs_limit) == 0 && $count < ($page_limit > 0 ? $page_limit : $count + 1)) {\n"
    perl_script = perl_script + "    close $out;\n"
    perl_script = perl_script + "    $shard++;\n"
    perl_script = perl_script + "    open_shard();\n"
    perl_script = perl_script + "  }\n"
    perl_script = perl_script + "}\n"
    perl_script = perl_script + "close $out;\n"
    perl_script = perl_script + "my $manifest = $out_dir . '/manifest.json';\n"
    perl_script = perl_script + "open my $mf, '>', $manifest or die $!;\n"
    perl_script = perl_script + "print {$mf} \"{\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"dataset_name\\\": \\\"neurx-wikipedia\\\",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"total_pages\\\": $count,\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"total_shards\\\": \" . ($shard + 1) . \",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"shards\\\": [\\n\";\n"
    perl_script = perl_script + "for my $i (0 .. $shard) { my $path = sprintf('%s/shard_%05d.jsonl', $out_dir, $i); open my $sf, '<', $path or next; my $lines = 0; $lines++ while (<$sf>); close $sf; my $size = -s $path; print {$mf} '    {\"shard_id\": ' . sprintf('\"%s\"', sprintf('shard_%05d.jsonl', $i)) . ', \"file_path\": ' . sprintf('\"%s\"', $path) . ', \"num_documents\": ' . $lines . ', \"size_bytes\": ' . $size . '}'; print {$mf} \",\\n\" if $i < $shard; }\n"
    perl_script = perl_script + "print {$mf} \"  ]\\n\";\n"
    perl_script = perl_script + "print {$mf} \"}\\n\";\n"
    perl_script = perl_script + "close $mf;\n"

    string perl_cmd = "perl -e " + shell_escape(perl_script) + " " +
        shell_escape(temp_xml) + " " +
        shell_escape(config.output_dir) + " " +
        shell_escape(int_to_str(config.docs_per_shard)) + " " +
        shell_escape(int_to_str(config.max_pages))

    println("[*] Writing JSONL shards and manifest...")
    let (_, shard_code) = command(perl_cmd)
    if shard_code != 0 {
        println("[-] Failed to create shards")
        return 1
    }

    let shard_count_output = read_command_output("ls -1 " + shell_escape(config.output_dir + "/shard_*.jsonl") + " 2>/dev/null | wc -l")
    int actual_shards = parse_int(shard_count_output, total_shards)
    if actual_shards < 1 {
        actual_shards = total_shards
    }

    string manifest_json = generate_manifest_json(config, total_pages, actual_shards, []ShardMetadata{cap: 0})
    // The Perl side already writes a manifest; replace it with the S-generated
    // one so the entrypoint stays self-consistent.
    if !write_text_file(config.manifest_file, manifest_json) {
        println("[-] Failed to write manifest")
        return 1
    }

    println("")
    println("[+] Wikipedia sharding complete")
    println("[+] Shards   : " + int_to_str(actual_shards))
    println("[+] Pages    : " + int_to_str(total_pages))
    println("[+] Manifest : " + config.manifest_file)

    return 0
}

// ============================================================================
// Main entry
// ============================================================================

func main() int {
    string neurx_home = getenv("NEURX_HOME", ".")
    string dataset_root = neurx_home + "/dataset/pretrain"

    WikipediaConfig config
    config.input_bz2_file = getenv("ENWIKI_BZ2_FILE", dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2")
    config.output_dir = getenv("ENWIKI_SHARD_DIR", dataset_root + "/shard")
    config.manifest_file = getenv("ENWIKI_MANIFEST_FILE", dataset_root + "/manifest.json")
    config.docs_per_shard = parse_int(getenv("DOCS_PER_SHARD", "5000"), 5000)
    config.max_pages = parse_int(getenv("MAX_PAGES", "0"), 0)

    process_wikipedia(config)
}
