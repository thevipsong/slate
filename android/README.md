# 序事 for Android

序事（英文副标题 Slate）是使用 Kotlin 与 Jetpack Compose 编写的原生 Android 客户端。

## 当前能力

- 分组创建、重命名、删除与任务跨组移动
- 全部、待完成、已完成、逾期筛选和即时搜索
- 新增、编辑、完成、删除、排序与到期日
- 到期日当天 9:00 本地通知
- 深色、浅色、跟随系统主题
- 原子 JSON 存储与双代备份
- 导入、导出 macOS 序事（Slate v3）JSON
- 分组抽屉、完成/删除滑动操作、长按六点手柄拖拽排序与底部抽屉编辑
- 底部快捷输入、按逾期/今天/接下来/无日期分段和删除撤销
- 高对比任务卡片、1dp 输入焦点态与键盘自适应布局
- 拖拽手柄与内存预览排序，松手后一次性持久化
- 可选 Supabase 账户同步、前台约 5 秒轻量版本检查、版本冲突三方合并与自动重试
- 自适应平板双栏布局、桌面待办小组件、应用快捷新建和系统分享导入
- 到期通知可直接完成或延后一小时提醒
- Android Adaptive Icon，系统可安全裁切为圆形、圆角矩形或其他启动器形状

## 构建

需要 JDK 17+、Android SDK 36。

```bash
cd android
./gradlew testDebugUnitTest assembleDebug
```

APK 位于：

```text
app/build/outputs/apk/debug/app-debug.apk
```

也可以从仓库根目录运行：

```bash
./Scripts/build-android.sh
```

产物将复制到 `Dist/序事-Android-debug.apk`。

### 生成 Baseline Profile

连接 Android 13 或更高版本的设备/模拟器后运行：

```bash
./gradlew :app:generateBaselineProfile
```

生成器覆盖冷启动、首页显示和任务列表滚动路径。

### 构建可升级的签名发布版

首次构建先生成本机发布签名：

```bash
./Scripts/generate-android-signing.sh
```

随后构建：

```bash
./Scripts/build-android-release.sh
```

产物位于 `Dist/序事-Android-release.apk`。`Private/` 与
`android/keystore.properties` 均已被 Git 忽略。请单独、离线备份这两处文件；
今后若要让手机上的序事直接覆盖升级，必须继续使用同一签名。

## 工程结构

```text
app/src/main/java/com/thevipsong/slate/
├── data/          # Slate v3 模型、JSON 编解码、原子存储、Repository
├── reminders/     # Android 通知与 AlarmManager 调度
├── sync/          # 安全会话、Supabase API、三方合并与协调器
├── ui/            # Compose 主题、状态和主界面
├── MainActivity.kt
└── SlateApplication.kt
```

## 数据兼容

Android 与 macOS 均使用 `version: 3` 的 Slate JSON 兼容格式。Android 的同步元数据使用
可选字段，macOS 会安全忽略；手动导出时不会包含已删除项。
