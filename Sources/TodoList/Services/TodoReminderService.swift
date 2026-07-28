@preconcurrency import UserNotifications
import Combine
import Foundation

/// 可选的本地到期提醒。仅在用户主动开启后申请通知权限。
@MainActor
final class TodoReminderService: ObservableObject, TodoReminderScheduling {
    nonisolated static let enabledDefaultsKey = "reminders.enabled"
    nonisolated static let notificationPrefix = "slate.todo."

    @Published private(set) var isEnabled: Bool
    @Published private(set) var statusMessage: String?

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var syncTask: Task<Void, Never>?

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
    }

    func setEnabled(_ enabled: Bool, items: [TodoItem]) {
        if !enabled {
            syncTask?.cancel()
            isEnabled = false
            defaults.set(false, forKey: Self.enabledDefaultsKey)
            removeSlateNotifications()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    isEnabled = false
                    defaults.set(false, forKey: Self.enabledDefaultsKey)
                    statusMessage = "通知权限未开启。可稍后在系统设置中允许 Slate 发送通知。"
                    return
                }
                isEnabled = true
                defaults.set(true, forKey: Self.enabledDefaultsKey)
                sync(items: items)
            } catch {
                isEnabled = false
                defaults.set(false, forKey: Self.enabledDefaultsKey)
                statusMessage = "无法开启到期提醒：\(error.localizedDescription)"
            }
        }
    }

    func sync(items: [TodoItem]) {
        guard isEnabled else { return }
        syncTask?.cancel()
        let snapshot = items
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            await replacePendingNotifications(with: snapshot)
        }
    }

    func clearStatusMessage() {
        statusMessage = nil
    }

    /// 到期日当天 9:00 提醒；已经错过提醒时间的任务不会补发，避免重复打扰。
    nonisolated static func reminderDate(
        for dueDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let day = calendar.startOfDay(for: dueDate)
        guard let reminder = calendar.date(byAdding: .hour, value: 9, to: day),
              reminder > now else {
            return nil
        }
        return reminder
    }

    private func replacePendingNotifications(with items: [TodoItem]) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            isEnabled = false
            defaults.set(false, forKey: Self.enabledDefaultsKey)
            removeSlateNotifications()
            statusMessage = "Slate 的通知权限已关闭，到期提醒已停用。"
            return
        }

        await removeSlateNotificationsNow()

        for item in items where !item.isCompleted {
            guard let dueDate = item.dueDate,
                  let reminderDate = Self.reminderDate(for: dueDate) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "任务今天到期"
            content.body = item.title
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.notificationPrefix + item.id.uuidString,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                statusMessage = "部分到期提醒设置失败：\(error.localizedDescription)"
            }
        }
    }

    private func removeSlateNotifications() {
        Task { [weak self] in
            await self?.removeSlateNotificationsNow()
        }
    }

    private func removeSlateNotificationsNow() async {
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.notificationPrefix) }
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered
            .map(\.request.identifier)
            .filter { $0.hasPrefix(Self.notificationPrefix) }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }
}
