// Node >=22.18. Tests the actual pure ArkTS helper, not the Harmony SDK or UI.
import assert from 'node:assert/strict';
import { copyFile, mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const directory = await mkdtemp(join(tmpdir(), 'kejian-form-check-'));
try {
  const source = join(root, 'ohos/entry/src/main/ets/widget/form_data.ets');
  const modulePath = join(directory, 'form_data.mts');
  await copyFile(source, modulePath);
  const { makeFormData } = await import(pathToFileURL(modulePath).href);
  const now = new Date(2026, 10, 19, 9);
  const first = { id: 'a', name: '课程甲', room: 'A301', date: '2026-11-19',
    start: '08:20', end: '09:55', changed: false };
  const second = { ...first, id: 'b', name: '课程乙', start: '10:10', end: '11:45' };
  const third = { ...first, id: 'c', name: '课程丙', date: '2026-11-20' };
  const snapshot = (lessons, extra = {}) => ({ version: 1, isDemo: false, lessons, ...extra });
  let checks = 0;
  function check(name, run) { run(); checks++; process.stdout.write('PASS ' + name + '\n'); }

  check('ongoing class and next class', () => {
    const data = makeFormData(snapshot([second, third, first]), now);
    assert.equal(data.course1Name, '课程甲');
    assert.equal(data.course2Name, '课程乙');
    assert.match(data.course1Detail, /进行中 08:20–09:55\nA301/);
  });
  check('exact end boundary advances to next date', () => {
    const data = makeFormData(snapshot([first, second, third]), new Date(2026, 10, 19, 9, 55));
    assert.equal(data.course1Name, '课程乙');
    assert.equal(data.course2Name, '课程丙');
    assert.match(data.course2Detail, /明天/);
  });
  check('last course is never duplicated', () => {
    const data = makeFormData(snapshot([first]), now);
    assert.equal(data.course1Name, '课程甲');
    assert.equal(data.course2Name, '暂无课程');
  });
  check('equal starts sort by stable lesson id without mutating input', () => {
    const lessons = [{ ...first, id: 'z', name: '后' }, first];
    assert.equal(makeFormData(snapshot(lessons), now).course1Name, '课程甲');
    assert.equal(lessons[0].id, 'z');
  });
  check('unknown snapshot version and missing data show an empty card', () => {
    for (const value of [null, {}, snapshot([first], { version: 2 }), snapshot(null)]) {
      assert.equal(makeFormData(value, now).course1Name, '暂无课程');
    }
  });
  check('invalid dates and malformed lessons are ignored', () => {
    const lessons = [null, {}, { ...first, date: '2026-02-30' },
      { ...first, start: '99:00' }, { ...first, end: '08:00' }, second];
    assert.equal(makeFormData(snapshot(lessons), now).course1Name, '课程乙');
  });
  check('rescheduled courses and missing room keep their status', () => {
    const data = makeFormData(snapshot([{ ...first, changed: true, room: '' }]), now);
    assert.match(data.course1Detail, /教室待补充 · 已调课/);
  });
  check('demo snapshots remain visibly marked', () => {
    assert.equal(makeFormData(snapshot([first], { isDemo: true }), now).heading, '示例课表');
  });
  check('month rollover uses calendar tomorrow', () => {
    const data = makeFormData(snapshot([{ ...first, date: '2027-01-01' }]), new Date(2026, 11, 31, 23, 59));
    assert.match(data.course1Detail, /明天/);
  });
  check('later dates display a calendar label', () => {
    assert.match(makeFormData(snapshot([{ ...first, date: '2026-11-25' }]), now).course1Detail, /11\/25/);
  });
  // Manifest checks are static; they do not substitute for DevEco validation.
  const forms = JSON.parse(await readFile(join(root,
    'ohos/entry/src/main/resources/base/profile/form_config.json'), 'utf8')).forms;
  const module = JSON.parse(await readFile(join(root, 'ohos/entry/src/main/module.json5'), 'utf8')).module;
  check('two independent dynamic cards use square and horizontal dimensions', () => {
    assert.equal(forms.length, 2);
    assert.deepEqual(forms.map(f => f.supportDimensions), [['2*2'], ['2*4']]);
    assert.equal(forms.filter(f => f.isDefault).length, 1);
    assert.ok(forms.every(f => f.isDynamic && f.updateEnabled));
    assert.equal(module.extensionAbilities[0].name, 'ScheduleFormAbility');
  });
  process.stdout.write(checks + ' HarmonyOS helper/config checks passed. No HAP or UI compilation performed.\n');
} finally {
  await rm(directory, { recursive: true, force: true });
}
