# MoodMusic Technical Design - Feature Completion Guide

## Executive Summary

This document provides detailed technical specifications for completing the MoodMusic Flutter application. It covers architecture patterns, implementation strategies, API integrations, and system design for all remaining features needed to reach production MVP status.

**Current Architecture Status**: Foundation established with Provider pattern, Firebase integration, and basic emotion detection
**Target**: Production-ready application with advanced features and enterprise-grade reliability
**Technology Stack**: Flutter 3.16+, Firebase, AWS Rekognition, Spotify API, RevenueCat

---

## 1. System Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
├─────────────────────────────────────────────────────────────┤
│ Flutter UI          │ Widgets        │ Screens             │
│ - Material Design   │ - Custom       │ - Auth              │
│ - Responsive        │ - Reusable     │ - Scanner           │
│ - Accessible        │ - Animated     │ - Results           │
│                     │                │ - Analytics         │
├─────────────────────────────────────────────────────────────┤
│                    State Management                          │
├─────────────────────────────────────────────────────────────┤
│ Provider Pattern    │ ViewModels     │ State Classes       │
│ - AuthProvider      │ - Business     │ - Immutable         │
│ - AppStateProvider  │   Logic        │ - Serializable     │
│ - MusicProvider     │ - Validation   │ - Cache-friendly    │
│ - EventProvider     │ - Transformation│                    │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                             │
├─────────────────────────────────────────────────────────────┤
│ Business Services   │ Integration    │ Utility Services    │
│ - MoodEngine        │ Services       │ - CacheService      │
│ - RecommendationSvc │ - SpotifyAPI   │ - EncryptionSvc     │
│ - AnalyticsEngine   │ - AWSService   │ - NotificationSvc   │
│ - EventEngine       │ - EventAPIs    │ - LocationService   │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                                │
├─────────────────────────────────────────────────────────────┤
│ Local Storage       │ Cloud Storage  │ External APIs       │
│ - SQLite DB         │ - Firestore    │ - Spotify Web API   │
│ - Secure Storage    │ - Cloud Storage│ - AWS Rekognition   │
│ - SharedPrefs       │ - Firebase Auth│ - Ticketmaster      │
│ - Cache Storage     │                │ - Eventbrite        │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow Architecture

```
User Interaction → UI Layer → Provider/ViewModel → Service Layer → Data Layer
                                    ↑                                  ↓
                              State Updates ←── API Response ←── External API
                                    ↓
                            UI Re-render with New State
```

### 1.3 Offline-First Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local SQLite  │    │  Service Layer  │    │   Cloud APIs    │
│                 │    │                 │    │                 │
│ • Mood History  │◄──►│ • Cache Manager │◄──►│ • Spotify API   │
│ • User Prefs    │    │ • Sync Engine   │    │ • AWS Services  │
│ • Music Cache   │    │ • Offline Queue │    │ • Event APIs    │
│ • Event Cache   │    │ • Conflict Res. │    │ • Firebase      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## 2. Core Feature Implementation Specifications

### 2.1 Enhanced Spotify Integration

#### 2.1.1 OAuth 2.0 Implementation

```dart
// spotify_auth_service.dart
class SpotifyAuthService {
  static const String clientId = 'YOUR_SPOTIFY_CLIENT_ID';
  static const String redirectUri = 'moodmusic://spotify-auth';
  static const List<String> scopes = [
    'user-read-private',
    'user-read-email', 
    'user-top-read',
    'user-read-playback-state',
    'app-remote-control',
    'streaming',
    'playlist-modify-public',
    'playlist-modify-private',
    'playlist-read-private',
    'user-library-read',
    'user-library-modify',
  ];

  Future<SpotifyAuthResult> authenticate() async {
    try {
      // Step 1: Generate PKCE challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      
      // Step 2: Build authorization URL
      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'scope': scopes.join(' '),
        'state': _generateState(),
      });

      // Step 3: Launch browser and wait for callback
      final result = await _launchAuthUrl(authUrl);
      
      // Step 4: Exchange code for tokens
      return await _exchangeCodeForTokens(result.code, codeVerifier);
      
    } catch (e) {
      throw SpotifyAuthException('Authentication failed: $e');
    }
  }

  Future<void> refreshToken() async {
    final refreshToken = await _secureStorage.read(key: 'spotify_refresh_token');
    if (refreshToken == null) throw SpotifyAuthException('No refresh token');

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
      },
    );

    if (response.statusCode == 200) {
      final tokens = json.decode(response.body);
      await _storeTokens(tokens);
    } else {
      throw SpotifyAuthException('Token refresh failed');
    }
  }
}
```

#### 2.1.2 Advanced API Client with Rate Limiting

```dart
// spotify_api_client.dart
class SpotifyApiClient {
  final http.Client _httpClient;
  final RateLimiter _rateLimiter;
  final CacheManager _cache;
  
  SpotifyApiClient({
    http.Client? httpClient,
    CacheManager? cache,
  }) : _httpClient = httpClient ?? http.Client(),
       _cache = cache ?? CacheManager.instance,
       _rateLimiter = RateLimiter(
         requestsPerSecond: 10,
         requestsPerHour: 20000,
       );

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    bool useCache = true,
    Duration cacheDuration = const Duration(minutes: 15),
  }) async {
    // Check cache first
    if (useCache) {
      final cached = await _cache.get<T>(endpoint, queryParams);
      if (cached != null) return ApiResponse.success(cached);
    }

    // Rate limiting
    await _rateLimiter.acquire();

    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await _httpClient.get(
        uri,
        headers: await _buildHeaders(),
      );

      return await _handleResponse<T>(response, endpoint, queryParams, cacheDuration);
      
    } on SocketException {
      return ApiResponse.networkError();
    } on TimeoutException {
      return ApiResponse.timeout();
    } catch (e) {
      logger.error('API request failed', error: e);
      return ApiResponse.error(e.toString());
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await _getValidToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<String> _getValidToken() async {
    final expiresAt = await _secureStorage.read(key: 'spotify_expires_at');
    if (expiresAt != null && DateTime.now().isBefore(DateTime.parse(expiresAt))) {
      return await _secureStorage.read(key: 'spotify_access_token') ?? '';
    }
    
    // Token expired, refresh it
    await SpotifyAuthService().refreshToken();
    return await _secureStorage.read(key: 'spotify_access_token') ?? '';
  }
}
```

#### 2.1.3 Music Recommendation Engine

```dart
// music_recommendation_engine.dart
class MusicRecommendationEngine {
  final SpotifyApiClient _apiClient;
  final UserMusicProfileService _profileService;
  final MoodAnalysisEngine _moodEngine;

  Future<List<Track>> generateMoodBasedRecommendations({
    required Mood mood,
    required UserMusicProfile profile,
    int limit = 50,
  }) async {
    // Step 1: Define audio features based on mood
    final audioFeatures = _mapMoodToAudioFeatures(mood);
    
    // Step 2: Get genre seeds based on user profile and mood
    final genreSeeds = _selectGenreSeeds(profile, mood);
    
    // Step 3: Get artist/track seeds from user's top items
    final artistSeeds = await _getArtistSeeds(profile);
    final trackSeeds = await _getTrackSeeds(profile);

    // Step 4: Generate recommendations using multiple strategies
    final strategies = [
      RecommendationStrategy.moodReinforcement,
      RecommendationStrategy.personalTaste,
      RecommendationStrategy.discovery,
      RecommendationStrategy.contrast,
    ];

    final allRecommendations = <Track>[];
    
    for (final strategy in strategies) {
      final recommendations = await _generateByStrategy(
        strategy: strategy,
        mood: mood,
        profile: profile,
        audioFeatures: audioFeatures,
        genreSeeds: genreSeeds,
        artistSeeds: artistSeeds,
        trackSeeds: trackSeeds,
        limit: limit ~/ strategies.length,
      );
      
      allRecommendations.addAll(recommendations);
    }

    // Step 5: Diversify and rank recommendations
    return _diversifyAndRank(allRecommendations, mood, profile);
  }

  AudioFeatures _mapMoodToAudioFeatures(Mood mood) {
    switch (mood.primary) {
      case EmotionType.happy:
        return AudioFeatures(
          valence: (0.7, 1.0),      // High positivity
          energy: (0.6, 1.0),       // High energy
          danceability: (0.5, 1.0), // Danceable
          tempo: (120, 180),        // Upbeat tempo
        );
      
      case EmotionType.sad:
        return AudioFeatures(
          valence: (0.0, 0.4),      // Low positivity
          energy: (0.0, 0.5),       // Low energy
          acousticness: (0.3, 1.0), // More acoustic
          tempo: (60, 120),         // Slower tempo
        );
      
      case EmotionType.angry:
        return AudioFeatures(
          valence: (0.0, 0.6),      // Mixed positivity
          energy: (0.7, 1.0),       // High energy
          loudness: (-5, 0),        // Loud
          tempo: (140, 200),        // Fast tempo
        );
      
      case EmotionType.calm:
        return AudioFeatures(
          valence: (0.4, 0.8),      // Moderate positivity
          energy: (0.0, 0.4),       // Low energy
          acousticness: (0.4, 1.0), // Acoustic preference
          instrumentalness: (0.2, 1.0), // Some instrumental
        );
      
      case EmotionType.anxious:
        return AudioFeatures(
          valence: (0.3, 0.7),      // Balanced
          energy: (0.3, 0.7),       // Moderate energy
          speechiness: (0.0, 0.3),  // Less speech
          tempo: (80, 140),         // Moderate tempo
        );
      
      case EmotionType.excited:
        return AudioFeatures(
          valence: (0.8, 1.0),      // Very positive
          energy: (0.8, 1.0),       // Very high energy
          danceability: (0.7, 1.0), // Very danceable
          tempo: (140, 200),        // Fast tempo
        );
      
      default:
        return AudioFeatures.neutral();
    }
  }
}
```

