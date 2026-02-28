# Technology Stack

**Analysis Date:** 2026-02-28

## Languages

**Primary:**
- **Dart** 3.2+ - Main application language
- **Flutter** 3.16+ - UI framework

**Secondary:**
- **C++** - Windows platform plugin support (CMake)
- **Java/Kotlin** - Android platform support (Gradle)
- **Swift/Objective-C** - iOS/macOS platform support (not actively used)

## Runtime

**Environment:**
- Flutter SDK: >=3.16.0 <4.0.0
- Dart SDK: >=3.2.0 <4.0.0
- Platforms: Windows (primary), Android, Linux

**Package Manager:**
- **Pub** (Dart/Flutter package manager)
- Lockfile: `pubspec.lock` (present)

## Frameworks

**Core:**
- **flutter_riverpod** ^2.5.1 - State management with code generation
- **riverpod_annotation** ^2.3.5 - Riverpod code generation annotations
- **go_router** ^14.2.0 - Declarative routing with deep linking support

**Testing:**
- **flutter_test** (SDK) - Flutter testing framework
- **mocktail** ^1.0.3 - Mocking library for tests
- **glados** ^1.1.1 - Property-based testing
- **integration_test** (SDK) - Integration testing

**Build/Dev:**
- **build_runner** ^2.4.9 - Code generation runner
- **riverpod_generator** ^2.4.0 - Riverpod code generation
- **freezed** ^2.5.2 - Immutable data class generation
- **json_serializable** ^6.8.0 - JSON serialization generation
- **hive_generator** ^2.0.1 - Hive adapter generation
- **flutter_lints** ^4.0.0 - Dart/Flutter linting rules

## Key Dependencies

**Critical:**
- **dio** ^5.4.0 - HTTP client for API communication
- **dio_http2_adapter** ^2.3.0 - HTTP/2 support for Dio
- **flutter_riverpod** ^2.5.1 - Primary state management solution
- **freezed_annotation** ^2.4.1 - Immutable data models with copy methods

**Infrastructure:**
- **hive** ^2.2.3 + **hive_flutter** ^1.1.0 - NoSQL local storage
- **sqflite_common_ffi** ^2.3.4 - SQLite FFI for desktop platforms
- **flutter_secure_storage** ^9.2.4 - Encrypted secure storage for tokens
- **shared_preferences** ^2.2.3 - Simple key-value storage

**Network & API:**
- **dio** ^5.4.0 - Main HTTP client with interceptors
- **dio_http2_adapter** ^2.3.0 - HTTP/2 adapter for high-performance requests
- **win32_registry** ^1.1.3 - Windows registry access for system proxy detection

**Data Processing:**
- **msgpack_dart** ^1.0.1 - MessagePack decoding for streaming API responses
- **archive** ^3.6.1 - ZIP file handling
- **csv** ^6.0.0 - CSV parsing for data import/export
- **cryptography** ^2.7.0 - Blake2b + Argon2id for NAI authentication
- **crypto** ^3.0.3 - SHA hashing for unique ID generation

**Media Processing:**
- **image** ^4.1.7 - Dart image processing library
- **audioplayers** ^6.0.0 - Sound effects playback
- **video_player** ^2.8.0 + **video_player_media_kit** ^1.0.5 - Video playback
- **media_kit_libs_windows_video** - Windows video codec support
- **cached_network_image** ^3.4.1 - Network image caching

**Desktop Integration:**
- **window_manager** ^0.3.9 - Window management (minimize, maximize, position)
- **tray_manager** ^0.2.3 - System tray integration
- **win32_registry** ^1.1.3 - Windows registry access

**UI Components:**
- **flex_color_scheme** ^7.3.1 - Material Design 3 theming
- **google_fonts** ^6.1.0 - Google Fonts integration
- **emoji_picker_flutter** ^2.1.1 - Emoji picker dialog
- **fl_chart** ^0.68.0 - Charts and data visualization
- **flutter_staggered_grid_view** ^0.7.0 - Masonry grid layouts
- **super_drag_and_drop** ^0.8.23 + **super_clipboard** ^0.8.23 - Drag & drop support
- **visibility_detector** ^0.4.0+2 - Widget visibility tracking

**Utilities:**
- **path_provider** ^2.1.3 - Platform-specific path access
- **path** ^1.9.0 - Path manipulation utilities
- **uuid** ^4.4.0 - UUID generation
- **intl** ^0.19.0 - Internationalization and formatting
- **timeago** ^3.7.1 - Relative time formatting
- **logger** ^2.4.0 - Structured logging
- **synchronized** ^3.1.0 - Concurrency synchronization primitives
- **collection** ^1.18.0 - Collection utilities

**File & Share:**
- **file_picker** ^8.0.0 - Native file picker dialogs
- **share_plus** ^10.0.0 - Platform sharing functionality
- **url_launcher** ^6.3.1 - Open URLs in default browser

**Device Info:**
- **device_info_plus** ^10.1.0 - Device information access
- **package_info_plus** ^8.0.0 - App version and package info
- **permission_handler** ^11.3.1 - Runtime permission requests

**Image Cache:**
- **flutter_cache_manager** ^3.3.0 - Custom cache management for images

## Configuration

**Environment:**
- Uses compile-time environment variables via `--dart-define`
- Production detection: `const bool.fromEnvironment('dart.vm.product')`
- No `.env` file usage detected

**Build:**
- **analysis_options.yaml** - Dart analysis configuration
  - Enforces: const constructors, final fields/locals, trailing commas
  - Excludes generated files: `**/*.g.dart`, `**/*.freezed.dart`
- **l10n.yaml** - Internationalization configuration
- **devtools_options.yaml** - Flutter DevTools configuration

**Platform Configuration:**
- **Android**: `android/app/build.gradle`, `android/build.gradle`
- **Windows**: `windows/CMakeLists.txt`, `windows/runner/CMakeLists.txt`
- **Assets**: Images, fonts, sounds, databases in `assets/` directory

## Platform Requirements

**Development:**
- Flutter SDK 3.16.0 or higher
- Dart SDK 3.2.0 or higher
- Windows: Visual Studio 2019 or later with C++ workload
- Android: Android Studio with SDK 21+

**Production:**
- **Windows**: Windows 10 or later (64-bit)
- **Android**: API level 21+ (Android 5.0+)
- **Linux**: Ubuntu 18.04+ or equivalent

**Deployment Targets:**
- Windows Desktop (primary platform)
- Android Mobile
- Linux Desktop (supported)

---

*Stack analysis: 2026-02-28*
