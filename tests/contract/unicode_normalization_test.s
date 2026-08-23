package main
use neurx.core.unicode.normalization.{unicode_database, load_unicode_database, unicode_nfc, unicode_nfkc}

func main() {
    unicode_database database = load_unicode_database("configs/unicode")
    if !database.valid || database.version != "17.0.0" { return 1 }
    string ring = "A" + string(204) + string(138)
    string composed_ring = "" + string(195) + string(133)
    if unicode_nfc(database, ring) != composed_ring { return 1 }
    string circled_one = "" + string(226) + string(145) + string(160)
    if unicode_nfkc(database, circled_one) != "1" { return 1 }
    string reordered = "a" + string(204) + string(149) + string(204) + string(128)
    string reordered_expected = "" + string(195) + string(160) + string(204) + string(149)
    if unicode_nfc(database, reordered) != reordered_expected { return 1 }
    string hangul = "" + string(234) + string(176) + string(128)
    if unicode_nfc(database, hangul) != hangul { return 1 }
    println("PASS pure S Unicode 17 NFC NFKC normalization contract")
    0
}
