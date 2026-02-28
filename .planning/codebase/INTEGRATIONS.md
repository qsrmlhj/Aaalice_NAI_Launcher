# External Integrations

**Analysis Date:** 2026-02-28

## APIs & External Services

**NovelAI API:**
- **Base URL**: `https://api.novelai.net`
- **Image Base URL**: `https://image.novelai.net`
- **Authentication**: Bearer Token (JWT or Persistent Token with `pst-` prefix)
- **Services**:
  - `NaiAuthApiService` (`lib/data/datasources/remote/nai_auth_api_service.dart`) - Login and token validation
  - `NaiImageGenerationApiService` (`lib/data/datasources/remote/nai_image_generation_api_service.dart`) - Text-to-image generation (25KB)
  - `NaiImageEnhancementApiService` (`lib/data/datasources/remote/nai_image_enhancement_api_service.dart`) - Image enhancement, upscaling, img2img
  - `NaiUserInfoApiService` (`lib/data/datasources/remote/nai_user_info_api_service.dart`) - User subscription and data
  - `NaiTagSuggestionApiService` (`lib/data/datasources/remote/nai_tag_suggestion_api_service.dart`) - AI tag suggestions
- **Key Endpoints**:
  - POST `/user/login` - Authentication
  - POST `/ai/generate-image` - Image generation
  - POST `/ai/generate-image-stream` - Streaming generation
  - POST `/ai/upscale` - Image upscaling
  - POST `/ai/augment-image` - Image augmentation
  - POST `/ai/annotate-image` - Image annotation
  - POST `/ai/encode-vibe` - Vibe encoding
  - GET `/user/data` - User data
  - GET `/user/subscription` - Subscription info
  - GET `/ai/generate-image/suggest-tags` - Tag suggestions

**Danbooru API:**
- **Base URL**: `https://danbooru.donmai.us`
- **Authentication**: Basic Auth (username:api_key)
- **Services**:
  - `DanbooruApiService` (`lib/data/datasources/remote/danbooru_api_service.dart`) - Posts, tags, favorites (17KB)
  - `DanbooruPoolService` (`lib/data/datasources/remote/danbooru_pool_service.dart`) - Pool management
  - `DanbooruTagGroupService` (`lib/data/datasources/remote/danbooru_tag_group_service.dart`) - Tag groups
- **Key Endpoints**:
  - GET `/posts.json` - Post listings
  - GET `/tags.json` - Tag search
  - GET `/pools.json` - Pool listings
  - GET `/favorites.json` - User favorites
  - GET `/profile.json` - User profile
  - GET `/explore/posts/popular.json` - Popular posts
  - GET `/autocomplete.json` - Tag autocomplete
  - GET `/artists.json` - Artist search
  - GET `/wiki_pages.json` - Wiki pages

## Data Storage

**Databases:**
- **SQLite** (via `sqflite_common_ffi`)
  - Connection: Local FFI database
  - Client: `database_manager.dart` with connection pooling
  - Files:
    - `lib/core/database/database_manager.dart` - Database lifecycle
    - `lib/core/database/connection_pool.dart` - Connection pooling
    - `lib/core/database/datasources/gallery_data_source.dart` - Gallery operations
    - `lib/core/database/datasources/danbooru_tag_data_source.dart` - Danbooru tag cache
    - `lib/core/database/datasources/cooccurrence_data_source.dart` - Tag co-occurrence data
  - Purpose: Gallery indexing, complex queries, tag co-occurrence analysis

- **Hive** (NoSQL)
  - Boxes: `settings`, `history`, `tagCache`, `gallery`, `localFavorites`, `tags`, `searchIndex`, `statisticsCache`, `replicationQueue`, `queueExecutionState`
  - Files:
    - `lib/core/storage/local_storage_service.dart` - Main Hive storage service
    - `lib/core/cache/tag_cache_service.dart` - Tag caching
    - `lib/core/cache/thumbnail_cache_service.dart` - Thumbnail caching
  - Purpose: User settings, generation history, tag cache, gallery metadata

- **SecureStorage** (Encrypted)
  - Package: `flutter_secure_storage` ^9.2.4
  - File: `lib/core/storage/secure_storage_service.dart`
  - Purpose: Access tokens, user credentials, API keys
  - Keys managed: `accessToken`, `refreshToken`, `userKey`

