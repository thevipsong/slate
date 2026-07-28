# 为 Slate 贡献

感谢你愿意改进 Slate。为保持项目简洁、可靠，请在提交改动前阅读以下约定。

## 开始之前

- Bug 和小型体验改进可以直接创建 Issue。
- 涉及数据格式、交互模型或大范围界面调整的改动，请先在 Issue 中讨论。
- 安全漏洞不要提交公开 Issue，请按照 [SECURITY.md](SECURITY.md) 私下报告。
- 截图、日志和测试夹具不得包含真实待办、联系方式或其他私人信息。

## 本地开发

环境要求：

- macOS 15 或更高版本
- Swift 6 工具链
- 推荐使用 Xcode 16 或更高版本

```bash
git clone https://github.com/thevipsong/slate.git
cd slate
swift build
./Scripts/run-tests.sh
```

也可以在 Xcode 中打开 `Package.swift`，选择 `TodoList` scheme 和 `My Mac` 运行。

## 分支与提交

1. 从最新的 `main` 创建独立分支。
2. 一个分支只处理一个主题，避免混入无关格式化或重构。
3. 使用简短、明确的提交信息，例如 `Fix due-date picker focus`。
4. 提交前确认 `git diff` 中没有构建产物、用户数据或凭据。

## 代码约定

- 保持 SwiftUI 视图职责清晰，业务状态放在 `TodoViewModel` 或对应 Service 中。
- 新增行为应优先补充 ViewModel、存储层或服务层测试。
- 保持键盘操作、辅助功能标签、浅色和深色模式可用。
- 不引入外部依赖，除非收益明确且已在 Issue 中讨论。
- 数据结构变更必须考虑旧版本迁移和备份回退。

## Pull Request

Pull Request 应说明：

- 改了什么，以及为什么需要改
- 对用户或数据兼容性的影响
- 已执行的自动测试和手动验证
- 界面变化的脱敏截图（如适用）

提交前至少运行：

```bash
swift build
./Scripts/run-tests.sh
```
