#!/usr/bin/env bash
# 薄封装：定位 turing-pdf CLI 并把参数透传。供 agent / 脚本直接调用。
#
# 默认行为：**自动开启版面检测** —— 调用方没给 --layout-model / --layout-api 时，
#   只要找得到版面模型，就自动补上 --layout-model。模型来源（按优先级）：
#     1) $TURING_PDF_LAYOUT_MODEL
#          - 填路径  → 用这个模型（不存在则告警并退回纯翻译）
#          - 填 off / none / 0 → 显式关闭，不加
#     2) 未设置（或为空）→ 用本 skill 自带的 models/PP-DocLayoutV3.onnx 或 models/inference.onnx
#   都找不到就退回纯翻译（不加该参数）。
#
# 用法：
#   translate.sh --input in.pdf --translate-url <端点> --all --layout dual-wide --output out.pdf
#
# CLI 定位顺序：$TURING_PDF_BIN → PATH 里的 turing-pdf → 本 skill 的 bin/turing-pdf[.exe]
set -euo pipefail

SKILL_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_cli() {
  if [ -n "${TURING_PDF_BIN:-}" ] && [ -x "${TURING_PDF_BIN}" ]; then
    printf '%s' "$TURING_PDF_BIN"; return 0
  fi
  if command -v turing-pdf >/dev/null 2>&1; then
    command -v turing-pdf; return 0
  fi
  local c
  for c in "$SKILL_HOME/bin/turing-pdf" "$SKILL_HOME/bin/turing-pdf.exe"; do
    if [ -x "$c" ]; then printf '%s' "$c"; return 0; fi
  done
  echo "找不到 turing-pdf 可执行文件：设 TURING_PDF_BIN、加进 PATH，或放到本 skill 的 bin/ 下。" >&2
  return 127
}

# 调用方已显式指定版面检测参数时，不插手。
has_layout_flag=0
for a in "$@"; do
  case "$a" in
    --layout-model|--layout-api) has_layout_flag=1 ;;
  esac
done

layout_args=()
if [ "$has_layout_flag" = 0 ]; then
  env_mdl="${TURING_PDF_LAYOUT_MODEL-__unset__}"
  case "$env_mdl" in
    off|none|0)
      : ;;   # 显式关闭
    __unset__|"")
      for cand in "$SKILL_HOME/models/PP-DocLayoutV3.onnx" "$SKILL_HOME/models/inference.onnx"; do
        if [ -f "$cand" ]; then layout_args=(--layout-model "$cand"); break; fi
      done
      ;;
    *)
      if [ -f "$env_mdl" ]; then
        layout_args=(--layout-model "$env_mdl")
      else
        echo "警告：TURING_PDF_LAYOUT_MODEL=$env_mdl 不存在，本次退回纯翻译（不启用版面检测）" >&2
      fi
      ;;
  esac
fi

BIN="$(find_cli)"
if [ "${#layout_args[@]}" -gt 0 ]; then
  exec "$BIN" "${layout_args[@]}" "$@"
fi
exec "$BIN" "$@"
