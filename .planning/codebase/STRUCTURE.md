# Codebase Structure

**Analysis Date:** 2026-02-28

## Directory Layout

```
lib/
├── core/                      # Infrastructure & cross-cutting concerns (188 files)
│   ├── cache/                 # Image and tag caching
│   ├── constants/             # App constants, storage keys, API constants
│   ├── crypto/                # Encryption services
│   ├── database/              # SQLite, connection pooling, datasources
│   ├── enums/                 # Enumeration types
│   ├── exceptions/            # Custom exceptions
│   ├── extensions/            # Dart/Flutter extensions
│   ├── network/               # Dio, proxy, HTTP configuration
│   ├── parsers/               # Data parsers
│   ├── services/              # Core business services (20 services)
│   ├── shortcuts/             # Keyboard shortcuts system
│   ├── storage/               # Hive, SecureStorage abstractions
│   └── utils/                 # Utilities (logger, converters, parsers)
├── data/                      # Data layer (296 files)
│   ├── datasources/           # Data access
│   │   ├── local/             # Hive, SQLite datasources
│   │   └── remote/            # API services
│   ├── models/                # Data models (Freezed)
│   │   ├── auth/              # Authentication models
│   │   ├── character/         # Character prompt models
│   │   ├── danbooru/          # Danbooru integration
│   │   ├── gallery/           # Gallery models
│   │   ├── image/             # Image generation params
│   │   ├── prompt/            # Prompt configuration (92 files)
│   │   ├── queue/             # Queue task models
│   │   ├── tag/               # Tag models
│   │   └── vibe/              # Vibe Transfer models
│   ├── repositories/          # Repository implementations
│   └── services/              # Data services (metadata, gallery, search)
├── domain/                    # Domain layer (entities)
│   └── entities/              # Business entities
├── presentation/              # UI layer (445 files)
│   ├── providers/             # Riverpod providers (140 providers)
│   ├── router/                # GoRouter configuration
│   ├── screens/               # Feature screens (117 files)
│   │   ├── auth/              # Login
│   │   ├── generation/        # Image generation
│   │   ├── local_gallery/     # Local gallery
│   │   ├── online_gallery/    # Danbooru gallery
│   │   ├── prompt_config/     # Prompt configuration
│   │   ├── settings/          # App settings
│   │   ├── statistics/        # Usage statistics
│   │   ├── tag_library_page/  # Tag library
│   │   └── vibe_library/      # Vibe library
│   ├── themes/                # App themes
│   ├── utils/                 # UI utilities
│   └── widgets/               # Reusable widgets (40+ directories)
├── l10n/                      # Internationalization
│   ├── app_en.arb             # English translations (134KB)
│   └── app_zh.arb             # Chinese translations (126KB)
├── app.dart                   # Main app widget
└── main.dart                  # Application entry point

test/                          # Test suite
├── core/                      # Core layer tests
├── data/                      # Data layer tests
├── presentation/              # Presentation tests
└── fixtures/                  # Test fixtures

logs/                          # Application logs
scripts/                       # Windows batch scripts
tools/                         # Development tools
assets/                        # Static assets
fonts/                         # Custom fonts
```

## Directory Purposes

### Core Layer (`lib/core/`)