### 2.2 Advanced Emotion Detection System

#### 2.2.1 AWS Rekognition Integration with Fallback

```dart
// emotion_detection_service.dart
class EmotionDetectionService {
  final AWSRekognitionService _awsService;
  final TensorFlowLiteService _tfLiteService;
  final NetworkService _networkService;

  Future<EmotionAnalysisResult> analyzeEmotion(File imageFile) async {
    try {
      // Check network connectivity
      if (await _networkService.hasConnection()) {
        return await _analyzeWithAWS(imageFile);
      } else {
        return await _analyzeOffline(imageFile);
      }
    } catch (e) {
      logger.warning('AWS analysis failed, falling back to offline', error: e);
      return await _analyzeOffline(imageFile);
    }
  }

  Future<EmotionAnalysisResult> _analyzeWithAWS(File imageFile) async {
    // Step 1: Optimize image for AWS
    final optimizedImage = await _optimizeImageForAWS(imageFile);
    
    // Step 2: Upload to AWS Rekognition
    final rekognitionResult = await _awsService.detectFaces(
      imageBytes: optimizedImage.bytes,
      attributes: ['ALL'],
    );

    // Step 3: Process AWS response
    if (rekognitionResult.faceDetails?.isEmpty ?? true) {
      throw EmotionDetectionException('No faces detected');
    }

    final faceDetail = rekognitionResult.faceDetails!.first;
    final emotions = faceDetail.emotions ?? [];

    // Step 4: Convert AWS emotions to our format
    final emotionScores = <EmotionType, double>{};
    for (final emotion in emotions) {
      final emotionType = _mapAWSEmotionToType(emotion.type);
      if (emotionType != null) {
        emotionScores[emotionType] = emotion.confidence! / 100.0;
      }
    }

    // Step 5: Calculate overall confidence
    final overallConfidence = _calculateOverallConfidence(emotionScores);

    return EmotionAnalysisResult(
      emotions: emotionScores,
      confidence: overallConfidence,
      processingTime: DateTime.now().difference(startTime),
      method: EmotionDetectionMethod.aws,
      faceCount: rekognitionResult.faceDetails!.length,
      imageQuality: _assessImageQuality(faceDetail),
    );
  }

  Future<EmotionAnalysisResult> _analyzeOffline(File imageFile) async {
    // Load TensorFlow Lite model if not already loaded
    await _tfLiteService.loadModel();

    // Preprocess image for TF Lite
    final inputTensor = await _preprocessImageForTFLite(imageFile);

    // Run inference
    final output = await _tfLiteService.runInference(inputTensor);

    // Post-process results
    final emotionScores = _processTFLiteOutput(output);
    
    return EmotionAnalysisResult(
      emotions: emotionScores,
      confidence: _calculateOverallConfidence(emotionScores),
      processingTime: DateTime.now().difference(startTime),
      method: EmotionDetectionMethod.offline,
      faceCount: 1, // TF Lite model assumes single face
      imageQuality: ImageQuality.unknown,
    );
  }

  Future<OptimizedImage> _optimizeImageForAWS(File imageFile) async {
    final image = img.decodeImage(await imageFile.readAsBytes());
    if (image == null) throw ImageProcessingException('Invalid image format');

    // Resize if too large (AWS has 5MB limit)
    img.Image resized = image;
    if (imageFile.lengthSync() > 4 * 1024 * 1024) { // 4MB threshold
      final aspectRatio = image.width / image.height;
      final targetWidth = aspectRatio > 1 ? 1920 : (1920 * aspectRatio).round();
      final targetHeight = aspectRatio > 1 ? (1920 / aspectRatio).round() : 1920;
      
      resized = img.copyResize(image, width: targetWidth, height: targetHeight);
    }

    // Convert to JPEG with quality optimization
    final jpegBytes = img.encodeJpg(resized, quality: 90);
    
    return OptimizedImage(
      bytes: jpegBytes,
      width: resized.width,
      height: resized.height,
      format: ImageFormat.jpeg,
    );
  }
}
```

#### 2.2.2 Enhanced Mood Engine with Complex Emotions

```dart
// advanced_mood_engine.dart
class AdvancedMoodEngine {
  final MoodProfileRepository _profileRepo;
  final UserFeedbackService _feedbackService;

  Future<Mood> analyzeMood(EmotionAnalysisResult emotionResult) async {
    // Step 1: Load mood profiles
    final profiles = await _profileRepo.getAllProfiles();
    
    // Step 2: Calculate compatibility scores
    final profileScores = <MoodProfile, double>{};
    
    for (final profile in profiles) {
      final score = _calculateProfileCompatibility(emotionResult, profile);
      if (score > 0.3) { // Minimum threshold
        profileScores[profile] = score;
      }
    }

    // Step 3: Handle complex emotions (multiple high scores)
    if (profileScores.length > 1) {
      return _handleComplexEmotion(profileScores, emotionResult);
    }

    // Step 4: Single mood or fallback
    if (profileScores.isNotEmpty) {
      final bestProfile = profileScores.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      
      return _createMoodFromProfile(bestProfile, profileScores[bestProfile]!);
    }

    // Step 5: Fallback to neutral/drift mood
    return _createFallbackMood(emotionResult);
  }

  Mood _handleComplexEmotion(
    Map<MoodProfile, double> profileScores, 
    EmotionAnalysisResult emotionResult,
  ) {
    // Sort by score
    final sortedProfiles = profileScores.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    final primary = sortedProfiles.first;
    final secondary = sortedProfiles.length > 1 ? sortedProfiles[1] : null;

    // Check if secondary emotion is significant
    if (secondary != null && secondary.value > primary.value * 0.7) {
      return Mood(
        primary: primary.key.emotion,
        secondary: secondary.key.emotion,
        confidence: primary.value,
        complexity: MoodComplexity.complex,
        profile: primary.key,
        rawEmotions: emotionResult.emotions,
        detectedAt: DateTime.now(),
      );
    }

    return Mood(
      primary: primary.key.emotion,
      confidence: primary.value,
      complexity: MoodComplexity.simple,
      profile: primary.key,
      rawEmotions: emotionResult.emotions,
      detectedAt: DateTime.now(),
    );
  }

  double _calculateProfileCompatibility(
    EmotionAnalysisResult emotionResult, 
    MoodProfile profile,
  ) {
    double totalScore = 0.0;
    double totalWeight = 0.0;

    for (final emotion in EmotionType.values) {
      final detectedValue = emotionResult.emotions[emotion] ?? 0.0;
      final profileRange = profile.emotionRanges[emotion];
      
      if (profileRange != null) {
        final weight = profile.emotionWeights[emotion] ?? 1.0;
        final score = _calculateEmotionScore(detectedValue, profileRange);
        
        totalScore += score * weight;
        totalWeight += weight;
      }
    }

    return totalWeight > 0 ? totalScore / totalWeight : 0.0;
  }

  double _calculateEmotionScore(double value, EmotionRange range) {
    if (value >= range.min && value <= range.max) {
      // Perfect match
      return 1.0;
    } else if (value < range.min) {
      // Below range - calculate distance penalty
      final distance = range.min - value;
      return math.max(0.0, 1.0 - (distance * 2)); // 2x penalty for being outside
    } else {
      // Above range - calculate distance penalty
      final distance = value - range.max;
      return math.max(0.0, 1.0 - (distance * 2));
    }
  }
}
```

### 2.3 Local Database & Cloud Synchronization

#### 2.3.1 SQLite Database Schema & Repository Pattern

