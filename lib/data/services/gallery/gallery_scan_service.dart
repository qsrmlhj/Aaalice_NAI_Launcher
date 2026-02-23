import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../image_metadata_service.dart';

/// 扫描结果
class ScanResult {
  int filesScanned = 0;
  int filesAdded = 0;
  int filesUpdated = 0;
  int filesDeleted = 0;
  int filesSkipped = 0;
  Duration duration = Duration.zero;
  List<String> errors = [];

  @override
  String toString() {
    return 'ScanResult(scanned: $filesScanned, added: $filesAdded, '
        'updated: $filesUpdated, skipped: $filesSkipped, deleted: $filesDeleted, duration: $duration)';
  }
}

/// 扫描进度回调
typedef ScanProgressCallback = void Function({
  required int processed,
  required int total,
  String? currentFile,
  required String phase,
});

/// 扫描优先级
enum ScanPriority { high, low }

/// 批量解析结果（从 isolate 返回）
class _ParseResult {
  final List<({String path, NaiImageMetadata? metadata, int? width, int? height})> results;
  final List<String> errors;

  _ParseResult(this.results, this.errors);
}

/// 画廊扫描服务
///
/// 策略：
/// - 小批量（<=500张）：主线程直接处理
/// - 大批量（>500张）：使用 isolate 批量解析
class GalleryScanService {
  final GalleryDataSource _dataSource;

  static const List<String> _supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
  static const int _batchSize = 50;
  static const int _isolateThreshold = 500;
  static const int _highPriorityDelayMs = 10;
  static const int _lowPriorityDelayMs = 50;

  GalleryScanService({required GalleryDataSource dataSource}) : _dataSource = dataSource;

  static GalleryScanService? _instance;
  static GalleryScanService get instance {
    _instance ??= GalleryScanService(dataSource: GalleryDataSource());
    return _instance!;
  }

  /// 检测需要处理的文件数量
  Future<(int, int)> detectFilesNeedProcessing(Directory rootDir) async {
    final existingFiles = await _getAllFileHashes();
    final existingPaths = existingFiles.keys.toSet();

    int totalFiles = 0;
    int needProcessing = 0;

    await for (final file in _scanDirectory(rootDir)) {
      totalFiles++;
      final path = file.path;
      final existingHash = existingFiles[path];

      if (!existingPaths.contains(path)) {
        needProcessing++;
      } else if (existingHash != null) {
        final currentHash = await _computeFileHash(file);
        if (currentHash != existingHash) {
          needProcessing++;
        }
      }
    }

    return (totalFiles, needProcessing);
  }

