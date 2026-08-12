package neurx.shard.shard_enwiki
use std.io.{exit}
use std.os.{command, getenv}
use std.strings.{split, join, contains, has_prefix, has_suffix}

func string_char(int c) string {
    string(c)
}


struct enwiki_shard_config {
    string input_bz2_file
    string temp_xml_file
    string shard_dir
    string manifest_file
    int target_shard_size_mb
    bool cleanup_temp
}


func main() {
    println("")
    println("╔══════════════════════════════════════════════════════════╗")
    println("║     NeurX Wikipedia Shard Processing (S Language)        ║")
    println("╚══════════════════════════════════════════════════════════╝")
    println("")
    let neurx_home = getenv("NEURX_HOME", ".")
    let dataset_root = neurx_home + "/dataset/pretrain"
    enwiki_shard_config config
    config.input_bz2_file = getenv("ENWIKI_BZ2_FILE", dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2")
    config.temp_xml_file = getenv("ENWIKI_TEMP_XML", dataset_root + "/tmp/enwiki-latest-pages-articles.xml")
    config.shard_dir = getenv("ENWIKI_SHARD_DIR", dataset_root + "/shard")
    config.manifest_file = getenv("ENWIKI_MANIFEST_FILE", dataset_root + "/enwiki_manifest.json")
    config.target_shard_size_mb = 500
    config.cleanup_temp = true
    println("📋 Configuration:")
    println("  • Input file: " + config.input_bz2_file)
    println("  • Temp XML: " + config.temp_xml_file)
    println("  • Shard dir: " + config.shard_dir)
    println("  • manifest: " + config.manifest_file)
    println("  • Target shard size: " + itoa(config.target_shard_size_mb) + " MB")
    println("")
    if !process_enwiki_dataset(config) {
        println("")
        println("❌ Failed to process enwiki dataset")
        return 1
    }
    println("")
    println("✅ Wikipedia sharding complete")
    return 0
}


func process_enwiki_dataset(enwiki_shard_config config) bool {
    println("🔍 Checking input file...")
    let check_cmd = "test -f \"" + config.input_bz2_file + "\""
    let (_, exit_code) = command(check_cmd)
    if exit_code != 0 {
        println("❌ Error: Input file not found: " + config.input_bz2_file)
        return false
    }
    println("  ✓ Input file exists")
    println("")
    println("📁 Creating directories...")
    let mkdir_cmd = "mkdir -p \"" + config.shard_dir + "\" \"$(dirname \"" + config.temp_xml_file + "\")\""
    let (_, exit_code) = command(mkdir_cmd)
    if exit_code != 0 {
        println("❌ Error: Failed to create directories")
        return false
    }
    println("  ✓ Directories created")
    println("")
    println("📦 Decompressing bz2 file...")
    let bunzip_cmd = "bzip2 -d -c \"" + config.input_bz2_file + "\" > \"" + config.temp_xml_file + "\""
    let (output, exit_code) = command(bunzip_cmd)
    if exit_code != 0 {
        println("❌ Error: Failed to decompress bz2 file")
        println("  Output: " + output)
        return false
    }
    println("  ✓ Decompression complete")
    println("")
    println("📊 Analyzing file...")
    let size_cmd = "stat -f%z \"" + config.temp_xml_file + "\" 2>/dev/null || stat -c%s \"" + config.temp_xml_file + "\""
    let (size_output, _) = command(size_cmd)
    let file_size_mb = atoi(size_output) / (1024 * 1024)
    println("  • XML file size: " + itoa(file_size_mb) + " MB")
    let shard_count = max(1, file_size_mb / config.target_shard_size_mb + 1)
    println("  • Estimated shards: " + itoa(shard_count))
    println("")
    println("✂️ Splitting into shards...")
    if !split_xml_into_shards(config, shard_count) {
        println("❌ Error: Failed to split XML file")
        return false
    }
    println("  ✓ Splitting complete")
    println("")
    println("📝 Generating manifest...")
    if !generate_enwiki_manifest(config, shard_count) {
        println("❌ Error: Failed to generate manifest")
        return false
    }
    println("  ✓ manifest generated")
    println("")
    if config.cleanup_temp {
        println("🧹 Cleaning up temporary files...")
        let rm_cmd = "rm -f \"" + config.temp_xml_file + "\""
        let (_, _) = command(rm_cmd)
        println("  ✓ Cleanup complete")
        println("")
    }
    return true
}


func split_xml_into_shards(enwiki_shard_config config, int shard_count) bool {
    let target_size = itoa(config.target_shard_size_mb * 1024)
    let split_cmd = "split -b " + target_size + "M \"" + config.temp_xml_file + "\" \"" + config.shard_dir + "/shard_\""
    let (output, exit_code) = command(split_cmd)
    if exit_code != 0 {
        println("  Error during split: " + output)
        return false
    }
    let list_cmd = "ls -lh \"" + config.shard_dir + "/shard_\"* 2>/dev/null | wc -l"
    let (count_output, _) = command(list_cmd)
    println("  • Generated shards: " + count_output)
    let rename_cmd = "cd \"" + config.shard_dir + "\" && for f in shard_*; do [ ! -f \"${f}.xml\" ] && mv \"$f\" \"${f}.xml\"; done"
    let (_, _) = command(rename_cmd)
    return true
}


func generate_enwiki_manifest(enwiki_shard_config config, int shard_count) bool {
    let count_cmd = "ls -1 \"" + config.shard_dir + "/shard_\"*.xml 2>/dev/null | wc -l"
    let (count_output, _) = command(count_cmd)
    let actual_shard_count = atoi(count_output)
    let size_cmd = "du -sb \"" + config.shard_dir + "\" | awk '{print $1}'"
    let (total_size_str, _) = command(size_cmd)
    let total_size_bytes = atoi(total_size_str)
    let total_size_mb = total_size_bytes / (1024 * 1024)
    let date_cmd = "date -u +%Y-%m-%dT%H:%M:%SZ"
    let (timestamp, _) = command(date_cmd)
    string manifest = "{" + "\n"
    manifest = manifest + "  \"dataset_name\": \"enwiki-latest\",\n"
    manifest = manifest + "  \"dataset_version\": \"latest\",\n"
    manifest = manifest + "  \"source_file\": \"" + config.input_bz2_file + "\",\n"
    manifest = manifest + "  \"created_at\": \"" + timestamp + "\",\n"
    manifest = manifest + "  \"total_shards\": " + itoa(actual_shard_count) + ",\n"
    manifest = manifest + "  \"total_size_bytes\": " + itoa(total_size_bytes) + ",\n"
    manifest = manifest + "  \"total_size_mb\": " + itoa(total_size_mb) + ",\n"
    manifest = manifest + "  \"shard_dir\": \"" + config.shard_dir + "\",\n"
    manifest = manifest + "  \"target_shard_size_mb\": " + itoa(config.target_shard_size_mb) + ",\n"
    manifest = manifest + "  \"format\": \"xml\",\n"
    manifest = manifest + "  \"shards\": [\n"
    manifest = manifest + "  \"shards\": []\n"
    manifest = manifest + "}\n"
    let write_cmd = "cat > \"" + config.manifest_file + "\" << 'EOF'\n" + manifest + "EOF"
    let (output, exit_code) = command(write_cmd)
    if exit_code != 0 {
        println("  Error writing manifest: " + output)
        return false
    }
    println("  • manifest written to: " + config.manifest_file)
    println("  • Total shards: " + itoa(actual_shard_count))
    println("  • Total size: " + itoa(total_size_mb) + " MB")
    return true
}


func atoi(string s) int {
    let mut result = 0
    let mut i = 0
    while i < len(s) && (string_char(s[i]) == " " || s[i] == 9) {
        i = i + 1
    }
    let negative = i < len(s) && string_char(s[i]) == "-"
    if negative || (i < len(s) && string_char(s[i]) == "+") {
        i = i + 1
    }
    while i < len(s) && s[i] >= 48 && s[i] <= 57 {
        result = result * 10 + (s[i] - 48)
        i = i + 1
    }
    if negative {
        result = -result
    }
    result
}


func itoa(int n) string {
    if n == 0 {
        "0"
    }
    let negative = n < 0
    let mut n = if negative { -n } else { n }
    let mut result = ""
    while n > 0 {
        let mut digit = n
        let mut quotient = 0
        while digit >= 10 {
            digit = digit - 10
            quotient = quotient + 1
        }
        result = string_char(digit + 48) + result
        n = quotient
    }
    if negative {
        result = "-" + result
    }
    result
}


func max(int a, int b) int {
    if a > b { a } else { b }
}


func char(int n) int {
    n
}