**cache/** - Performance optimization
- `danbooru_image_cache_manager.dart` - Image caching
- `tag_cache_service.dart` - Tag data caching

**database/** - SQLite infrastructure
- `datasources/` - SQL queries and data access
  - `gallery_data_source.dart` (78KB) - Main gallery SQL
  - `danbooru_tag_data_source.dart` (15KB) - Tag data access
  - `cooccurrence_data_source.dart` - Tag cooccurrence
- `connection_pool.dart` - Database connection management
- `database_manager.dart` - Database lifecycle

**network/** - HTTP infrastructure
- `dio_client.dart` (12KB) - Main HTTP client
- `proxy_service.dart` - System proxy handling
- `error_mappers/` - Error translation
- `request_builders/` - HTTP request construction

**services/** - Business services
- `notification_service.dart` - Sound notifications
- `data_migration_service.dart` - Version migrations
- `anlas_calculator.dart` - Currency calculation
- `tag_counting_service.dart` - Tag statistics

**storage/** - Persistence abstractions
- `local_storage_service.dart` - Hive wrapper
- `secure_storage_service.dart` - Encrypted storage
- `base_hive_storage.dart` - Base class for Hive storage

**utils/** - Utilities
- `app_logger.dart` - Logging to file and console
- `sd_to_nai_converter.dart` - Prompt format conversion
- `vibe_file_parser.dart` (25KB) - Vibe file parsing
- `nai_prompt_parser.dart` - NAI prompt syntax

### Data Layer (`lib/data/`)

**datasources/local/** - Local data
- `nai_tags_data_source.dart` - NAI tag data
- `pool_cache_service.dart` - Danbooru pool cache
- `tag_group_cache_service.dart` - Tag group cache

**datasources/remote/** - API clients
- `nai_image_generation_api_service.dart` (25KB) - Image generation
- `nai_auth_api_service.dart` - Authentication
- `nai_image_enhancement_api_service.dart` - Img2img, upscaling
- `danbooru_api_service.dart` (17KB) - Danbooru integration
- `danbooru_pool_service.dart` - Pool browsing
- `danbooru_tag_group_service.dart` - Tag groups

**models/** - Immutable data classes
- Uses Freezed for code generation
- Organized by feature domain
- 189 total model files

**repositories/** - Data access abstraction
- `gallery_folder_repository.dart` - Folder operations
- `collection_repository.dart` - User collections
- `character_prompt_repository.dart` - Character prompts

**services/** - Data operations
- `gallery/` - Gallery-specific services
- `metadata/` - Metadata extraction
- `image_metadata_service.dart` (21KB) - EXIF/metadata handling
- `thumbnail_service.dart` (24KB) - Thumbnail generation

### Presentation Layer (`lib/presentation/`)

**providers/** - State management (140 providers)
- `auth_provider.dart` (30KB) - Authentication state
- `gallery_provider.dart` - Gallery data
- `generation_provider.dart` - Generation params
- `queue_execution_provider.dart` - Batch processing
- `tag_library_provider.dart` - Tag management

**screens/** - Feature screens
- Each subdirectory = one feature
- Contains screen + widgets
- Desktop/mobile layouts where needed

**widgets/** - Reusable components
- `navigation/` - Nav rail, app bars
- `gallery/` - Gallery grid, cards
- `generation/` - Parameter panels
- `queue/` - Queue management UI
- `shortcuts/` - Keyboard handling
- `common/` - Shared components

**router/** - Navigation
- `app_router.dart` (23KB) - Route definitions
- Uses GoRouter with StatefulShellRoute

## Key File Locations

### Entry Points
- `lib/main.dart` - Application bootstrap
- `lib/app.dart` - Root widget configuration
- `lib/presentation/router/app_router.dart` - Route definitions

### Configuration
- `pubspec.yaml` - Dependencies (100+ packages)
- `analysis_options.yaml` - Lint rules
- `l10n.yaml` - Internationalization config

### Core Logic
- `lib/core/network/dio_client.dart` - HTTP client
- `lib/core/database/datasources/gallery_data_source.dart` - Main data access
- `lib/data/datasources/remote/nai_image_generation_api_service.dart` - Core API

### State Management
- `lib/presentation/providers/auth_provider.dart` - Auth state
- `lib/presentation/providers/queue_execution_provider.dart` - Queue state

### Platform-Specific
- `windows/` - Windows runner
- `android/` - Android runner
- `lib/core/services/notification_service.dart` - Desktop notifications

## Naming Conventions

### Files
- **Snake case:** `gallery_data_source.dart`
- **Provider files:** `*_provider.dart`
- **Generated files:** `*.g.dart`, `*.freezed.dart`
- **Service files:** `*_service.dart`
- **Repository files:** `*_repository.dart`
- **Model files:** `*.dart` (containing Freezed classes)
- **Screen files:** `*_screen.dart`

### Directories
- **Lowercase with underscores:** `tag_library_page/`
- **Feature-based names:** `local_gallery/`, `vibe_library/`

### Classes (from code analysis)
- **Services:** `*Service` - Singleton services
- **Repositories:** `*Repository` - Data access
- **Providers:** `*Provider` - Riverpod providers
- **Controllers:** `*Controller` - State controllers
- **Models:** `*Model` or feature name (Freezed)
- **Screens:** `*Screen` - Full page widgets
- **Widgets:** Descriptive names, no suffix

## Where to Add New Code

### New Feature (e.g., "bookmark")

**Primary code:**
- Data: `lib/data/models/bookmark/` - Models
- Data: `lib/data/repositories/bookmark_repository.dart` - Repository
- Data: `lib/data/datasources/local/bookmark_data_source.dart` - Local data
- Core: `lib/core/services/bookmark_service.dart` - Business logic

**Presentation:**
- Screen: `lib/presentation/screens/bookmark/bookmark_screen.dart`
- Provider: `lib/presentation/providers/bookmark_provider.dart`
- Widgets: `lib/presentation/widgets/bookmark/` - Feature widgets

**Tests:**
- `test/data/repositories/bookmark_repository_test.dart`
- `test/presentation/providers/bookmark_provider_test.dart`

### New Component

**Implementation:**
- `lib/presentation/widgets/[category]/new_component.dart`
- Export from `lib/presentation/widgets/[category]/[category].dart` if barrel file exists

### New API Service

**Implementation:**
- `lib/data/datasources/remote/new_api_service.dart`
- Add provider in `lib/presentation/providers/` if needed
- Update `lib/core/network/dio_client.dart` if base URL changes

### New Utility

**Core utility:**
- `lib/core/utils/new_utility.dart`
- Add unit tests in `test/core/`

### New Model

**Implementation:**
- `lib/data/models/feature/model_name.dart`
- Use Freezed: `@freezed class ModelName with _$ModelName`
- Run: `dart run build_runner build --delete-conflicting-outputs`

## Special Directories

**Generated Code:**
- Pattern: `*.g.dart`, `*.freezed.dart`
- Generated: Yes (by build_runner)
- Committed: Yes (in repo)
- Count: 173 generated files, 68 Freezed files

**Cache Directories:**
- `lib/core/cache/` - Runtime caches
- Not committed, runtime only

**Logs:**
- `logs/` - Application logs
- Pattern: `app_YYYYMMDD_HHMMSS.log`
- Retention: 3 files
- Not committed

**Test Fixtures:**
- `test/fixtures/` - Test data files
- Committed: Yes

**Localization:**
- `lib/l10n/` - ARB translation files
- Generation: `flutter gen-l10n`
- Output: `lib/l10n/app_localizations.dart` (generated)

---

*Structure analysis: 2026-02-28*
