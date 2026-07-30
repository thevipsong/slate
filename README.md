<p align="center">
  <img src="generated-images/slate-icon-1024.png" width="96" alt="序事 App 图标" />
</p>

<h1 align="center">序事</h1>

<p align="center">
  <strong>序事 · 极简待办</strong>
  <br />
  <em>Slate</em>
  <br />
  记下每件事，按自己的节奏完成。
  <br />
  本地优先 · 双端原生 · 数据可迁移
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/Android-8.0%2B-3DDC84" alt="Android" />
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
  <img src="https://img.shields.io/badge/macOS%20tests-62%20passed-brightgreen" alt="Tests" />
  <a href="https://github.com/thevipsong/slate/actions/workflows/ci.yml">
    <img src="https://github.com/thevipsong/slate/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
</p>

---

## ✨ 核心亮点

- 🧩 **分组 + 筛选 + 搜索** — 多分组切换（创建/重命名/移动），支持全部 / 待完成 / 已完成 / 逾期四种筛选，⌘F 搜索标题即时过滤
- 📅 **轻量到期日** — 自定义深色日历面板，一行内标记「今天 / 昨天 / 逾期 / M-D」，逾期橙色警示，逾期筛选 + 统计卡一目了然
- ⌨️ **键盘驱动** — 几乎不需要鼠标：⌘N 新建、⌘↩ 添加、⌘Z 撤销、⌘⇧↩ 切换完成、⌘⌫ 删除、Esc 取消编辑、⌘1-3 切换筛选、⌘[ ] 切分组、⌘F 搜索
- ☑️ **菜单栏快速捕获** — 序事常驻菜单栏且不占用 Dock；按 ⌥Space 从任何应用呼出，输入后回车即保存并继续聚焦
- ✨ **严格单选 + 拖拽** — 单击任务立即选中且始终只保留一条高亮；支持同组内拖拽排序，并可通过右键菜单移动到其他分组
- 🔙 **多步撤销** — 增加 / 删除 / 完成 / 编辑 / 移动全覆盖，撤销栈上限可配
- 🏠 **本地优先 JSON 存储** — 默认不上传；原子写入 + 双代备份 + 损坏自动回退 + 版本迁移链（v1→v2→v3），可选启用加密会话的双端同步
- 🌤️ **天气 + 每日名言** — 8 个城市可选天气（当前温度 + 图标），每日一句中文名言，Header 一行展示，不打扰
- 🎨 **可配置主题** — 深色 / 浅色 / 跟随系统；Rounded / Sans Serif / Monospaced 三种字体；字号可调
- 🧱 **零外部依赖** — 纯 SwiftUI + MVVM，Package.swift 没有一行 `.package(url:)`。编译链极短，构建秒级
- 🧪 **62 项 macOS 自动化测试 + Android 单元测试** — 覆盖 CRUD / 筛选 / 分组 / 拖拽 / 撤销 / 选择状态 / 并发 / 持久化往返 / 合并冲突 / 可选 Supabase 集成测试 / 边界

---

## 🚀 快速开始

### Android APK

Android 版位于 [`android/`](android/)，使用 Kotlin + Jetpack Compose 原生开发，
支持核心待办功能、本地提醒和与 macOS 版兼容的 JSON 导入导出。0.3.0
采用分组抽屉、紧凑状态筛选、悬浮新增、按需展开搜索和任务编辑底部抽屉；
支持左右滑动快捷操作、完成提示、长按整卡拖拽排序，以及前台近实时双端同步。

```bash
./Scripts/build-android.sh
```

可安装 APK 将生成到 `Dist/序事-Android-debug.apk`。详细环境要求和工程说明见
[`android/README.md`](android/README.md)。

需要长期安装并支持后续覆盖升级时，首次运行
`./Scripts/generate-android-signing.sh` 生成本机签名，再运行
`./Scripts/build-android-release.sh`，产物为
`Dist/序事-Android-release.apk`。签名文件不会上传 GitHub，必须另行备份。

### 系统要求

- macOS 15.0 (Sequoia) 或更高版本
- Swift 6.0+（Xcode 16+ 或仅 Command Line Tools）

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/thevipsong/slate.git
cd slate

