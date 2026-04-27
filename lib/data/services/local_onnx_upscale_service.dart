import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

final localOnnxUpscaleServiceProvider =
    Provider<LocalOnnxUpscaleService>((ref) {
  return const LocalOnnxUpscaleService();
});

class LocalOnnxUpscaleResult {
  const LocalOnnxUpscaleResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class LocalOnnxUpscaleService {
  const LocalOnnxUpscaleService();

  Future<LocalOnnxUpscaleResult> upscaleLanczos({
    required Uint8List imageBytes,
    required double scale,
  }) async {
    final source = img.decodeImage(imageBytes);
    if (source == null) {
      throw StateError('无法解码源图像');
    }

    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());
    final resized = LanczosImageResizer.resize(
      source,
      width: width,
      height: height,
    );
    return LocalOnnxUpscaleResult(
      bytes: Uint8List.fromList(img.encodePng(resized)),
      width: width,
      height: height,
    );
  }
}

class LanczosImageResizer {
  const LanczosImageResizer._();

  static const int _radius = 3;

  static img.Image resize(
    img.Image source, {
    required int width,
    required int height,
  }) {
    if (source.width == width && source.height == height) {
      return source.clone();
    }

    final destination = img.Image(width: width, height: height);
    final scaleX = source.width / width;
    final scaleY = source.height / height;

    for (var y = 0; y < height; y++) {
      final srcY = (y + 0.5) * scaleY - 0.5;
      final yStart = math.max(0, (srcY - _radius + 1).floor());
      final yEnd = math.min(source.height - 1, (srcY + _radius).floor());
      for (var x = 0; x < width; x++) {
        final srcX = (x + 0.5) * scaleX - 0.5;
        final xStart = math.max(0, (srcX - _radius + 1).floor());
        final xEnd = math.min(source.width - 1, (srcX + _radius).floor());

        var totalWeight = 0.0;
        var red = 0.0;
        var green = 0.0;
        var blue = 0.0;
        var alpha = 0.0;

        for (var sy = yStart; sy <= yEnd; sy++) {
          final wy = _lanczos(srcY - sy);
          if (wy == 0) continue;
          for (var sx = xStart; sx <= xEnd; sx++) {
            final wx = _lanczos(srcX - sx);
            if (wx == 0) continue;
            final weight = wx * wy;
            final pixel = source.getPixel(sx, sy);
            totalWeight += weight;
            red += pixel.r * weight;
            green += pixel.g * weight;
            blue += pixel.b * weight;
            alpha += pixel.a * weight;
          }
        }

        if (totalWeight == 0) {
          final nearest = source.getPixel(
            srcX.round().clamp(0, source.width - 1).toInt(),
            srcY.round().clamp(0, source.height - 1).toInt(),
          );
          destination.setPixel(x, y, nearest);
        } else {
          destination.setPixelRgba(
            x,
            y,
            _clampChannel(red / totalWeight),
            _clampChannel(green / totalWeight),
            _clampChannel(blue / totalWeight),
            _clampChannel(alpha / totalWeight),
          );
        }
      }
    }

    return destination;
  }

  static double _lanczos(double x) {
    final ax = x.abs();
    if (ax < 1e-7) return 1;
    if (ax >= _radius) return 0;
    return _sinc(ax) * _sinc(ax / _radius);
  }

  static double _sinc(double x) {
    final v = math.pi * x;
    return math.sin(v) / v;
  }

  static int _clampChannel(double value) {
    return value.round().clamp(0, 255).toInt();
  }
}
