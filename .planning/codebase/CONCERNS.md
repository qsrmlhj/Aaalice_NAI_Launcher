# Codebase Concerns

**Analysis Date:** 2026-02-28

## Tech Debt

### Unimplemented Features (TODOs)

**Vibe Export Handler - Missing Embedding Logic:**
- Issue: Vibe embedding logic is not implemented, only shows placeholder toast
- Files: `lib/presentation/screens/generation/handlers/vibe_export_handler.dart:333`
- Impact: Users cannot actually embed Vibe data into PNG metadata
- Fix approach: Implement actual embedding using `vibe_image_embedder.dart` functionality

**Add to Library Dialog - Not Connected to Provider:**
- Issue: "Add to library" feature is stubbed with fake delay and mock save
- Files: `lib/presentation/widgets/common/add_to_library_dialog.dart:125`, `lib/presentation/widgets/common/add_to_library_dialog.dart:230`
- Impact: Users cannot save tags to library from generation screen
- Fix approach: Connect to `TagLibraryProvider` and implement actual save logic

**Save as Preset Dialog - Not Implemented:**
- Issue: Save as preset feature is completely stubbed
- Files: `lib/presentation/widgets/common/save_as_preset_dialog.dart:10`, `lib/presentation/widgets/common/save_as_preset_dialog.dart:105`
- Impact: Users cannot save generation parameters as presets
- Fix approach: Implement `PromptPresetProvider` integration and `RandomPromptPreset` model

**Image Detail Panel - Missing Vibe Save Dialog:**
- Issue: Save Vibe dialog not implemented
- Files: `lib/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart:623`
- Impact: Users cannot save Vibe data from existing images
- Fix approach: Implement using `VibeLibraryService`

### Code Generation Debt

**High Generated Code Ratio:**
- 241 generated files (`.g.dart`, `.freezed.dart`)
- 1038 total Dart files
- 23% of codebase is generated
- Impact: Longer build times, potential merge conflicts in generated files
- Files: Throughout `lib/` directory

**Deprecated API Usage:**
- Issue: Using deprecated methods in gallery scanning
- Files:
  - `lib/data/services/gallery/gallery_stream_scanner.dart:159` - `@deprecated use instance instead`
  - `lib/data/services/gallery/scan_state_manager.dart:524-525` - `@Deprecated('使用 startScanAsync 代替，此方法存在竞态条件风险')`
- Impact: Race condition risks in gallery scanning
- Fix approach: Migrate to new async methods

### Type Safety Concerns

**Heavy `dynamic` Usage:**
- 731 instances of `dynamic` type (excluding generated files)
- Impact: Reduced type safety, potential runtime errors
- Files: Throughout codebase, especially in cache and database layers

**Extensive `late` Keyword Usage:**
- 580 instances of `late` keyword (excluding generated files)
- Impact: Potential runtime null errors if not properly initialized
- Files: Common in service classes and controllers

## Known Bugs

### Stub Implementations

**Bulk Operation Service - Fake Ref:**
- Issue: Uses fake Ref implementation that throws UnimplementedError
- Files: `lib/data/services/bulk_operation_service.dart:422-426`
- Impact: May cause crashes if used without proper Ref
- Fix approach: Remove backward compatibility hack, enforce proper DI

### Error Handling Gaps

**Empty Returns in Cache Services:**
- Multiple methods return null/empty collections instead of proper error handling
- Files:
  - `lib/core/cache/gallery_cache_manager.dart` - Returns null on cache miss (lines 444, 477)
  - `lib/core/cache/tag_cache_service.dart` - Returns null on failure (lines 167, 177)
  - `lib/core/cache/thumbnail_cache_service.dart` - Multiple null returns (lines 278, 299, 328, 350, 474, 544)
- Impact: Silent failures, difficult to debug cache issues
- Fix approach: Use Result type or throw specific exceptions

**Database Empty Returns:**
- Issue: Empty inputs return early without logging
- Files: Multiple data sources (`cooccurrence_data_source.dart`, `danbooru_tag_data_source.dart`, `gallery_data_source.dart`)
- Pattern: `if (tags.isEmpty) return {}` or `if (query.isEmpty) return []`
- Impact: Silent failures, masking potential bugs upstream

## Security Considerations

### Cryptographic Implementation

**NAI Crypto Service:**
- Status: Implements Blake2b + Argon2id correctly for NovelAI authentication
- Files: `lib/core/crypto/nai_crypto_service.dart`
- Security: Uses proper key derivation with salt
- Note: Password prefix (first 6 chars) used in salt generation is part of NovelAI spec

### Storage Security

**Secure Storage Usage:**
- Access tokens stored in `flutter_secure_storage`
- User credentials properly encrypted
- Files: `lib/core/storage/secure_storage_service.dart`

**Hive Storage (Non-Sensitive):**
- Settings, cache, and metadata stored in Hive (unencrypted)
- No sensitive data should be stored in Hive boxes
- Files: `lib/core/storage/local_storage_service.dart`

### Network Security

**Dio Client Configuration:**
- HTTP/2 support with fallback to HTTP/1.1 for proxies
- Certificate validation enabled by default
- Files: `lib/core/network/dio_client.dart`

## Performance Bottlenecks

### Database Performance

**Gallery Data Source Complexity:**
- File: `lib/core/database/datasources/gallery_data_source.dart` (2565 lines)
- Issues:
  - Large file with multiple responsibilities
  - Complex batch operations (lines 1100-1200)
  - Multiple query patterns without proper indexing verification
