import Foundation
import Testing
#if canImport(TodoList)
@testable import TodoList
#endif

struct TodoReminderServiceTests {
    @Test func reminderDateUsesNineAMOnDueDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let due = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 12
        ))!
        let now = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 12, hour: 8
        ))!

        let reminder = TodoReminderService.reminderDate(
            for: due,
            now: now,
            calendar: calendar
        )
        #expect(calendar.component(.hour, from: reminder!) == 9)
        #expect(calendar.isDate(reminder!, inSameDayAs: due))
    }

    @Test func reminderDateSkipsElapsedReminderTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let due = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 12
        ))!
        let now = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 12, hour: 10
        ))!

        #expect(TodoReminderService.reminderDate(
            for: due,
            now: now,
            calendar: calendar
        ) == nil)
    }
}
