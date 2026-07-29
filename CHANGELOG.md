# Changelog

Slate 的重要变更记录在此文件中。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- GitHub Actions 自动构建与测试
- Bug、功能建议和 Pull Request 模板
- 贡献指南与安全报告策略
- Kotlin + Jetpack Compose 原生 Android 客户端
- Android 到期提醒、主题切换、分组、筛选、搜索与任务管理
- macOS / Android Slate v3 JSON 双向导入导出
- Supabase 可选账户同步、乐观并发控制与三方冲突合并
- Android CI、独立发布签名与签名 APK 构建脚本
- Android 任务右滑完成、左滑删除与长按拖拽排序
- Android 悬浮新增入口、按需展开搜索与任务编辑底部抽屉
- macOS 与 Android 前台自动检查远端版本并近实时合并
- Android Adaptive Icon 前景/背景分层适配

### Changed

- macOS 客户端增加数据导入、导出及双端同步设置
- macOS 自动化测试扩展到 60 项，并覆盖跨端数据、真实同步链路、重复 ID 修复与合并冲突
- Android 首页压缩为紧凑 Header、分组抽屉和状态分段控件，显著增加首屏任务容量
- Android 日期选择器、主题卡片、提醒开关与同步卡片统一 Slate 视觉语言
- Android 完成操作改为单手势单次消费，并显示明确 Snackbar 反馈
- Android 应用版本更新为 0.3.0（versionCode 3），可覆盖升级旧版本

### Fixed

- 修复云端或导入档案含重复 UUID 时 macOS 在合并阶段触发断言并闪退
- 修复 Android 右滑完成后提示可能错误、任务未稳定进入“已完成”的问题
- 修复双端仅在手动同步或重新打开页面后才刷新远端修改的问题

## [1.0.0] - 2026-07-28

### Added

- 原生 SwiftUI macOS 待办应用
- 分组、筛选、搜索、编辑和同组拖拽排序
- 自定义到期日日历与本地提醒
- 浅色、深色、字体和字号设置
- 本地 JSON 原子存储、双代备份与旧版本迁移
- 52 项自动化测试
