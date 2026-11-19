import { ScheduleFormContent } from './ScheduleFormContent';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct WideForm {
  build() {
    ScheduleFormContent({ wide: true });
  }
}