**File Storage:**
- **Local Filesystem**
  - Images: User's Documents/NAI_Launcher/images/
  - Vibe data: Documents/NAI_Launcher/vibes/
  - Logs: Documents/NAI_Launcher/logs/
  - Co-occurrence data: 100MB+ tag relationship files
  - Implementation: `path_provider` for cross-platform paths

**Caching:**
- **Danbooru Image Cache**
  - Manager: `lib/core/cache/danbooru_image_cache_manager.dart`
  - Max: 500 items / 200MB
  - Policy: LRU eviction

- **Gallery Cache**
  - Manager: `lib/core/cache/gallery_cache_manager.dart`
  - Thumbnails: `lib/core/cache/thumbnail_cache_service.dart`
  - Max: 500 thumbnails

- **Tag Cache**
  - Service: `lib/core/cache/tag_cache_service.dart`
  - Hot tags threshold-based caching

## Authentication & Identity

**Auth Provider:**
- **NovelAI Custom Authentication**
  - Protocol: Access Key generation using Blake2b + Argon2id
  - Token Types:
    - Persistent Token (`pst-` prefix, 64-char hex)
    - JWT Token (standard JWT format)
  - File: `lib/core/crypto/nai_crypto_service.dart`
  - Token Refresh: Automatic 401 handling with `token_refresh_service.dart`

**Danbooru Authentication:**
- Type: Basic HTTP Authentication
- Credentials: Username + API Key
- Storage: SecureStorage
- File: `lib/data/services/danbooru_auth_service.dart`

## Monitoring & Observability

**Error Tracking:**
- Custom logging framework only
- No external error tracking service (Sentry, Crashlytics, etc.)

**Logs:**
- **AppLogger** (`lib/core/utils/app_logger.dart`)
  - Console + File dual output
  - Log rotation: Keep last 3 startup logs
  - Max size: 100MB per log file
  - Naming: `app_YYYYMMDD_HHMMSS.log` (production), `test_YYYYMMDD_HHMMSS.log` (test)
  - Directory: Documents/NAI_Launcher/logs/

**Analytics:**
- No external analytics service detected
- Local statistics tracking in gallery feature

## CI/CD & Deployment

**Hosting:**
- GitHub repository (source control)
- No CI/CD pipelines detected in repository
- Manual build and release process

**Build Platforms:**
- Windows: MSIX or executable builds
- Android: APK and AppBundle builds
- Build commands in `scripts/` directory:
  - `scripts/dev_tools.bat` - Development utilities
  - `scripts/quick_check.bat` - Pre-commit checks

## Environment Configuration

**Required Configuration:**
- No external API keys required (user-provided tokens only)
- No environment files (.env) used
- Configuration stored in:
  - Hive boxes (user settings)
  - SecureStorage (credentials)
  - SQLite (app data)

**Proxy Support:**
- System proxy auto-detection (Windows registry)
- Manual proxy configuration in app settings
- HTTP/1.1 fallback when proxy enabled
- HTTP/2 direct connection when no proxy
- File: `lib/core/network/proxy_service.dart`

## Webhooks & Callbacks

**Incoming:**
- None detected

**Outgoing:**
- None detected

## Network Configuration

**HTTP Client:**
- **Dio** with custom configuration
- Interceptors:
  - `AuthInterceptor` - Automatic token attachment and refresh
  - `ErrorInterceptor` - Error mapping and logging
- Adapter selection:
  - HTTP/2 (Http2Adapter) for direct connections
  - HTTP/1.1 (default) for proxy connections
- Timeouts: 30s connect, 120s receive

**Protocol Support:**
- HTTP/2 for NovelAI API (when no proxy)
- HTTP/1.1 for proxy connections
- HTTP/2 for Danbooru (when supported)

## Rate Limiting & Concurrency

**Client-Side Controls:**
- Connection pooling for SQLite (max 5 connections)
- Synchronized access to critical sections (`synchronized` package)
- Request concurrency controlled by Riverpod provider scoping

**Server-Side Limits:**
- NovelAI: Token-based rate limiting (handled by API)
- Danbooru: Standard API rate limits (no specific handling detected)

---

*Integration audit: 2026-02-28*
