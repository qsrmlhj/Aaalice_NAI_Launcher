import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

class ShareImageSettings {
  const ShareImageSettings({
    this.stripMetadataForCopyAndDrag = false,
    this.assetProtectionMode = false,
  });

  final bool stripMetadataForCopyAndDrag;
  final bool assetProtectionMode;

  bool get effectiveStripMetadataForCopyAndDrag =>
      assetProtectionMode || stripMetadataForCopyAndDrag;

  ShareImageSettings copyWith({
    bool? stripMetadataForCopyAndDrag,
    bool? assetProtectionMode,
  }) {
    return ShareImageSettings(
      stripMetadataForCopyAndDrag:
          stripMetadataForCopyAndDrag ?? this.stripMetadataForCopyAndDrag,
      assetProtectionMode: assetProtectionMode ?? this.assetProtectionMode,
    );
  }
}

final shareImageSettingsProvider =
    NotifierProvider<ShareImageSettingsNotifier, ShareImageSettings>(
  ShareImageSettingsNotifier.new,
);

class ShareImageSettingsNotifier extends Notifier<ShareImageSettings> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ShareImageSettings build() {
    return ShareImageSettings(
      stripMetadataForCopyAndDrag: _storage.getSetting<bool>(
            StorageKeys.shareStripMetadata,
            defaultValue: false,
          ) ??
          false,
      assetProtectionMode: _storage.getSetting<bool>(
            StorageKeys.assetProtectionMode,
            defaultValue: false,
          ) ??
          false,
    );
  }

  Future<void> setStripMetadataForCopyAndDrag(bool value) async {
    state = state.copyWith(stripMetadataForCopyAndDrag: value);
    await _storage.setSetting(StorageKeys.shareStripMetadata, value);
  }

  Future<void> setAssetProtectionMode(bool value) async {
    state = state.copyWith(assetProtectionMode: value);
    await _storage.setSetting(StorageKeys.assetProtectionMode, value);
  }
}
