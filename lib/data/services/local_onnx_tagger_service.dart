import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import 'local_onnx_model_service.dart';

final localOnnxTaggerServiceProvider = Provider<LocalOnnxTaggerService>((ref) {
  return const LocalOnnxTaggerService();
});

class OnnxTaggerLabel {
  const OnnxTaggerLabel({
    required this.name,
    this.category,
  });

  final String name;
  final String? category;

  bool get isRating => category == '9' || name.startsWith('rating:');
}

class OnnxTaggerTag {
  const OnnxTaggerTag({
    required this.name,
    required this.score,
    this.category,
  });

  final String name;
  final double score;
  final String? category;
}

class OnnxTaggerResult {
  const OnnxTaggerResult({
    required this.model,
    required this.tags,
  });

  final LocalOnnxModelDescriptor model;
  final List<OnnxTaggerTag> tags;

  String get prompt => tags.map((tag) => tag.name).join(', ');
}

class LocalOnnxTaggerService {
  const LocalOnnxTaggerService();

  static const int defaultInputSize = 448;

  Future<OnnxTaggerResult> tagImage({
    required Uint8List imageBytes,
    required LocalOnnxModelDescriptor model,
    double threshold = 0.35,
    bool includeRatings = false,
  }) async {
    if (model.labelsPath == null || model.labelsPath!.isEmpty) {
      throw StateError(
        '模型缺少标签文件，请放置 selected_tags.csv / tags.csv / labels.txt',
      );
    }

    final labels = await loadLabels(model.labelsPath!);
    if (labels.isEmpty) {
      throw StateError('标签文件为空: ${model.labelsPath}');
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('无法解码图片');
    }

    final inputSize = _resolveInputSize(model);
    final input = _preprocessImage(decoded, inputSize);
    final options = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final session = OrtSession.fromFile(File(model.path), options);
    final runOptions = OrtRunOptions();
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      input,
      [1, inputSize, inputSize, 3],
    );

    List<OrtValue?>? outputs;
    try {
      final inputName =
          session.inputNames.isNotEmpty ? session.inputNames.first : 'input';
      final asyncOutputs = session.runAsync(runOptions, {inputName: inputOrt});
      outputs = asyncOutputs == null
          ? session.run(runOptions, {inputName: inputOrt})
          : await asyncOutputs;
      final scores = outputs.isNotEmpty
          ? _flattenScores(outputs.first?.value)
          : <double>[];
      return OnnxTaggerResult(
        model: model,
        tags: _buildTags(
          labels: labels,
          scores: scores,
          threshold: threshold,
          includeRatings: includeRatings,
        ),
      );
    } finally {
      for (final output in outputs ?? const <OrtValue?>[]) {
        output?.release();
      }
      inputOrt.release();
      runOptions.release();
      session.release();
      options.release();
    }
  }

  Future<List<OnnxTaggerLabel>> loadLabels(String labelsPath) async {
    final file = File(labelsPath);
    if (!await file.exists()) {
      return const [];
    }

    final extension = labelsPath.split('.').last.toLowerCase();
    final raw = await file.readAsString();
    if (extension == 'json') {
      return _parseJsonLabels(raw);
    }
    if (extension == 'csv') {
      return _parseCsvLabels(raw);
    }
    return _parseTextLabels(raw);
  }

  int _resolveInputSize(LocalOnnxModelDescriptor model) {
    final lower = model.name.toLowerCase();
    final match = RegExp(r'(?:^|[^0-9])(224|256|384|448|512)(?:[^0-9]|$)')
        .firstMatch(lower);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return defaultInputSize;
  }

  Float32List _preprocessImage(img.Image source, int inputSize) {
    final squareSize = math.max(source.width, source.height);
    final canvas = img.Image(width: squareSize, height: squareSize);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      canvas,
      source,
      dstX: (squareSize - source.width) ~/ 2,
      dstY: (squareSize - source.height) ~/ 2,
    );

    final resized = img.copyResize(
      canvas,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.cubic,
    );

    final data = Float32List(inputSize * inputSize * 3);
    var offset = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        data[offset++] = pixel.r.toDouble();
        data[offset++] = pixel.g.toDouble();
        data[offset++] = pixel.b.toDouble();
      }
    }
    return data;
  }

  List<double> _flattenScores(Object? value) {
    final scores = <double>[];

    void walk(Object? current) {
      if (current is num) {
        scores.add(current.toDouble());
        return;
      }
      if (current is Iterable) {
        for (final item in current) {
          walk(item);
        }
      }
    }

    walk(value);
    return scores;
  }

  List<OnnxTaggerTag> _buildTags({
    required List<OnnxTaggerLabel> labels,
    required List<double> scores,
    required double threshold,
    required bool includeRatings,
  }) {
    final count = math.min(labels.length, scores.length);
    final tags = <OnnxTaggerTag>[];
    for (var i = 0; i < count; i++) {
      final label = labels[i];
      final score = scores[i];
      if (score < threshold) continue;
      if (!includeRatings && label.isRating) continue;
      tags.add(
        OnnxTaggerTag(
          name: label.name,
          score: score,
          category: label.category,
        ),
      );
    }
    tags.sort((a, b) => b.score.compareTo(a.score));
    return tags;
  }

  List<OnnxTaggerLabel> _parseCsvLabels(String raw) {
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(raw)
        .where((row) => row.isNotEmpty)
        .toList();
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final hasHeader = header.contains('name') ||
        header.contains('tag') ||
        header.contains('category');
    final headerNameIndex = hasHeader
        ? math.max(header.indexOf('name'), header.indexOf('tag'))
        : -1;
    final nameIndex = headerNameIndex >= 0
        ? headerNameIndex
        : rows.first.length > 1
            ? 1
            : 0;
    final categoryIndex = hasHeader ? header.indexOf('category') : 2;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    return dataRows
        .map((row) {
          if (row.length <= nameIndex) {
            return null;
          }
          final name = row[nameIndex].toString().trim();
          if (name.isEmpty) {
            return null;
          }
          final category = categoryIndex >= 0 && row.length > categoryIndex
              ? row[categoryIndex].toString().trim()
              : null;
          return OnnxTaggerLabel(name: name, category: category);
        })
        .whereType<OnnxTaggerLabel>()
        .toList();
  }

  List<OnnxTaggerLabel> _parseTextLabels(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) {
      final parts = line.split(RegExp(r'[\t,]'));
      return OnnxTaggerLabel(name: parts.first.trim());
    }).toList();
  }

  List<OnnxTaggerLabel> _parseJsonLabels(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((item) {
            if (item is String) {
              return OnnxTaggerLabel(name: item.trim());
            }
            if (item is Map<String, dynamic>) {
              final name = (item['name'] ?? item['tag'] ?? item['label'])
                  ?.toString()
                  .trim();
              if (name == null || name.isEmpty) {
                return null;
              }
              return OnnxTaggerLabel(
                name: name,
                category: item['category']?.toString(),
              );
            }
            return null;
          })
          .whereType<OnnxTaggerLabel>()
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final labels = decoded['labels'] ?? decoded['tags'];
      if (labels is List) {
        return labels
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .map((item) => OnnxTaggerLabel(name: item))
            .toList();
      }
    }
    return const [];
  }
}
