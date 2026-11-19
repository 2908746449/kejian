import { ScheduleFormContent } from './ScheduleFormContent';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct CompactForm {
  build() {
    ScheduleFormContent({ wide: false });
  }
}
