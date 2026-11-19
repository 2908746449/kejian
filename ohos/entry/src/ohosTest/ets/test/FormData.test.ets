import { describe, it, expect } from '@ohos/hypium';
import { makeFormData, SnapshotLesson, WidgetSnapshot } from '../../../main/ets/widget/form_data';

export default function formDataTest() {
  describe('ScheduleFormData', () => {
    const lesson: SnapshotLesson = {
      id: 'test', name: '测试课程', room: 'A301', date: '2026-11-19',
      start: '08:20', end: '09:55', changed: false
    };
    const snapshot: WidgetSnapshot = { version: 1, isDemo: false, lessons: [lesson] };

    it('includes_an_ongoing_class', 0, () => {
      const data = makeFormData(snapshot, new Date(2026, 10, 19, 9, 0));
      expect(data.course1Name).assertEqual('测试课程');
      expect(data.course1Detail).assertContain('进行中');
    });
    it('excludes_an_ended_class', 0, () => {
      const data = makeFormData(snapshot, new Date(2026, 10, 19, 9, 55));
      expect(data.course1Name).assertEqual('暂无课程');
    });
    it('rejects_unknown_versions', 0, () => {
      const future: WidgetSnapshot = { version: 2, isDemo: false, lessons: [lesson] };
      expect(makeFormData(future).course1Name).assertEqual('暂无课程');
    });
  });
}
