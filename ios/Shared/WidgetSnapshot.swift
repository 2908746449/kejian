import Foundation

struct WidgetLesson: Codable, Identifiable {
  let id: String
  let name: String
  let room: String
  let date: String
  let start: String
  let end: String
  let changed: Bool

  func starts(in calendar: Calendar) -> Date? { WidgetDates.date(date, time: start, in: calendar) }
  func ends(in calendar: Calendar) -> Date? { WidgetDates.date(date, time: end, in: calendar) }
}

enum WidgetDates {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    return calendar
  }
  static func date(_ day: String, time: String = "00:00", in calendar: Calendar) -> Date? {
    let parts = day.split(separator: "-").compactMap { Int($0) }
    let clock = time.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 3, clock.count == 2 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: clock[0], minute: clock[1]))
  }

  static func key(_ date: Date, in calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
}

struct WidgetSnapshot: Codable {
  let version: Int
  let semesterName: String
  let firstMonday: String
  let weekCount: Int
  let isDemo: Bool
  let lessons: [WidgetLesson]

  static func decode(_ data: Data) throws -> WidgetSnapshot {
    let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    guard snapshot.version == 1 else {
      throw CocoaError(.coderReadCorrupt)
    }
    return snapshot
  }

  func state(at now: Date, calendar: Calendar = WidgetDates.calendar) -> WidgetState {
    let today = WidgetDates.key(now, in: calendar)
    let upcoming = lessons.filter { ($0.ends(in: calendar) ?? .distantPast) > now }
      .sorted { ($0.starts(in: calendar) ?? .distantPast) < ($1.starts(in: calendar) ?? .distantPast) }
    let next = upcoming.first
    let start = WidgetDates.date(firstMonday, in: calendar) ?? now
    let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
    let week = Int(floor(Double(days) / 7)) + 1
    let weekLabel = week < 1 ? "学期未开始" : week > weekCount ? "学期已结束" : "第 \(week) 周"
    let active = next.map { ($0.starts(in: calendar) ?? .distantFuture) <= now } ?? false
    return WidgetState(next: next, today: upcoming.filter { $0.date == today }, weekLabel: weekLabel,
      status: next == nil ? "暂无后续课程" : active ? "正在上课" : "下一节课", isDemo: isDemo)
  }

  /// Entries at starts, ends, and midnights keep the widget useful while the app
  /// is closed. The extension rereads the full semester at the end of this window.
  func transitionDates(after now: Date, calendar: Calendar = WidgetDates.calendar) -> [Date] {
    let midnight = calendar.startOfDay(for: now)
    let horizon = calendar.date(byAdding: .day, value: 2, to: midnight)!
    var dates = Set([now])
    for offset in 1...2 {
      dates.insert(calendar.date(byAdding: .day, value: offset, to: midnight)!)
    }
    for lesson in lessons {
      for date in [lesson.starts(in: calendar), lesson.ends(in: calendar)].compactMap({ $0 }) {
        if date > now && date < horizon { dates.insert(date) }
      }
    }
    return dates.sorted()
  }
}

struct WidgetState {
  let next: WidgetLesson?
  let today: [WidgetLesson]
  let weekLabel: String
  let status: String
  let isDemo: Bool
  static let empty = WidgetState(next: nil, today: [], weekLabel: "我的课表", status: "打开课间，同步课表", isDemo: false)
}

enum WidgetStore {
  static var container: URL? {
    let group = Bundle.main.object(forInfoDictionaryKey: "KejianAppGroup") as? String ?? "group.dev.kejian.kejian"
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
  }
  static func read() -> WidgetSnapshot? {
    guard let url = container?.appendingPathComponent("schedule-widget-v1.json"),
      let data = try? Data(contentsOf: url) else { return nil }
    return try? WidgetSnapshot.decode(data)
  }
  static func write(_ source: String) throws {
    let data = Data(source.utf8)
    _ = try WidgetSnapshot.decode(data)
    guard let url = container?.appendingPathComponent("schedule-widget-v1.json") else {
      throw CocoaError(.fileWriteNoPermission)
    }
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
}
