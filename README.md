# 语音速记 VoiceNote

一个纯本地的 iOS 语音速记 App：边说话边实时转写中文，录音与文字一起存档，可回放、编辑、复制、分享。不联网也可以识别（设备支持离线识别时自动启用）。

## 功能

- **实时转写**：`AVAudioEngine` 采到的同一路音频，一边写进 `AVAudioFile`，一边喂给 `SFSpeechRecognizer`，所以录音和文字天然对齐
- **波形反馈**：把 RMS 响度换算成 0~1 的柱状波形，随声音跳动
- **自动标题**：取转写内容的头 18 个字作为标题
- **列表**：按时间倒序，支持搜索标题/正文、左滑删除
- **详情**：回放录音、进度条、文字可直接改（返回时自动保存）、一键复制、系统分享
- **纯本地存储**：`Documents/notes.json` + `Documents/Audio/*.caf`，无账号、无服务器

## 目录结构

```
project.yml                      XcodeGen 工程描述（不提交 .xcodeproj）
.github/workflows/build-ipa.yml  macOS runner 编译 + 打包无签名 IPA
tools/make_icon.py               纯标准库生成 1024 图标
VoiceNote/
  App/VoiceNoteApp.swift
  Models/Note.swift
  Store/NoteStore.swift          JSON 持久化 + 音频文件管理
  Audio/VoiceRecorder.swift      录音 + 实时转写（核心）
  Audio/AudioPlayback.swift      AVAudioPlayer 封装
  Views/NoteListView.swift
  Views/RecordingView.swift
  Views/NoteDetailView.swift
  Views/Components/          波形、录音按钮、分享面板
  Resources/Info.plist          权限文案
  Resources/Assets.xcassets     AppIcon / AccentColor
```

## 构建

工程文件由 XcodeGen 生成，仓库里只放 `project.yml`（避免手写 pbxproj 冲突）。

**云端（推荐，无需 Mac / 无需 Apple 账号）**

```bash
git init && git add -A && git commit -m "feat: 语音速记 v1"
git remote add origin https://github.com/<你的账号>/voicenote.git
git push -u origin main
```

推上去后 GitHub Actions 自动跑，约 3~5 分钟，在 Actions → 这次运行 → Artifacts 下载 `VoiceNote-unsigned-ipa`，里面就是 `VoiceNote-unsigned.ipa`。

**本地（有 Mac 时）**

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project VoiceNote.xcodeproj -scheme VoiceNote \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## 安装到越狱设备

产物是**未签名** IPA，靠越狱环境绕过签名校验：

1. **TrollStore**（iOS 14.0 ~ 16.6.1 首选）：把 ipa 传到手机，用 TrollStore 打开安装，永久有效
2. **AppSync Unified + Filza**：装了 AppSync 后，Filza 里点 ipa 直接安装
3. **命令行**：`ipainstaller VoiceNote-unsigned.ipa`（越狱包管理器里装 `ipainstaller`）

首次进入 App 会请求「麦克风」和「语音识别」权限。如果越狱环境下弹窗被吞掉，去 设置 → 隐私 里手动打开，或在 App 内提示页点「去设置」。

## 已知限制

- **未签名包的能力边界**：拿不到 APNs 推送、iCloud 同步、HealthKit 等需要 entitlement 的能力；本 App 全部是本地功能，不受影响
- **停止录音时可能丢最后一两个字**：结束瞬间会中止识别任务，转写内容以停止前已返回的部分结果为准
- **离线识别依赖设备**：`SFSpeechRecognizer.supportsOnDeviceRecognition` 为真时才强制本地识别，否则走系统在线识别（需要网络）
- **部署目标 iOS 15.0**：要支持更低版本需改 `project.yml` 里的 `deploymentTarget`，同时检查用到的 API

## 版本

v1.0.0 — 首个可安装版本
