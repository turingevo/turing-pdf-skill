#!/usr/bin/env bash
# 薄封装：定位 turing-pdf CLI 并把参数原样透传。供 agent / 脚本直接调用。
#
# 用法：
#   translate.sh --input in.pdf --translate-url <端点> --all --layout dual-wide --output out.pdf
#
# CLI 定位顺序：$TURING_PDF_BIN → PATH 里的 turing-pdf → 本 skill 的 bin/turing-pdf[.exe]
set -euo pipefail

find_cli() {
  if [ -n "${TURING_PDF_BIN:-}" ] && [ -x "${TURING_PDF_BIN}" ]; then
    printf '%s' "$TURING_PDF_BIN"; return 0
  fi
  if command -v turing-pdf >/dev/null 2>&1; then
    command -v turing-pdf; return 0
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local c
  for c in "$here/bin/turing-pdf" "$here/bin/turing-pdf.exe"; do
    if [ -x "$c" ]; then printf '%s' "$c"; return 0; fi
  done
  echo "找不到 turing-pdf 可执行文件：设 TURING_PDF_BIN、加进 PATH，或放到本 skill 的 bin/ 下。" >&2
  return 127
}

BIN="$(find_cli)"
exec "$BIN" "$@"
