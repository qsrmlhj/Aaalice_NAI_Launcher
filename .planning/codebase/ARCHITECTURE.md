# Architecture

**Analysis Date:** 2026-02-28

## Pattern Overview

**Overall:** Clean Architecture + Domain-Driven Design (DDD) + Layered Architecture

**Key Characteristics:**
- Strict separation of concerns with core/data/presentation layers
- Feature-first organization within layers
- Repository pattern for data access
- Service-oriented business logic
- State management via Riverpod (functional + controller patterns)
- Code generation heavy (Freezed, Riverpod, Hive, JSON Serializable)

## Layers

### Core Layer (Infrastructure)
- **Purpose:** Cross-cutting concerns, platform abstractions, utilities
- **Location:** `lib/core/`
- **Contains:** Services, storage, network, cache, crypto, extensions, utils
- **Depends on:** Flutter SDK, third-party packages
- **Used by:** Data layer, Presentation layer

**Key Components:**
- **Storage:** `lib/core/storage/` - Hive, SecureStorage, SQLite abstractions
- **Network:** `lib/core/network/` - Dio client, proxy service, HTTP configuration
- **Cache:** `lib/core/cache/` - Danbooru image cache, tag cache
- **Crypto:** `lib/core/crypto/` - NAI authentication encryption
- **Database:** `lib/core/database/` - Connection pooling, SQLite datasources
- **Services:** `lib/core/services/` - 20+ business services (auth, migration, calculation)

### Data Layer
- **Purpose:** Data access, API communication, local persistence
- **Location:** `lib/data/`
- **Contains:** Models, datasources, repositories, data services
- **Depends on:** Core layer
- **Used by:** Presentation layer

**Sub-layers:**
- **Datasources:** `lib/data/datasources/`
  - Local: Hive, SQLite (tag cache, pool cache, tag groups)
  - Remote: NAI API services, Danbooru API services
- **Models:** `lib/data/models/` - 189 files, Freezed immutable classes
- **Repositories:** `lib/data/repositories/` - Gallery, collection, character prompt repos
- **Services:** `lib/data/services/` - Business logic services (gallery, metadata, search)

### Domain Layer
- **Purpose:** Business entities and domain logic
- **Location:** `lib/domain/`
- **Contains:** Entities, mappers
- **Depends on:** Nothing (pure Dart)
- **Used by:** Data layer, Presentation layer

**Components:**
- **Entities:** `lib/domain/entities/` - Core business objects
- **Mappers:** `lib/domain/entities/gallery_entity_mapper.dart` - Data-to-domain mapping

### Presentation Layer
- **Purpose:** UI, state management, user interaction
- **Location:** `lib/presentation/`
- **Contains:** Screens, widgets, providers, router, themes
- **Depends on:** Data layer, Core layer
- **Used by:** Flutter framework

**Sub-layers:**
- **Screens:** `lib/presentation/screens/` - 117 Dart files, feature-based
- **Widgets:** `lib/presentation/widgets/` - 40+ component directories
- **Providers:** `lib/presentation/providers/` - 140 Riverpod providers
- **Router:** `lib/presentation/router/` - GoRouter configuration
- **Themes:** `lib/presentation/themes/` - App theming

## Data Flow

### Image Generation Flow:

1. **UI Layer:** User configures parameters in `GenerationScreen`
2. **State Layer:** Providers validate and hold state
3. **Service Layer:** `NaiImageGenerationApiService` builds request
4. **Network Layer:** Dio client sends HTTP/2 request with auth
5. **Response:** Image bytes returned, saved via `ImageSaveUtils`
6. **Persistence:** Metadata extracted, stored in SQLite/Hive
7. **UI Update:** Gallery providers refreshed, UI rebuilds

### Gallery Browsing Flow:

