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

private let ink = Color(red: 0.15, green: 0.20, blue: 0.18)
private let accent = Color(red: 0.31, green: 0.42, blue: 0.37)
private let paper = Color(red: 0.91, green: 0.93, blue: 0.87)

struct ScheduleWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ScheduleEntry
  let wide: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: !wide && family != .systemLarge ? 5 : 12) {
      HStack(spacing: 4) {
        Text("课间").font(.system(size: family == .systemSmall ? 11 : 13, weight: .bold))
        Spacer(minLength: 2)
        Text(entry.state.isDemo ? "示例" : entry.state.weekLabel)
          .font(.system(size: 10)).lineLimit(1)
      }.foregroundColor(accent)
      if wide {
        HStack(alignment: .top, spacing: 16) {
          lessonCard(entry.state.next, label: entry.state.status)
            .frame(maxWidth: .infinity, alignment: .leading)
          Divider()
          lessonCard(entry.state.following, label: "再下一节")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        lessonCard(entry.state.next, label: entry.state.status)
        Divider().padding(.vertical, family == .systemLarge ? 4 : 0)
        lessonCard(entry.state.following, label: "再下一节")
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .modifier(WidgetBackground())
    .accessibilityElement(children: .combine)
  }

  private func lessonCard(_ lesson: WidgetLesson?, label: String) -> some View {
    let compact = !wide && family != .systemLarge
    return VStack(alignment: .leading, spacing: compact ? 2 : 6) {
      if compact {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(label).font(.system(size: 8)).foregroundColor(accent)
          Text(lesson?.name ?? "暂无课程")
            .font(.system(size: 13, weight: .bold)).foregroundColor(ink)
        }.lineLimit(1).minimumScaleFactor(0.75)
      } else {
        Text(label).font(.system(size: 10)).foregroundColor(accent)
        Text(lesson?.name ?? "暂无后续课程")
          .font(.system(size: family == .systemLarge ? 21 : 18, weight: .bold))
          .foregroundColor(ink).lineLimit(2).minimumScaleFactor(0.75)
      }
      if let lesson = lesson {
        Text(timeLabel(lesson)).font(.system(size: compact ? 9 : 11)).foregroundColor(accent).lineLimit(1).minimumScaleFactor(0.75)
        Text((lesson.room.isEmpty ? "教室待补充" : lesson.room) + (lesson.changed ? " · 已调课" : ""))
          .font(.system(size: compact ? 9 : 11)).foregroundColor(accent).lineLimit(1).minimumScaleFactor(0.75)
      } else {
        Text("点击打开课间").font(.system(size: compact ? 9 : 11)).foregroundColor(accent)
      }
    }
  }

  private func timeLabel(_ lesson: WidgetLesson) -> String {
    let today = WidgetDates.key(entry.date, in: WidgetDates.calendar)
    let day = lesson.date == today ? "今天" : String(lesson.date.suffix(5)).replacingOccurrences(of: "-", with: "/")
    return "\(day) \(lesson.start)—\(lesson.end)"
  }
}

private struct WidgetBackground: ViewModifier {
  @ViewBuilder func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { paper }
    } else {
      content.padding(14).background(paper)
    }
  }
}

struct KejianScheduleWidget: Widget {
  let kind = "KejianScheduleWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
      ScheduleWidgetView(entry: entry, wide: false)
    }
    .configurationDisplayName("课间 · 原版")
    .description("保留原有尺寸，上下显示接下来的两门课、时间与教室。")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct KejianWideScheduleWidget: Widget {
  let kind = "KejianWideScheduleWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
      ScheduleWidgetView(entry: entry, wide: true)
    }
    .configurationDisplayName("课间 · 宽版")
    .description("横向长方形，左右并排显示接下来的两门课、时间与教室。")
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
