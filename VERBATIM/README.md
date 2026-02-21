# VERBATIM

> macOS 全局语音输入工具 — 按住快捷键录音，松开后自动识别并粘贴到当前光标位置。

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 功能

- **全局快捷键**：按住 `Option + Space`（可自定义）触发录音，松开立即识别
- **多种 ASR 来源**：
  - 本地 FunASR（离线，隐私保护）
  - OpenAI Whisper
  - Groq（免费额度）
  - SiliconFlow（中文优化）
  - 讯飞 iFlytek IAT（中文优秀）
  - 自定义兼容 OpenAI 接口的服务
- **LLM 后处理**：识别文本可选择直接输出 / 逻辑优化 / Code 模式 / 自定义提示词
- **自动粘贴**：识别完成后直接粘贴到原来的光标位置，无需切换窗口
- **历史记录**：查看并复制历史识别结果
- **系统托盘**：最小化到状态栏，常驻后台

---

## 系统要求

- macOS 12+
- Flutter stable 3.38+（含 Dart 3.10+）
- Xcode 15+
- SoX（提供 `rec` 录音命令）

---

## 快速开始

### 1. 安装依赖

```bash
brew install sox
flutter pub get
```

### 2. 运行

```bash
flutter run -d macos
```

首次启动会弹出配置向导，引导你选择 ASR 服务并授予权限。

### 3. 构建发布版

```bash
flutter build macos --release
```

产物位于 `build/macos/Build/Products/Release/VERBATIM.app`。

---

## 权限配置（重要）

应用需要以下两项权限方能正常工作：

| 权限 | 用途 | 配置路径 |
|------|------|----------|
| 麦克风 | 录音 | 系统设置 → 隐私与安全性 → 麦克风 |
| 辅助功能 | 自动粘贴 | 系统设置 → 隐私与安全性 → 辅助功能 |

> 如果自动粘贴失败，尝试在辅助功能列表中删除 VERBATIM 并重新添加。

---

## ASR 服务配置

### 本地 FunASR（离线推荐）

应用内置 FunASR 服务端脚本，可在本机运行：

```bash
# 安装依赖（需要 Python 3.8+）
pip install funasr modelscope flask

# 下载模型（首次需要，约 1GB）
python assets/download_models.py

# 启动服务
python assets/funasr_server.py
```

服务默认监听 `http://localhost:10095`。

### 云端服务

在设置中填入对应 API Key：

| 服务 | 凭证格式 | 获取地址 |
|------|----------|----------|
| OpenAI Whisper | `sk-...` | platform.openai.com |
| Groq | `gsk_...` | console.groq.com |
| SiliconFlow | `sf-...` | siliconflow.cn |
| 讯飞 iFlytek | `AppID:APIKey:APISecret` | console.xfyun.cn |
| 自定义 | 任意 | — |

---

## LLM 后处理

在设置中配置 OpenAI 兼容接口（或留空跳过后处理）：

- **直接输出**：原始识别文本，不做修改
- **逻辑优化**：修正标点、语序，使文本更流畅
- **Code 模式**：将语音描述转为代码片段
- **自定义提示词**：可添加、删除自定义处理指令

---

## 项目结构

```
lib/
├── app.dart              # 核心逻辑（录音、识别、粘贴）
├── main.dart             # 入口
├── models/               # 数据模型（AsrProvider、AppSettings 等）
├── screens/              # 界面（主悬浮条、设置、历史、结果弹窗）
├── services/             # ASR / LLM 服务（HTTP / WebSocket）
├── theme/                # 设计系统（AppTheme 颜色常量）
└── widgets/              # 通用组件（GlassCard、GlassSwitch）
assets/
├── funasr_server.py      # 本地 FunASR HTTP 服务
├── download_models.py    # 模型下载脚本
└── tray_icon.png         # 系统托盘图标
```

---

## 常见问题

**Q: 报错"未找到 rec 命令"**
A: 执行 `brew install sox`，然后确认 `which rec` 有输出。

**Q: 录音正常但识别失败（本地 FunASR）**
A: 确认服务已启动：`curl http://localhost:10095/health` 应返回 200。

**Q: 识别成功但未粘贴**
A: 检查辅助功能权限；在系统设置中将 VERBATIM 条目删除后重新添加。

**Q: 讯飞凭证格式**
A: 在 [console.xfyun.cn](https://console.xfyun.cn) 创建应用后，将 AppID、APIKey、APISecret 按 `AppID:APIKey:APISecret` 格式填入。

---

## 开发

```bash
flutter analyze   # 静态分析
flutter test      # 单元测试
```

---

## License

MIT © 2025 Tengxiaoteng
