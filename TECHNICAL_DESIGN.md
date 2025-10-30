# MoodMusic Flutter App - Technical Design Document

## 1. System Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Layer (Flutter)                   │
├─────────────────┬─────────────────┬─────────────────────────┤
│   UI Screens    │    Widgets      │    State Management     │
│                 │                 │     (Provider)          │
├─────────────────┼─────────────────┼─────────────────────────┤
│   Services      │   Data Models   │   Local Storage         │
│   Layer         │                 │   (SQLite + SharedPref) │
└─────────────────┴─────────────────┴─────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                 External Services Layer                     │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│ AWS         │ Spotify     │ Events      │ Firebase            │
│ Rekognition │ Web API     │ APIs        │ (Auth/DB/Analytics) │
└─────────────┴─────────────┴─────────────┴─────────────────────┘
```

### 1.2 Core Design Principles

- **Single Responsibility**: Each component has one clear purpose
- **Dependency Injection**: Provider pattern for clean separation
- **Reactive Programming**: Stream-based data flow
- **Error Boundary**: Graceful failure handling at every layer
- **Offline-First**: Local storage with cloud synchronization

## 2. Detailed Component Architecture

### 2.1 State Management Architecture

#### Provider Hierarchy
```dart
MultiProvider(
  providers: [
    // Core app state
    ChangeNotifierProvider<AppStateProvider>(),
    ChangeNotifierProvider<UserProvider>(),
    ChangeNotifierProvider<SubscriptionProvider>(),
    
    // External integrations
    ChangeNotifierProvider<AWSProvider>(),
    ChangeNotifierProvider<SpotifyProvider>(),
    ChangeNotifierProvider<EventsProvider>(),
    
    // Data persistence
    ChangeNotifierProvider<DatabaseProvider>(),
    ChangeNotifierProvider<CacheProvider>(),
  ],
  child: MoodMusicApp(),
)
```

#### State Flow Diagram
```
User Action → Provider → Service Layer → API/Database → State Update → UI Rebuild
     ↑                                                                    ↓
     └─────────────── User Feedback ←── UI Response ←──────────────────────┘
```

### 2.2 Data Layer Architecture

#### Database Schema Design

**SQLite Local Database**
```sql
-- Users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    created_at INTEGER NOT NULL,
    last_login INTEGER,
    subscription_status TEXT DEFAULT 'free',
    preferences TEXT -- JSON blob
);

-- Mood sessions table
CREATE TABLE mood_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    mood TEXT NOT NULL,
    confidence REAL NOT NULL,
    timestamp INTEGER NOT NULL,
    emotion_data TEXT, -- JSON blob of all emotions
    complex_mood_data TEXT, -- JSON blob of MoodProfile
    location_lat REAL,
    location_lng REAL,
    synced_to_cloud BOOLEAN DEFAULT FALSE
);

-- Music recommendations table
CREATE TABLE music_recommendations (
    id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES mood_sessions(id),
    song_id TEXT NOT NULL,
    song_name TEXT NOT NULL,
    artist TEXT NOT NULL,
    spotify_url TEXT,
    recommendation_reason TEXT,
    user_feedback INTEGER, -- 1=liked, 0=neutral, -1=disliked
    played BOOLEAN DEFAULT FALSE
);

-- Event recommendations table
CREATE TABLE event_recommendations (
    id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES mood_sessions(id),
    event_id TEXT NOT NULL,
    event_name TEXT NOT NULL,
    venue TEXT NOT NULL,
    date INTEGER NOT NULL,
    location_lat REAL,
    location_lng REAL,
    ticket_url TEXT,
    user_feedback INTEGER
);

-- User preferences table
CREATE TABLE user_preferences (
    user_id TEXT PRIMARY KEY REFERENCES users(id),
    preferred_genres TEXT, -- JSON array
    preferred_artists TEXT, -- JSON array
    location_enabled BOOLEAN DEFAULT TRUE,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    privacy_level INTEGER DEFAULT 1,
    updated_at INTEGER NOT NULL
);
```

**Firebase Firestore Cloud Schema**
```javascript
// Users collection
users/{userId} = {
  email: string,
  displayName: string,
  createdAt: timestamp,
  lastLogin: timestamp,
  subscriptionStatus: 'free' | 'premium_monthly' | 'premium_yearly',
  preferences: {
    genres: string[],
    artists: string[],
    locationEnabled: boolean,
    notificationsEnabled: boolean,
    privacyLevel: number
  }
}