- Impact: Potential slow queries on large galleries
- Improvement path: Split into specialized data sources, add query profiling

**Connection Pool Configuration:**
- Max 3 concurrent isolates (`lib/core/utils/isolate_pool.dart:12`)
- Database connection pool with health monitoring
- Timeout configurations:
  - Operation timeout: 30 seconds
  - Transaction timeout: 60 seconds
  - Connection acquire timeout: 5 seconds
- Files: `lib/core/database/base_data_source.dart:34-36`

### Memory Management

**Cache Size Limits:**
- L1 Memory Cache threshold: 100MB (`lib/core/cache/gallery_cache_manager.dart:280`)
- Thumbnail cache with size-based eviction
- Image cache: 500 images / 200MB limit (from CLAUDE.md)
- Impact: Potential memory pressure on low-end devices

**Large File Handling:**
- Co-occurrence data: 100MB+ files downloaded on demand
- Vibe data processing in isolates (good)
- PNG metadata parsing in isolates (good)

### Isolate Usage

**Proper Isolate Patterns:**
- Vibe parsing uses `compute()` correctly (`lib/core/utils/vibe_file_parser.dart`)
- Vibe embedding uses `compute()` correctly (`lib/core/utils/vibe_image_embedder.dart`)
- Isolate pool limits concurrency (max 3)

**Potential Issues:**
- Heavy database operations may not always use isolates
- Image processing could block UI if not careful

## Fragile Areas

### Gallery Scanning System

**Race Condition Risks:**
- Deprecated synchronous methods still present
- Files: `lib/data/services/gallery/scan_state_manager.dart`
- Issue: Comment indicates "此方法存在竞态条件风险" (this method has race condition risk)
- Safe modification: Use `startScanAsync()` instead

**State Management Complexity:**
- Multiple providers for gallery state
- Stream-based scanning with pause/resume
- Files: `lib/data/services/gallery/gallery_stream_scanner.dart`

### Database Migration System

**Migration Dependencies:**
- Complex migration system with version tracking
- Files: `lib/core/database/README_MIGRATION.md`
- Risk: Migration failures could corrupt user data
- Mitigation: Backup system in place

### Cache Coherence

**Multi-Level Cache:**
- L1: Memory cache
- L2: Hive cache
- L3: Database cache
- Risk: Cache invalidation across layers may be inconsistent
- Files: `lib/core/cache/gallery_cache_manager.dart`

## Scaling Limits

### Database Limits

**SQLite Limits:**
- Single-file database for gallery index
- Concurrent connection pool (size not explicitly limited)
- Large galleries (10k+ images) may experience slowdowns
- Files: `lib/core/database/connection_pool_holder.dart`

**Hive Box Limits:**
- All Hive boxes loaded into memory
- Large boxes could cause memory issues
- No lazy loading for Hive

### Network Limits

**Concurrent Requests:**
- HTTP client with connection pooling
- No explicit limit on concurrent API requests
- Image generation queue handles batching

## Dependencies at Risk

### Flutter Ecosystem

**Package Versions:**
- Flutter SDK: `>=3.16.0`
- Dart SDK: `>=3.2.0 <4.0.0`
- Most dependencies are well-maintained

**Risk Packages:**
- `media_kit_libs_windows_video: any` - Uses `any` version constraint
- `png_chunks_extract: any` - Uses `any` version constraint
- Impact: Potential breaking changes on updates

**Windows-Specific Packages:**
- `win32_registry: ^1.1.3` - Windows-only, critical for system proxy
- `window_manager: ^0.3.9` - Desktop window management
- `tray_manager: ^0.2.3` - System tray support

## Missing Critical Features

### Testing Coverage

**Low Test Coverage:**
- Only 24 test files for 1038 source files (2.3% test ratio)
- 807 test definitions total
- Mock usage: 65 instances
- Test files location: `/test` directory

**Untested Critical Paths:**
- Image generation flow
- Vibe encoding/decoding
- Database migrations
- Gallery scanning (complex state machine)
- Cache management

**Missing Test Types:**
- Integration tests (only one mentioned)
- Widget tests limited to simple components
- No E2E tests for critical user flows

### Error Recovery

**Incomplete Error Handling:**
- Many `return null` patterns instead of proper error propagation
- Limited retry logic outside of database operations
- No circuit breaker pattern for API calls

### Documentation

**Missing Documentation:**
- Complex algorithms lack detailed comments
- Database schema not documented outside of migration files
- No architecture decision records (ADRs)

## Test Coverage Gaps

**Critical Untested Areas:**

1. **Crypto Service:**
   - No tests for `NAICryptoService`
   - Critical for authentication
   - Files: `lib/core/crypto/nai_crypto_service.dart`

2. **Cache Services:**
   - Complex cache invalidation logic untested
   - Memory pressure handling not verified
   - Files: `lib/core/cache/*.dart`

3. **Gallery Scanning:**
   - Race condition prone code
   - Stream-based scanning complex
   - Files: `lib/data/services/gallery/*.dart`

4. **API Services:**
   - Error handling not fully tested
   - Retry logic verification missing
   - Files: `lib/data/datasources/remote/*.dart`

5. **Vibe Processing:**
   - Isolate-based processing needs testing
   - PNG metadata handling critical
   - Files: `lib/core/utils/vibe_*.dart`

**Test Infrastructure:**
- Uses `mocktail` for mocking
- Has `glados` for property-based testing (underutilized)
- Test fixtures available in `test/fixtures/`

---

*Concerns audit: 2026-02-28*