```dart
// database_schema.dart
class DatabaseSchema {
  static const String dbName = 'moodmusic.db';
  static const int dbVersion = 1;

  static const String createTables = '''
    -- Users table
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      display_name TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      preferences TEXT, -- JSON
      subscription_status TEXT,
      last_sync INTEGER
    );

    -- Mood sessions table
    CREATE TABLE mood_sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      mood_type TEXT NOT NULL,
      confidence REAL NOT NULL,
      complexity TEXT NOT NULL,
      raw_emotions TEXT NOT NULL, -- JSON
      image_path TEXT,
      detected_at INTEGER NOT NULL,
      synced_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users (id)
    );

    -- Music interactions table
    CREATE TABLE music_interactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      session_id TEXT,
      track_id TEXT NOT NULL,
      track_name TEXT NOT NULL,
      artist_name TEXT NOT NULL,
      action_type TEXT NOT NULL, -- played, liked, skipped, saved
      timestamp INTEGER NOT NULL,
      context TEXT, -- JSON with mood, playlist info, etc.
      synced_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users (id),
      FOREIGN KEY (session_id) REFERENCES mood_sessions (id)
    );

    -- Event interactions table
    CREATE TABLE event_interactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      session_id TEXT,
      event_id TEXT NOT NULL,
      event_name TEXT NOT NULL,
      venue_name TEXT,
      action_type TEXT NOT NULL, -- viewed, saved, purchased
      timestamp INTEGER NOT NULL,
      context TEXT, -- JSON
      synced_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users (id),
      FOREIGN KEY (session_id) REFERENCES mood_sessions (id)
    );

    -- Playlists table
    CREATE TABLE playlists (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      spotify_playlist_id TEXT,
      name TEXT NOT NULL,
      description TEXT,
      mood_type TEXT,
      track_count INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      synced_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES users (id)
    );

    -- Cache tables for offline functionality
    CREATE TABLE cached_recommendations (
      id TEXT PRIMARY KEY,
      mood_type TEXT NOT NULL,
      user_preferences_hash TEXT NOT NULL,
      recommendations TEXT NOT NULL, -- JSON
      cached_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL
    );

    -- Indexes for performance
    CREATE INDEX idx_mood_sessions_user_date ON mood_sessions (user_id, detected_at);
    CREATE INDEX idx_music_interactions_user_date ON music_interactions (user_id, timestamp);
    CREATE INDEX idx_event_interactions_user_date ON event_interactions (user_id, timestamp);
    CREATE INDEX idx_playlists_user ON playlists (user_id);
    CREATE INDEX idx_cached_recommendations_mood ON cached_recommendations (mood_type, expires_at);
  ''';
}

// mood_session_repository.dart
class MoodSessionRepository {
  final Database _db;
  final EncryptionService _encryption;

  Future<MoodSession> insert(MoodSession session) async {
    final data = {
      'id': session.id,
      'user_id': session.userId,
      'mood_type': session.mood.primary.name,
      'confidence': session.mood.confidence,
      'complexity': session.mood.complexity.name,
      'raw_emotions': json.encode(session.mood.rawEmotions.map(
        (k, v) => MapEntry(k.name, v),
      )),
      'image_path': await _encryption.encryptString(session.imagePath ?? ''),
      'detected_at': session.detectedAt.millisecondsSinceEpoch,
      'synced_at': null,
    };

    await _db.insert('mood_sessions', data);
    return session.copyWith(needsSync: true);
  }

  Future<List<MoodSession>> getRecentSessions(String userId, {int limit = 50}) async {
    final results = await _db.query(
      'mood_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'detected_at DESC',
      limit: limit,
    );

    return results.map(_mapToMoodSession).toList();
  }

  Future<MoodAnalytics> getUserMoodAnalytics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final whereClause = StringBuffer('user_id = ?');
    final whereArgs = <dynamic>[userId];

    if (startDate != null) {
      whereClause.write(' AND detected_at >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause.write(' AND detected_at <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final results = await _db.query(
      'mood_sessions',
      where: whereClause.toString(),
      whereArgs: whereArgs,
      orderBy: 'detected_at ASC',
    );

    return _calculateAnalytics(results.map(_mapToMoodSession).toList());
  }

  MoodSession _mapToMoodSession(Map<String, dynamic> data) {
    final rawEmotions = <EmotionType, double>{};
    final emotionsJson = json.decode(data['raw_emotions']) as Map<String, dynamic>;
    
    for (final entry in emotionsJson.entries) {
      final emotionType = EmotionType.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => EmotionType.neutral,
      );
      rawEmotions[emotionType] = entry.value as double;
    }

    return MoodSession(
      id: data['id'],
      userId: data['user_id'],
      mood: Mood(
        primary: EmotionType.values.firstWhere(
          (e) => e.name == data['mood_type'],
        ),
        confidence: data['confidence'],
        complexity: MoodComplexity.values.firstWhere(
          (c) => c.name == data['complexity'],
        ),
        rawEmotions: rawEmotions,
        detectedAt: DateTime.fromMillisecondsSinceEpoch(data['detected_at']),
      ),
      imagePath: data['image_path'] != null 
          ? _encryption.decryptString(data['image_path'])
          : null,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(data['detected_at']),
      needsSync: data['synced_at'] == null,
    );
  }
}
```

#### 2.3.2 Cloud Synchronization Engine

```dart
// sync_engine.dart
class SyncEngine {
  final FirestoreService _firestore;
  final DatabaseService _localDb;
  final NetworkService _network;
  final ConflictResolver _conflictResolver;

  Future<SyncResult> syncAllData(String userId) async {
    if (!await _network.hasConnection()) {
      return SyncResult.noConnection();
    }

    final result = SyncResult();

    try {
      // Step 1: Push local changes to cloud
      await _pushLocalChanges(userId, result);

      // Step 2: Pull remote changes from cloud
      await _pullRemoteChanges(userId, result);

      // Step 3: Resolve any conflicts
      await _resolveConflicts(userId, result);

      // Step 4: Update last sync timestamp
      await _updateLastSyncTimestamp(userId);

      return result;

    } catch (e) {
      logger.error('Sync failed', error: e);
      return SyncResult.error(e.toString());
    }
  }

  Future<void> _pushLocalChanges(String userId, SyncResult result) async {
    // Push mood sessions
    final unsyncedSessions = await _localDb.moodSessions
        .getUnsyncedSessions(userId);
    
    for (final session in unsyncedSessions) {
      try {
        await _firestore.collection('mood_sessions').doc(session.id).set({
          'user_id': userId,
          'mood_type': session.mood.primary.name,
          'confidence': session.mood.confidence,
          'complexity': session.mood.complexity.name,
          'raw_emotions': session.mood.rawEmotions.map(
            (k, v) => MapEntry(k.name, v),
          ),
          'detected_at': session.detectedAt,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Mark as synced locally
        await _localDb.moodSessions.markAsSynced(session.id);
        result.pushedSessions++;

      } catch (e) {
        logger.warning('Failed to sync session ${session.id}', error: e);
        result.errors.add('Session sync failed: $e');
      }
    }

    // Push music interactions
    final unsyncedInteractions = await _localDb.musicInteractions
        .getUnsyncedInteractions(userId);
    
    for (final interaction in unsyncedInteractions) {
      try {
        await _firestore.collection('music_interactions').doc(interaction.id).set({
          'user_id': userId,
          'session_id': interaction.sessionId,
          'track_id': interaction.trackId,
          'track_name': interaction.trackName,
          'artist_name': interaction.artistName,
          'action_type': interaction.actionType.name,
          'timestamp': interaction.timestamp,
          'context': interaction.context,
          'created_at': FieldValue.serverTimestamp(),
        });

        await _localDb.musicInteractions.markAsSynced(interaction.id);
        result.pushedInteractions++;

      } catch (e) {
        logger.warning('Failed to sync interaction ${interaction.id}', error: e);
        result.errors.add('Interaction sync failed: $e');
      }
    }
  }

  Future<void> _pullRemoteChanges(String userId, SyncResult result) async {
    final lastSync = await _localDb.users.getLastSyncTimestamp(userId);
    
    // Pull mood sessions created/updated since last sync
    final remoteSessions = await _firestore
        .collection('mood_sessions')
        .where('user_id', isEqualTo: userId)
        .where('updated_at', isGreaterThan: lastSync)
        .get();

    for (final doc in remoteSessions.docs) {
      try {
        final remoteSession = _mapFirestoreToMoodSession(doc.data());
        final localSession = await _localDb.moodSessions.findById(doc.id);

        if (localSession == null) {
          // New remote session
          await _localDb.moodSessions.insert(remoteSession.copyWith(
            needsSync: false,
          ));
          result.pulledSessions++;
        } else {
          // Potential conflict - let conflict resolver handle it
          await _conflictResolver.resolveMoodSessionConflict(
            localSession, 
            remoteSession,
          );
        }

      } catch (e) {
        logger.warning('Failed to pull session ${doc.id}', error: e);
        result.errors.add('Session pull failed: $e');
      }
    }

    // Similar logic for other data types...
  }

  Future<void> _resolveConflicts(String userId, SyncResult result) async {
    final conflicts = await _conflictResolver.getPendingConflicts(userId);
    
    for (final conflict in conflicts) {
      try {
        final resolution = await _conflictResolver.resolveConflict(conflict);
        
        switch (resolution.action) {
          case ConflictResolutionAction.useLocal:
            // Push local version to cloud
            await _pushConflictedItem(resolution.localItem);
            break;
            
          case ConflictResolutionAction.useRemote:
            // Replace local with remote
            await _replaceLocalItem(resolution.remoteItem);
            break;
            
          case ConflictResolutionAction.merge:
            // Create merged version
            final merged = await _conflictResolver.mergeItems(
              resolution.localItem,
              resolution.remoteItem,
            );
            await _replaceLocalItem(merged);
            await _pushConflictedItem(merged);
            break;
        }

        result.resolvedConflicts++;

      } catch (e) {
        logger.error('Failed to resolve conflict', error: e);
        result.errors.add('Conflict resolution failed: $e');
      }
    }
  }
}
```

### 2.4 Premium Subscription System

#### 2.4.1 RevenueCat Integration