// Mood sessions subcollection
users/{userId}/moodSessions/{sessionId} = {
  mood: string,
  confidence: number,
  timestamp: timestamp,
  emotionData: object,
  complexMoodData: object,
  location: geopoint?,
  musicRecommendations: reference[],
  eventRecommendations: reference[]
}

// Music recommendations subcollection
users/{userId}/musicRecommendations/{recommendationId} = {
  sessionId: reference,
  songId: string,
  songName: string,
  artist: string,
  spotifyUrl: string,
  recommendationReason: string,
  userFeedback: number?,
  played: boolean,
  timestamp: timestamp
}
```

### 2.3 Service Layer Architecture

#### Core Services Structure
```dart
abstract class BaseService {
  bool get isInitialized;
  Future<void> initialize();
  Future<void> dispose();
  Stream<ServiceStatus> get statusStream;
}

// Emotion Analysis Service
class EmotionAnalysisService extends BaseService {
  final AWSRekognitionClient _rekognitionClient;
  final MoodEngine _moodEngine;
  final CacheService _cacheService;
  
  Future<EmotionAnalysisResult> analyzeImage(Uint8List imageBytes);
  Future<MoodProfile?> matchMoodProfile(Map<String, double> emotions);
}

// Music Service
class MusicService extends BaseService {
  final SpotifyWebApi _spotifyApi;
  final RecommendationEngine _recommendationEngine;
  
  Future<List<Song>> getRecommendationsForMood(Mood mood, UserProfile user);
  Future<AudioPlayer> playPreview(String previewUrl);
  Future<void> createMoodPlaylist(String mood, List<Song> songs);
}

// Events Service  
class EventsService extends BaseService {
  final TicketmasterApi _ticketmasterApi;
  final EventbriteApi _eventbriteApi;
  final LocationService _locationService;
  
  Future<List<Event>> findEventsForMood(Mood mood, Location location);
  Future<EventDetails> getEventDetails(String eventId);
}
```

### 2.4 API Integration Architecture

#### Spotify Web API Integration
```dart
class SpotifyWebApi {
  static const String _baseUrl = 'https://api.spotify.com/v1';
  static const String _authUrl = 'https://accounts.spotify.com';
  
  final Dio _httpClient;
  final TokenManager _tokenManager;
  
  // OAuth 2.0 Flow
  Future<AuthResult> authenticate(List<String> scopes);
  Future<String> refreshAccessToken(String refreshToken);
  
  // User Profile & Preferences
  Future<SpotifyUser> getCurrentUser();
  Future<List<Track>> getUserTopTracks({String timeRange = 'medium_term'});
  Future<List<Artist>> getUserTopArtists({String timeRange = 'medium_term'});
  
  // Recommendations
  Future<List<Track>> getRecommendations({
    required List<String> seedGenres,
    required Map<String, double> audioFeatures,
    int limit = 20,
  });
  
  // Playback Control
  Future<void> playTrack(String trackId);
  Future<void> pausePlayback();
  Future<CurrentPlayback> getCurrentPlayback();
  
  // Playlist Management
  Future<Playlist> createPlaylist(String name, String description);
  Future<void> addTracksToPlaylist(String playlistId, List<String> trackIds);
}
```

#### AWS Rekognition Integration
```dart
class AWSRekognitionService {
  final AWSCredentialsProvider _credentialsProvider;
  final RekognitionClient _client;
  
  Future<EmotionDetectionResult> detectEmotions(Uint8List imageBytes) async {
    final request = DetectFacesRequest(
      image: Image(bytes: imageBytes),
      attributes: [FaceAttribute.all],
    );
    
    final response = await _client.detectFaces(request);
    return _processEmotionResponse(response);
  }
  
  EmotionDetectionResult _processEmotionResponse(DetectFacesResponse response) {
    // Process AWS response into standardized format
    final face = response.faceDetails?.first;
    if (face?.emotions == null) {
      throw EmotionDetectionException('No emotions detected');
    }
    
    final emotions = <String, double>{};
    for (final emotion in face!.emotions!) {
      emotions[emotion.type!.value] = emotion.confidence ?? 0.0;
    }
    
    return EmotionDetectionResult(
      emotions: emotions,
      boundingBox: face.boundingBox,
      confidence: face.confidence ?? 0.0,
      timestamp: DateTime.now(),
    );
  }
}
```

### 2.5 Security Architecture

#### Authentication Flow
```dart
class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final SignInWithApple _appleSignIn;
  
  // Multi-provider authentication
  Future<AuthResult> signInWithEmail(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithApple();
  Future<void> signOut();
  
  // Token management
  Future<String> getCurrentUserToken();
  Future<void> refreshUserToken();
  
  // Account management
  Future<void> deleteAccount();
  Future<void> exportUserData();
}
```

#### Secure Storage Implementation
```dart
class SecureStorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _preferences;
  
  // Sensitive data (tokens, keys)
  Future<void> storeSecurely(String key, String value);
  Future<String?> getSecurely(String key);
  Future<void> deleteSecure(String key);
  
  // Non-sensitive preferences
  Future<void> storePreference(String key, dynamic value);
  Future<T?> getPreference<T>(String key);
  
  // Encryption utilities
  String _encrypt(String plaintext, String key);
  String _decrypt(String ciphertext, String key);
}
```

## 3. Performance Optimization

### 3.1 Image Processing Optimization

```dart
class ImageOptimizationService {
  static const int maxImageSize = 1024; // pixels
  static const int jpegQuality = 85;
  