1. **UI Layer:** `LocalGalleryScreen` displays grid
2. **Data Layer:** `GalleryDataSource` queries SQLite (78KB file)
3. **Cache Layer:** Thumbnails served from `ThumbnailService`
4. **Pagination:** Lazy loading via provider pagination
5. **Filtering:** Tag-based filtering in-memory + SQL

### Authentication Flow:

1. **UI Layer:** `LoginScreen` captures credentials
2. **Service Layer:** `NaiAuthApiService` encrypts and sends
3. **Storage Layer:** Token stored in `SecureStorageService`
4. **State Layer:** `AuthNotifier` updates authentication state
5. **Router Layer:** GoRouter redirects based on auth status

## Key Abstractions

### Repository Pattern
- **Purpose:** Abstract data access
- **Examples:** `GalleryFolderRepository`, `CollectionRepository`, `CharacterPromptRepository`
- **Pattern:** Singleton or Riverpod-provided, async methods

### Service Pattern
- **Purpose:** Encapsulate business logic
- **Examples:**
  - Core: `NotificationService`, `DataMigrationService`
  - Data: `ImageMetadataService`, `ThumbnailService`, `TagLibraryService`
- **Pattern:** Singleton or generated provider, focused responsibility

### DataSource Pattern
- **Purpose:** Abstract specific data sources
- **Examples:** `GalleryDataSource`, `DanbooruTagDataSource`, `CooccurrenceDataSource`
- **Pattern:** Database-specific implementations, SQL or NoSQL

### Provider Pattern (Riverpod)
- **Functional Providers:** `@riverpod` - Simple state/functions
- **Controller Providers:** `@Riverpod(keepAlive: true)` - Complex state management
- **Examples:** 140 providers across the app

## Entry Points

### Application Entry:
- **File:** `lib/main.dart`
- **Responsibilities:**
  - Initialize Flutter bindings
  - Initialize Hive, SQLite
  - Run `AppBootstrap` (splash)
  - Launch `NAILauncherApp`

### App Widget:
- **File:** `lib/app.dart`
- **Responsibilities:**
  - Configure MaterialApp.router
  - Initialize global shortcuts
  - Setup theme, locale, font providers
  - Configure window management (desktop)

### Router Configuration:
- **File:** `lib/presentation/router/app_router.dart` (753 lines)
- **Routes:** 12 main routes
- **Strategy:** StatefulShellRoute with mixed keep-alive
  - Keep-alive: localGallery (index 2), onlineGallery (index 3)
  - Non-keep-alive: generation, settings, etc.

### Bootstrap:
- **File:** `lib/presentation/screens/splash/app_bootstrap.dart`
- **Responsibilities:**
  - Initialize Hive boxes
  - Run data migrations
  - Preload critical data
  - Initialize database pools

## Error Handling

**Strategy:** Layer-specific handling with centralized logging

**Patterns:**
- **API Errors:** Dio interceptors, automatic token refresh on 401
- **Async Operations:** `AsyncValue.guard()` in controllers
- **Database:** Connection pooling with retry logic
- **Logging:** `AppLogger` with file output to `logs/` directory

**Error Types:**
- `AuthErrorService` - Authentication error handling
- Custom exceptions in `lib/core/exceptions/`

## Cross-Cutting Concerns

**Logging:**
- **Framework:** Custom `AppLogger`
- **Output:** Console + file (`logs/app_YYYYMMDD_HHMMSS.log`)
- **Retention:** Last 3 log files kept

**Validation:**
- Input validation in providers
- Data validation in models (Freezed)
- API response validation via Dio

**Authentication:**
- JWT-based with automatic refresh
- Secure storage for tokens
- Auth state synced across router

**Storage:**
- **Hive:** Settings, cache, small data
- **SQLite:** Gallery index, structured data
- **SecureStorage:** Tokens, credentials
- **FileSystem:** Images, vibes, large data

**Networking:**
- HTTP/2 by default, HTTP/1.1 for proxy
- Automatic proxy detection
- Request/response interceptors
- Connection pooling

---

*Architecture analysis: 2026-02-28*
