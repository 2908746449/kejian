import SwiftUI
import WidgetKit

struct ScheduleEntry: TimelineEntry {
  let date: Date
  let state: WidgetState
}

struct ScheduleProvider: TimelineProvider {
  func placeholder(in context: Context) -> ScheduleEntry {
    let lesson = WidgetLesson(id: "preview", name: "高等数学", room: "博学楼 A301", date: "2026-11-09", start: "08:00", end: "09:40", changed: false)
    return ScheduleEntry(date: Date(), state: WidgetState(next: lesson, today: [lesson], weekLabel: "第 10 周", status: "下一节课", isDemo: true))
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

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 4) {
        Text("课间").font(.system(size: 13, weight: .bold))
        Spacer(minLength: 2)
        Text(entry.state.isDemo ? "示例" : entry.state.weekLabel)
          .font(.system(size: 10)).lineLimit(1)
      }.foregroundColor(accent)
      if family == .systemMedium {
        HStack(alignment: .top, spacing: 16) {
          mainLesson.frame(maxWidth: .infinity, alignment: .leading)
          if !following.isEmpty {
            Divider()
            lessonRows(limit: 2).frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      } else {
        mainLesson
        if family == .systemLarge {
          Divider().padding(.vertical, 2)
          lessonRows(limit: 5)
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .modifier(WidgetBackground())
    .accessibilityElement(children: .combine)
  }

  private var following: [WidgetLesson] { entry.state.today.filter { $0.id != entry.state.next?.id } }

  private var mainLesson: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.state.status).font(.system(size: 10)).foregroundColor(accent)
      Text(entry.state.next?.name ?? "享受一段自由时光")
        .font(.system(size: family == .systemSmall ? 19 : 21, weight: .bold))
        .foregroundColor(ink).lineLimit(2).minimumScaleFactor(0.75)
      if let lesson = entry.state.next {
        Text(timeLabel(lesson)).font(.system(size: 11)).foregroundColor(accent).lineLimit(1).minimumScaleFactor(0.75)
        Text((lesson.room.isEmpty ? "教室待补充" : lesson.room) + (lesson.changed ? " · 已调课" : ""))
          .font(.system(size: 11)).foregroundColor(accent).lineLimit(1)
      } else {
        Text("点击打开课间").font(.system(size: 11)).foregroundColor(accent)
      }
    }
  }

  private func lessonRows(limit: Int) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("今日后续").font(.system(size: 10)).foregroundColor(accent)
      if following.isEmpty {
        Text("今天没有其他课程").font(.system(size: 12)).foregroundColor(accent)
      }
      ForEach(Array(following.prefix(limit))) { lesson in
        HStack(alignment: .top, spacing: 10) {
          Text(lesson.start).font(.system(size: 11, weight: .medium)).foregroundColor(accent)
          VStack(alignment: .leading, spacing: 3) {
            Text(lesson.name).font(.system(size: 12, weight: .semibold)).foregroundColor(ink).lineLimit(1)
            Text(lesson.room.isEmpty ? "教室待补充" : lesson.room).font(.system(size: 10)).foregroundColor(accent).lineLimit(1)
          }
        }
      }
      if following.count > limit {
        Text("还有 \(following.count - limit) 门，打开课间查看").font(.system(size: 10)).foregroundColor(accent)
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

@main
struct KejianScheduleWidget: Widget {
  let kind = "KejianScheduleWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
      ScheduleWidgetView(entry: entry)
    }
    .configurationDisplayName("课间 · 今日课程")
    .description("下一节课和今日安排，包含调课与教室变更。")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