  Future<Uint8List> optimizeForAnalysis(Uint8List originalImage) async {
    // Resize image to optimal dimensions
    final image = img.decodeImage(originalImage);
    if (image == null) throw ImageProcessingException('Invalid image format');
    
    // Resize maintaining aspect ratio
    final resized = img.copyResize(
      image,
      width: maxImageSize,
      height: maxImageSize,
      interpolation: img.Interpolation.linear,
    );
    
    // Compress with optimal quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }
  
  Future<void> cleanupTempImages() async {
    // Clean up temporary image files
    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync();
    
    for (final file in files) {
      if (file.path.endsWith('.jpg') || file.path.endsWith('.png')) {
        await file.delete();
      }
    }
  }
}
```

### 3.2 Caching Strategy

```dart
class CacheService {
  final Dio _httpClient;
  final Database _database;
  
  // API Response Caching
  Future<T?> getCachedResponse<T>(String key, Duration maxAge) async {
    final cached = await _database.query(
      'api_cache',
      where: 'key = ? AND created_at > ?',
      whereArgs: [key, DateTime.now().subtract(maxAge).millisecondsSinceEpoch],
    );
    
    if (cached.isNotEmpty) {
      return jsonDecode(cached.first['data'] as String) as T;
    }
    return null;
  }
  
  Future<void> cacheResponse<T>(String key, T data) async {
    await _database.insert(
      'api_cache',
      {
        'key': key,
        'data': jsonEncode(data),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Image Caching
  Future<String> cacheImage(String url) async {
    final response = await _httpClient.get(url, options: Options(responseType: ResponseType.bytes));
    final bytes = response.data as Uint8List;
    
    final filename = url.split('/').last;
    final file = File('${(await getApplicationDocumentsDirectory()).path}/$filename');
    await file.writeAsBytes(bytes);
    
    return file.path;
  }
}
```

### 3.3 Memory Management

```dart
class MemoryManager {
  static const int maxImageCacheSize = 50 * 1024 * 1024; // 50MB
  static const int maxApiCacheEntries = 1000;
  
  Future<void> performMemoryCleanup() async {
    await _cleanupImageCache();
    await _cleanupApiCache();
    await _cleanupTempFiles();
  }
  
  Future<void> _cleanupImageCache() async {
    final cacheDir = await getApplicationCacheDirectory();
    final files = cacheDir.listSync().where((f) => f is File).cast<File>();
    
    int totalSize = 0;
    final fileInfos = <FileInfo>[];
    
    for (final file in files) {
      final stat = await file.stat();
      totalSize += stat.size;
      fileInfos.add(FileInfo(file, stat.modified, stat.size));
    }
    
    if (totalSize > maxImageCacheSize) {
      // Remove oldest files first
      fileInfos.sort((a, b) => a.lastModified.compareTo(b.lastModified));
      
      int removedSize = 0;
      for (final fileInfo in fileInfos) {
        await fileInfo.file.delete();
        removedSize += fileInfo.size;
        
        if (totalSize - removedSize <= maxImageCacheSize * 0.8) break;
      }
    }
  }
}
```

## 4. Error Handling & Resilience

### 4.1 Error Hierarchy

```dart
abstract class MoodMusicException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const MoodMusicException(this.message, {this.code, this.originalError});
}

class NetworkException extends MoodMusicException {
  const NetworkException(String message, {String? code}) : super(message, code: code);
}

class AuthenticationException extends MoodMusicException {
  const AuthenticationException(String message) : super(message);
}

class EmotionDetectionException extends MoodMusicException {
  const EmotionDetectionException(String message) : super(message);
}

class SubscriptionException extends MoodMusicException {
  const SubscriptionException(String message) : super(message);
}
```

### 4.2 Resilience Patterns

```dart
class RetryHandler {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 1);
  
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = maxRetries,
    Duration delay = baseDelay,
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempt = 0;
    
    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxAttempts || 
            (shouldRetry != null && !shouldRetry(e as Exception))) {
          rethrow;
        }
        