# 开发模式运行
swift run TodoList

# 或使用 Xcode
# File → Open → 选择 Package.swift → 选择 My Mac → Run
```

### 菜单栏模式

序事启动后常驻 macOS 菜单栏，不显示 Dock 图标：

- 点击单色对号图标，或在任意应用中按 `⌥Space`，打开快速捕获面板
- 面板打开后会自动聚焦输入框；输入任务并按回车即可保存并继续录入
- 顶部可切换任务分组，列表中可直接完成当前待办
- 所有待办都会进入内部滚动列表，不再隐藏第 9 项及后续任务
- 右下角“更多”菜单可选择紧凑、标准、宽敞三档面板高度
- 完成任务时先显示删除线与降噪状态，1.2 秒后再折叠消失；期间再次点击可撤销
- 点击“打开完整序事”进入分组、筛选、搜索、排序、同步等完整管理界面
- 点击面板外部会自动收起；关闭完整窗口不会退出菜单栏进程
- 从面板右下角的更多菜单选择“退出序事”可完全退出

### 打包本机 App

```bash
# 生成 序事.app（含临时自签名）
./Scripts/build-app.sh

# 打开
open Dist/序事.app
```

> 产物位于 `Dist/序事.app`，可直接拖入 Applications 文件夹。脚本使用临时签名，
> 适合本机开发和测试；面向其他用户发布前需使用 Developer ID 签名并完成 Apple 公证。

### 构建 macOS 正式发布包

正式分发脚本要求本机已安装 Developer ID Application 证书，并已通过
`notarytool store-credentials` 保存公证凭据：

```bash
SLATE_VERSION=1.1.0 \
SLATE_BUILD_NUMBER=2 \
SLATE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
SLATE_NOTARY_PROFILE="slate-notary" \
./Scripts/build-macos-release.sh
```

可通过 `SLATE_BUNDLE_ID` 覆盖默认的 `com.thevipsong.slate`。脚本会执行 Hardened
Runtime 签名、Apple 公证、票据装订、Gatekeeper 校验，并生成
`Dist/序事-macOS-<版本>.zip` 与对应的 SHA-256 文件。

### 运行测试

```bash
# 通过项目脚本（兼容仅有 CLT 的环境）
./Scripts/run-tests.sh

