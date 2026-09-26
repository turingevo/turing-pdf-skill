# turing-pdf-skill

Agent skill：包装 `turing-pdf` 命令行工具，把 PDF 里的文字翻译并按原版式回填，产出单语或双语 PDF。

- `SKILL.md`：给 agent 的执行说明（何时触发、怎么调用、怎么判断成功）。
- `scripts/translate.sh`：薄封装，按顺序定位 `turing-pdf` 并原样透传参数。

## 安装到你的 agent

把本仓库（至少 `SKILL.md` 与 `scripts/`）放进 agent 的 skills 目录。目录结构大致为：

```
turing-pdf-skill/
├── SKILL.md
└── scripts/
    └── translate.sh
```

## 先拿到 CLI

本 skill 只是外壳，真正的引擎是 `turing-pdf` 命令行工具。从**本仓库的 Releases**
下载对应平台的压缩包：

| 平台 | 资产 |
|---|---|
| Linux x86_64 | `turing-pdf-cli-linux-x86_64.tar.gz` |
| Windows x86_64 | `turing-pdf-cli-windows-x86_64.tar.gz` |
| macOS（Apple Silicon） | `turing-pdf-cli-macos-aarch64.tar.gz` |

解压得到 `turing-pdf`（Windows 为 `turing-pdf.exe`），三选一让它可被找到：

1. 放进 `PATH`；
2. 放到本 skill 的 `bin/` 目录；
3. 用环境变量指定：`export TURING_PDF_BIN=/绝对路径/turing-pdf`。

## 还要一个翻译端点

`turing-pdf` 是 HTTP 客户端，**必须给一个 OpenAI 兼容的 `/v1/chat/completions` 端点**：

- 远程服务：`--translate-url https://…/v1/chat/completions --api-key …`；或
- 本机跑的 llama-server：`--translate-url http://127.0.0.1:8888/v1/chat/completions`。

本 skill **不含模型，也不负责启动 llama-server**；本地服务请自行拉起。

## 示例

```bash
scripts/translate.sh --input in.pdf \
  --translate-url http://127.0.0.1:8888/v1/chat/completions \
  --model local-model \
  --all --layout dual-wide \
  --output out.pdf
```

`--layout` 取 `mono` | `dual-wide` | `interleave`（`--bilingual` = dual-wide）。完整参数见
`turing-pdf -h`，或随二进制分发的 `README.md`。

## 许可

- 本仓库的 skill 文本与脚本：**MIT**（见 [`LICENSE`](LICENSE)）。
- **`turing-pdf` 二进制为闭源专有软件**：个人非商业使用免费，商业使用需另行授权。
  其许可与第三方声明随二进制一起分发（压缩包内的 `LICENSE.md` 与 `THIRD-PARTY.md`）。