```dart
// subscription_service.dart
class SubscriptionService {
  final Purchases purchases = Purchases();
  final SubscriptionStateNotifier _stateNotifier;

  static const String monthlyProductId = 'moodmusic_pro_monthly';
  static const String yearlyProductId = 'moodmusic_pro_yearly';
  static const String familyProductId = 'moodmusic_family';

  Future<void> initialize(String userId) async {
    // Configure RevenueCat
    await purchases.configure(
      PurchasesConfiguration('YOUR_REVENUECAT_API_KEY')
        ..appUserID = userId
        ..observerMode = false,
    );

    // Set up purchase listener
    purchases.addPurchaseListener(_handlePurchaseUpdate);

    // Set up customer info listener for subscription status
    purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

    // Check current subscription status
    await _checkSubscriptionStatus();
  }

  Future<List<Package>> getAvailablePackages() async {
    try {
      final offerings = await purchases.getOfferings();
      final currentOffering = offerings.current;
      
      if (currentOffering != null) {
        return currentOffering.availablePackages;
      }
      
      return [];
    } catch (e) {
      logger.error('Failed to get packages', error: e);
      return [];
    }
  }

  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      final purchaserInfo = await purchases.purchasePackage(package);
      
      if (purchaserInfo.customerInfo.entitlements.active.isNotEmpty) {
        await _updateLocalSubscriptionStatus(SubscriptionStatus.active);
        return PurchaseResult.success(purchaserInfo);
      } else {
        return PurchaseResult.failed('Purchase completed but no active entitlements');
      }
      
    } on PlatformException catch (e) {
      if (e.code == 'purchase_cancelled') {
        return PurchaseResult.cancelled();
      } else {
        return PurchaseResult.failed(e.message ?? 'Purchase failed');
      }
    } catch (e) {
      return PurchaseResult.failed(e.toString());
    }
  }

  Future<RestoreResult> restorePurchases() async {
    try {
      final purchaserInfo = await purchases.restorePurchases();
      
      if (purchaserInfo.entitlements.active.isNotEmpty) {
        await _updateLocalSubscriptionStatus(SubscriptionStatus.active);
        return RestoreResult.success(purchaserInfo);
      } else {
        await _updateLocalSubscriptionStatus(SubscriptionStatus.inactive);
        return RestoreResult.noSubscriptions();
      }
      
    } catch (e) {
      return RestoreResult.failed(e.toString());
    }
  }

  Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await purchases.getCustomerInfo();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      // Fallback to local status if network is unavailable
      final localStatus = await _getLocalSubscriptionStatus();
      return localStatus == SubscriptionStatus.active;
    }
  }

  Future<EntitlementInfo?> getActiveSubscription() async {
    try {
      final customerInfo = await purchases.getCustomerInfo();
      final activeEntitlements = customerInfo.entitlements.active;
      
      if (activeEntitlements.isNotEmpty) {
        return activeEntitlements.values.first;
      }
      
      return null;
    } catch (e) {
      logger.error('Failed to get active subscription', error: e);
      return null;
    }
  }

  void _handlePurchaseUpdate(
    CustomerInfo customerInfo,
    PurchaseDetails purchaseDetails,
  ) {
    // Update local subscription status
    if (customerInfo.entitlements.active.isNotEmpty) {
      _updateLocalSubscriptionStatus(SubscriptionStatus.active);
    } else {
      _updateLocalSubscriptionStatus(SubscriptionStatus.inactive);
    }

    // Notify listeners
    _stateNotifier.updatePurchaseState(
      PurchaseState(
        isActive: customerInfo.entitlements.active.isNotEmpty,
        products: customerInfo.allPurchasedProductIdentifiers,
        customerInfo: customerInfo,
      ),
    );
  }

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    // Handle subscription status changes (renewals, cancellations, etc.)
    final hasActiveSubscription = customerInfo.entitlements.active.isNotEmpty;
    
    if (hasActiveSubscription) {
      _updateLocalSubscriptionStatus(SubscriptionStatus.active);
      _stateNotifier.notifySubscriptionActivated();
    } else {
      _updateLocalSubscriptionStatus(SubscriptionStatus.inactive);
      _stateNotifier.notifySubscriptionDeactivated();
    }

    // Handle expiring subscriptions
    for (final entitlement in customerInfo.entitlements.all.values) {
      if (entitlement.willRenew == false && entitlement.isActive) {
        final daysUntilExpiry = entitlement.expirationDate
            ?.difference(DateTime.now())
            .inDays ?? 0;
            
        if (daysUntilExpiry <= 3) {
          _stateNotifier.notifySubscriptionExpiring(daysUntilExpiry);
        }
      }
    }
  }
}
```

#### 2.4.2 Feature Gating System

```dart
// feature_gate_service.dart
class FeatureGateService {
  final SubscriptionService _subscriptionService;
  final UserPreferencesService _preferencesService;

  // Free tier limits
  static const int freeDailyScans = 3;
  static const int freeMaxPlaylists = 3;
  static const int freeEventViewsPerDay = 5;

  Future<bool> canAccessFeature(Feature feature) async {
    final hasSubscription = await _subscriptionService.hasActiveSubscription();
    
    if (hasSubscription) {
      return true; // Premium users get all features
    }

    // Check free tier limitations
    switch (feature) {
      case Feature.moodScan:
        return await _canPerformMoodScan();
      
      case Feature.createPlaylist:
        return await _canCreatePlaylist();
      
      case Feature.viewEvents:
        return await _canViewEvents();
      
      case Feature.advancedAnalytics:
      case Feature.exportData:
      case Feature.prioritySupport:
        return false; // Premium only
      
      case Feature.musicPreviews:
      case Feature.basicAnalytics:
        return true; // Always free
      
      default:
        return false;
    }
  }

  Future<bool> _canPerformMoodScan() async {
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    final scansToday = await _preferencesService.getInt('scans_$todayKey') ?? 0;
    return scansToday < freeDailyScans;
  }

  Future<void> recordMoodScan() async {
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    final scansToday = await _preferencesService.getInt('scans_$todayKey') ?? 0;
    await _preferencesService.setInt('scans_$todayKey', scansToday + 1);
  }

  Future<int> getRemainingScansToday() async {
    if (await _subscriptionService.hasActiveSubscription()) {
      return -1; // Unlimited
    }

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${今.day}';
    
    final scansToday = await _preferencesService.getInt('scans_$todayKey') ?? 0;
    return math.max(0, freeDailyScans - scansToday);
  }

  Future<FeatureGateResult> checkFeatureAccess(Feature feature) async {
    final hasAccess = await canAccessFeature(feature);
    
    if (hasAccess) {
      return FeatureGateResult.allowed();
    }

    // Provide context for why access was denied
    switch (feature) {
      case Feature.moodScan:
        final remaining = await getRemainingScansToday();
        if (remaining == 0) {
          return FeatureGateResult.dailyLimitReached(
            message: 'You\'ve used all 3 free mood scans today. Upgrade to Premium for unlimited scans!',
            upgradeButtonText: 'Upgrade Now',
          );
        }
        break;
      
      case Feature.createPlaylist:
        final playlistCount = await _getPlaylistCount();
        if (playlistCount >= freeMaxPlaylists) {
          return FeatureGateResult.limitReached(
            message: 'Free accounts can create up to 3 playlists. Upgrade for unlimited playlists!',
            upgradeButtonText: 'Go Premium',
          );
        }
        break;
      
      default:
        return FeatureGateResult.premiumRequired(
          message: 'This feature is available with MoodMusic Premium.',
          upgradeButtonText: 'Try Premium Free',
        );
    }

    return FeatureGateResult.denied();
  }
}
```

### 2.5 Event Discovery System

#### 2.5.1 Multi-API Event Integration

```dart
// event_discovery_service.dart
class EventDiscoveryService {
  final TicketmasterApiClient _ticketmaster;
  final EventbriteApiClient _eventbrite;
  final LocationService _locationService;
  final EventRecommendationEngine _recommendationEngine;

  Future<List<Event>> discoverEvents({
    required Mood mood,
    required UserLocation location,
    int radius = 25, // miles
    int limit = 50,
  }) async {
    final allEvents = <Event>[];

    // Parallel API calls for better performance
    final results = await Future.wait([
      _getTicketmasterEvents(location, radius, limit ~/ 2),
      _getEventbriteEvents(location, radius, limit ~/ 2),
    ]);

    allEvents.addAll(results[0]);
    allEvents.addAll(results[1]);

    // Remove duplicates and rank by relevance to mood
    final uniqueEvents = _removeDuplicateEvents(allEvents);
    final rankedEvents = await _recommendationEngine.rankEventsByMood(
      events: uniqueEvents,
      mood: mood,
      userLocation: location,
    );

    return rankedEvents.take(limit).toList();
  }

  Future<List<Event>> _getTicketmasterEvents(
    UserLocation location,
    int radius,
    int limit,
  ) async {
    try {
      final response = await _ticketmaster.searchEvents(
        latitude: location.latitude,
        longitude: location.longitude,
        radius: radius,
        unit: 'miles',
        size: limit,
        sort: 'date,asc',
        includeTBA: false,
        includeTBD: false,
      );

      return response.embedded?.events
          ?.map(_mapTicketmasterEvent)
          .toList() ?? [];

    } catch (e) {
      logger.warning('Ticketmaster API failed', error: e);
      return [];
    }
  }

  Future<List<Event>> _getEventbriteEvents(
    UserLocation location,
    int radius,
    int limit,
  ) async {
    try {
      // Convert radius to kilometers for Eventbrite
      final radiusKm = (radius * 1.60934).round();
      
      final response = await _eventbrite.searchEvents(
        latitude: location.latitude,
        longitude: location.longitude,
        within: '${radiusKm}km',
        limit: limit,
        sortBy: 'date',
        categories: _getMoodRelevantCategories(),
      );

      return response.events
          ?.map(_mapEventbriteEvent)
          .toList() ?? [];

    } catch (e) {
      logger.warning('Eventbrite API failed', error: e);
      return [];
    }
  }

  Event _mapTicketmasterEvent(TicketmasterEvent tmEvent) {
    return Event(
      id: tmEvent.id,
      name: tmEvent.name,
      description: tmEvent.info,
      startDate: DateTime.parse(tmEvent.dates.start.dateTime),
      endDate: tmEvent.dates.end != null 
          ? DateTime.parse(tmEvent.dates.end!.dateTime)
          : null,
      venue: Venue(
        name: tmEvent.embedded?.venues?.first.name ?? '',
        address: _buildAddress(tmEvent.embedded?.venues?.first),
        city: tmEvent.embedded?.venues?.first.city?.name ?? '',
        state: tmEvent.embedded?.venues?.first.state?.name ?? '',
        country: tmEvent.embedded?.venues?.first.country?.name ?? '',
        coordinates: tmEvent.embedded?.venues?.first.location != null
            ? Coordinates(
                latitude: double.parse(tmEvent.embedded!.venues!.first.location!.latitude),
                longitude: double.parse(tmEvent.embedded!.venues!.first.location!.longitude),
              )
            : null,
      ),
      categories: tmEvent.classifications
          ?.map((c) => c.segment?.name ?? '')
          .where((name) => name.isNotEmpty)
          .toList() ?? [],
      priceRange: tmEvent.priceRanges?.isNotEmpty == true
          ? PriceRange(
              min: tmEvent.priceRanges!.first.min,
              max: tmEvent.priceRanges!.first.max,
              currency: tmEvent.priceRanges!.first.currency,
            )
          : null,
      images: tmEvent.images
          ?.map((img) => EventImage(
                url: img.url,
                width: img.width,
                height: img.height,
                ratio: img.ratio,
              ))
          .toList() ?? [],
      ticketUrl: tmEvent.url,
      source: EventSource.ticketmaster,
      sourceId: tmEvent.id,
    );
  }

  Event _mapEventbriteEvent(EventbriteEvent ebEvent) {
    return Event(
      id: 'eb_${ebEvent.id}',
      name: ebEvent.name.text,
      description: ebEvent.description?.text,
      startDate: DateTime.parse(ebEvent.start.utc),
      endDate: DateTime.parse(ebEvent.end.utc),
      venue: Venue(
        name: ebEvent.venue?.name ?? '',
        address: ebEvent.venue?.address?.localizedAddressDisplay,
        city: ebEvent.venue?.address?.city,
        state: ebEvent.venue?.address?.region,
        country: ebEvent.venue?.address?.country,
        coordinates: ebEvent.venue?.latitude != null && ebEvent.venue?.longitude != null
            ? Coordinates(
                latitude: double.parse(ebEvent.venue!.latitude!),
                longitude: double.parse(ebEvent.venue!.longitude!),
              )
            : null,
      ),
      categories: [ebEvent.category?.name].where((c) => c != null).cast<String>().toList(),
      priceRange: ebEvent.ticketAvailability?.minTicketPrice != null
          ? PriceRange(
              min: ebEvent.ticketAvailability!.minTicketPrice! / 100, // Convert cents to dollars
              max: ebEvent.ticketAvailability!.maxTicketPrice != null 
                  ? ebEvent.ticketAvailability!.maxTicketPrice! / 100
                  : null,
              currency: 'USD',
            )
          : null,
      images: ebEvent.logo != null
          ? [EventImage(
              url: ebEvent.logo!.url,
              width: ebEvent.logo!.aspectRatio != null ? 600 : null,
              height: ebEvent.logo!.aspectRatio != null ? (600 / double.parse(ebEvent.logo!.aspectRatio!)).round() : null,
            )]
          : [],
      ticketUrl: ebEvent.url,
      source: EventSource.eventbrite,
      sourceId: ebEvent.id,
    );
  }
}
```

