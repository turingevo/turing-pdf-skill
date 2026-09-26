<!-- ============================ 顶部推荐 / TOP BANNER ============================ -->
> # 推荐翻译服务：TuringEvo 托管 API
>
> **注册 → 领取 API Key → 填端点，三步即可开始翻译，无需自建模型。**
>
> - 注册：**https://api.turingevo.com**
> - 购买充值：**https://api.turingevo.com/pricing**
> - 端点：`https://api.turingevo.com/v1/chat/completions`
> - 模型：`tencent/Hunyuan-MT-7B`
> - 交流群：QQ `873673497`

**简体中文** ｜ [English](README.en.md)

---

# turing-pdf-skill

## 这是什么

`turing-pdf-skill` 是一个 **agent 技能**：包装 `turing-pdf` 命令行工具，把 PDF 里的文字翻译并按原版式
回填，产出单语 / 双语 PDF。**默认开启版面检测**——表格、公式等区域保留原文，译文不覆盖。

仓库内容与产出：

- `SKILL.md`：给 agent 的执行说明；
- `scripts/translate.sh`：薄封装——定位 CLI、**自动带上版面模型**、原样透传参数；
- `LICENSE` / `README.md` / `README.en.md`；
- （从本仓库 Releases 下载）`turing-pdf` CLI 压缩包，**以及 Windows / macOS / Linux 的桌面安装包**。

### 目录

