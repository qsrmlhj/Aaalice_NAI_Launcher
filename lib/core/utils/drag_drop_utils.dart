import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/gallery/local_image_record.dart';

/// 拖拽数据格式常量
class DragDropFormats {
  /// PNG 图像格式
  static const String png = 'image/png';

  /// 文件 URI 格式
  static const String fileUri = 'text/uri-list';

  /// 自定义本地图像记录格式
  static const String localImageRecord = 'application/x-local-image-record';
}

/// 图像拖拽数据包装类
///
/// 用于在拖拽操作中传递 LocalImageRecord 数据
class ImageDragData {
  /// 图像记录
  final LocalImageRecord record;

  /// 可选的预览图像数据
  final Uint8List? previewBytes;

  /// 创建图像拖拽数据
  const ImageDragData({
    required this.record,
    this.previewBytes,
  });

  /// 从 LocalImageRecord 创建拖拽数据
  factory ImageDragData.fromRecord(
    LocalImageRecord record, {
    Uint8List? previewBytes,
  }) {
    return ImageDragData(
      record: record,
      previewBytes: previewBytes,
    );
  }

  /// 获取文件路径
  String get path => record.path;

  /// 获取文件名
  String get fileName {
    final parts = record.path.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : record.path;
  }

  /// 获取文件扩展名
  String get extension {
    final name = fileName;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(dotIndex + 1).toLowerCase() : '';
  }

  /// 是否为 PNG 格式
  bool get isPng => extension == 'png';
}

/// 构建图像拖拽预览 Widget
///
/// 小而精美的设计，纵向长条形卡片
///
/// [theme] - 当前主题
/// [dragData] - 拖拽数据
/// [width] - 预览宽度，默认 72（更窄更精致）
/// [hintText] - 操作提示文字
/// [showHint] - 是否显示操作提示
Widget buildImageDragFeedback(
  ThemeData theme,
  ImageDragData dragData, {
  double width = 72,
  String? hintText,
  bool showHint = true,
}) {
  final colorScheme = theme.colorScheme;
  
  return Material(
    // 柔和的阴影
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.3),
    // 外层大圆角
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: width,
      decoration: BoxDecoration(
        // 渐变背景，增加质感
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        // 细边框
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图片区域（占主要空间）
            _buildImageSection(theme, dragData),
            
            // 信息区域（紧凑）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.7),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 文件名（截断显示）
                  Text(
                    dragData.fileName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  // 文件大小（更小的灰色文字）
                  Text(
                    _formatFileSize(dragData.record.size),
                    style: TextStyle(
                      fontSize: 7.5,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            
            // 提示区域（迷你标签样式）
            if (showHint)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 8,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      hintText ?? '拖拽',
                      style: TextStyle(
                        fontSize: 7.5,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 构建图片区域
Widget _buildImageSection(ThemeData theme, ImageDragData dragData) {
  final colorScheme = theme.colorScheme;
  
  // 如果有预览数据或文件存在，显示图片
  if (dragData.previewBytes != null || 
      (dragData.path.isNotEmpty && File(dragData.path).existsSync())) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        child: _buildImageContent(dragData),
      ),
    );
  }
  
  // 占位符样式
  return Container(
    width: double.infinity,
    height: 72,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.surfaceContainerHighest,
          colorScheme.surfaceContainerHigh,
        ],
      ),
    ),
    child: Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          dragData.isPng ? Icons.image_rounded : Icons.insert_drive_file_rounded,
          size: 20,
          color: colorScheme.primary.withOpacity(0.6),
        ),
      ),
    ),
  );
}

/// 构建图片内容
Widget _buildImageContent(ImageDragData dragData) {
  if (dragData.previewBytes != null) {
    return Image.memory(
      dragData.previewBytes!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
    );
  }
  
  return Image.file(
    File(dragData.path),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
  );
}

/// 错误占位符
Widget _buildErrorPlaceholder() {
  return Center(
    child: Icon(
      Icons.broken_image_rounded,
      size: 24,
      color: Colors.grey[400],
    ),
  );
}

/// 格式化文件大小
String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
