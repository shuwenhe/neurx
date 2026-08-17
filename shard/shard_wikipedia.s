package neurx.shard.shard_wikipedia
use neurx.runtime.io.{runtime_env_get, runtime_run_command_output}

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
    runtime_run_command("test -f " + shell_escape(path)).ok
}

func dir_exists(string path) bool {
    runtime_run_command("test -d " + shell_escape(path)).ok
}

func make_dir(string path) bool {
    runtime_run_command("mkdir -p " + shell_escape(path)).ok
}

func write_text_file(string path, string content) bool {
    runtime_run_command("printf %s " + shell_escape(content) + " > " + shell_escape(path)).ok
}

func read_command_output(string cmd) string {
    trim(runtime_run_command_output(cmd))
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

func process_wikipedia(string input_bz2_file, string output_dir, string manifest_file, string docs_per_shard, string max_pages) int {
    println("")
    println("╔══════════════════════════════════════════════════════════╗")
    println("║    NeurX Wikipedia Shard Processing (S Language)        ║")
    println("╚══════════════════════════════════════════════════════════╝")
    println("")
    println("Input      : " + input_bz2_file)
    println("Output dir : " + output_dir)
    println("manifest   : " + manifest_file)
    println("Docs/shard : " + docs_per_shard)
    println("Max pages  : " + max_pages)
    println("")
    if runtime_run_command_output("sh -c \"if [ -f " + input_bz2_file + " ]; then echo ok; fi\"") == "" {
        println("[-] Input file not found: " + input_bz2_file)
        return 1
    }
    if runtime_run_command_output("sh -c \"mkdir -p " + output_dir + " && echo ok\"") == "" {
        println("[-] Failed to create output directory: " + output_dir)
        return 1
    }
    if runtime_run_command_output("sh -c \"mkdir -p $(dirname " + manifest_file + ") && echo ok\"") == "" {
        println("[-] Failed to create manifest directory")
        return 1
    }
    string temp_xml = output_dir + "/.wikipedia_dump.xml"
    if runtime_run_command_output("sh -c \"rm -f " + output_dir + "/shard_*.jsonl " + temp_xml + " " + manifest_file + " " + output_dir + "/.wikipedia_shard_complete && echo ok\"") == "" {
        println("[-] Failed to clean output directory")
        return 1
    }
    println("[*] Decompressing Wikipedia dump...")
    if runtime_run_command_output("sh -c \"bzip2 -dc " + input_bz2_file + " > " + temp_xml + " && echo ok\"") == "" {
        println("[-] Failed to decompress input file")
        return 1
    }
    string perl_script = ""
    perl_script = perl_script + "use strict; use warnings; use POSIX qw(strftime); use JSON::PP qw(encode_json);\n"
    perl_script = perl_script + "my ($input, $out_dir, $manifest, $docs_per_shard, $max_pages) = @ARGV;\n"
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
    perl_script = perl_script + "open_shard();\n"
    perl_script = perl_script + "for my $page (@pages) {\n"
    perl_script = perl_script + "  last if $page_limit > 0 && $count >= $page_limit;\n"
    perl_script = perl_script + "  my ($title) = $page =~ m{<title>(.*?)</title>}s;\n"
    perl_script = perl_script + "  my ($page_id) = $page =~ m{<id>(.*?)</id>}s;\n"
    perl_script = perl_script + "  my ($text) = $page =~ m{<text[^>]*>(.*?)</text>}s;\n"
    perl_script = perl_script + "  $title = '' unless defined $title;\n"
    perl_script = perl_script + "  $page_id = '' unless defined $page_id;\n"
    perl_script = perl_script + "  $text = '' unless defined $text;\n"
    perl_script = perl_script + "  my $json = encode_json({title => $title, page_id => $page_id, text => $text, source => 'enwiki'});\n"
    perl_script = perl_script + "  print {$out} $json, \"\\n\";\n"
    perl_script = perl_script + "  $count++;\n"
    perl_script = perl_script + "  if ($docs_limit > 0 && ($count % $docs_limit) == 0 && $count < ($page_limit > 0 ? $page_limit : $count + 1)) {\n"
    perl_script = perl_script + "    close $out;\n"
    perl_script = perl_script + "    $shard++;\n"
    perl_script = perl_script + "    open_shard();\n"
    perl_script = perl_script + "  }\n"
    perl_script = perl_script + "}\n"
    perl_script = perl_script + "close $out;\n"
    perl_script = perl_script + "open my $mf, '>', $manifest or die $!;\n"
    perl_script = perl_script + "print {$mf} \"{\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"dataset_name\\\": \\\"neurx-wikipedia\\\",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"created_at\\\": \\\"\" . strftime('%Y-%m-%dT%H:%M:%SZ', gmtime()) . \"\\\",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"source_file\\\": \\\"\" . $input . \"\\\",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"shard_dir\\\": \\\"\" . $out_dir . \"\\\",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"manifest_file\\\": \\\"\" . $manifest . \"\\\",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"docs_per_shard\\\": \" . $docs_per_shard . \",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"max_pages\\\": \" . $max_pages . \",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"total_pages\\\": $count,\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"total_shards\\\": \" . ($shard + 1) . \",\\n\";\n"
    perl_script = perl_script + "print {$mf} \"  \\\"shards\\\": [\\n\";\n"
    perl_script = perl_script + "for my $i (0 .. $shard) { my $path = sprintf('%s/shard_%05d.jsonl', $out_dir, $i); open my $sf, '<', $path or next; my $lines = 0; $lines++ while (<$sf>); close $sf; my $size = -s $path; print {$mf} '    {\"shard_id\": ' . sprintf('\"%s\"', sprintf('shard_%05d.jsonl', $i)) . ', \"file_path\": ' . sprintf('\"%s\"', $path) . ', \"num_documents\": ' . $lines . ', \"size_bytes\": ' . $size . '}'; print {$mf} \",\\n\" if $i < $shard; }\n"
    perl_script = perl_script + "print {$mf} \"  ]\\n\";\n"
    perl_script = perl_script + "print {$mf} \"}\\n\";\n"
    perl_script = perl_script + "close $mf;\n"
    string perl_cmd = "cat > /tmp/neurx_wikipedia_shard.pl <<'EOF'\n"
    perl_cmd = perl_cmd + perl_script + "\nEOF\n"
    perl_cmd = perl_cmd + "perl /tmp/neurx_wikipedia_shard.pl "
    perl_cmd = perl_cmd + temp_xml + " "
    perl_cmd = perl_cmd + output_dir + " "
    perl_cmd = perl_cmd + manifest_file + " "
    perl_cmd = perl_cmd + docs_per_shard + " "
    perl_cmd = perl_cmd + max_pages
    perl_cmd = perl_cmd + " && echo ok"
    println("[*] Writing JSONL shards and manifest...")
    if runtime_run_command_output(perl_cmd) == "" {
        println("[-] Failed to create shards")
        return 1
    }
    println("")
    println("[+] Wikipedia sharding complete")
    println("[+] manifest : " + manifest_file)
    return 0
}

func main() {
    string neurx_home = runtime_env_get("NEURX_HOME", ".")
    string dataset_root = neurx_home + "/dataset/pretrain"
    string input_bz2_file = runtime_env_get("ENWIKI_BZ2_FILE", dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2")
    string output_dir = runtime_env_get("ENWIKI_SHARD_DIR", dataset_root + "/shard")
    string manifest_file = runtime_env_get("ENWIKI_MANIFEST_FILE", dataset_root + "/manifest.json")
    string docs_per_shard = runtime_env_get("DOCS_PER_SHARD", "5000")
    string max_pages = runtime_env_get("MAX_PAGES", "0")
    process_wikipedia(input_bz2_file, output_dir, manifest_file, docs_per_shard, max_pages)
}
