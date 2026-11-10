import SwiftUI
import WidgetKit

struct ScheduleEntry: TimelineEntry {
  let date: Date
  let state: WidgetState
}

struct ScheduleProvider: TimelineProvider {
  func placeholder(in context: Context) -> ScheduleEntry {
    let lesson = WidgetLesson(id: "preview", name: "高等数学", room: "博学楼 A301", date: "2026-11-09", start: "08:20", end: "09:55", changed: false)
    let following = WidgetLesson(id: "preview-next", name: "设计思维", room: "创意工坊 203", date: "2026-11-09", start: "14:00", end: "15:35", changed: false)
    return ScheduleEntry(date: Date(), state: WidgetState(next: lesson, following: following, weekLabel: "第 10 周", status: "下一节课", isDemo: true))
  }
  func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entry(at: Date(), snapshot: WidgetStore.read()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
    let now = Date()
    guard let snapshot = WidgetStore.read() else {
      completion(Timeline(entries: [entry(at: now, snapshot: nil)], policy: .after(now.addingTimeInterval(1800))))
      return
    }
    let entries = snapshot.transitionDates(after: now).map { entry(at: $0, snapshot: snapshot) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
  private func entry(at date: Date, snapshot: WidgetSnapshot?) -> ScheduleEntry {
    ScheduleEntry(date: date, state: snapshot?.state(at: date) ?? .empty)
  }
}

private let ink = Color(red: 0.15, green: 0.24, blue: 0.18)
private let accent = Color(red: 0.31, green: 0.42, blue: 0.37)
private let paper = Color(red: 0.91, green: 0.93, blue: 0.87)
private let firstCard = Color(red: 0.98, green: 0.99, blue: 0.96)
private let secondCard = Color(red: 0.86, green: 0.90, blue: 0.84)

struct ScheduleWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ScheduleEntry
  let wide: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: wide ? 8 : 5) {
      HStack(spacing: 4) {
        Text(wide ? "课间 · \(dateLabel)" : "课间")
          .font(.system(size: wide ? 12 : 11, weight: .bold))
        Spacer(minLength: 2)
        Text(entry.state.isDemo ? "示例" : entry.state.weekLabel)
          .font(.system(size: 9, weight: .medium)).lineLimit(1)
      }.foregroundColor(accent)
      if wide {
        HStack(spacing: 8) {
          wideLessonCard(entry.state.next, label: entry.state.status, color: firstCard)
          wideLessonCard(entry.state.following, label: "再下一节", color: secondCard)
        }.frame(maxHeight: .infinity)
      } else {
        compactLessonCard(entry.state.next, label: entry.state.status, color: firstCard)
        compactLessonCard(entry.state.following, label: "再下一节", color: secondCard)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .modifier(WidgetBackground())
    .accessibilityElement(children: .combine)
  }

  private func wideLessonCard(_ lesson: WidgetLesson?, label: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 2) {
        Text(label).lineLimit(1).minimumScaleFactor(0.8)
        Spacer(minLength: 2)
        Text(lesson.map(dayLabel) ?? "")
      }.font(.system(size: 9)).foregroundColor(accent)
      Text(lesson?.name ?? "暂无课程")
        .font(.system(size: 19, weight: .bold)).foregroundColor(ink)
        .lineLimit(2).minimumScaleFactor(0.75)
        .frame(maxHeight: .infinity, alignment: .leading)
      Text(lesson.map(clockLabel) ?? "暂无后续安排")
        .font(.system(size: 12, weight: .semibold)).foregroundColor(ink)
        .lineLimit(1).minimumScaleFactor(0.8)
      HStack(spacing: 3) {
        Image(systemName: "mappin.and.ellipse").font(.system(size: 9))
        Text(lesson.map(roomLabel) ?? "留一点时间给自己")
          .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
      }.foregroundColor(accent)
    }
    .padding(10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 14).fill(color))
  }

  private func compactLessonCard(_ lesson: WidgetLesson?, label: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(label == "下一节课" ? "下一节" : label)
          .font(.system(size: 7)).foregroundColor(accent)
        Text(lesson?.name ?? "暂无课程")
          .font(.system(size: family == .systemLarge ? 19 : 13, weight: .bold))
          .foregroundColor(ink)
      }.lineLimit(1).minimumScaleFactor(0.75)
      Text(lesson.map { "\(dayLabel($0)) \(clockLabel($0))" } ?? "点击打开课间")
        .font(.system(size: 9, weight: .semibold)).foregroundColor(accent)
        .lineLimit(1).minimumScaleFactor(0.8)
      Text(lesson.map(roomLabel) ?? "同步课表，安排从容")
        .font(.system(size: 9)).foregroundColor(accent)
        .lineLimit(1).minimumScaleFactor(0.8)
    }
    .padding(.horizontal, 8).padding(.vertical, 5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 12).fill(color))
  }

  private var dateLabel: String {
    let calendar = WidgetDates.calendar
    return "\(calendar.component(.month, from: entry.date))月\(calendar.component(.day, from: entry.date))日"
  }

  private func dayLabel(_ lesson: WidgetLesson) -> String {
    let calendar = WidgetDates.calendar
    let today = WidgetDates.key(entry.date, in: calendar)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: entry.date).map { WidgetDates.key($0, in: calendar) }
    if lesson.date == today { return "今天" }
    if lesson.date == tomorrow { return "明天" }
    return String(lesson.date.suffix(5)).replacingOccurrences(of: "-", with: "/")
  }

  private func clockLabel(_ lesson: WidgetLesson) -> String { "\(lesson.start)—\(lesson.end)" }

  private func roomLabel(_ lesson: WidgetLesson) -> String {
    (lesson.room.isEmpty ? "教室待补充" : lesson.room) + (lesson.changed ? " · 已调课" : "")
  }
}

private struct WidgetBackground: ViewModifier {
  @ViewBuilder func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { paper }
    } else {
      content.padding(12).background(paper)
    }
  }
}

struct KejianScheduleWidget: Widget {
  let kind = "KejianScheduleWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
      ScheduleWidgetView(entry: entry, wide: false)
    }
    .configurationDisplayName("课间 · 2×2")
    .description("小方块双课表，上下显示接下来的两门课、时间与教室。")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct KejianWideScheduleWidget: Widget {
  let kind = "KejianWideScheduleWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
      ScheduleWidgetView(entry: entry, wide: true)
    }
    .configurationDisplayName("课间 · 4×2")
    .description("横向双卡，大字课名、上课时间和教室一目了然。")
    .supportedFamilies([.systemMedium])
  }
}

@main
struct KejianWidgets: WidgetBundle {
  var body: some Widget {
    KejianScheduleWidget()
    KejianWideScheduleWidget()
  }
}