#### 2.5.2 Event Recommendation Engine

```dart
// event_recommendation_engine.dart
class EventRecommendationEngine {
  final UserPreferencesService _preferencesService;
  final EventInteractionRepository _interactionRepo;

  Future<List<Event>> rankEventsByMood({
    required List<Event> events,
    required Mood mood,
    required UserLocation userLocation,
  }) async {
    final userPreferences = await _preferencesService.getEventPreferences();
    final interactionHistory = await _interactionRepo.getUserInteractionHistory();

    final scoredEvents = <ScoredEvent>[];

    for (final event in events) {
      final score = await _calculateEventScore(
        event: event,
        mood: mood,
        userLocation: userLocation,
        preferences: userPreferences,
        history: interactionHistory,
      );

      if (score > 0.3) { // Minimum relevance threshold
        scoredEvents.add(ScoredEvent(event: event, score: score));
      }
    }

    // Sort by score descending
    scoredEvents.sort((a, b) => b.score.compareTo(a.score));

    return scoredEvents.map((se) => se.event).toList();
  }

  Future<double> _calculateEventScore({
    required Event event,
    required Mood mood,
    required UserLocation userLocation,
    required EventPreferences preferences,
    required List<EventInteraction> history,
  }) async {
    double totalScore = 0.0;
    double totalWeight = 0.0;

    // 1. Mood-Event Category Mapping (40% weight)
    final moodCategoryScore = _calculateMoodCategoryScore(mood, event.categories);
    totalScore += moodCategoryScore * 0.4;
    totalWeight += 0.4;

    // 2. Personal Preferences (25% weight)
    final preferencesScore = _calculatePreferencesScore(preferences, event);
    totalScore += preferencesScore * 0.25;
    totalWeight += 0.25;

    // 3. Distance from User (15% weight)
    final distanceScore = _calculateDistanceScore(userLocation, event.venue.coordinates);
    totalScore += distanceScore * 0.15;
    totalWeight += 0.15;

    // 4. Time/Date Relevance (10% weight)
    final timeScore = _calculateTimeScore(event, mood);
    totalScore += timeScore * 0.1;
    totalWeight += 0.1;

    // 5. Historical Interactions (10% weight)
    final historyScore = _calculateHistoryScore(history, event);
    totalScore += historyScore * 0.1;
    totalWeight += 0.1;

    return totalWeight > 0 ? totalScore / totalWeight : 0.0;
  }

  double _calculateMoodCategoryScore(Mood mood, List<String> eventCategories) {
    final moodEventMapping = {
      EmotionType.happy: {
        'Comedy': 1.0,
        'Festival': 0.9,
        'Concert': 0.8,
        'Dance': 0.9,
        'Family': 0.7,
        'Social': 0.8,
      },
      EmotionType.excited: {
        'Concert': 1.0,
        'Sports': 0.9,
        'Festival': 0.95,
        'Dance': 1.0,
        'Party': 0.95,
        'Adventure': 0.8,
      },
      EmotionType.calm: {
        'Classical': 1.0,
        'Art': 0.9,
        'Theater': 0.8,
        'Jazz': 0.9,
        'Museum': 0.85,
        'Acoustic': 0.9,
      },
      EmotionType.sad: {
        'Classical': 0.8,
        'Jazz': 0.7,
        'Art': 0.75,
        'Theater': 0.7,
        'Support Group': 0.9,
        'Meditation': 0.8,
      },
      EmotionType.angry: {
        'Rock': 0.9,
        'Metal': 1.0,
        'Sports': 0.8,
        'Fitness': 0.85,
        'Martial Arts': 0.9,
      },
      EmotionType.anxious: {
        'Meditation': 1.0,
        'Yoga': 1.0,
        'Classical': 0.8,
        'Nature': 0.9,
        'Therapy': 0.95,
        'Support Group': 0.9,
      },
    };

    final moodMappings = moodEventMapping[mood.primary] ?? {};
    double maxScore = 0.0;

    for (final category in eventCategories) {
      for (final mappingEntry in moodMappings.entries) {
        if (category.toLowerCase().contains(mappingEntry.key.toLowerCase())) {
          maxScore = math.max(maxScore, mappingEntry.value);
        }
      }
    }

    // Consider secondary mood if present
    if (mood.secondary != null && mood.complexity == MoodComplexity.complex) {
      final secondaryMappings = moodEventMapping[mood.secondary] ?? {};
      double secondaryScore = 0.0;
      
      for (final category in eventCategories) {
        for (final mappingEntry in secondaryMappings.entries) {
          if (category.toLowerCase().contains(mappingEntry.key.toLowerCase())) {
            secondaryScore = math.max(secondaryScore, mappingEntry.value);
          }
        }
      }
      
      // Blend primary and secondary scores
      maxScore = (maxScore * 0.7) + (secondaryScore * 0.3);
    }

    return maxScore;
  }

  double _calculateDistanceScore(UserLocation userLocation, Coordinates? eventLocation) {
    if (eventLocation == null) return 0.5; // Neutral score if no location

    final distance = _calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      eventLocation.latitude,
      eventLocation.longitude,
    );

    // Score decreases with distance
    if (distance <= 5) return 1.0;      // Within 5 miles: perfect
    if (distance <= 10) return 0.9;     // Within 10 miles: excellent
    if (distance <= 25) return 0.7;     // Within 25 miles: good
    if (distance <= 50) return 0.4;     // Within 50 miles: okay
    return 0.1;                         // Beyond 50 miles: poor
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 3959; // Earth radius in miles

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
```

---

## 3. Advanced Features Implementation

### 3.1 Personal Analytics Dashboard

#### 3.1.1 Mood Analytics Engine

