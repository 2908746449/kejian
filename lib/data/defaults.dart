import '../domain/models.dart';

/// Confirmed by the user on 2026-11-09: 45-minute lessons, 5-minute breaks,
/// and 15-minute breaks between pairs. Evening retains the two existing slots.
const kailiUniversityPeriods = [
  Period(1, '08:20', '09:05'),
  Period(2, '09:10', '09:55'),
  Period(3, '10:10', '10:55'),
  Period(4, '11:00', '11:45'),
  Period(5, '14:00', '14:45'),
  Period(6, '14:50', '15:35'),
  Period(7, '15:50', '16:35'),
  Period(8, '16:40', '17:25'),
  Period(9, '19:00', '19:45'),
  Period(10, '19:50', '20:35'),
];

const _legacyDefaultPeriods = [
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
];

bool _samePeriods(List<Period> a, List<Period> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every(
      (i) =>
          a[i].number == b[i].number &&
          a[i].start == b[i].start &&
          a[i].end == b[i].end,
    );

bool usesKailiUniversityPeriods(List<Period> periods) =>
    _samePeriods(periods, kailiUniversityPeriods);

/// Update the old, untouched default once. Custom times and course data stay
/// intact, and the revision prevents later manual edits from being re-applied.
ScheduleData upgradeScheduleDefaults(ScheduleData data) {
  if (data.defaultsVersion >= currentDefaultsVersion) return data;
  final semester = data.semester;
  return data.copyWith(
    defaultsVersion: currentDefaultsVersion,
    semester: _samePeriods(semester.periods, _legacyDefaultPeriods)
        ? Semester(
            name: semester.name,
            firstMonday: semester.firstMonday,
            weekCount: semester.weekCount,
            periods: kailiUniversityPeriods,
          )
        : semester,
  );
}