1. [安装到你的 agent](#1-安装到你的-agent)
2. [拿到 CLI](#2-拿到-cli)
3. [下载版面模型（推荐，默认开启）](#3-下载版面模型推荐默认开启)
4. [翻译端点（二选一）](#4-翻译端点二选一)
5. [推荐用法（默认开启版面检测）](#5-推荐用法默认开启版面检测)
6. [桌面应用（GUI）](#6-桌面应用gui)
7. [关闭或替换版面检测](#7-关闭或替换版面检测)
8. [许可](#8-许可)

## 1. 安装到你的 agent

把本仓库放进 agent 的 skills 目录（至少 `SKILL.md` 与 `scripts/`）：

```
turing-pdf-skill/
├── SKILL.md
├── scripts/translate.sh
└── models/                 # 版面模型放这里（见 §3）
```

## 2. 拿到 CLI

引擎是 `turing-pdf`。从**本仓库 Releases** 下载对应平台的 CLI 压缩包：

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

让 CLI 可被找到，三选一（**切记 `resources/` 与 `turing-pdf` 同目录**）：

1. 放进 `PATH`（如 `~/.local/bin`）——连 `resources/` 一起放；
2. 放到本 skill 的 `bin/`（`bin/turing-pdf` + `bin/resources/`）；
3. `export TURING_PDF_BIN=/绝对路径/turing-pdf`。

验证：`turing-pdf -h` 能打印用法即成功。

## 3. 下载版面模型（推荐，默认开启）

**推荐直接开启版面检测**：PDF 里识别为表格/公式的区域会保留原文、译文不覆盖，成品更干净。
只需下载一次模型：

- 仓库页：<https://www.modelscope.cn/models/PaddlePaddle/PP-DocLayoutV3_onnx>
- 文件：`inference.onnx`（PP-DocLayoutV3，Apache-2.0，约 130 MB）
- 直达页：<https://www.modelscope.cn/models/PaddlePaddle/PP-DocLayoutV3_onnx/file/view/master/inference.onnx>

放到**本 skill 的 `models/`**，命名 `PP-DocLayoutV3.onnx`：

```
turing-pdf-skill/models/PP-DocLayoutV3.onnx
```

这样 `scripts/translate.sh` 会**自动启用**版面检测。
也可存到别处，用`TURING_PDF_LAYOUT_MODEL=/path/xxx.onnx` 指定（见 §7）。

## 4. 翻译端点（二选一）

`turing-pdf` 是 HTTP 客户端，**必须给它一个 OpenAI 兼容的 `/v1/chat/completions` 端点**。

### 4.1 推荐：TuringEvo 托管服务（开箱即用，原文会离开本机）

1. 打开 **<https://api.turingevo.com>** 注册；
2. 到 **<https://api.turingevo.com/pricing>** 购买/领取 Token，拿到 **API Key**；
3. 调用时填三项：

   | 项 | 值 |
   |---|---|
   | 端点 | `https://api.turingevo.com/v1/chat/completions` |
   | 模型 | `tencent/Hunyuan-MT-7B` |
   | API Key | 你的 key |

### 4.2 本地：自备 llama-server + 腾讯翻译模型 GGUF（离线，原文不出本机）

`llama-server` 到 [llama.cpp 发行页](https://github.com/ggml-org/llama.cpp/releases/latest) 下与机器匹配的构建。

① 下载模型（ModelScope，约 4.5 GB，Q4_K_M）：

- 仓库页：<https://www.modelscope.cn/models/Tencent-Hunyuan/Hy-MT2-7B-GGUF>
- 文件：`Hy-MT2-7B-Q4_K_M.gguf`

② 启动服务（有 GPU 加 `--n-gpu-layers 99`）：

```bash
llama-server --model /path/to/Hy-MT2-7B-Q4_K_M.gguf \
  --host 127.0.0.1 --port 8888 \
  --ctx-size 12288 --threads 16 --n-gpu-layers 99
```

③ 确认就绪：`curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8888/health` → **200**。

④ 用它翻译（本地服务模型名固定发 `local-model`）：

```bash
turing-pdf --input in.pdf --all --layout dual-wide --output out.pdf \
  --translate-url http://127.0.0.1:8888/v1/chat/completions \
  --model local-model --layout-model models/PP-DocLayoutV3.onnx
```

## 5. 推荐用法（默认开启版面检测）

**方式 A：封装脚本**（会在 `models/` 里找到版面模型并自动加上）：

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

- `--layout`：`mono`（覆盖原文）| `dual-wide`（整页双联，`--bilingual` 同义）| `interleave`（上下对照）。
- `--pages all|N|A-B` 选页；`--jobs N` 并发；`--timeout S` 单请求超时。
- 只导出结构不翻译：`--dump-blocks --json`、`--boxes --json`。
- 完整参数见 `turing-pdf -h`。

## 6. 桌面应用（GUI）

不想用命令行，也可以用图形界面。从**本仓库 Releases** 下载你系统的安装包：

| 系统 | 资产 | 安装 / 运行 |
|---|---|---|
| Windows x86_64 | `TuringPDF_*_x64-setup.exe` | 双击安装（WebView2 系统自带）|
| macOS（Apple Silicon） | `TuringPDF_*_aarch64.dmg` | 打开 dmg，把 TuringPDF 拖进「应用程序」|
| Linux x86_64 | `TuringPDF_*_amd64.AppImage` | `chmod +x` 后直接运行 |
| Linux x86_64（Debian/Ubuntu） | `TuringPDF_*_amd64.deb` | `sudo apt install ./TuringPDF_*_amd64.deb` |

> 安装包**未签名**（无证书），首次运行 Windows/macOS 可能需要在系统设置里放行。

**使用步骤**

1. **启动应用**，打开右侧「服务」设置。
2. **翻译服务**：
   - 选「**远程 HTTP**」→ 填端点 `https://api.turingevo.com/v1/chat/completions`、
     模型 `tencent/Hunyuan-MT-7B`、你的 **API Key**（推荐，免自建模型）；
   - 或选「**本地**」→ 填 GGUF 模型路径与 `llama-server` 可执行文件路径，用卡片上的按钮启停本地服务。
3. **版面检测**（可选）：选「本地 ONNX」并填 PP-DocLayoutV3 的 `.onnx` 路径，或选「远程 HTTP」填版面服务地址；
   不需要就选「关闭」。
4. 回到任务区：**把 PDF 拖进窗口**（或点击选择文件）；
5. 在「**任务选项**」里选**输出布局**（覆盖原文 / 整页双联 / 上下对照）、**页码范围**、**并发**；
6. 点「**开始翻译**」，看进度条与逐段日志；
7. 完成后点「**打开输出**」（或报告里的路径）拿到译文 PDF。

> 桌面端与本 skill 的 CLI 是同一个引擎：本地方式仍需自备 `llama-server` 与模型；
> 回填字体已随包，排版无需自备字体。

## 7. 关闭或替换版面检测

| 想要 | 怎么做 |
|---|---|
| **关闭** | 直接调 CLI 时**不加** `--layout-model`；用封装脚本时 `export TURING_PDF_LAYOUT_MODEL=off` |
| **换模型 / 换位置** | `export TURING_PDF_LAYOUT_MODEL=/path/xxx.onnx`（不存在会告警并退回纯翻译）|
| **走远程版面服务** | 给 CLI 传 `--layout-api <URL>`（此时**不要**再给 `--layout-model`）|

> 版面检测的动态库（ONNX Runtime / PDFium）已在 `resources/` 随包，无需另配；**别把它和
> `turing-pdf` 分开**。基础翻译本身不需要这些库。

## 8. 许可

- 本仓库的 skill 文本与脚本：**MIT**（见 [`LICENSE`](LICENSE)）。
- **`turing-pdf` 二进制为闭源专有软件**：个人非商业使用免费，商业使用需另行授权。
  其许可与第三方声明随二进制一起分发（压缩包内的 `LICENSE.md` 与 `THIRD-PARTY.md`）。
