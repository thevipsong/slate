import SwiftUI

/// 深色主题适配的自定义日历选择器
/// - 替代原生 DatePicker，解决白底刺眼、顶部冗余输入框等问题
/// - 点击日期直接选中并关闭，无需二次确认
/// - 底部整合"清除"和"今天"操作
struct CalendarPickerView: View {
    @Binding var selectedDate: Date?
    @State private var displayedMonth: Date
    @EnvironmentObject var theme: AppTheme
    var onSelection: ((Date?) -> Void)?
    var onDismiss: () -> Void

    private let calendar = Calendar.current
    private let weekdayLabels: [String]

    private var today: Date { calendar.startOfDay(for: Date()) }

    init(
        selectedDate: Binding<Date?>,
        onSelection: ((Date?) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self._selectedDate = selectedDate
        self.onSelection = onSelection
        self.onDismiss = onDismiss
        let date = selectedDate.wrappedValue ?? Date()
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        self._displayedMonth = State(initialValue: Calendar.current.date(from: components)!)
        self.weekdayLabels = Self.buildWeekdayLabels()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            weekdayRow
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            dayGrid
                .padding(.horizontal, 12)
                .padding(.bottom, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))

            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 264)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.secondaryText)
            .accessibilityLabel("上个月")

            Spacer()

            Text(monthYearString)
                .font(theme.font(14, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation(.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.secondaryText)
            .accessibilityLabel("下个月")
        }
    }

    private var monthYearString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年 M月"
        return fmt.string(from: displayedMonth)
    }

    // MARK: - Weekday Row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(theme.font(11, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Grid

    private var dayGrid: some View {
        let days = computeDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let date = day {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            selectedDate = date
            onSelection?(date)
            onDismiss()
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(theme.font(13, weight: isToday || isSelected ? .semibold : .regular))
                .frame(width: 34, height: 34)
                .background {
                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                    } else if isToday {
                        Circle()
                            .strokeBorder(AppColors.accent.opacity(0.5), lineWidth: 1.5)
                    }
                }
                .foregroundStyle(
                    isSelected ? .white
                        : isCurrentMonth ? .primary
                        : AppColors.placeholderText
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDateString(date))
        .accessibilityValue(
            isSelected ? "已选择"
                : isToday ? "今天"
                : ""
        )
        .accessibilitySelected(isSelected)
    }

    // MARK: - Day Computation

    private func computeDays() -> [Date?] {
        let firstOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        )!
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth)!
        let numDays = range.count

        // Compute leading blank cells based on firstWeekday
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let first = calendar.firstWeekday
        var offset = weekday - first
        if offset < 0 { offset += 7 }

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in 1...numDays {
            var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
            comps.day = day
            days.append(calendar.date(from: comps))
        }

        // Pad to full rows
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("清除") {
                selectedDate = nil
                onSelection?(nil)
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(theme.font(13, weight: .medium))
            .foregroundStyle(AppColors.secondaryText)

            Spacer()

            Button("今天") {
                selectedDate = today
                onSelection?(today)
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(theme.font(13, weight: .medium))
            .foregroundStyle(AppColors.accent)
        }
    }

    // MARK: - Helpers

    private static func buildWeekdayLabels() -> [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private func accessibilityDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }
}
