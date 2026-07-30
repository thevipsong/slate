import AppKit
import Foundation
import SwiftUI
import Testing
#if canImport(TodoList)
@testable import TodoList
#endif

struct AppThemeTests {
    @Test
    @MainActor
    func selectedAppearancePersistsAcrossInstances() {
        let suiteName = "AppThemeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let theme = AppTheme(defaults: defaults)
        theme.colorSchemeRaw = "dark"

        let restored = AppTheme(defaults: defaults)
        #expect(restored.colorSchemeRaw == "dark")
        #expect(restored.preferredColorScheme == .dark)
        #expect(restored.appKitAppearance?.name == .darkAqua)

        restored.colorSchemeRaw = "light"
        #expect(restored.preferredColorScheme == .light)
        #expect(restored.appKitAppearance?.name == .aqua)
    }

    @Test
    @MainActor
    func systemAppearanceClearsWindowOverride() {
        let suiteName = "AppThemeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let theme = AppTheme(defaults: defaults)
        theme.colorSchemeRaw = "system"

        #expect(theme.preferredColorScheme == nil)
        #expect(theme.appKitAppearance == nil)
    }
}
