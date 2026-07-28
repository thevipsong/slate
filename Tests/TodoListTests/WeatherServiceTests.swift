import Testing
import Foundation
#if canImport(TodoList)
@testable import TodoList
#endif

/// WeatherService 解析与 WMO 映射测试（纯逻辑，不发网络请求）
struct WeatherServiceTests {

    private func meteoJSON(temp: Double = 29.1, code: Int = 3) -> Data {
        Data("""
        {"current": {"time": "2026-07-27T13:30", "temperature_2m": \(temp), "weather_code": \(code)}}
        """.utf8)
    }

    @Test func parseRoundsTemperature() {
        let snapshot = WeatherService.parse(meteoJSON(temp: 29.4))
        #expect(snapshot?.temperatureC == 29)
        #expect(WeatherService.parse(meteoJSON(temp: 29.6))?.temperatureC == 30)
    }

    @Test func displayTextUsesLocalChinese() {
        let snapshot = WeatherService.parse(meteoJSON(code: 3))
        #expect(snapshot?.displayText == "29° 阴")
        #expect(WeatherService.parse(meteoJSON(code: 0))?.displayText == "29° 晴")
        #expect(WeatherService.parse(meteoJSON(code: 95))?.displayText == "29° 雷暴")
    }

    @Test func parseRejectsGarbage() {
        #expect(WeatherService.parse(Data("not json".utf8)) == nil)
        #expect(WeatherService.parse(Data("{}".utf8)) == nil)
        #expect(WeatherService.parse(Data("{\"current\":{}}".utf8)) == nil)
    }

    @Test func symbolMapping() {
        #expect(WeatherService.parse(meteoJSON(code: 0))?.symbolName == "sun.max")
        #expect(WeatherService.parse(meteoJSON(code: 2))?.symbolName == "cloud.sun")
        #expect(WeatherService.parse(meteoJSON(code: 45))?.symbolName == "cloud.fog")
        #expect(WeatherService.parse(meteoJSON(code: 61))?.symbolName == "cloud.rain")
        #expect(WeatherService.parse(meteoJSON(code: 71))?.symbolName == "cloud.snow")
        #expect(WeatherService.parse(meteoJSON(code: 96))?.symbolName == "cloud.bolt.rain")
        #expect(WeatherService.parse(meteoJSON(code: 999))?.symbolName == "cloud")
    }

    @Test func dailyQuoteStableWithinSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let morning = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 8))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 23))!
        #expect(WeatherService.dailyQuote(for: morning, calendar: calendar)
                == WeatherService.dailyQuote(for: night, calendar: calendar))
    }

    @Test func dailyQuoteFollowsDayOfYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let day1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        #expect(WeatherService.dailyQuote(for: day1, calendar: calendar) == WeatherService.dailyQuotes[0])
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        #expect(WeatherService.dailyQuote(for: day2, calendar: calendar) == WeatherService.dailyQuotes[1])
        // 跨年边界：12月31日 → 次年1月1日回到第一句
        let lastDay = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        #expect(WeatherService.dailyQuote(for: lastDay, calendar: calendar)
                == WeatherService.dailyQuotes[(365 - 1) % WeatherService.dailyQuotes.count])
    }

    @Test func dailyQuotesFitHeaderLine() {
        #expect(!WeatherService.dailyQuotes.isEmpty)
        for quote in WeatherService.dailyQuotes {
            #expect(!quote.isEmpty)
            #expect(quote.count <= 60)  // 副标题一行放得下
        }
    }
}
