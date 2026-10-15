# 两个计划（TwoPlans）iOS App

一个用 **SwiftUI** 写的 iOS 原生 App，用来跟踪你的两个年度计划：

1. **AI 学习计划**：计算机基础一年成长计划（12 个月 × 4 周 = 48 周）。
2. **唱歌计划**：零基础流行音乐一年学习计划（前 3 个月按周、第 4–12 月按月）。

起算日固定为 **2026-09-25**（第 1 天），一年为期。App 提供：今日是第几天/第几周/第几月、当前模块、总进度条、今日任务勾选、12 个月进度网格、每日打卡（连续天数 + 最近 8 周方格日历）、以及唱歌计划的每日练习菜单和月度检查点。

> ⚠️ **重要前提**：本工程是在 Windows 上起草的源码，**Windows 本机无法编译 iOS 原生二进制**（需要 macOS + Xcode 工具链）。本仓库是「配套源码 + CI 出包」方案：你在本地 macOS 用 Xcode 打开验证，或交给 GitHub Actions（macOS  runner）一键产出未签名 IPA。

---

## 一、工程结构

```
ios/
├─ project.yml              # XcodeGen 工程描述，一键生成 xcodeproj
├─ build-ipa.yml            # GitHub Actions：产出未签名 IPA（见下）
└─ TwoPlans/
   ├─ Info.plist            # 必要 Info key（显示名「两个计划」等）
   ├─ App.swift             # @main，TabView 两个 Tab
   ├─ Models.swift          # 数据结构 + 两个计划的真实内容
   ├─ DateEngine.swift      # 起算日推算（用 Calendar.startOfDay）
   ├─ PlanView.swift         # 通用计划视图（两个 Tab 共用）
   └─ README.md             # 本文档
```

技术约束（已遵守）：纯 SwiftUI + Foundation，**部署目标 iOS 15.0**，未使用任何第三方依赖，未使用 iOS 16+ 才有的 API（`NavigationStack` 的 path 绑定、`ContentUnavailableView` 等均未使用）。持久化用 `@AppStorage` + `Codable` JSON 字符串写入 `UserDefaults`，两个计划用 `study` / `sing` 前缀区分。

---

## 二、本地 macOS / Xcode 编译

1. 安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（推荐用 Homebrew）：
   ```bash
   brew install xcodegen
   ```
2. 进入 `ios/` 目录生成工程：
   ```bash
   cd ios
   xcodegen generate
   ```
   会生成 `TwoPlans.xcodeproj`。
3. 用 Xcode 打开，选择真机或模拟器（iOS 15+），`Cmd+R` 运行。
   - Bundle ID：`com.local.twoplans`
   - 显示名：`两个计划`
   - 部署目标：iOS 15.0
4. 若是真机调试又不想付费，见「四、免费开发者账号签名」。

---

## 三、CI 产出未签名 IPA（GitHub Actions）

`build-ipa.yml` 已放在 `ios/` 根目录。三种用法：

- **用法 A（最省事）**：双击 `ios/publish-to-github.bat`（或在 Git Bash 里跑 `bash ios/publish-to-github.sh`）。
  脚本会把仓库推送到 GitHub 并把 workflow 摆到位。有 `gh` 命令行时全自动建仓库；没有的话会提示你先建一个空仓库再粘贴 `用户名/仓库名`。
- **用法 B**：手动 `cp ios/build-ipa.yml .github/workflows/build-ipa.yml` 后提交推送。
- **用法 C**：保留在 `ios/build-ipa.yml`，在 workflow 里先 cp 过去再触发。

流程：`macos-14` runner → `brew install xcodegen ldid` → `xcodegen generate` → `xcodebuild clean archive`（关闭签名）→ 把 `.app` 放进 `Payload` → **用 ldid 对 Payload 里每个 Mach-O 做 ad-hoc 签名** → zip 成 `TwoPlans.ipa` → 自动发到 **Releases**（同时保留一份 Actions artifact 备份）。

两个关键细节，别省：

1. **必须有 ldid 那一步。** xcodebuild 关掉签名产出的是「完全没有签名」的 Mach-O，TrollStore 读不到签名会直接拒绝安装；`ldid -S` 补的是 ad-hoc 占位签名，有了它 CoreTrust 才放行。
2. **从 Releases 下，不要从 artifact 下。** GitHub 的 artifact 必须登录才能下载，手机上没法直接拿；Release 附件是公开直链，Safari 点开就能下载。

产物仍是**无证书签名的 IPA**，普通未越狱 iPhone 装不了，按下面两种方式处理。

### A. TrollStore（需 iOS 14.0–16.6.1 / 部分 17 内核，且已安装 TrollStore）

TrollStore 利用 CoreTrust 漏洞，可永久安装此类 IPA 且不过期：

1. 推送后等 Actions 跑绿（约 3-5 分钟），打开仓库 Releases 页。
2. **iPhone 上**：Safari 打开 Releases 里 `TwoPlans.ipa` 的链接，下载完点分享 → **TrollStore** → Install。
   或者先把 ipa 用 AirDrop / 文件 App 传到手机，再从 TrollStore 里选它安装。
3. 桌面出现「两个计划」图标，长期可用，不受 7 天限制，也不需要连电脑续签。

### B. AppSync Unified + 任意安装器（越狱环境）

适用于已越狱设备（Dopamine / Palera1n / checkra1n 等）：

1. 在 Cydia / Sileo / Zebra 中添加源，安装 **AppSync Unified**（绕过签名校验）。
2. 用 **Filza**、**Sideloadly（本地侧载）** 或 **TrollStore** 把 `TwoPlans.ipa` 安装到设备。
3. 因 AppSync 已屏蔽签名检查，未签名 App 可正常打开。

> 越狱/未签名安装的可用性依赖设备系统版本与漏洞，请自行确认当前环境支持哪一种。

---

## 四、没有签名时：Xcode 免费开发者账号签名 7 天

如果没有越狱，也不想走 CI，可用 Apple ID 免费签名（限制：每 7 天需重签，且需连接 Mac）：

1. Xcode → Settings → Accounts，添加你的普通 Apple ID。
2. 打开 `TwoPlans.xcodeproj`，选中 `TwoPlans` target → Signing & Capabilities：
   - 勾选「Automatically manage signing」
   - Team 选择你的个人账号（Xcode 会生成 `com.local.twoplans` 的个人签名，必要时把 Bundle ID 改成你自己的唯一后缀以免冲突）
3. 连接 iPhone，`Cmd+R` 安装运行。
4. 7 天后签名过期，重连 Mac 重新运行一次即可续期。

> 注意：免费账号签名无法做 App 分发，仅限该 Apple ID 绑定的设备安装自测。

---

## 五、数据说明

- 学习计划 48 周、唱歌计划前 3 月按周 + 第 4–12 月按月，内容均提炼自原始 `.md` 计划文档。
- 勾选、打卡、检查点都存于 `UserDefaults`（按计划前缀隔离），卸载 App 会清空。
- 打卡日期以设备当前时区的 `yyyy-MM-dd` 存储；「连续天数」从今天（或昨天）往前数连续打卡天数。

---

## 六、无法在本机验证的部分

以下只能在 macOS/Xcode 或真机上确认，Windows 起草阶段无法验证：

- 实际编译是否一次通过（已尽量只用稳定 API，但仍需 Xcode 实编确认）。
- 真机/模拟器上的 UI 表现与交互。
- IPA 签名与越狱机安装的可用性（取决于你的设备系统版本）。
