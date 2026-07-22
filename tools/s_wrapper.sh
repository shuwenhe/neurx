#!/bin/bash

REAL_S="/usr/local/bin/s"
if [ ! -x "$REAL_S" ]; then
  REAL_S=$(command -v s 2>/dev/null || true)
fi

if [ -z "$REAL_S" ] || [ ! -x "$REAL_S" ]; then
  echo "error: could not find an executable 's' compiler" >&2
  exit 1
fi

if [ "$1" = "ir" ]; then
  shift

  input="$1"
  shift
  if [ "$1" = "-o" ]; then
    shift
    output="$1"
    exec "$REAL_S" "$input" "$output"
  else

    exec "$REAL_S" ir "$input" "$@"
  fi
else
  exec "$REAL_S" "$@"
fi
