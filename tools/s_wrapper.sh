#!/bin/bash
# Simple wrapper to make different 's' invocations compatible.
# If called as: s ir <input.s> -o <output.ir>
# translate to: s <input.s> <output.ir>

REAL_S="/usr/local/bin/s"
if [ -z "$REAL_S" ]; then
  REAL_S=$(command -v s 2>/dev/null || true)
fi

if [ "$1" = "ir" ]; then
  shift
  # handle: <input> -o <output>
  input="$1"
  shift
  if [ "$1" = "-o" ]; then
    shift
    output="$1"
    exec "$REAL_S" "$input" "$output"
  else
    # fallback: pass through
    exec "$REAL_S" ir "$input" "$@"
  fi
else
  exec "$REAL_S" "$@"
fi
