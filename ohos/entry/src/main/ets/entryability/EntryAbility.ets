
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { MethodCall, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { fileIo, picker } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { makeFormData, WidgetSnapshot } from '../widget/form_data';
import { readOptionalText, writeAll, writeTextAtomic } from '../platform/PrivateFiles';

const SNAPSHOT_FILE = 'kejian-schedule-snapshot.json';
const STORAGE_FILE = 'kejian-schedule.json';

interface RecognitionBox {
  text: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

export default class EntryAbility extends FlutterAbility {
  private recognizing: boolean = false;
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    this.registerStorageChannel(flutterEngine);
    this.registerFileChannel(flutterEngine);
    this.registerRecognitionChannel(flutterEngine);
    this.registerWidgetChannel(flutterEngine);
  }

  private registerStorageChannel(flutterEngine: FlutterEngine): void {
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'dev.kejian/storage');
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          const path = this.context.filesDir + '/' + STORAGE_FILE;
          if (call.method === 'load') {
            result.success(readOptionalText(path));
            return;
          }
          if (call.method === 'cacheDirectory') {
            result.success(this.context.cacheDir);
            return;
          }
          if (call.method === 'save') {
            const source = call.args as string;
            writeTextAtomic(path, source);
            result.success(null);
            return;
          }
          result.notImplemented();
        } catch (error) {
          result.error('STORAGE_FAILED', '无法读写本地课表。', String(error));
        }
      }
    });
  }

  private registerFileChannel(flutterEngine: FlutterEngine): void {
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'dev.kejian/files');
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        void this.handleFileCall(call, result);
      }
    });
  }

  private async handleFileCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker(this.context);
      if (call.method === 'pick') {
        const extensions = call.args as Array<string>;
        const options = new picker.DocumentSelectOptions();
        options.maxSelectNumber = 1;
        options.fileSuffixFilters = ['课表文件|' + extensions.map((extension: string) => '.' + extension).join(',')];
        const uris = await documentPicker.select(options);
        if (uris.length === 0) {
          result.success(null);
          return;
        }
        const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
        try {
          const stat = fileIo.statSync(file.fd);
          if (stat.size > 20 * 1024 * 1024) {
            throw new Error('请选择 20 MB 以内的课表文件');
          }
          const bytes = new Uint8Array(stat.size);
          let offset = 0;
          while (offset < bytes.byteLength) {
            const chunk = new ArrayBuffer(Math.min(64 * 1024, bytes.byteLength - offset));
            const count = fileIo.readSync(file.fd, chunk, { offset: offset });
            if (count <= 0) {
              throw new Error('无法完整读取所选文件。');
            }
            bytes.set(new Uint8Array(chunk, 0, count), offset);
            offset += count;
          }
          const uriName = decodeURIComponent(uris[0].split('/').pop() ?? 'course-file');
          result.success({ name: uriName, bytes: bytes });
        } finally {
          fileIo.closeSync(file);
        }
        return;
      }
      if (call.method === 'save') {
        const options = new picker.DocumentSaveOptions();
        options.newFileNames = [call.argument('name') as string];
        const uris = await documentPicker.save(options);
        if (uris.length === 0) {
          result.success(null);
          return;
        }
        const file = fileIo.openSync(uris[0],
          fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          writeAll(file.fd, call.argument('bytes') as Uint8Array);
          fileIo.fsyncSync(file.fd);
        } finally {
          fileIo.closeSync(file);
        }
        result.success(uris[0]);
        return;
      }
      result.notImplemented();
    } catch (error) {
      result.error('FILE_ACCESS_FAILED', '无法访问所选文件。', String(error));
    }
  }

  private registerRecognitionChannel(flutterEngine: FlutterEngine): void {
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'dev.kejian/recognition');
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method !== 'recognize') {
          result.notImplemented();
          return;
        }
        if (this.recognizing) {
          result.error('OCR_BUSY', '正在识别另一份课表，请稍候。', null);
          return;
        }
        this.recognizing = true;
        void this.recognizeImage(call.args as Uint8Array).then((boxes: Array<RecognitionBox>) => {
          result.success(boxes);
        }).catch((error: Error) => {
          result.error('OCR_FAILED', '图片识别失败，请换一张清晰完整的课表。', error.message);
        }).finally(() => {
          this.recognizing = false;
        });
      }
    });
  }

  private async recognizeImage(bytes: Uint8Array): Promise<Array<RecognitionBox>> {
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      const initialized = await textRecognition.init();
      if (!initialized) {
        throw new Error('鸿蒙系统文字识别服务不可用。');
      }
      const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      source = image.createImageSource(buffer);
      pixelMap = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      const recognition = await textRecognition.recognizeText({ pixelMap: pixelMap });
      const boxes: Array<RecognitionBox> = [];
      for (const block of recognition.blocks) {
        for (const line of block.lines) {
          for (const word of line.words) {
            const points = word.cornerPoints;
            if (points.length < 4) {
              continue;
            }
            const xs = points.map((point) => point.x);
            const ys = points.map((point) => point.y);
            const left = Math.min(...xs);
            const top = Math.min(...ys);
            const width = Math.max(...xs) - left;
            const height = Math.max(...ys) - top;
            const characters = Array.from(word.value);
            characters.forEach((character: string, index: number) => {
              boxes.push({
                text: character,
                x: left + width * index / characters.length,
                y: top,
                width: width / characters.length,
                height: height
              });
            });
          }
        }
      }
      return boxes;
    } finally {
      // Cleanup failures must not hide a recognition error or a valid result.
      try { await pixelMap?.release(); } catch (_) {}
      try { await source?.release(); } catch (_) {}
      try { await textRecognition.release(); } catch (_) {}
    }
  }

  private registerWidgetChannel(flutterEngine: FlutterEngine): void {
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'dev.kejian/widgets');
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method !== 'sync') {
          result.notImplemented();
          return;
        }
        try {
          const source = call.args as string;
          const snapshot = JSON.parse(source) as WidgetSnapshot;
          if (snapshot === null || snapshot.version !== 1 || !Array.isArray(snapshot.lessons)) {
            throw new Error('Unsupported widget snapshot');
          }
          const path = this.context.filesDir + '/' + SNAPSHOT_FILE;
          writeTextAtomic(path, source);
          void this.updateInstalledForms(snapshot).then(() => result.success(null)).catch((error: Error) => {
            result.error('FORM_UPDATE_FAILED', '已保存课表，但无法更新服务卡片。', error.message);
          });
        } catch (error) {
          result.error('WIDGET_SYNC_FAILED', '无法保存服务卡片课表。', String(error));
        }
      }
    });
  }

  private async updateInstalledForms(snapshot: WidgetSnapshot): Promise<void> {
    const path = this.context.filesDir + '/kejian-form-ids.json';
    const source = readOptionalText(path);
    if (source === null) {
      return;
    }
    const formIds = JSON.parse(source) as Array<string>;
    let failed = false;
    for (const formId of formIds) {
      try {
        await formProvider.updateForm(formId,
          formBindingData.createFormBindingData(makeFormData(snapshot)));
      } catch (_) {
        // Retain the id on transient system errors so the next sync can retry.
        failed = true;
      }
    }
    if (failed) {
      throw new Error('One or more service cards could not be updated; please retry.');
    }
  }
}
