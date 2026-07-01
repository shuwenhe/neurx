#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "usage: link_s_ir_module.sh <module.ir> <importer.ir> <module.prefix> <output.ir>" >&2
    exit 2
fi

MODULE_IR="$1"
IMPORTER_IR="$2"
MODULE_PREFIX="$3"
OUTPUT_IR="$4"

TMP_FUNCS="$(mktemp)"
trap 'rm -f "$TMP_FUNCS"' EXIT

awk -F'|' '$1 == "FUNC_BEGIN" { print $2 }' "$MODULE_IR" > "$TMP_FUNCS"

{
    echo "SSEED-TARGET-V1"
    awk -v prefix="$MODULE_PREFIX" -v funcs_file="$TMP_FUNCS" '
        BEGIN {
            FS = "|"
            OFS = "|"
            while ((getline fn < funcs_file) > 0) {
                mapped[fn] = prefix "." fn
            }
        }
        NR == 1 && $0 == "SSEED-TARGET-V1" { next }
        {
            if ($1 == "FUNC_BEGIN" && ($2 in mapped)) {
                $2 = mapped[$2]
            }
            if ($1 == "FUNC_END" && ($2 in mapped)) {
                $2 = mapped[$2]
            }
            if ($1 == "LABEL") {
                $2 = prefix "." $2
            }
            if ($1 == "JUMP" || $1 == "JUMP_IF_FALSE") {
                $2 = prefix "." $2
            }
            if ($1 == "CALL" && ($3 in mapped)) {
                $3 = mapped[$3]
            }
            print
        }
    ' "$MODULE_IR"
    awk -v prefix="$MODULE_PREFIX" -v funcs_file="$TMP_FUNCS" '
        BEGIN {
            FS = "|"
            OFS = "|"
            while ((getline fn < funcs_file) > 0) {
                mapped[fn] = prefix "." fn
            }
        }
        NR == 1 && $0 == "SSEED-TARGET-V1" { next }
        {
            if ($1 == "FUNC_BEGIN" && ($2 in mapped)) {
                $2 = mapped[$2]
            }
            if ($1 == "FUNC_END" && ($2 in mapped)) {
                $2 = mapped[$2]
            }
            if ($1 == "LABEL") {
                $2 = prefix "." $2
            }
            if ($1 == "JUMP" || $1 == "JUMP_IF_FALSE") {
                $2 = prefix "." $2
            }
            if ($1 == "CALL" && ($3 in mapped)) {
                $3 = mapped[$3]
            }
            print
        }
    ' "$IMPORTER_IR"
} > "$OUTPUT_IR"
