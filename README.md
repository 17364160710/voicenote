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

推上去后 GitHub Actions 自动跑，约 3~5 分钟。两种拿包方式：

- **免登录直链**：Releases 页面的 `build-latest` 标签下有 `VoiceNote-unsigned.ipa`，链接形如
  `https://github.com/<账号>/<仓库>/releases/download/build-latest/VoiceNote-unsigned.ipa`
- **Artifacts**：Actions → 这次运行 → Artifacts → `VoiceNote-unsigned-ipa`（zip，解压得 ipa）

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

1. **TrollStore**（iOS 14.0 ~ 16.6.1 首选）：把 ipa 传到手机，用 TrollStore 打开安装，永久有效，它会自动做 ad-hoc 签名
2. **AppSync Unified + Filza**：装了 AppSync 后，Filza 里点 ipa 直接安装
3. **命令行**：`ipainstaller VoiceNote-unsigned.ipa`（越狱包管理器里装 `ipainstaller`）

国内直连 GitHub Release 经常被重置，下载时给链接加个镜像前缀即可：

```
https://gh-proxy.com/https://github.com/17364160710/voicenote/releases/download/build-latest/VoiceNote-unsigned.ipa
```

**装完打不开 / 一闪退**：说明设备对签名校验更严（A12 以上带 PAC）。两个办法：
- 用 TrollStore 装（它负责签名）
- 或者在电脑上重新 fakesign 再打包：

```bash
unzip VoiceNote-unsigned.ipa -d tmp
ldid -S tmp/Payload/VoiceNote.app/VoiceNote
cd tmp && zip -qry ../VoiceNote-signed.ipa Payload
```

首次进入 App 会请求「麦克风」和「语音识别」权限。如果越狱环境下弹窗被吞掉，去 设置 → 隐私 里手动打开，或在 App 内提示页点「去设置」。

## 数据与卸载（重要）

### 数据只写在一个地方

App 的所有持久化数据都在自己的沙盒内，不写沙盒外、不写 UserDefaults、不写钥匙串：

```
Documents/notes.json     备忘索引（标题、转写文字、时间、时长）
Documents/Audio/*.caf    录音文件，一条备忘一个文件
```

### 四道删除保障

| 场景 | 行为 |
|---|---|
| 列表左滑 → 点「删除」 | 弹出二次确认（标题 + 「录音与文字一并删除」），确认后才删。`allowsFullSwipe: false` 关掉了整条滑到底直接删的手势 |
| 详情页右上角垃圾桶 | 同样是二次确认后才删 |
| 清空所有备忘（右上角 `⋯` → 清空所有备忘） | 删光全部录音 + 删除索引文件，二次确认里会显示条数与占用大小 |
| 启动时自动清理孤儿文件 | 录音途中 App 被杀进程会留下没有对应备忘的 `.caf`，每次启动扫描并删除。**索引读取失败时跳过清理**，避免误删 |

### 卸载

**iOS 的机制本身就会在卸载 App 时整体删除它的沙盒容器**——`notes.json` 和所有 `.caf` 都会一起消失，不需要 App 自己做任何事。TrollStore、AppSync + Filza、`ipainstaller` 三种装法的行为一致。

唯一会残留的是**系统级的隐私授权记录**（TCC），不在 App 沙盒里，任何 App 卸载都不会清它：

- 常规做法：设置 → 隐私与安全性 → 麦克风 / 语音识别，里面的「语音速记」条目会被系统标记为失效，重装后继续沿用
- 想彻底抹掉：越狱机 SSH 进去清 `TCC.db` 里 `com.stiker.voicenote` 的记录，一般没必要

如果越狱工具异常卸载导致容器没被删（极少见），可以手动定位后删除：

```bash
# 用 root 或 mobile 身份执行
grep -rl "com.stiker.voicenote" /var/mobile/Containers/Data/Application/*/.com.apple.mobile_container_manager.metadata.plist
# 输出里那一串 UUID 目录就是容器，直接删掉
rm -rf /var/mobile/Containers/Data/Application/<UUID>
```

## 已知限制

- **未签名包的能力边界**：拿不到 APNs 推送、iCloud 同步、HealthKit 等需要 entitlement 的能力；本 App 全部是本地功能，不受影响
- **停止录音时可能丢最后一两个字**：结束瞬间会中止识别任务，转写内容以停止前已返回的部分结果为准
- **离线识别依赖设备**：`SFSpeechRecognizer.supportsOnDeviceRecognition` 为真时才强制本地识别，否则走系统在线识别（需要网络）
- **部署目标 iOS 15.0**：要支持更低版本需改 `project.yml` 里的 `deploymentTarget`，同时检查用到的 API

## 版本

v1.2.0 — 删除改为二次确认，左滑不再支持整条滑动直删
v1.1.0 — 增加孤儿文件清理、清空全部数据、磁盘占用显示
v1.0.0 — 首个可安装版本