```dart
// mood_analytics_engine.dart
class MoodAnalyticsEngine {
  final MoodSessionRepository _sessionRepo;
  final MusicInteractionRepository _musicRepo;
  final EventInteractionRepository _eventRepo;

  Future<PersonalInsights> generatePersonalInsights(
    String userId, {
    AnalyticsTimeframe timeframe = AnalyticsTimeframe.month,
  }) async {
    final dateRange = _getDateRangeForTimeframe(timeframe);
    
    // Parallel data fetching
    final results = await Future.wait([
      _sessionRepo.getSessionsInDateRange(userId, dateRange.start, dateRange.end),
      _musicRepo.getInteractionsInDateRange(userId, dateRange.start, dateRange.end),
      _eventRepo.getInteractionsInDateRange(userId, dateRange.start, dateRange.end),
    ]);

    final sessions = results[0] as List<MoodSession>;
    final musicInteractions = results[1] as List<MusicInteraction>;
    final eventInteractions = results[2] as List<EventInteraction>;

    return PersonalInsights(
      timeframe: timeframe,
      dateRange: dateRange,
      moodPatterns: _analyzeMoodPatterns(sessions),
      musicDiscovery: _analyzeMusicDiscovery(musicInteractions),
      eventEngagement: _analyzeEventEngagement(eventInteractions),
      correlations: await _analyzeCorrelations(sessions, musicInteractions, eventInteractions),
      trends: _analyzeTrends(sessions),
      recommendations: await _generateRecommendations(sessions, musicInteractions),
    );
  }

  MoodPatterns _analyzeMoodPatterns(List<MoodSession> sessions) {
    if (sessions.isEmpty) return MoodPatterns.empty();

    // Emotion distribution
    final emotionCounts = <EmotionType, int>{};
    final emotionConfidences = <EmotionType, List<double>>{};
    
    for (final session in sessions) {
      emotionCounts[session.mood.primary] = 
          (emotionCounts[session.mood.primary] ?? 0) + 1;
      
      emotionConfidences.putIfAbsent(session.mood.primary, () => [])
          .add(session.mood.confidence);
    }

    // Calculate averages and percentages
    final totalSessions = sessions.length;
    final emotionDistribution = emotionCounts.map(
      (emotion, count) => MapEntry(
        emotion, 
        EmotionStats(
          percentage: count / totalSessions,
          averageConfidence: emotionConfidences[emotion]!
              .reduce((a, b) => a + b) / emotionConfidences[emotion]!.length,
          occurrences: count,
        ),
      ),
    );

    // Time-based patterns
    final hourlyDistribution = _analyzeHourlyPatterns(sessions);
    final dailyDistribution = _analyzeDailyPatterns(sessions);
    final weeklyTrends = _analyzeWeeklyTrends(sessions);

    // Mood stability analysis
    final stability = _calculateMoodStability(sessions);

    return MoodPatterns(
      emotionDistribution: emotionDistribution,
      dominantEmotion: emotionCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key,
      hourlyPatterns: hourlyDistribution,
      dailyPatterns: dailyDistribution,
      weeklyTrends: weeklyTrends,
      stability: stability,
      complexEmotionRate: sessions
          .where((s) => s.mood.complexity == MoodComplexity.complex)
          .length / totalSessions,
    );
  }

  Map<int, EmotionType> _analyzeHourlyPatterns(List<MoodSession> sessions) {
    final hourlyEmotions = <int, Map<EmotionType, int>>{};
    
    for (final session in sessions) {
      final hour = session.detectedAt.hour;
      hourlyEmotions.putIfAbsent(hour, () => {});
      hourlyEmotions[hour]![session.mood.primary] = 
          (hourlyEmotions[hour]![session.mood.primary] ?? 0) + 1;
    }

    // Find dominant emotion for each hour
    return hourlyEmotions.map((hour, emotions) {
      final dominantEmotion = emotions.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      return MapEntry(hour, dominantEmotion);
    });
  }

  MoodStability _calculateMoodStability(List<MoodSession> sessions) {
    if (sessions.length < 3) return MoodStability.insufficient();

    // Sort sessions by time
    sessions.sort((a, b) => a.detectedAt.compareTo(b.detectedAt));

    double totalVariation = 0.0;
    int transitionCount = 0;

    for (int i = 1; i < sessions.length; i++) {
      final prev = sessions[i - 1];
      final current = sessions[i];

      // Calculate emotional distance
      final distance = _calculateEmotionalDistance(prev.mood, current.mood);
      totalVariation += distance;

      if (prev.mood.primary != current.mood.primary) {
        transitionCount++;
      }
    }

    final averageVariation = totalVariation / (sessions.length - 1);
    final transitionRate = transitionCount / (sessions.length - 1);

    StabilityLevel level;
    if (averageVariation < 0.3 && transitionRate < 0.4) {
      level = StabilityLevel.veryStable;
    } else if (averageVariation < 0.5 && transitionRate < 0.6) {
      level = StabilityLevel.stable;
    } else if (averageVariation < 0.7 && transitionRate < 0.8) {
      level = StabilityLevel.moderate;
    } else {
      level = StabilityLevel.variable;
    }

    return MoodStability(
      level: level,
      averageVariation: averageVariation,
      transitionRate: transitionRate,
      stabilityScore: 1.0 - ((averageVariation + transitionRate) / 2),
    );
  }

  double _calculateEmotionalDistance(Mood mood1, Mood mood2) {
    // Define emotional coordinates in 2D space
    final emotionCoordinates = {
      EmotionType.happy: (0.8, 0.8),      // High valence, high arousal
      EmotionType.excited: (0.9, 0.9),    // Very high valence, very high arousal
      EmotionType.calm: (0.6, 0.2),       // Moderate valence, low arousal
      EmotionType.sad: (0.2, 0.3),        // Low valence, low-moderate arousal
      EmotionType.angry: (0.1, 0.9),      // Very low valence, very high arousal
      EmotionType.anxious: (0.3, 0.8),    // Low valence, high arousal
    };

    final coord1 = emotionCoordinates[mood1.primary] ?? (0.5, 0.5);
    final coord2 = emotionCoordinates[mood2.primary] ?? (0.5, 0.5);

    final dx = coord1.$1 - coord2.$1;
    final dy = coord1.$2 - coord2.$2;

    return math.sqrt(dx * dx + dy * dy);
  }

  Future<List<PersonalRecommendation>> _generateRecommendations(
    List<MoodSession> sessions,
    List<MusicInteraction> musicInteractions,
  ) async {
    final recommendations = <PersonalRecommendation>[];

    // Analyze patterns to generate insights
    final patterns = _analyzeMoodPatterns(sessions);

    // Recommendation 1: Peak happiness times
    if (patterns.hourlyPatterns.isNotEmpty) {
      final happyHours = patterns.hourlyPatterns.entries
          .where((entry) => entry.value == EmotionType.happy)
          .map((entry) => entry.key)
          .toList();

      if (happyHours.isNotEmpty) {
        recommendations.add(PersonalRecommendation(
          type: RecommendationType.optimalTiming,
          title: 'Your Happiness Peak Hours',
          description: 'You tend to be happiest around ${_formatHours(happyHours)}. '
              'Consider scheduling important activities during these times.',
          actionable: true,
          confidence: 0.8,
        ));
      }
    }

    // Recommendation 2: Music mood improvement
    final musicMoodCorrelation = await _analyzeMusicMoodCorrelation(
      sessions, 
      musicInteractions,
    );
    
    if (musicMoodCorrelation.hasPositiveEffect) {
      recommendations.add(PersonalRecommendation(
        type: RecommendationType.musicTherapy,
        title: 'Music Boosts Your Mood',
        description: 'Listening to ${musicMoodCorrelation.topGenres.join(", ")} '
            'tends to improve your mood by ${(musicMoodCorrelation.averageImprovement * 100).round()}%.',
        actionable: true,
        confidence: musicMoodCorrelation.confidence,
      ));
    }

    // Recommendation 3: Mood stability improvement
    if (patterns.stability.level == StabilityLevel.variable) {
      recommendations.add(PersonalRecommendation(
        type: RecommendationType.stability,
        title: 'Consider Mood Regulation',
        description: 'Your mood tends to vary frequently. Regular exercise, '
            'meditation, or consistent sleep patterns might help.',
        actionable: true,
        confidence: 0.7,
      ));
    }

    return recommendations;
  }
}

// Data models for analytics
class PersonalInsights {
  final AnalyticsTimeframe timeframe;
  final DateRange dateRange;
  final MoodPatterns moodPatterns;
  final MusicDiscoveryStats musicDiscovery;
  final EventEngagementStats eventEngagement;
  final List<MoodCorrelation> correlations;
  final List<MoodTrend> trends;
  final List<PersonalRecommendation> recommendations;

  PersonalInsights({
    required this.timeframe,
    required this.dateRange,
    required this.moodPatterns,
    required this.musicDiscovery,
    required this.eventEngagement,
    required this.correlations,
    required this.trends,
    required this.recommendations,
  });
}

class MoodPatterns {
  final Map<EmotionType, EmotionStats> emotionDistribution;
  final EmotionType dominantEmotion;
  final Map<int, EmotionType> hourlyPatterns;
  final Map<int, EmotionType> dailyPatterns; // 0 = Sunday
  final List<WeeklyTrend> weeklyTrends;
  final MoodStability stability;
  final double complexEmotionRate;

  MoodPatterns({
    required this.emotionDistribution,
    required this.dominantEmotion,
    required this.hourlyPatterns,
    required this.dailyPatterns,
    required this.weeklyTrends,
    required this.stability,
    required this.complexEmotionRate,
  });

  static MoodPatterns empty() => MoodPatterns(
    emotionDistribution: {},
    dominantEmotion: EmotionType.neutral,
    hourlyPatterns: {},
    dailyPatterns: {},
    weeklyTrends: [],
    stability: MoodStability.insufficient(),
    complexEmotionRate: 0.0,
  );
}
```

### 3.2 Advanced UI Components

#### 3.2.1 Interactive Mood Analytics Charts

