import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { makeFormData, WidgetSnapshot } from './form_data';
import { readOptionalText, writeTextAtomic } from '../platform/PrivateFiles';

const SNAPSHOT_FILE = 'kejian-schedule-snapshot.json';
const FORM_IDS_FILE = 'kejian-form-ids.json';

export default class ScheduleFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const parameters = want.parameters ?? {};
    const formId = parameters[formInfo.FormParam.IDENTITY_KEY];
    if (formId !== undefined && formId !== null) {
      this.storeFormId(String(formId), true);
    }
    const snapshot = this.readSnapshot();
    return formBindingData.createFormBindingData(makeFormData(snapshot));
  }

  onUpdateForm(formId: string): void {
    const data = formBindingData.createFormBindingData(makeFormData(this.readSnapshot()));
    void formProvider.updateForm(formId, data).catch(() => {});
  }

  onRemoveForm(formId: string): void {
    this.storeFormId(formId, false);
  }

  private readSnapshot(): WidgetSnapshot | null {
    try {
      const source = readOptionalText(this.context.filesDir + '/' + SNAPSHOT_FILE);
      return source === null ? null : JSON.parse(source) as WidgetSnapshot;
    } catch (_) {
      return null;
    }
  }

  private storeFormId(formId: string, add: boolean): void {
    if (formId.length === 0) {
      return;
    }
    const path = this.context.filesDir + '/' + FORM_IDS_FILE;
    let ids: Array<string> = [];
    try {
      const source = readOptionalText(path);
      ids = source === null ? [] : JSON.parse(source) as Array<string>;
    } catch (_) {
      ids = [];
    }
    ids = ids.filter((id: string) => id !== formId);
    if (add) {
      ids.push(formId);
    }
    writeTextAtomic(path, JSON.stringify(ids));
  }
}
