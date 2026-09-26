# turing-pdf-skill

Agent skill：包装 `turing-pdf` 命令行工具，把 PDF 里的文字翻译并按原版式回填，产出单语或双语 PDF。
**默认开启版面检测**——PDF 里识别为表格/公式的区域会保留原文，译文不覆盖，版式更干净。

- `SKILL.md`：给 agent 的执行说明（何时触发、怎么调用、怎么判断成功）。
- `scripts/translate.sh`：薄封装，定位 `turing-pdf`、**自动带上版面模型**并原样透传参数。

目录：

1. [安装到你的 agent](#1-安装到你的-agent)
2. [先拿到 CLI](#2-先拿到-cli)
3. [下载版面检测模型（推荐，默认开启）](#3-下载版面检测模型推荐默认开启)
4. [翻译端点（二选一，必须有一个）](#4-翻译端点二选一必须有一个)
5. [推荐用法（默认开启版面检测）](#5-推荐用法默认开启版面检测)
6. [关闭或替换版面检测](#6-关闭或替换版面检测)
7. [许可](#7-许可)

---

## 1. 安装到你的 agent

把本仓库放进 agent 的 skills 目录（至少 `SKILL.md` 与 `scripts/`）：

```
turing-pdf-skill/
├── SKILL.md
├── scripts/translate.sh
└── models/                 # 版面模型放这里（见 §3）
```

## 2. 先拿到 CLI

本 skill 只是外壳，真正的引擎是 `turing-pdf`。从**本仓库的 Releases** 下载对应平台的压缩包：

| 平台 | 资产 |
|---|---|
| Linux x86_64 | `turing-pdf-cli-linux-x86_64.tar.gz` |
| Windows x86_64 | `turing-pdf-cli-windows-x86_64.tar.gz` |
| macOS（Apple Silicon） | `turing-pdf-cli-macos-aarch64.tar.gz` |

解压后是一个目录：

```
turing-pdf            # 主程序（Windows 为 turing-pdf.exe）
resources/            # 版面检测用的 ONNX Runtime + PDFium 动态库
LICENSE.md  THIRD-PARTY.md  README.md
```

让 CLI 可被找到，三选一（**切记 `resources/` 要和 `turing-pdf` 同目录**）：

1. 放进 `PATH`（如 `~/.local/bin`）——连 `resources/` 一起放；
2. 放到本 skill 的 `bin/`（`bin/turing-pdf` + `bin/resources/`）；
3. `export TURING_PDF_BIN=/绝对路径/turing-pdf`。

验证：`turing-pdf -h` 能打印用法即成功。

## 3. 下载版面检测模型（推荐，默认开启）

**推荐直接开启版面检测**：PDF 里识别为表格/公式的区域会保留原文，译文不覆盖，成品更干净。
只需下载一次模型：

- 仓库页：<https://www.modelscope.cn/models/PaddlePaddle/PP-DocLayoutV3_onnx>
- 文件：`inference.onnx`（PP-DocLayoutV3，Apache-2.0，约 130 MB）
- 直达页：<https://www.modelscope.cn/models/PaddlePaddle/PP-DocLayoutV3_onnx/file/view/master/inference.onnx>

放到**本 skill 的 `models/`**，命名 `PP-DocLayoutV3.onnx`：

```
turing-pdf-skill/models/PP-DocLayoutV3.onnx
```

这样 `scripts/translate.sh` 会**自动启用**版面检测，无需每次传参。

> 也可存到别处，用环境变量 `TURING_PDF_LAYOUT_MODEL=/path/xxx.onnx` 指定（见 §6）。

## 4. 翻译端点（二选一，必须有一个）

`turing-pdf` 是 HTTP 客户端，**必须给它一个 OpenAI 兼容的 `/v1/chat/completions` 端点**——
远程服务，或你在本机跑起来的 llama-server。

### 4.1 推荐：TuringEvo 托管服务（开箱即用，原文会离开本机）

1. 打开 **<https://api.turingevo.com>**，注册账号；
2. 到 **<https://api.turingevo.com/pricing>** 购买/领取 Token，拿到 **API Key**；
3. 调用时填三项：

   | 项 | 值 |
   |---|---|
   | 端点 | `https://api.turingevo.com/v1/chat/completions` |
   | 模型 | `tencent/Hunyuan-MT-7B` |
   | API Key | 你的 key |

> 交流群：QQ `873673497`。

### 4.2 本地：自备 llama-server + 腾讯翻译模型 GGUF（离线，原文不出本机）

需要一个 `llama-server`（到 [llama.cpp 发行页](https://github.com/ggml-org/llama.cpp/releases/latest)
下载与你系统/硬件匹配的构建，解压即得 `llama-server` 及其依赖库）。

**① 下载模型**（ModelScope，约 4.5 GB，Q4_K_M 量化）：

- 仓库页：<https://www.modelscope.cn/models/Tencent-Hunyuan/Hy-MT2-7B-GGUF>
- 文件：`Hy-MT2-7B-Q4_K_M.gguf`
- 直达页：<https://www.modelscope.cn/models/Tencent-Hunyuan/Hy-MT2-7B-GGUF/file/view/master/Hy-MT2-7B-Q4_K_M.gguf>

**② 启动本地服务**（把路径换成你下载的 `.gguf`；有 GPU 加 `--n-gpu-layers 99`）：

```bash
llama-server \
  --model /path/to/Hy-MT2-7B-Q4_K_M.gguf \
  --host 127.0.0.1 --port 8888 \
  --ctx-size 12288 --threads 16 --n-gpu-layers 99
```

**③ 确认就绪**：`GET http://127.0.0.1:8888/health` 返回 **200**（模型加载中返回 503）：

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8888/health   # 期望 200
```

**④ 用它翻译**（本地服务的模型名不参与路由，固定发 `local-model` 即可）：

```bash
turing-pdf --input in.pdf --all --layout dual-wide --output out.pdf \
  --translate-url http://127.0.0.1:8888/v1/chat/completions \
  --model local-model \
  --layout-model models/PP-DocLayoutV3.onnx
```

## 5. 推荐用法（默认开启版面检测）

**方式 A：封装脚本**（`scripts/translate.sh` 会在 `models/` 里找到版面模型并自动加上）：

```bash
# 托管服务
scripts/translate.sh --input in.pdf \
  --translate-url https://api.turingevo.com/v1/chat/completions \
  --model tencent/Hunyuan-MT-7B --api-key "$TURINGEVO_KEY" \
  --all --layout dual-wide --output out.pdf

# 本地 llama-server，只翻 1–10 页
scripts/translate.sh --input in.pdf \
  --translate-url http://127.0.0.1:8888/v1/chat/completions \
  --model local-model --pages 1-10 --layout dual-wide --output out.pdf
```

**方式 B：直接调 CLI**（自己带上 `--layout-model`）：

```bash
turing-pdf --input in.pdf \
  --translate-url https://api.turingevo.com/v1/chat/completions \
  --model tencent/Hunyuan-MT-7B --api-key "$TURINGEVO_KEY" \
  --all --layout dual-wide \
  --layout-model /path/to/models/PP-DocLayoutV3.onnx \
  --output out.pdf
```

- `--layout` 取 `mono`（覆盖原文）| `dual-wide`（整页双联，`--bilingual` 同义）| `interleave`（上下对照）。
- `--pages all|N|A-B` 选页；`--jobs N` 并发；`--timeout S` 单请求超时。
- 只导出结构不翻译：`--dump-blocks --json`、`--boxes --json`。
- 完整参数见 `turing-pdf -h`，或随二进制分发的 `README.md`。

## 6. 关闭或替换版面检测

| 想要 | 怎么做 |
|---|---|
| **关闭** | 直接调 CLI 时**不加** `--layout-model`；用封装脚本时 `export TURING_PDF_LAYOUT_MODEL=off` |
| **换模型 / 换位置** | `export TURING_PDF_LAYOUT_MODEL=/path/xxx.onnx`（不存在会告警并退回纯翻译）|
| **走远程版面服务** | 给 CLI 传 `--layout-api <URL>`（此时**不要**再给 `--layout-model`）|

> 版面检测的动态库（ONNX Runtime / PDFium）已在 `resources/` 随包，无需另配；**别把它和
> `turing-pdf` 分开**。基础翻译本身不需要这些库。

## 7. 许可

- 本仓库的 skill 文本与脚本：**MIT**（见 [`LICENSE`](LICENSE)）。
- **`turing-pdf` 二进制为闭源专有软件**：个人非商业使用免费，商业使用需另行授权。
  其许可与第三方声明随二进制一起分发（压缩包内的 `LICENSE.md` 与 `THIRD-PARTY.md`）。