```dart
// mood_analytics_chart.dart
class MoodAnalyticsChart extends StatefulWidget {
  final PersonalInsights insights;
  final ChartType chartType;
  final VoidCallback? onChartTypeChanged;

  const MoodAnalyticsChart({
    super.key,
    required this.insights,
    required this.chartType,
    this.onChartTypeChanged,
  });

  @override
  State<MoodAnalyticsChart> createState() => _MoodAnalyticsChartState();
}

class _MoodAnalyticsChartState extends State<MoodAnalyticsChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartHeader(),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return _buildChart();
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _getChartTitle(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        DropdownButton<ChartType>(
          value: widget.chartType,
          items: ChartType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.displayName),
            );
          }).toList(),
          onChanged: (newType) {
            if (newType != null) {
              widget.onChartTypeChanged?.call();
            }
          },
        ),
      ],
    );
  }

  Widget _buildChart() {
    switch (widget.chartType) {
      case ChartType.emotionDistribution:
        return _buildEmotionDistributionChart();
      case ChartType.timePattern:
        return _buildTimePatternChart();
      case ChartType.moodTrends:
        return _buildMoodTrendsChart();
      case ChartType.stability:
        return _buildStabilityChart();
    }
  }

  Widget _buildEmotionDistributionChart() {
    final data = widget.insights.moodPatterns.emotionDistribution;
    
    return PieChart(
      PieChartData(
        sections: data.entries.map((entry) {
          final emotion = entry.key;
          final stats = entry.value;
          
          return PieChartSectionData(
            value: stats.percentage * 100,
            title: '${(stats.percentage * 100).round()}%',
            color: AppTheme.moodColor(emotion).withOpacity(_animation.value),
            radius: 80 + (20 * _animation.value),
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: -90,
      ),
    );
  }

  Widget _buildTimePatternChart() {
    final hourlyData = widget.insights.moodPatterns.hourlyPatterns;
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final emotions = EmotionType.values;
                if (value.toInt() < emotions.length) {
                  return Text(
                    emotions[value.toInt()].displayName,
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
              reservedSize: 60,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}:00',
                  style: const TextStyle(fontSize: 10),
                );
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: hourlyData.entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                EmotionType.values.indexOf(entry.value).toDouble(),
              );
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                AppTheme.primaryColor,
              ],
            ),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1 * _animation.value),
                  AppTheme.primaryColor.withOpacity(0.05 * _animation.value),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTrendsChart() {
    final trends = widget.insights.trends;
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < trends.length) {
                  final trend = trends[value.toInt()];
                  return Text(
                    DateFormat('MM/dd').format(trend.date),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: trends.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.averageMoodScore,
              );
            }).toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2 * _animation.value),
                  AppTheme.primaryColor.withOpacity(0.1 * _animation.value),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityChart() {
    final stability = widget.insights.moodPatterns.stability;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Stability Score Circle
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: stability.stabilityScore * _animation.value,
                strokeWidth: 12,
                backgroundColor: Colors.grey.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStabilityColor(stability.level),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(stability.stabilityScore * 100).round()}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getStabilityColor(stability.level),
                    ),
                  ),
                  Text(
                    stability.level.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Stability Metrics
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStabilityMetric(
              'Variation',
              '${(stability.averageVariation * 100).round()}%',
              Icons.trending_up,
            ),
            _buildStabilityMetric(
              'Transitions',
              '${(stability.transitionRate * 100).round()}%',
              Icons.swap_horiz,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStabilityMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: AppTheme.primaryColor.withOpacity(_animation.value),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _getStabilityColor(StabilityLevel level) {
    switch (level) {
      case StabilityLevel.veryStable:
        return Colors.green;
      case StabilityLevel.stable:
        return Colors.lightGreen;
      case StabilityLevel.moderate:
        return Colors.orange;
      case StabilityLevel.variable:
        return Colors.red;
      case StabilityLevel.insufficient:
        return Colors.grey;
    }
  }

  Widget _buildChartLegend() {
    switch (widget.chartType) {
      case ChartType.emotionDistribution:
        return _buildEmotionLegend();
      case ChartType.timePattern:
        return _buildTimePatternLegend();
      case ChartType.moodTrends:
        return _buildTrendsLegend();
      case ChartType.stability:
        return _buildStabilityLegend();
    }
  }

  Widget _buildEmotionLegend() {
    final data = widget.insights.moodPatterns.emotionDistribution;
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: data.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.moodColor(entry.key),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.key.displayName} (${entry.value.occurrences})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }

  String _getChartTitle() {
    switch (widget.chartType) {
      case ChartType.emotionDistribution:
        return 'Emotion Distribution';
      case ChartType.timePattern:
        return 'Daily Mood Patterns';
      case ChartType.moodTrends:
        return 'Mood Trends Over Time';
      case ChartType.stability:
        return 'Mood Stability Analysis';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
```

---

## 4. Production Deployment Architecture

### 4.1 CI/CD Pipeline Configuration

```yaml
# .github/workflows/ci-cd.yml
name: MoodMusic CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  FLUTTER_VERSION: '3.16.0'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .
        
      - name: Analyze project source
        run: flutter analyze --fatal-infos
        
      - name: Run tests
        run: flutter test --coverage
        
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          
      - name: Setup Android signing
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE }}" | base64 -d > android/app/keystore.jks
          echo "storeFile=keystore.jks" >> android/key.properties
          echo "keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}" >> android/key.properties
          echo "storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}" >> android/key.properties
          echo "keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}" >> android/key.properties
          
      - name: Build Android APK
        run: flutter build apk --release
        
      - name: Build Android AAB
        run: flutter build appbundle --release
        
      - name: Upload APK to Firebase App Distribution
        uses: wzieba/Firebase-Distribution-Github-Action@v1
        with:
          appId: ${{ secrets.FIREBASE_ANDROID_APP_ID }}
          token: ${{ secrets.FIREBASE_TOKEN }}
          groups: internal-testers
          file: build/app/outputs/flutter-apk/app-release.apk
          
      - name: Deploy to Google Play Internal Testing
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.moodmusic.app
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal

  build-ios:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          
      - name: Setup iOS signing
        run: |
          echo "${{ secrets.IOS_CERTIFICATE }}" | base64 -d > ios_certificate.p12
          echo "${{ secrets.IOS_PROVISIONING_PROFILE }}" | base64 -d > ios_profile.mobileprovision
          
          # Create keychain and add certificate
          security create-keychain -p "" build.keychain
          security import ios_certificate.p12 -t agg -k build.keychain -P "${{ secrets.IOS_CERTIFICATE_PASSWORD }}" -A
          security list-keychains -s build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "" build.keychain
          
          # Install provisioning profile
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp ios_profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
          
      - name: Build iOS IPA
        run: |
          flutter build ios --release --no-codesign
          cd ios
          xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/Runner.xcarchive archive
          xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build -exportOptionsPlist ExportOptions.plist
          
      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: ios/build/Runner.ipa
          issuer-id: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          api-key-id: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          api-private-key: ${{ secrets.APP_STORE_CONNECT_API_PRIVATE_KEY }}

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run security scan
        uses: securecodewarrior/github-action-add-sarif@v1
        with:
          sarif-file: 'security-scan-results.sarif'
          
      - name: Dependency vulnerability scan
        run: |
          flutter pub deps
          # Add dependency scanning tool here

  performance-test:
    needs: [build-android, build-ios]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run performance tests
        run: |
          # Add performance testing commands
          echo "Performance tests would run here"
          
      - name: Upload performance results
        uses: actions/upload-artifact@v3
        with:
          name: performance-results
          path: performance-results/
```

### 4.2 Infrastructure as Code (Terraform)

```hcl
# infrastructure/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# AWS Provider for Rekognition and other services
provider "aws" {
  region = var.aws_region
}

# Google Cloud Provider for Firebase
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# AWS Rekognition IAM Role
resource "aws_iam_role" "rekognition_role" {
  name = "moodmusic-rekognition-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rekognition.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "rekognition_policy" {
  name = "moodmusic-rekognition-policy"
  role = aws_iam_role.rekognition_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectFaces",
          "rekognition:IndexFaces",
          "rekognition:SearchFaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch for monitoring
resource "aws_cloudwatch_log_group" "moodmusic_logs" {
  name              = "/aws/lambda/moodmusic"
  retention_in_days = 30
}

# S3 bucket for temporary image storage
resource "aws_s3_bucket" "temp_images" {
  bucket = "moodmusic-temp-images-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_lifecycle_configuration" "temp_images_lifecycle" {
  bucket = aws_s3_bucket.temp_images.id

  rule {
    id     = "delete_temp_images"
    status = "Enabled"

    expiration {
      days = 1  # Delete images after 1 day
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Firebase project configuration
resource "google_firebase_project" "moodmusic" {
  provider = google-beta
  project  = var.gcp_project_id
}

resource "google_firestore_database" "moodmusic_db" {
  project     = var.gcp_project_id
  name        = "(default)"
  location_id = var.firestore_region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_firebase_project.moodmusic]
}

# Firestore security rules
resource "google_firestore_document" "security_rules" {
  project     = var.gcp_project_id
  collection  = "security_rules"
  document_id = "firestore_rules"
  fields = jsonencode({
    rules = {
      stringValue = file("${path.module}/firestore.rules")
    }
  })

  depends_on = [google_firestore_database.moodmusic_db]
}

# Cloud Functions for backend processing
resource "google_cloudfunctions_function" "mood_processing" {
  name        = "mood-processing"
  description = "Process mood analysis results"
  runtime     = "python39"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_source.name
  trigger {
    event_type = "google.firestore.document.write"
    resource   = "projects/${var.gcp_project_id}/databases/(default)/documents/mood_sessions/{sessionId}"
  }

  entry_point = "process_mood_data"

  environment_variables = {
    SPOTIFY_CLIENT_ID     = var.spotify_client_id
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
    AWS_REGION           = var.aws_region
  }
}

resource "google_storage_bucket" "function_source" {
  name     = "moodmusic-functions-${random_id.bucket_suffix.hex}"
  location = var.gcp_region
}

resource "google_storage_bucket_object" "function_source" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_source.name
  source = "${path.module}/functions/mood-processing.zip"
}

# Monitoring and alerting
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "High Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "Error rate too high"

    condition_threshold {
      filter         = "resource.type=\"cloud_function\" AND resource.labels.function_name=\"mood-processing\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 0.1

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "firestore_region" {
  description = "Firestore region"
  type        = string
  default     = "us-central"
}

variable "spotify_client_id" {
  description = "Spotify client ID"
  type        = string
  sensitive   = true
}

variable "spotify_client_secret" {
  description = "Spotify client secret"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
}

# Outputs
output "aws_rekognition_role_arn" {
  description = "ARN of the Rekognition IAM role"
  value       = aws_iam_role.rekognition_role.arn
}

output "s3_temp_bucket" {
  description = "S3 bucket for temporary images"
  value       = aws_s3_bucket.temp_images.bucket
}

output "firestore_database" {
  description = "Firestore database name"
  value       = google_firestore_database.moodmusic_db.name
}
```

