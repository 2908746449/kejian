import '../domain/models.dart';

ScheduleData demoData(DateTime now) {
  final monday = addDays(dayOnly(now), 1 - now.weekday - 8 * 7);
  final all = List.generate(16, (i) => i + 1);
  Meeting m(String id, int day, int start, String room, {List<int>? weeks}) =>
      Meeting(
        id: id,
        weekday: day,
        startPeriod: start,
        endPeriod: start + 1,
        weeks: weeks ?? all,
        room: room,
      );
  Course c(
    String id,
    String name,
    String teacher,
    int color,
    List<Meeting> meetings,
  ) => Course(
    id: id,
    name: name,
    teacher: teacher,
    note: '',
    color: color,
    meetings: meetings,
  );
  return ScheduleData(
    isDemo: true,
    semester: Semester(
      name: '${now.year} · ${now.month >= 7 ? '秋季' : '春季'}学期',
      firstMonday: monday,
      weekCount: 20,
      periods: const [
        Period(1, '08:00', '08:45'),
        Period(2, '08:55', '09:40'),
        Period(3, '10:00', '10:45'),
        Period(4, '10:55', '11:40'),
        Period(5, '14:00', '14:45'),
        Period(6, '14:55', '15:40'),
        Period(7, '16:00', '16:45'),
        Period(8, '16:55', '17:40'),
        Period(9, '19:00', '19:45'),
        Period(10, '19:55', '20:40'),
      ],
    ),
    courses: [
      c('math', '高等数学', '陈老师', 0, [
        m('math-1', 1, 1, '博学楼 A301'),
        m('math-2', 4, 3, '博学楼 A301'),
      ]),
      c('design', '设计思维', '林老师', 1, [m('design-1', 1, 5, '创意工坊 203')]),
      c('english', '大学英语', '王老师', 2, [
        m('english-1', 2, 3, '文华楼 B205'),
        m('english-2', 5, 1, '文华楼 B205'),
      ]),
      c('code', '程序设计', '刘老师', 3, [
        m('code-1', 2, 5, '信息楼 402'),
        m('code-2', 4, 5, '计算中心 301'),
      ]),
      c('physics', '大学物理', '赵老师', 4, [m('physics-1', 3, 1, '理学楼 102')]),
      c('sport', '体育 · 羽毛球', '周老师', 5, [
        m(
          'sport-1',
          3,
          7,
          '体育馆 2 号场',
          weeks: all.where((w) => w.isOdd).toList(),
        ),
      ]),
      c('history', '中国近现代史', '李老师', 1, [m('history-1', 5, 5, '人文楼 201')]),
    ],
  );
}
