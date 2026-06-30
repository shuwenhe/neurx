#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <output.s>" >&2
  exit 1
fi

OUT_PATH="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$(dirname "$OUT_PATH")"

cat >"$OUT_PATH" <<'EOF'
package main

EOF

append_file() {
  local input_path="$1"
  shift
  local tmp_path
  tmp_path="$(mktemp)"
  grep -vE '^(package |use )' "$input_path" >"$tmp_path"
  while [ "$#" -gt 0 ]; do
    perl -0pi -e "$1" "$tmp_path"
    shift
  done
  cat "$tmp_path" >>"$OUT_PATH"
  printf '\n' >>"$OUT_PATH"
  rm -f "$tmp_path"
}

append_file \
  "$ROOT_DIR/model/transformer/norm_embed.s" \
  's/\ballocate_vector\b/norm_allocate_vector/g' \
  's/\bcopy_vector\b/norm_copy_vector/g' \
  's/\bsqrt_approx\b/norm_sqrt_approx/g' \
  's/\bexp_approx\b/norm_exp_approx/g'

append_file \
  "$ROOT_DIR/model/transformer/attention.s" \
  's/\ballocate_vector\b/attention_allocate_vector/g' \
  's/\bcopy_vector\b/attention_copy_vector/g' \
  's/\bexp_approx\b/attention_exp_approx/g' \
  's/\bsqrt_approx\b/attention_sqrt_approx/g' \
  's/\bfill_ramp\b/attention_fill_ramp/g' \
  's/\bmatmul_flat\b/attention_matmul_flat/g'

append_file \
  "$ROOT_DIR/model/transformer/ffn.s" \
  's/\ballocate_vector\b/ffn_allocate_vector/g' \
  's/\bcopy_vector\b/ffn_copy_vector/g' \
  's/\bexp_approx\b/ffn_exp_approx/g' \
  's/\bsqrt_approx\b/ffn_sqrt_approx/g' \
  's/\bbuild_ramp\b/ffn_build_ramp/g' \
  's/\bmatmul_flat\b/ffn_matmul_flat/g'

append_file \
  "$ROOT_DIR/model/transformer/transformer.s" \
  's/\ballocate_vector\b/transformer_allocate_vector/g' \
  's/\bcopy_vector\b/transformer_copy_vector/g' \
  's/\badd_vectors\b/transformer_add_vectors/g' \
  's/\bmatmul_flat\b/transformer_matmul_flat/g' \
  's/\bfill_ramp\b/transformer_fill_ramp/g'

append_file "$ROOT_DIR/model/transformer/model_class.s"
append_file "$ROOT_DIR/test/test_transformer_model_e2e.s"