### 4.3 Monitoring & Observability

```dart
// monitoring_service.dart
class MonitoringService {
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  final Logger _logger;

  static const Map<String, String> _eventNames = {
    'mood_scan_completed': 'mood_scan_completed',
    'music_recommendation_generated': 'music_recommendation_generated',
    'subscription_purchased': 'subscription_purchased',
    'event_viewed': 'event_viewed',
    'app_error': 'app_error',
  };

  Future<void> trackMoodScanCompleted({
    required String moodType,
    required double confidence,
    required String detectionMethod,
    required Duration processingTime,
  }) async {
    await _analytics.logEvent(
      name: _eventNames['mood_scan_completed']!,
      parameters: {
        'mood_type': moodType,
        'confidence': confidence,
        'detection_method': detectionMethod,
        'processing_time_ms': processingTime.inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Custom business metrics
    await _analytics.logEvent(
      name: 'custom_mood_scan',
      parameters: {
        'mood_primary': moodType,
        'confidence_bucket': _getConfidenceBucket(confidence),
        'method': detectionMethod,
        'performance_bucket': _getPerformanceBucket(processingTime),
      },
    );
  }

  Future<void> trackMusicRecommendation({
    required String moodType,
    required List<String> recommendedTracks,
    required String strategy,
    required Duration generationTime,
  }) async {
    await _analytics.logEvent(
      name: _eventNames['music_recommendation_generated']!,
      parameters: {
        'mood_type': moodType,
        'track_count': recommendedTracks.length,
        'strategy': strategy,
        'generation_time_ms': generationTime.inMilliseconds,
        'first_track_id': recommendedTracks.isNotEmpty ? recommendedTracks.first : '',
      },
    );
  }

  Future<void> trackUserInteraction({
    required String interactionType,
    required String itemType,
    required String itemId,
    Map<String, dynamic>? context,
  }) async {
    await _analytics.logEvent(
      name: 'user_interaction',
      parameters: {
        'interaction_type': interactionType, // tap, swipe, long_press, etc.
        'item_type': itemType, // song, event, button, etc.
        'item_id': itemId,
        'screen': context?['screen'] ?? 'unknown',
        'mood_context': context?['mood'] ?? 'none',
        ...?context,
      },
    );
  }

  Future<void> trackSubscriptionEvent({
    required String eventType, // purchase, cancel, restore, expire
    required String productId,
    String? revenue,
    String? currency,
  }) async {
    await _analytics.logEvent(
      name: _eventNames['subscription_purchased']!,
      parameters: {
        'event_type': eventType,
        'product_id': productId,
        'revenue': revenue,
        'currency': currency ?? 'USD',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (eventType == 'purchase' && revenue != null) {
      await _analytics.logEvent(
        name: 'purchase',
        parameters: {
          'currency': currency ?? 'USD',
          'value': double.tryParse(revenue) ?? 0.0,
          'items': [
            {
              'item_id': productId,
              'item_name': _getProductName(productId),
              'item_category': 'subscription',
              'quantity': 1,
              'price': double.tryParse(revenue) ?? 0.0,
            }
          ],
        },
      );
    }
  }

  Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    // Log to Crashlytics for detailed error tracking
    await _crashlytics.recordError(
      errorMessage,
      stackTrace != null ? StackTrace.fromString(stackTrace) : null,
      fatal: false,
      information: [
        'Error Type: $errorType',
        'Context: ${context?.toString() ?? 'None'}',
      ],
    );

    // Log to Analytics for business intelligence
    await _analytics.logEvent(
      name: _eventNames['app_error']!,
      parameters: {
        'error_type': errorType,
        'error_category': _categorizeError(errorType),
        'screen': context?['screen'] ?? 'unknown',
        'user_action': context?['user_action'] ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> trackPerformanceMetric({
    required String metricName,
    required double value,
    String? unit,
    Map<String, dynamic>? attributes,
  }) async {
    // Custom performance tracking
    await _analytics.logEvent(
      name: 'performance_metric',
      parameters: {
        'metric_name': metricName,
        'value': value,
        'unit': unit ?? 'ms',
        'timestamp': DateTime.now().toIso8601String(),
        ...?attributes,
      },
    );

    // Log performance issues
    if (_isPerformanceIssue(metricName, value)) {
      await trackError(
        errorType: 'performance_issue',
        errorMessage: '$metricName took ${value}${unit ?? 'ms'} - exceeds threshold',
        context: {
          'metric_name': metricName,
          'value': value,
          'threshold': _getPerformanceThreshold(metricName),
          ...?attributes,
        },
      );
    }
  }

  String _getConfidenceBucket(double confidence) {
    if (confidence >= 0.8) return 'high';
    if (confidence >= 0.6) return 'medium';
    if (confidence >= 0.4) return 'low';
    return 'very_low';
  }

  String _getPerformanceBucket(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 1000) return 'fast';      // Under 1 second
    if (ms <= 3000) return 'normal';    // 1-3 seconds
    if (ms <= 5000) return 'slow';      // 3-5 seconds
    return 'very_slow';                 // Over 5 seconds
  }

  String _categorizeError(String errorType) {
    if (errorType.contains('network') || errorType.contains('api')) {
      return 'network';
    } else if (errorType.contains('auth') || errorType.contains('permission')) {
      return 'authentication';
    } else if (errorType.contains('camera') || errorType.contains('emotion')) {
      return 'core_feature';
    } else if (errorType.contains('payment') || errorType.contains('subscription')) {
      return 'monetization';
    } else {
      return 'general';
    }
  }

  String _getProductName(String productId) {
    const productNames = {
      'moodmusic_pro_monthly': 'MoodMusic Pro Monthly',
      'moodmusic_pro_yearly': 'MoodMusic Pro Yearly',
      'moodmusic_family': 'MoodMusic Family',
    };
    return productNames[productId] ?? 'Unknown Product';
  }

  bool _isPerformanceIssue(String metricName, double value) {
    final thresholds = {
      'app_launch_time': 3000.0,      // 3 seconds
      'emotion_detection_time': 5000.0, // 5 seconds
      'music_recommendation_time': 3000.0, // 3 seconds
      'api_response_time': 10000.0,   // 10 seconds
      'memory_usage_mb': 200.0,       // 200 MB
    };

    final threshold = thresholds[metricName];
    return threshold != null && value > threshold;
  }

  double _getPerformanceThreshold(String metricName) {
    const thresholds = {
      'app_launch_time': 3000.0,
      'emotion_detection_time': 5000.0,
      'music_recommendation_time': 3000.0,
      'api_response_time': 10000.0,
      'memory_usage_mb': 200.0,
    };
    return thresholds[metricName] ?? 0.0;
  }

  // Health check monitoring
  Future<void> performHealthCheck() async {
    final healthMetrics = <String, dynamic>{};

    try {
      // Test critical services
      final stopwatch = Stopwatch()..start();
      
      // Test Spotify API connectivity
      await _testSpotifyConnectivity();
      healthMetrics['spotify_connection'] = 'healthy';
      
      // Test AWS Rekognition connectivity
      await _testAWSConnectivity();
      healthMetrics['aws_connection'] = 'healthy';
      
      // Test Firebase connectivity
      await _testFirebaseConnectivity();
      healthMetrics['firebase_connection'] = 'healthy';
      
      // Test local database
      await _testLocalDatabase();
      healthMetrics['local_db'] = 'healthy';
      
      stopwatch.stop();
      healthMetrics['total_check_time_ms'] = stopwatch.elapsedMilliseconds;
      
      await _analytics.logEvent(
        name: 'health_check',
        parameters: {
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          ...healthMetrics,
        },
      );
      
    } catch (e) {
      await trackError(
        errorType: 'health_check_failed',
        errorMessage: e.toString(),
        context: healthMetrics,
      );
    }
  }

  Future<void> _testSpotifyConnectivity() async {
    // Implementation would test basic Spotify API connectivity
  }

  Future<void> _testAWSConnectivity() async {
    // Implementation would test AWS service connectivity
  }

  Future<void> _testFirebaseConnectivity() async {
    // Implementation would test Firebase connectivity
  }

  Future<void> _testLocalDatabase() async {
    // Implementation would test local database connectivity
  }
}
```

---

## Conclusion

This comprehensive technical design document provides detailed implementation specifications for completing the MoodMusic Flutter application. The architecture emphasizes:

1. **Scalable Design**: Modular architecture that can handle growth
2. **Security First**: End-to-end encryption and privacy protection
3. **Performance Optimization**: Sub-3-second response times across features
4. **Offline Capability**: Core features work without internet
5. **Enterprise Monitoring**: Comprehensive observability and error tracking
6. **CI/CD Automation**: Automated testing, building, and deployment

### Key Implementation Priorities:
1. **Complete Spotify Integration** with intelligent recommendation engine
2. **Production-grade Emotion Detection** with AWS and offline fallback
3. **Robust Subscription System** with RevenueCat integration
4. **Local Event Discovery** through multiple API integrations
5. **Advanced Analytics Dashboard** with personalized insights
6. **Comprehensive Testing** achieving 90%+ code coverage
7. **Security Hardening** for production deployment

The technical specifications provide sufficient detail for a development team to implement all remaining features while maintaining code quality, security, and performance standards required for a production mobile application.

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-23  
**Next Review**: 2025-02-06  
**Owner**: Technical Lead  
**Status**: Ready for Implementation