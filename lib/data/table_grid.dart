import 'dart:typed_data';

class TableGrid {
  final List<double> horizontal, vertical;
  const TableGrid(this.horizontal, this.vertical);
}

/// Locate long straight rules. Text strokes are too short to pass the threshold.
/// Callers pass a copy when they also want rules erased before OCR.
TableGrid detectTableGrid(
  Uint8List rgba,
  int width,
  int height, {
  bool erase = false,
}) {
  final horizontal = List<int>.filled(height, 0);
  final vertical = List<int>.filled(width, 0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (rgba[i] < 120 &&
          rgba[i + 1] < 120 &&
          rgba[i + 2] < 120 &&
          rgba[i + 3] > 180) {
        horizontal[y]++;
        vertical[x]++;
      }
    }
  }
  List<double> bands(List<int> projection, double threshold) {
    final result = <double>[];
    for (var i = 0; i < projection.length; i++) {
      if (projection[i] < threshold) continue;
      final start = i;
      while (i + 1 < projection.length && projection[i + 1] >= threshold) {
        i++;
      }
      result.add((start + i) / 2);
    }
    return result;
  }

  final h = bands(horizontal, width * .55), v = bands(vertical, height * .38);
  if (erase && h.length >= 3 && v.length >= 4) {
    for (final line in h) {
      for (var y = (line - 2).round(); y <= (line + 2).round(); y++) {
        if (y < 0 || y >= height) continue;
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          rgba[i] = rgba[i + 1] = rgba[i + 2] = 255;
        }
      }
    }
    for (final line in v) {
      for (var x = (line - 2).round(); x <= (line + 2).round(); x++) {
        if (x < 0 || x >= width) continue;
        for (var y = 0; y < height; y++) {
          final i = (y * width + x) * 4;
          rgba[i] = rgba[i + 1] = rgba[i + 2] = 255;
        }
      }
    }
  }
  return TableGrid(h, v);
}
