import Foundation

@main
struct WidgetSnapshotCheck {
  static func main() throws {
    let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "examples/widget-snapshot.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let snapshot = try WidgetSnapshot.decode(data)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let lesson = snapshot.lessons.first!
    let starts = lesson.starts(in: calendar)!
    let ends = lesson.ends(in: calendar)!
    precondition(snapshot.state(at: starts, calendar: calendar).next?.id == lesson.id, "Start boundary")
    precondition(snapshot.state(at: starts, calendar: calendar).status == "正在上课", "Active lesson")
    precondition(snapshot.state(at: ends, calendar: calendar).next?.id != lesson.id, "End boundary")
    let firstMonday = WidgetDates.date(snapshot.firstMonday, in: calendar)!
    precondition(snapshot.state(at: firstMonday, calendar: calendar).weekLabel == "第 1 周", "First week")
    precondition(snapshot.state(at: firstMonday.addingTimeInterval(-60), calendar: calendar).weekLabel == "学期未开始", "Before semester")
    let afterTerm = calendar.date(byAdding: .day, value: snapshot.weekCount * 7, to: firstMonday)!
    precondition(snapshot.state(at: afterTerm, calendar: calendar).next == nil, "After semester")
    let transitions = snapshot.transitionDates(after: starts, calendar: calendar)
    precondition(transitions.first == starts && transitions.contains(ends), "Start/end timeline")
    precondition(transitions.contains(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: starts))!), "Midnight timeline")
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    precondition(snapshot.state(at: lesson.starts(in: calendar)!, calendar: calendar).next?.id == lesson.id, "Local wall-clock after timezone change")
    let bad = String(data: data, encoding: .utf8)!.replacingOccurrences(of: "\"version\": 1", with: "\"version\": 999")
    do {
      _ = try WidgetSnapshot.decode(Data(bad.utf8))
      fatalError("Unsupported snapshot version accepted")
    } catch {}
    let first = WidgetLesson(id: "first", name: "第一门", room: "A101", date: "2026-11-09", start: "08:20", end: "09:55", changed: false)
    let second = WidgetLesson(id: "second", name: "第二门", room: "A102", date: "2026-11-09", start: "14:00", end: "15:35", changed: true)
    let tomorrow = WidgetLesson(id: "tomorrow", name: "明天的课", room: "A103", date: "2026-11-10", start: "08:20", end: "09:55", changed: false)
    let pair = WidgetSnapshot(version: 1, semesterName: "测试", firstMonday: "2026-11-09", weekCount: 1, isDemo: false, lessons: [tomorrow, second, first])
    let firstState = pair.state(at: first.starts(in: calendar)!, calendar: calendar)
    precondition(firstState.next?.id == "first" && firstState.following?.id == "second", "Two classes in chronological order")
    let afterFirst = pair.state(at: first.ends(in: calendar)!, calendar: calendar)
    precondition(afterFirst.next?.id == "second" && afterFirst.following?.id == "tomorrow", "End boundary rolls both cards and includes the next day")
    let afterSecond = pair.state(at: second.ends(in: calendar)!, calendar: calendar)
    precondition(afterSecond.next?.id == "tomorrow" && afterSecond.following == nil, "Single remaining class is not duplicated")
    let afterAll = pair.state(at: tomorrow.ends(in: calendar)!, calendar: calendar)
    precondition(afterAll.next == nil && afterAll.following == nil, "No ended lessons in either card")
    precondition(afterFirst.following?.date == "2026-11-10" && afterFirst.next?.changed == true, "Cross-date and moved lesson metadata retained")
    print("15 native widget data/timeline checks passed (Foundation; not an iOS UI build).")
  }
}
