// Keep this helper free of platform APIs so its date rules can run in Node too.
export interface SnapshotLesson {
  id: string;
  name: string;
  room: string;
  date: string;
  start: string;
  end: string;
  changed: boolean;
}

export interface WidgetSnapshot {
  version: number;
  isDemo: boolean;
  lessons: Array<SnapshotLesson>;
}

export interface ScheduleFormData {
  heading: string;
  course1Name: string;
  course1Detail: string;
  course2Name: string;
  course2Detail: string;
}

interface FormLesson {
  name: string;
  detail: string;
}

export function makeFormData(snapshot: WidgetSnapshot | null, now: Date = new Date()): ScheduleFormData {
  let upcoming: Array<SnapshotLesson> = [];
  const supported = snapshot !== null && snapshot.version === 1 && Array.isArray(snapshot.lessons);
  if (supported && snapshot !== null) {
    upcoming = snapshot.lessons.filter((lesson: SnapshotLesson) =>
      validLesson(lesson) && atTime(lesson.date, lesson.end).getTime() > now.getTime())
      .sort((a: SnapshotLesson, b: SnapshotLesson) => {
        const difference = atTime(a.date, a.start).getTime() - atTime(b.date, b.start).getTime();
        return difference !== 0 ? difference : a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
      });
  }
  const first = upcoming.length > 0 ? formatLesson(upcoming[0], now) : emptyLesson();
  const second = upcoming.length > 1 ? formatLesson(upcoming[1], now) : emptyLesson();
  return {
    heading: supported && snapshot !== null && snapshot.isDemo ? '示例课表' : '接下来',
    course1Name: first.name,
    course1Detail: first.detail,
    course2Name: second.name,
    course2Detail: second.detail
  };
}

function validLesson(lesson: SnapshotLesson): boolean {
  if (lesson === null || typeof lesson.id !== 'string' || typeof lesson.name !== 'string' ||
    typeof lesson.room !== 'string' || typeof lesson.date !== 'string' ||
    typeof lesson.start !== 'string' || typeof lesson.end !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}$/.test(lesson.date) ||
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(lesson.start) ||
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(lesson.end)) {
    return false;
  }
  const start = atTime(lesson.date, lesson.start);
  return dateKey(start) === lesson.date &&
    atTime(lesson.date, lesson.end).getTime() > start.getTime();
}

function atTime(date: string, time: string): Date {
  const dateParts = date.split('-').map(Number);
  const timeParts = time.split(':').map(Number);
  return new Date(dateParts[0], dateParts[1] - 1, dateParts[2], timeParts[0], timeParts[1]);
}

function formatLesson(lesson: SnapshotLesson, now: Date): FormLesson {
  const start = atTime(lesson.date, lesson.start);
  const end = atTime(lesson.date, lesson.end);
  const today = dateKey(now);
  const tomorrowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const tomorrow = dateKey(tomorrowDate);
  const day = lesson.date === today ? '今天' : lesson.date === tomorrow ? '明天' : lesson.date.slice(5).replace('-', '/');
  const status = start.getTime() <= now.getTime() && now.getTime() < end.getTime()
    ? '进行中 ' + lesson.start : day + ' ' + lesson.start;
  const room = lesson.room.trim().length > 0 ? lesson.room : '教室待补充';
  return { name: lesson.name, detail: status + '–' + lesson.end + '\n' + room + (lesson.changed ? ' · 已调课' : '') };
}

function emptyLesson(): FormLesson {
  return { name: '暂无课程', detail: '打开课间查看完整课表' };
}

function dateKey(date: Date): string {
  const year = date.getFullYear().toString().padStart(4, '0');
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return year + '-' + month + '-' + day;
}
