import Foundation
import Testing

// 测试入口：本机没有完整 Xcode（无 XCTest），用 CLT 自带的 Swift Testing。
// __swiftPMEntryPoint 是 Testing framework 的公开入口，负责发现 @Test 并执行。
// 返回类型显式标注 CInt 消除 CInt / Never 两个重载的歧义。
@main
struct TestRunner {
    static func main() async {
        let code: CInt = await Testing.__swiftPMEntryPoint()
        exit(code)
    }
}