  /// 快速启动扫描
  Future<ScanResult> quickStartupScan(
    Directory rootDir, {
    int maxFiles = 100,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.high,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Quick startup scan started (max $maxFiles files)', 'GalleryScanService');

    try {
      onProgress?.call(processed: 0, total: 0, phase: 'checking');
      final existingFiles = await _getAllFileHashes();

      final recentFiles = await _collectRecentFiles(rootDir, maxFiles: maxFiles);
      result.filesScanned = recentFiles.length;

      final filesToProcess = <File>[];
      for (final file in recentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (existingHash == null) {
          filesToProcess.add(file);
        } else {
          final currentHash = await _computeFileHash(file);
          if (currentHash != existingHash) {
            filesToProcess.add(file);
          } else {
            result.filesSkipped++;
          }
        }
      }

      AppLogger.i(
        'Quick scan: ${recentFiles.length} files, ${filesToProcess.length} need processing',
        'GalleryScanService',
      );

      if (filesToProcess.isNotEmpty) {
        await _processFilesSmart(
          filesToProcess,
          result,
          isFullScan: false,
          onProgress: onProgress,
          priority: priority,
        );
      }
    } catch (e, stack) {
      AppLogger.e('Quick startup scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    AppLogger.i('Quick startup scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 完整增量扫描
  Future<ScanResult> incrementalScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Incremental scan started', 'GalleryScanService');

    try {
      onProgress?.call(processed: 0, total: 0, phase: 'checking');

      final existingFiles = await _getAllFileHashes();
      final existingPaths = existingFiles.keys.toSet();

      final currentFiles = <File>[];
      await for (final file in _scanDirectory(rootDir)) {
        currentFiles.add(file);
      }
      result.filesScanned = currentFiles.length;

      final filesToProcess = <File>[];
      for (final file in currentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (!existingPaths.contains(path)) {
          filesToProcess.add(file);
        } else if (existingHash != null) {
          final currentHash = await _computeFileHash(file);
          if (currentHash != existingHash) {
            filesToProcess.add(file);
          } else {
            result.filesSkipped++;
          }
        }
      }

      if (filesToProcess.isNotEmpty) {
        await _processFilesSmart(
          filesToProcess,
          result,
          isFullScan: false,
          onProgress: onProgress,
          priority: priority,
        );
      }

      final currentPaths = currentFiles.map((f) => f.path).toSet();
      final deletedPaths = existingPaths.difference(currentPaths);
      if (deletedPaths.isNotEmpty) {
        await _dataSource.batchMarkAsDeleted(deletedPaths.toList());
        result.filesDeleted = deletedPaths.length;
      }
    } catch (e, stack) {
      AppLogger.e('Incremental scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    onProgress?.call(processed: result.filesScanned, total: result.filesScanned, phase: 'completed');
    AppLogger.i('Incremental scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 全量扫描
  Future<ScanResult> fullScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Full scan started', 'GalleryScanService');

    try {
      final files = await _collectImageFiles(rootDir);
      result.filesScanned = files.length;

      await _processFilesSmart(
        files,
        result,
        isFullScan: true,
        onProgress: onProgress,
        priority: priority,
      );
    } catch (e, stack) {
      AppLogger.e('Full scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    onProgress?.call(processed: result.filesScanned, total: result.filesScanned, phase: 'completed');
    AppLogger.i('Full scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 查漏补缺：为缺少元数据的图片重新解析
  Future<ScanResult> fillMissingMetadata({
    ScanProgressCallback? onProgress,
    int batchSize = 100,
    ScanPriority priority = ScanPriority.low,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('开始查漏补缺：查找缺少元数据的图片', 'GalleryScanService');

    try {
      final allImages = await _dataSource.getAllImages();
      result.filesScanned = allImages.length;

      final filesNeedMetadata = <File>[];
      final imageIdMap = <String, int>{};

      for (final image in allImages) {
        if (image.isDeleted) continue;
        if (p.extension(image.filePath).toLowerCase() != '.png') continue;
        if (image.id == null) continue;

        final metadata = await _dataSource.getMetadataByImageId(image.id!);
        if (metadata == null || metadata.prompt.isEmpty) {
          final file = File(image.filePath);
          if (await file.exists()) {
            filesNeedMetadata.add(file);
            imageIdMap[image.filePath] = image.id!;
          }
        }
      }

      AppLogger.i(
        '发现 ${filesNeedMetadata.length} 张图片需要补充元数据（共 ${allImages.length} 张）',
        'GalleryScanService',
      );

      if (filesNeedMetadata.isEmpty) {
        AppLogger.i('所有图片已有元数据，无需补充', 'GalleryScanService');
        return result;
      }

      await _processMetadataBatchesWithIsolate(
        filesNeedMetadata,
        imageIdMap,
        result,
        batchSize: batchSize,
        onProgress: onProgress,
        priority: priority,
      );

      AppLogger.i(
        '查漏补缺完成: ${result.filesUpdated} 张图片已更新元数据',
        'GalleryScanService',
      );
    } catch (e, stack) {
      AppLogger.e('查漏补缺失败', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    return result;
  }

  Future<void> _processMetadataBatchesWithIsolate(
    List<File> files,
    Map<String, int> imageIdMap,
    ScanResult result, {
    required int batchSize,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    int processedCount = 0;
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i += batchSize) {
      final batch = files.skip(i).take(batchSize).toList();
      final batchNum = (i ~/ batchSize) + 1;
      final totalBatches = ((files.length - 1) ~/ batchSize) + 1;

      AppLogger.d('处理批次 $batchNum/$totalBatches: ${batch.length} 张图片', 'GalleryScanService');
      onProgress?.call(
        processed: i,
        total: totalFiles,
        phase: 'filling_metadata_batch_$batchNum',
      );

      final paths = <String>[];
      final bytesList = <Uint8List>[];

      for (final file in batch) {
        try {
          final bytes = await file.readAsBytes();
          paths.add(file.path);
          bytesList.add(bytes);
        } catch (e) {
          result.errors.add('${file.path}: $e');
        }
      }

      if (paths.isEmpty) continue;

      final parseResult = await _parseInIsolate(paths, bytesList);

      for (var j = 0; j < parseResult.results.length; j++) {
        final res = parseResult.results[j];
        final imageId = imageIdMap[res.path];

        if (imageId != null && res.metadata != null && res.metadata!.hasData) {
          try {
            await _dataSource.upsertMetadata(imageId, res.metadata!);
            result.filesUpdated++;
            ImageMetadataService().cacheMetadata(res.path, res.metadata!);
          } catch (e) {
            result.errors.add('${res.path}: $e');
          }
        }
      }

      result.errors.addAll(parseResult.errors);
      processedCount += batch.length;

      onProgress?.call(
        processed: processedCount,
        total: totalFiles,
        currentFile: batch.last.path,
        phase: 'filling_metadata',
      );

      final delayMs = priority == ScanPriority.low ? _lowPriorityDelayMs : _highPriorityDelayMs;
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    onProgress?.call(processed: totalFiles, total: totalFiles, phase: 'completed');
  }

  /// 处理指定文件
  Future<void> processFiles(List<File> files, {ScanPriority priority = ScanPriority.low}) async {
    if (files.isEmpty) return;

    final result = ScanResult();
    await _processFilesSmart(files, result, isFullScan: false, priority: priority);

    AppLogger.d(
      'Processed ${files.length} files: ${result.filesAdded} added, ${result.filesUpdated} updated',
      'GalleryScanService',
    );
  }

  /// 标记文件为已删除
  Future<void> markAsDeleted(List<String> paths) async {
    if (paths.isEmpty) return;
    await _dataSource.batchMarkAsDeleted(paths);
  }

  Future<Map<String, String>> _getAllFileHashes() async {
    try {
      final images = await _dataSource.getAllImages();
      return {for (var img in images) img.filePath: img.fileHash ?? ''};
    } catch (e, stack) {
      AppLogger.e('Failed to get all file hashes', e, stack, 'GalleryScanService');
      return {};
    }
  }

  Future<void> _processFilesSmart(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    if (files.length <= _isolateThreshold) {
      AppLogger.d('Processing ${files.length} files in main thread', 'GalleryScanService');
      await _processInMainThread(
        files,
        result,
        isFullScan: isFullScan,
        onProgress: onProgress,
        priority: priority,
      );
    } else {
      AppLogger.d('Processing ${files.length} files with isolate', 'GalleryScanService');
      await _processWithIsolate(
        files,
        result,
        isFullScan: isFullScan,
        onProgress: onProgress,
        priority: priority,
      );
    }
  }

  Future<void> _processInMainThread(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    int processedCount = 0;

    for (var i = 0; i < files.length; i += _batchSize) {
      final batch = files.skip(i).take(_batchSize).toList();

      for (final file in batch) {
        await _processSingleFile(file, result, isFullScan: isFullScan);
        processedCount++;
      }

      onProgress?.call(
        processed: processedCount,
        total: files.length,
        currentFile: batch.last.path,
        phase: 'indexing',
      );

      final delay = priority == ScanPriority.low
          ? const Duration(milliseconds: _lowPriorityDelayMs)
          : Duration.zero;
      await Future.delayed(delay);
    }
  }

  Future<void> _processWithIsolate(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    int processedCount = 0;

    for (var i = 0; i < files.length; i += _batchSize) {
      final batch = files.skip(i).take(_batchSize).toList();

      final paths = <String>[];
      final bytesList = <Uint8List>[];

      for (final file in batch) {
        try {
          final bytes = await file.readAsBytes();
          paths.add(file.path);
          bytesList.add(bytes);
        } catch (e) {
          result.errors.add('${file.path}: $e');
        }
      }

      if (paths.isEmpty) continue;

      final parseResult = await _parseInIsolate(paths, bytesList);

      for (var j = 0; j < parseResult.results.length; j++) {
        final res = parseResult.results[j];
        await _writeToDatabase(
          res.path,
          res.metadata,
          res.width,
          res.height,
          result,
          isFullScan: isFullScan,
        );

        if (res.metadata != null && res.metadata!.hasData) {
          ImageMetadataService().cacheMetadata(res.path, res.metadata!);
        }
      }

      result.errors.addAll(parseResult.errors);
      processedCount += batch.length;

      onProgress?.call(
        processed: processedCount,
        total: files.length,
        currentFile: batch.last.path,
        phase: 'indexing',
      );

      final delay = priority == ScanPriority.low
          ? const Duration(milliseconds: _lowPriorityDelayMs)
          : Duration.zero;
      await Future.delayed(delay);
    }
  }

  Future<_ParseResult> _parseInIsolate(List<String> paths, List<Uint8List> bytesList) async {
    return await Isolate.run(() async {
      final results = <({String path, NaiImageMetadata? metadata, int? width, int? height})>[];
      final errors = <String>[];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final bytes = bytesList[i];

        try {
          NaiImageMetadata? metadata;
          int? width;
          int? height;

          if (p.extension(path).toLowerCase() == '.png') {
            metadata = await NaiMetadataParser.extractFromBytes(bytes);
            if (metadata != null) {
              width = metadata.width;
              height = metadata.height;
            }
          }

          results.add((path: path, metadata: metadata, width: width, height: height));
        } catch (e) {
          errors.add('$path: $e');
        }
      }

      return _ParseResult(results, errors);
    });
  }

  Future<void> _writeToDatabase(
    String path,
    NaiImageMetadata? metadata,
    int? width,
    int? height,
    ScanResult result, {
    required bool isFullScan,
  }) async {
    try {
      final file = File(path);
      final stat = await file.stat();
      final fileName = p.basename(path);
      final fileHash = await _computeFileHash(file);

      final aspectRatio = (width != null && height != null && height > 0)
          ? width / height
          : null;

      final existingIdByHash = await _dataSource.getImageIdByHash(fileHash);
      if (existingIdByHash != null) {
        final existingRecord = await _dataSource.getImageById(existingIdByHash);
        if (existingRecord != null && existingRecord.filePath != path) {
          AppLogger.i(
            'Detected renamed file: ${existingRecord.filePath} -> $path',
            'GalleryScanService',
          );
          await _handleRenamedFile(existingIdByHash, path, fileName, stat, result);
          ImageMetadataService().notifyPathChanged(existingRecord.filePath, path);
          return;
        }
      }

      final imageId = await _dataSource.upsertImage(
        filePath: path,
        fileName: fileName,
        fileSize: stat.size,
        fileHash: fileHash,
        width: width,
        height: height,
        aspectRatio: aspectRatio,
        createdAt: stat.modified,
        modifiedAt: stat.modified,
        resolutionKey: width != null && height != null ? '${width}x$height' : null,
      );

      if (metadata != null && metadata.hasData) {
        await _dataSource.upsertMetadata(imageId, metadata);
      }

      if (isFullScan) {
        result.filesAdded++;
      } else {
        final existingId = await _dataSource.getImageIdByPath(path);
        if (existingId != null && existingId != imageId) {
          result.filesUpdated++;
        } else {
          result.filesAdded++;
        }
      }
    } catch (e) {
      result.errors.add('$path: $e');
    }
  }

  Future<void> _handleRenamedFile(
    int imageId,
    String newPath,
    String newFileName,
    FileStat stat,
    ScanResult result,
  ) async {
    try {
      await _dataSource.updateFilePath(imageId, newPath, newFileName: newFileName);
      result.filesUpdated++;
      AppLogger.d('Updated path for image $imageId: $newPath', 'GalleryScanService');
    } catch (e, stack) {
      AppLogger.e('Failed to handle renamed file: $newPath', e, stack, 'GalleryScanService');
      result.errors.add('$newPath: $e');
    }
  }

  Future<void> _processSingleFile(
    File file,
    ScanResult result, {
    required bool isFullScan,
  }) async {
    NaiImageMetadata? metadata;
    int? width;
    int? height;

    if (p.extension(file.path).toLowerCase() == '.png') {
      try {
        metadata = await ImageMetadataService().getMetadata(file.path);
        width = metadata?.width;
        height = metadata?.height;
      } catch (e) {
        result.errors.add('${file.path}: $e');
        return;
      }
    }

    await _writeToDatabase(
      file.path,
      metadata,
      width,
      height,
      result,
      isFullScan: isFullScan,
    );
  }

  Future<List<File>> _collectImageFiles(Directory dir) async {
    final files = <File>[];
    await for (final file in _scanDirectory(dir)) {
      files.add(file);
    }
    return files;
  }

  Future<List<File>> _collectRecentFiles(Directory dir, {required int maxFiles}) async {
    final filesWithTime = <File, DateTime>{};

    await for (final file in _scanDirectory(dir)) {
      try {
        final stat = await file.stat();
        filesWithTime[file] = stat.modified;
      } catch (e) {
        // 文件可能已被删除或无法访问，跳过
      }
    }

    final sortedEntries = filesWithTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(maxFiles).map((e) => e.key).toList();
  }

  Stream<File> _scanDirectory(Directory dir) async* {
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          yield entity;
        }
      }
    }
  }

  Future<String> _computeFileHash(File file) async {
    try {
      final stat = await file.stat();
      final fileSize = stat.size;

      if (fileSize <= 16384) {
        final bytes = await file.readAsBytes();
        return sha256.convert(bytes).toString();
      }

      final raf = await file.open(mode: FileMode.read);
      try {
        final headBytes = await raf.read(8192);
        await raf.setPosition(fileSize - 8192);
        final tailBytes = await raf.read(8192);

        final combined = Uint8List(headBytes.length + tailBytes.length + 8);
        combined.setAll(0, headBytes);
        combined.setAll(headBytes.length, tailBytes);

        final sizeBytes = ByteData(8);
        sizeBytes.setInt64(0, fileSize);
        combined.setAll(headBytes.length + tailBytes.length, sizeBytes.buffer.asUint8List());

        return sha256.convert(combined).toString();
      } finally {
        await raf.close();
      }
    } catch (e) {
      return '';
    }
  }
}
