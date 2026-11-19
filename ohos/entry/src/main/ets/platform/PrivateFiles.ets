import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export function readOptionalText(path: string): string | null {
  // A missing file means first launch. Other errors must preserve the old data.
  if (!fileIo.accessSync(path)) {
    return null;
  }
  return fileIo.readTextSync(path);
}

export function writeAll(fd: number, data: Uint8Array): void {
  let offset = 0;
  while (offset < data.byteLength) {
    const count = fileIo.writeSync(fd,
      data.buffer.slice(data.byteOffset + offset, data.byteOffset + data.byteLength));
    if (count <= 0) {
      throw new Error('File write did not complete');
    }
    offset += count;
  }
}

export function writeTextAtomic(path: string, source: string): void {
  const tempPath = path + '.tmp';
  const file = fileIo.openSync(tempPath,
    fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    writeAll(file.fd, new util.TextEncoder().encodeInto(source));
    fileIo.fsyncSync(file.fd);
  } finally {
    fileIo.closeSync(file);
  }
  // Rename only after the complete document has reached the private file.
  fileIo.renameSync(tempPath, path);
}