# 或通过 SwiftPM（需要完整 Xcode）
swift test
```

---

## 📁 目录结构

```
Slate/
├── Sources/
│   └── TodoList/
│       ├── App/
│       │   ├── TodoListApp.swift         # 菜单栏应用入口
│       │   └── SlateMenuBarController.swift # 状态项、全局快捷键、Popover 与完整窗口
│       ├── Models/
│       │   ├── TodoItem.swift            # 任务模型（含到期日）
│       │   ├── TodoGroup.swift           # 分组模型
│       │   └── TodoFilter.swift          # 筛选枚举（全部/待完成/已完成/逾期）
│       ├── ViewModels/
│       │   └── TodoViewModel.swift       # 核心逻辑：CRUD / 筛选 / 搜索 / 撤销 / 选择状态
│       ├── Views/
│       │   ├── ContentView.swift         # 布局容器
│       │   ├── HeaderView.swift          # 顶部：天气 + 名言 + 统计卡
│       │   ├── FilterBar.swift           # 筛选 chip + 搜索框
│       │   ├── GroupBar.swift            # 分组选项卡
│       │   ├── TodoListView.swift        # 任务列表 + 空状态
│       │   ├── TodoRowView.swift         # 单行任务（含到期日 chip）
│       │   ├── TodoInputView.swift       # 底栏输入区 + 日历按钮
│       │   ├── MenuBarQuickView.swift    # 菜单栏快速捕获面板
│       │   ├── CalendarPickerView.swift  # 自定义深色日历面板
│       │   ├── BulkActionBar.swift       # 批量操作栏
│       │   ├── AppTheme.swift            # 主题 / 字体 / 天气城市配置
│       │   └── AppColors.swift           # 全局色板
│       └── Services/
│           ├── TodoFileStore.swift       # JSON 读写：原子写 / 双备份 / 版本迁移
│           ├── SlateMergeEngine.swift    # 三方合并与冲突处理
│           ├── SlateSyncCoordinator.swift # Supabase 版本化同步
│           ├── WeatherService.swift      # 天气获取 + 每日名言
│           └── TodoReminderService.swift # 本地提醒
├── Tests/
│   └── TodoListTests/
│       ├── TodoViewModelTests.swift      # 视图模型测试
│       ├── TodoFileStoreTests.swift      # 存储层测试
│       ├── WeatherServiceTests.swift     # 天气 / 名言测试
│       ├── TodoReminderServiceTests.swift # 提醒服务测试
│       └── SupabaseSyncIntegrationTests.swift # 可选真实同步测试
├── Scripts/
│   ├── build-app.sh                      # Release 打包脚本
│   ├── build-macos-release.sh            # Developer ID 签名、公证与校验
│   ├── build-android.sh                  # Android 测试与 APK 构建
│   ├── build-android-release.sh          # Android 签名发布版构建
│   ├── generate-android-signing.sh       # 首次生成本机发布签名
│   ├── start-local-sync.sh               # 启动精简本地 Supabase
│   ├── run-sync-integration.sh           # Auth / RLS / RPC 集成验证
│   └── run-tests.sh                      # CLT 兼容测试脚本
├── android/                              # Kotlin + Jetpack Compose Android 客户端
├── Resources/
│   └── AppIcon.icns                      # App 图标
├── .github/
│   ├── workflows/ci.yml                  # GitHub Actions 持续集成
│   ├── ISSUE_TEMPLATE/                   # Bug / 功能建议模板
│   └── pull_request_template.md          # Pull Request 检查清单
├── Dist/                                 # 打包产物 (gitignored)
├── CHANGELOG.md                          # 版本变更记录
├── CONTRIBUTING.md                       # 贡献指南
├── SECURITY.md                           # 安全问题报告方式
├── Package.swift
└── README.md
```

---

## 🗺️ Roadmap

- [x] 分组管理 + 四种筛选
- [x] 搜索（⌘F 即时过滤）
- [x] 轻量到期日 + 自定义日历面板
- [x] 天气面板（可配置城市）
- [x] 每日中文名言
- [x] 主题 / 字体 / 字号可配置
- [x] 多步撤销
- [x] 严格单选
- [x] 同组拖拽排序 + 右键跨组移动
- [x] 纯本地 JSON 存储（原子写 + 备份 + 迁移）
- [x] 62 项自动化测试
- [x] 到期日本地通知提醒
- [x] Android 原生客户端基础版
- [x] Android 紧凑首页、滑动操作、长按排序与底部抽屉编辑
- [x] macOS / Android JSON 双向导入导出
- [x] Mac / Android 可选 Supabase 自动同步
- [ ] iCloud 同步（或在偏好中可选）
- [ ] 从 Things 3 / 提醒事项导入
- [ ] 标签系统
- [x] 菜单栏快速捕获模式 + 全局快捷键
- [ ] 窗口常驻置顶
- [ ] 自定义快捷键

---

## 🤝 Contributing

欢迎 Issue 和 Pull Request。完整的开发流程、代码规范和提交检查清单请参阅
[CONTRIBUTING.md](CONTRIBUTING.md)。

1. Fork 本仓库
2. 创建 Feature 分支 (`git checkout -b feature/amazing-idea`)
3. 提交你的改动 (`git commit -m 'feat: add amazing idea'`)
4. 推送到分支 (`git push origin feature/amazing-idea`)
5. 创建 Pull Request

提交前请运行测试确保通过：

```bash
./Scripts/run-tests.sh
```

---

## 🔐 Security

请不要在公开 Issue 中披露安全漏洞或包含私人待办数据的截图。安全问题请按照
[SECURITY.md](SECURITY.md) 中的方式私下报告。

---

## 📄 License

MIT © [thevipsong](https://github.com/thevipsong)

---

<p align="center">
  <sub>Built with SwiftUI. No Electron. No bloat.</sub>
</p>
