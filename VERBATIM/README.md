# VERBATIM

> 说话，文字直接出现在光标处。无需切换窗口，无需动手。

[![⬇ 下载 macOS 安装包](https://img.shields.io/badge/⬇_下载-macOS_v1.0.0-2060C8?style=for-the-badge)](https://github.com/Tengxiaoteng/VERBATIM/releases/latest/download/VERBATIM-v1.0.0-macos.zip)

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 为什么用 VERBATIM？

**打字太慢** — 说话比打字快 3 倍。长段文字、会议记录、备忘录，直接说出来，实时转文字。

**手不离键盘** — 在任何应用里按住 `Option+Space`，松开后文字已经粘贴好，不用切窗口、不用点击任何按钮。

**中文识别准** — 支持讯飞、SiliconFlow 等专为中文优化的服务，标点自动加，说完即可用。

---

## 截图

<table>
  <tr>
    <td><img src="screenshots/settings.png" width="380"/><br/><sub>多种识别服务可选</sub></td>
    <td><img src="screenshots/prompts.png" width="380"/><br/><sub>自定义 LLM 后处理</sub></td>
  </tr>
</table>

---

## 快速安装

```
1. brew install sox
2. 下载解压 → VERBATIM.app 拖入应用程序
3. 首次启动按提示授权麦克风 + 辅助功能
4. 按住 Option+Space 说话，松开自动粘贴
```

---

## 支持的 ASR 服务

| 服务 | 凭证格式 | 获取地址 |
|------|----------|----------|
| 本地 FunASR（离线） | 无需 Key | — |
| OpenAI Whisper | `sk-...` | platform.openai.com |
| Groq | `gsk_...` | console.groq.com |
| SiliconFlow | `sf-...` | siliconflow.cn |
| 讯飞 iFlytek | `AppID:APIKey:APISecret` | console.xfyun.cn |
| 自定义 OpenAI 兼容 | 任意 | — |

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

## License

MIT © 2025 Tengxiaoteng