        await Future.delayed(delay * attempt); // Exponential backoff
      }
    }
    
    throw StateError('Retry handler completed without result');
  }
}
```

### 4.3 Circuit Breaker Pattern

```dart
class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitState _state = CircuitState.closed;
  
  CircuitBreaker({
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 10),
    this.resetTimeout = const Duration(minutes: 1),
  });
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitState.open) {
      if (_lastFailureTime != null &&
          DateTime.now().difference(_lastFailureTime!) > resetTimeout) {
        _state = CircuitState.halfOpen;
      } else {
        throw CircuitBreakerException('Circuit breaker is open');
      }
    }
    
    try {
      final result = await operation().timeout(timeout);
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }
  
  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }
  
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }
}

enum CircuitState { closed, open, halfOpen }
```

## 5. Testing Architecture

### 5.1 Testing Strategy Overview

```dart
// Unit Tests
abstract class TestBase {
  late MockDatabase mockDatabase;
  late MockHttpClient mockHttpClient;
  late MockSecureStorage mockSecureStorage;
  
  @setUp
  void setUp() {
    mockDatabase = MockDatabase();
    mockHttpClient = MockHttpClient();
    mockSecureStorage = MockSecureStorage();
  }
  
  @tearDown
  void tearDown() {
    reset(mockDatabase);
    reset(mockHttpClient);
    reset(mockSecureStorage);
  }
}

// Widget Tests
class WidgetTestHelper {
  static Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => MockAppStateProvider(),
        ),
        // ... other mock providers
      ],
      child: MaterialApp(home: child),
    );
  }
  
  static Future<void> pumpAndSettle(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(createTestWidget(widget));
    await tester.pumpAndSettle();
  }
}

// Integration Tests
class IntegrationTestHelper {
  static Future<void> setupTestEnvironment() async {
    // Initialize test database
    await TestDatabase.initialize();
    
    // Setup mock external services
    MockServerSetup.configure();
    
    // Configure test user accounts
    await TestUserSetup.createTestUsers();
  }
  
  static Future<void> teardownTestEnvironment() async {
    await TestDatabase.cleanup();
    MockServerSetup.reset();
  }
}
```

### 5.2 Mock Services

```dart
class MockSpotifyService extends Mock implements SpotifyService {
  @override
  Future<List<Song>> getRecommendationsForMood(Mood mood) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    return _generateMockSongs(mood);
  }
  
  List<Song> _generateMockSongs(Mood mood) {
    // Generate realistic test data based on mood
    final moodSongs = {
      Mood.happy: [
        Song(id: 'test1', name: 'Happy Song', artist: 'Test Artist'),
        Song(id: 'test2', name: 'Upbeat Track', artist: 'Mock Band'),
      ],
      // ... other moods
    };
    
    return moodSongs[mood] ?? [];
  }
}
```

## 6. Deployment Architecture

### 6.1 Environment Configuration

```dart
class Environment {
  static const String dev = 'development';
  static const String staging = 'staging';
  static const String prod = 'production';
  
  static String get current => const String.fromEnvironment('ENV', defaultValue: dev);
  
  static EnvironmentConfig get config {
    switch (current) {
      case staging:
        return StagingConfig();
      case prod:
        return ProductionConfig();
      default:
        return DevelopmentConfig();
    }
  }
}

abstract class EnvironmentConfig {
  String get awsRegion;
  String get spotifyClientId;
  String get firebaseProjectId;
  bool get enableLogging;
  bool get enableAnalytics;
}

class ProductionConfig implements EnvironmentConfig {
  @override
  String get awsRegion => 'us-east-1';
  
  @override
  String get spotifyClientId => const String.fromEnvironment('SPOTIFY_CLIENT_ID_PROD');
  
  @override
  String get firebaseProjectId => 'moodmusic-prod';
  
  @override
  bool get enableLogging => false;
  
  @override
  bool get enableAnalytics => true;
}
```

### 6.2 Build Configuration

```yaml
# build.yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true
          include_if_null: false
      
flutter:
  android:
    minSdkVersion: 21
    targetSdkVersion: 33
    compileSdkVersion: 33
    
  ios:
    deployment_target: 13.0
    
  web:
    enabled: false # Not supporting web for this release
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-23  
**Next Review**: 2025-02-23  
**Owner**: Technical Architecture Team