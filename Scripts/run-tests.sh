#!/bin/zsh

# 跑单元测试。
# 本机只有 Command Line Tools（无 Xcode / XCTest），测试用 Swift Testing 编写，
# 由 CLT 自带的 Testing.framework 执行。SwiftPM（swift test）在本机被 sandbox-exec
# 策略拦截，所以这里用 swiftc 直接编译测试 runner 二进制再运行。
# SwiftPM 环境正常的机器上也可以直接 swift test（testTarget 已声明）。

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/tests"
TARGET="arm64-apple-macosx15.0"
DEV_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

mkdir -p "$BUILD_DIR"

# 排除 @main 入口文件（与测试 runner 的 @main 冲突）；
# 通知名 focusNewTodo 定义在 TodoInputView.swift，不受影响。
# @f 按行拆分（路径含空格，不能按词拆）
SOURCES=("${(@f)$(find "$PROJECT_DIR/Sources" -name "*.swift" ! -name "TodoListApp.swift")}")
TESTS=("${(@f)$(find "$PROJECT_DIR/Tests/TodoListTests" -name "*.swift")}")

echo "==> 编译测试 runner"
xcrun -sdk macosx swiftc \
    -target "$TARGET" \
    -module-name TodoListTests \
    -F "$DEV_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$DEV_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib \
    -load-plugin-library /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib \
    -o "$BUILD_DIR/run-tests" \
    "${SOURCES[@]}" "${TESTS[@]}" "$PROJECT_DIR/Tests/Runner/Runner.swift"

echo "==> 运行测试"
"$BUILD_DIR/run-tests"
