---
name: turing-pdf-translate
description: 用 turing-pdf CLI 把 PDF 的文字翻译并按原版式回填，产出单语或双语 PDF。当用户说“翻译这个 PDF”“做成中英对照 PDF”“把 PDF 转成中文”等时使用。需要一个 OpenAI 兼容端点（远程服务或本地 llama-server）与本机可用的 turing-pdf 可执行文件。
---

# turing-pdf：PDF 翻译

把 PDF 里的文字块抽出来、送 OpenAI 兼容接口翻译、再按原版式回填到新 PDF。
不直接操作 PDF 内部结构——调用 `turing-pdf` CLI 即可。

## 前置条件（先检查，缺一不可）

1. **CLI 可执行文件**：按顺序取第一个能跑通的：
   - 环境变量 `TURING_PDF_BIN` 指向的路径；
   - `PATH` 里的 `turing-pdf`；
   - 本 skill 目录下的 `bin/turing-pdf`（或 Windows 的 `bin/turing-pdf.exe`）。
   都没有时，从**本仓库的 Releases** 下载对应平台的 `turing-pdf-cli-<平台>.tar.gz`
   （`linux-x86_64` / `windows-x86_64` / `macos-aarch64`），解压得到 `turing-pdf`，
   放进 `PATH` 或本 skill 的 `bin/`。
   先执行 `turing-pdf -h` 验证可用；找不到又下不动就如实告诉用户，不要假装已翻译。
2. **翻译端点**：一个 OpenAI 兼容的 `/v1/chat/completions`，二选一：
   - 远程服务（`https://…`，通常要 `--api-key`）；或
   - 用户本机跑的 llama-server（如 `http://127.0.0.1:8888/v1/chat/completions`）。
   **本工具不提供端点、也不随包模型**。端点拿不到就问用户，别猜一个地址。

## 基本用法

```bash
"$TURING_PDF_BIN" --input <in.pdf> \
  --translate-url <端点> \
  --model <模型名> \
  --all --layout dual-wide \
  --output <out.pdf>
```

- `--layout mono`：覆盖原文（单语）。
  `--layout dual-wide`（推荐，`--bilingual` 同义）：整页双联——左原文、右译文。
  `--layout interleave`：每段原文后紧跟译文。
- `--pages all|N|A-B` 选页；不给 `--output` 则写到输入旁的 `<stem>.zh.pdf`。
- `--jobs N` 并发（默认 4；本地端点可调大）。
- `--api-key K` 仅远程端点需要。

也可用本 skill 的封装脚本（自动定位 CLI）：

```bash
scripts/translate.sh --input in.pdf --translate-url <端点> --all --layout dual-wide --output out.pdf
```

## 目标语言

CLI 本身不传目标语言，由端点决定：远程托管服务看 `--model`；本地 llama-server 看所加载
GGUF 的微调方向。若用户要的目标语言与端点/模型不匹配，如实说明，不要伪装成功。

## 只取结构（不翻译）

```bash
"$TURING_PDF_BIN" --input in.pdf --dump-blocks --json   # 文字块 + 规则
"$TURING_PDF_BIN" --input in.pdf --boxes --json         # 版式框
```

## 版面检测（可选，普通翻译不要加）

默认构建的 CLI 不含版面检测。若确认本机 CLI 是带 `layout` 特性构建的、且用户需要更稳的
表格/公式处理，才加其中之一：

```bash
  --layout-api <远程版面服务 URL>
  --layout-model <PP-DocLayoutV3.onnx> --ort <libonnxruntime.so> --pdfium <libpdfium.so>
```

## 判断成功

- 退出码 `0` 且 stdout 出现 `output: <路径>` → 成功，产物在该路径。
- 非 0 → 失败：把 stderr 最后几行回报给用户（常见：端点不通 / 401 缺 key / 模型未加载 /
  PDF 加密或损坏）。
- 进度行打在 stderr，不是结果。

## 注意

- 翻译会让 PDF 文字**离开本机**（发往端点）；用本地 llama-server 则不出本机。
- 原文件不动，产物是新文件。
- 不保证无损：公式可能降级；`mono` 的原文文字层仍在，不能用于脱敏。
