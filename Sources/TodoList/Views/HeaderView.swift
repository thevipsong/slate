import SwiftUI

struct HeaderView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var weatherService: WeatherService
    @State private var showingStats = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 左列：产品名 + 每日一句
            VStack(alignment: .leading, spacing: 4) {
                Text("Slate")
                    .font(theme.font(22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .tracking(-0.3)

                Text(weatherService.quoteText.isEmpty ? "Stay focused." : weatherService.quoteText)
                    .font(theme.font(13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            // 右列：日期一组、天气+待办数一组（统计 popover 入口）
            VStack(alignment: .trailing, spacing: 4) {
                Text(weatherService.dateText)
                    .font(theme.font(13, weight: .medium))
                    .foregroundStyle(.primary)

                Button {
                    showingStats.toggle()
                } label: {
                    HStack(spacing: 6) {
                        if let weatherText = weatherService.weatherText {
                            Label(weatherText, systemImage: weatherService.weatherSymbol)
                        }
                        Text("·")
                            .opacity(0.5)
                        Text(subtitle)
                        Image(systemName: showingStats ? "chevron.up" : "chevron.down")
                            .font(theme.font(9, weight: .semibold))
                            .opacity(0.6)
                    }
                    .font(theme.font(12))
                    .foregroundStyle(AppColors.secondaryText)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("显示详细统计")
                .popover(isPresented: $showingStats, arrowEdge: .bottom) {
                    StatisticsPopoverContent(viewModel: viewModel)
                        .environmentObject(theme)
                }
            }
        }
        .onAppear {
            let coord = theme.weatherCoordinate
            weatherService.configure(latitude: coord.lat, longitude: coord.lon)
        }
    }

    private var subtitle: String {
        // 走 VM 缓存聚合，不要每次 body 全量扫 items
        "\(viewModel.totalPendingCount) 项待办 · 共 \(viewModel.totalItemCount) 项"
    }
}

/// Popover 内显示的统计
private struct StatisticsPopoverContent: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                statBlock(value: viewModel.totalItemCount, label: "总计", tint: AppColors.accent)
                divider
                statBlock(value: viewModel.totalCompletedCount, label: "已完成", tint: AppColors.accent)
                divider
                statBlock(value: viewModel.totalPendingCount, label: "待完成", tint: .orange)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )

            if viewModel.totalOverdueCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                    Text("逾期 \(viewModel.totalOverdueCount) 项")
                }
                .font(theme.font(12, weight: .medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
            }

            if !viewModel.groups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("分组")
                        .font(theme.font(11, weight: .semibold))
                        .foregroundStyle(AppColors.inactiveText)
                        .textCase(.uppercase)

                    ForEach(viewModel.groups) { group in
                        let pendingInGroup = viewModel.pendingCount(for: group.id)
                        let totalInGroup = viewModel.totalCount(for: group.id)
                        HStack(spacing: 9) {
                            Image(systemName: group.systemImage)
                                .font(theme.font(11, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 18)
                            Text(group.name)
                                .font(theme.font(13, weight: .semibold))
                            Spacer()
                            Text("\(pendingInGroup) / \(totalInGroup)")
                                .font(theme.monoDigits(12, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                                .contentTransition(.numericText())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 12)
        .frame(width: 320)
    }

    private func statBlock(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(theme.font(22, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(theme.font(12, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 38)
    }
}

/// Theme 切换菜单按钮（嵌在右上）
struct ThemePickerView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var reminderService: TodoReminderService

    var body: some View {
        Menu {
            Section("外观") {
                Picker("主题", selection: $theme.colorSchemeRaw) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("字体") {
                Picker("字体", selection: $theme.fontFamilyRaw) {
                    ForEach(AppFontFamily.allCases) { family in
                        Text(family.rawValue).tag(family.rawValue)
                    }
                }
            }
            Section("字号") {
                Picker("字号", selection: $theme.fontScaleRaw) {
                    ForEach(AppFontScale.allCases) { scale in
                        Text(scale.label).tag(scale.rawValue)
                    }
                }
            }
            Section("天气城市") {
                Picker("城市", selection: $theme.weatherCityID) {
                    ForEach(AppTheme.weatherCities, id: \.id) { city in
                        Text(city.name).tag(city.id)
                    }
                }
                .onChange(of: theme.weatherCityID) { _, _ in
                    let coord = theme.weatherCoordinate
                    weatherService.configure(latitude: coord.lat, longitude: coord.lon)
                }
            }
            Section("提醒") {
                Toggle(
                    "到期日当天 9:00 提醒",
                    isOn: Binding(
                        get: { reminderService.isEnabled },
                        set: { reminderService.setEnabled($0, items: viewModel.items) }
                    )
                )
            }
            Section("数据") {
                Button("导入 Slate JSON…") {
                    NotificationCenter.default.post(name: .importSlateArchive, object: nil)
                }
                Button("导出 Slate JSON…") {
                    NotificationCenter.default.post(name: .exportSlateArchive, object: nil)
                }
            }
            Section("同步") {
                if viewModel.isSyncSignedIn {
                    Text(viewModel.syncAccountEmail ?? "已登录")
                    Button(viewModel.isSyncing ? "正在同步…" : "立即同步") {
                        viewModel.syncNow()
                    }
                    .disabled(viewModel.isSyncing)
                    Button("退出同步账户") {
                        viewModel.signOutSync()
                    }
                } else {
                    Button("配置双端同步…") {
                        NotificationCenter.default.post(name: .configureSlateSync, object: nil)
                    }
                }
                if let status = viewModel.syncStatusMessage {
                    Text(status)
                }
            }
        } label: {
            Image(systemName: "textformat")
                .font(theme.font(12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("外观、字体、城市、提醒与数据")
    }
}
