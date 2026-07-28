import AppKit
import SwiftUI

/// 捕获未被文本输入控件处理的裸 Enter，让“选中任务 → Enter 编辑”稳定生效。
/// 文本框拥有焦点时不拦截，避免影响新建任务和行内编辑的提交行为。
struct TaskEditingKeyMonitor: NSViewRepresentable {
    let viewModel: TodoViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.viewModel = viewModel
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var viewModel: TodoViewModel
        private var monitor: Any?

        init(viewModel: TodoViewModel) {
            self.viewModel = viewModel
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 36 || event.keyCode == 76,
                      event.modifierFlags
                        .intersection(.deviceIndependentFlagsMask)
                        .isEmpty,
                      !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                    return event
                }

                let handled = MainActor.assumeIsolated {
                    guard let self, self.viewModel.selectedCount == 1 else {
                        return false
                    }
                    self.viewModel.beginEditingSelectedItem()
                    return true
                }
                return handled ? nil : event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
