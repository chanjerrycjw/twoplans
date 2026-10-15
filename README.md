# 两个计划 · Web 页面 + iOS 应用

起算日 **2026-09-25**，与 `D:\ai\2026-09-24\计划部署` 里的开机提醒脚本保持一致。

| 计划 | 内容 | 网页版 |
|------|------|--------|
| 计划一 | 计算机基础一年成长计划（360 学习日 / 48 周 / 12 个月） | `study.html` |
| 计划二 | 零基础流行音乐一年计划（每天 20-60 分钟） | `sing.html` |
| 手机版 | 上面两个合并，底部双 Tab，单文件离线可用 | `两个计划-iOS.html` |

---

## 一、文件清单

```
D:\ai\2026-10-15\两个计划\
├─ index.html            入口导航页（点开先看这个）
├─ study.html            计划一：计算机基础一年成长计划
├─ sing.html             计划二：零基础流行音乐一年计划
├─ 两个计划-iOS.html      iOS 版：一个文件装两个计划，加到主屏幕后全屏运行
├─ build.py              重新打包脚本（改完数据跑一次）
├─ src\                  源码，别删
│   ├─ plans.js          两个计划的全部内容数据
│   ├─ app.js            日期引擎 + 渲染 + 存储
│   └─ style.css         样式
└─ ios\                  SwiftUI 原生工程（可云编译出 ipa）
```

三个 HTML 都是**自包含单文件**（CSS/JS/图标全内联），拷到哪都能单独打开，不依赖网络。

---

## 二、页面能干什么

- **今日视图**：今天第几天 / 第几周 / 第几月、当前模块的练习清单（可勾选）
- **打卡**：每天点一次，记录连续天数 + 最近 8 周热力图
- **12 个月地图**：当前月高亮，显示每个月任务完成比例
- **阶段目标**：四个季度各自的定位
- **唱歌专属**：按星期几的练习菜单、分级曲目库、月度检查点清单
- **全量大纲**：整年内容可展开，勾掉就永久记住
- **导出 / 导入**：进度存成本地 json，换设备可搬运

数据存在浏览器的 localStorage，键名前缀 `tp:<planId>:`。

> 今天是本机的 **2026-10-15**，对应第 21 天 / 第 3 周 / 第 1 月。

---

## 三、iPhone 上怎么装（越狱机适用）

### 方式 A：网页版（推荐，0 门槛）

1. 传 `两个计划-iOS.html` 到手机（隔空投送 / 微信文件 / Filza 都行）
2. **Safari** 打开 → 分享 → **添加到主屏幕**
3. 桌面出现图标，点开全屏无地址栏，离线可用

### 方式 B：原生 ipa（越狱才能装）

拿到 ipa 只有一条现实路径 —— **云编译**：这台机器是 Windows，编不出 iOS 原生二进制（需要 macOS + Xcode），任何号称能在 Windows 上直接产出 ipa 的办法都不成立。

我把这条路压到最省事：

1. 双击 `ios/publish-to-github.bat`（或 Git Bash 里 `bash ios/publish-to-github.sh`）
2. 没有 GitHub 账号先注册；脚本没检测到 `gh` 命令行时，会提示你去 https://github.com/new 建一个**空仓库**（别勾 README），回来粘贴 `用户名/仓库名`
3. 推送完成 **等 3-5 分钟** Actions 跑绿，仓库 **Releases** 页出现 `TwoPlans.ipa`
4. **iPhone Safari 打开那个 ipa 链接 → 下载完点分享 → TrollStore → Install**，永久有效，不用连电脑续签

> 打包含一步关键处理：用 `ldid -S` 给 Payload 里的 Mach-O 补 ad-hoc 签名。xcodebuild 关掉签名产出的是完全无签名的二进制，TrollStore 读不到签名会直接拒绝安装。
> 另外一定要从 **Releases** 下 ipa，不要从 Actions artifact 下 —— artifact 必须登录 GitHub 才能下载，手机上拿不到。

工程文件（已自审，全部只用 iOS 15 稳定 API，无第三方依赖）：

```
ios/
├─ project.yml              XcodeGen 工程描述（iOS 15.0，Bundle ID com.local.twoplans）
├─ build-ipa.yml            GitHub Actions：macos-14 + xcodegen + 免签名 archive + 打 IPA
└─ TwoPlans/
   ├─ App.swift             @main + TabView 两个 Tab
   ├─ Models.swift          48 周学习计划 + 17 块唱歌计划完整内容（含每日菜单 / 月度检查点）
   ├─ DateEngine.swift      2026-09-25 起算，全部走 Calendar.startOfDay 推算
   ├─ ProgressStore.swift   Codable 进度 + UserDefaults key 生成
   ├─ PlanView.swift        今日卡片 / 勾选 / 12 月网格 / 打卡 + 8 周日历 / 检查点 / 重置
   ├─ Info.plist
   └─ README.md             本地编译、CI 出包、TrollStore 与 AppSync 安装、免费账号签名
```

> 诚实说明：本机是 Windows，没有 Swift 工具链，**这套 Swift 代码没有实编验证过**。真机能跑与否要等你在 macOS 或云编译上跑一遍才知道。真出问题先告诉我报错内容。

---

## 四、改内容怎么改

所有计划内容集中在 `src/plans.js`：

- 起算日改文件顶部的 `START_DATE`
- 每月 / 每周的条目改 `PLANS.study.months` 和 `PLANS.sing.months`
- 唱歌的星期菜单改 `weekday`，曲库改 `songs`，检查点改 `checkpoints`

改完执行：

```
cd D:\ai\2026-10-15\两个计划
python build.py
```

三个 HTML 会重新生成。

---

## 五、和原有提醒的关系

`D:\ai\2026-09-24\计划部署` 里的 `.vbs` 开机弹窗**不用动**，照旧每天开机提醒。
网页版解决的是另一件事：打开就能看到「今天该练什么」，能勾掉、能打卡、能看到整年进度。
