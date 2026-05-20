#!/usr/bin/env bash

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates"

contains_any() {
  local haystack="$1"
  shift
  local needle
  for needle in "$@"; do
    if [[ "$haystack" == *"$needle"* ]]; then
      return 0
    fi
  done
  return 1
}

infer_template_completion() {
  local text="$1"
  local wants_hello=""
  if contains_any "$text" "hello" "hello world" "hello, world" "helloworld"; then
    wants_hello="1"
  fi

  if contains_any "$text" "c++" "cpp"; then
    if [[ -n "$wants_hello" ]] || contains_any "$text" "hello示例" "hello example" "hello程序"; then
      cat "${TEMPLATE_DIR}/cpp_hello.txt"
      return 0
    fi
  fi

  if [[ "$text" == *"python"* ]] && [[ -n "$wants_hello" ]]; then
    cat "${TEMPLATE_DIR}/python_hello.txt"
    return 0
  fi

  if [[ "$text" == *"java"* ]] && [[ -n "$wants_hello" ]]; then
    cat "${TEMPLATE_DIR}/java_hello.txt"
    return 0
  fi

  if [[ "$text" == *"qml"* ]] && [[ -n "$wants_hello" ]]; then
    cat "${TEMPLATE_DIR}/qml_hello.txt"
    return 0
  fi

  if contains_any "$text" "bash" "shell" "sh"; then
    if [[ -n "$wants_hello" ]]; then
      cat "${TEMPLATE_DIR}/bash_hello.txt"
      return 0
    fi
  fi

  if [[ "$text" == *"html"* ]] && [[ -n "$wants_hello" ]]; then
    cat "${TEMPLATE_DIR}/html_hello.txt"
    return 0
  fi

  if [[ "$text" == *"sql"* ]] && [[ -n "$wants_hello" ]]; then
    cat "${TEMPLATE_DIR}/sql_hello.txt"
    return 0
  fi

  return 1
}
