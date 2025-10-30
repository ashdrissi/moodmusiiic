# MoodMusic - API Integration Guide

## 1. Integration Overview

This guide provides comprehensive implementation details for all third-party API integrations required for the MoodMusic Flutter app, including authentication flows, error handling, rate limiting, and data transformation.

### 1.1 API Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                      │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Service       │   Repository    │   Provider              │
│   Layer         │   Layer         │   Layer                 │
└─────────────────┴─────────────────┴─────────────────────────┘
         │                │                │
┌─────────────────┬─────────────────┬─────────────────────────┐
│   HTTP Client   │   Cache Layer   │   Error Handler         │
│   (Dio)         │                 │                         │
└─────────────────┴─────────────────┴─────────────────────────┘
         │
┌─────────────────────────────────────────────────────────────┐
│                 External APIs                               │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│ Spotify     │ AWS         │ Ticketmaster│ Firebase            │
│ Web API     │ Rekognition │ /Eventbrite │                     │
└─────────────┴─────────────┴─────────────┴─────────────────────┘
```

### 1.2 Common Implementation Patterns

#### Base API Client
```dart
abstract class BaseApiClient {
  final Dio _dio;
  final String baseUrl;
  final Duration timeout;
  
  BaseApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
  }) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: timeout,
    receiveTimeout: timeout,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'MoodMusic/1.0',
    },
  )) {
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));
  }
  
  Future<Response<T>> _onRequest<T>(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add authentication headers
    await _addAuthHeaders(options);
    
    // Add rate limiting
    await _checkRateLimit(options);
    
    handler.next(options);
  }
  
  Future<void> _addAuthHeaders(RequestOptions options);
  Future<void> _checkRateLimit(RequestOptions options);
  
  DioException _onError(DioException error, ErrorInterceptorHandler handler) {
    // Transform errors into app-specific exceptions
    final transformedError = _transformError(error);
    handler.next(transformedError);
    return transformedError;
  }
  
  DioException _transformError(DioException error);
}
```

---

## 2. Spotify Web API Integration

### 2.1 Authentication Implementation

#### OAuth 2.0 Authorization Code Flow
```dart
class SpotifyAuthService {
  static const String _authUrl = 'https://accounts.spotify.com/authorize';
  static const String _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String _clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const String _redirectUri = 'com.moodmusic.app://callback/spotify';
  
  static const List<String> _requiredScopes = [
    'user-read-private',
    'user-read-email', 
    'user-top-read',
    'user-read-playback-state',
    'app-remote-control',
    'streaming',
    'playlist-modify-public',
    'playlist-modify-private',
  ];
  
  final Dio _dio = Dio();
  final SecureStorageService _secureStorage;
  
  SpotifyAuthService(this._secureStorage);
  
  /// Initiate OAuth flow
  Future<bool> authenticate() async {
    try {
      final state = _generateSecureState();
      final codeChallenge = _generateCodeChallenge();
      
      await _secureStorage.storeSecurely('spotify_state', state);
      await _secureStorage.storeSecurely('spotify_code_verifier', codeChallenge.verifier);
      
      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _requiredScopes.join(' '),
        'state': state,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge.challenge,
      });
      
      // Launch browser for user authorization
      final result = await _launchWebAuth(authUrl.toString());
      
      if (result.isSuccess) {
        return await _exchangeCodeForTokens(result.code!, result.state!);
      }
      
      return false;
    } catch (e) {
      debugPrint('Spotify authentication error: $e');
      return false;
    }
  }
  
  /// Exchange authorization code for access tokens
  Future<bool> _exchangeCodeForTokens(String code, String state) async {
    try {
      // Verify state parameter
      final storedState = await _secureStorage.getSecurely('spotify_state');
      if (storedState != state) {
        throw SecurityException('Invalid state parameter');
      }
      
      final codeVerifier = await _secureStorage.getSecurely('spotify_code_verifier');
      
      final response = await _dio.post(
        _tokenUrl,
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'client_id': _clientId,
          'code_verifier': codeVerifier,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
      
      final tokenData = response.data as Map<String, dynamic>;
      
      await _storeTokens(
        accessToken: tokenData['access_token'],
        refreshToken: tokenData['refresh_token'],
        expiresIn: tokenData['expires_in'],
      );
      
      return true;
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }
  
  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.getSecurely('spotify_refresh_token');
      if (refreshToken == null) return false;
      
      final response = await _dio.post(
        _tokenUrl,
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _clientId,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
      
      final tokenData = response.data as Map<String, dynamic>;
      
      await _storeTokens(
        accessToken: tokenData['access_token'],
        refreshToken: tokenData['refresh_token'] ?? refreshToken,
        expiresIn: tokenData['expires_in'],
      );
      
      return true;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
  
  String _generateSecureState() {
    final bytes = List<int>.generate(32, (i) => Random.secure().nextInt(256));
    return base64Url.encode(bytes);
  }
  
  CodeChallenge _generateCodeChallenge() {
    final bytes = List<int>.generate(32, (i) => Random.secure().nextInt(256));
    final verifier = base64Url.encode(bytes).replaceAll('=', '');
    final challenge = base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    
    return CodeChallenge(verifier: verifier, challenge: challenge);
  }
}
```

### 2.2 Spotify Web API Client
```dart
class SpotifyWebApiClient extends BaseApiClient {
  static const String _baseUrl = 'https://api.spotify.com/v1';
  
  final SpotifyAuthService _authService;
  final RateLimiter _rateLimiter;
  
  SpotifyWebApiClient(this._authService) 
      : _rateLimiter = RateLimiter(requestsPerSecond: 10),
        super(baseUrl: _baseUrl);
  
  @override
  Future<void> _addAuthHeaders(RequestOptions options) async {
    final accessToken = await _authService.getValidAccessToken();
    options.headers['Authorization'] = 'Bearer $accessToken';
  }
  
  @override
  Future<void> _checkRateLimit(RequestOptions options) async {
    await _rateLimiter.acquire();
  }
  
  /// Get current user's profile
  Future<SpotifyUser> getCurrentUser() async {
    final response = await _dio.get('/me');
    return SpotifyUser.fromJson(response.data);
  }
  
  /// Get user's top tracks
  Future<List<SpotifyTrack>> getUserTopTracks({
    String timeRange = 'medium_term',
    int limit = 50,
  }) async {
    final response = await _dio.get('/me/top/tracks', queryParameters: {
      'time_range': timeRange,
      'limit': limit,
    });
    
    final items = response.data['items'] as List;
    return items.map((item) => SpotifyTrack.fromJson(item)).toList();
  }
  
  /// Get music recommendations
  Future<List<SpotifyTrack>> getRecommendations({
    required List<String> seedGenres,
    required Map<String, double> audioFeatures,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'seed_genres': seedGenres.join(','),
      'limit': limit,
    };
    
    // Add audio feature parameters
    audioFeatures.forEach((key, value) {
      queryParams['target_$key'] = value;
    });
    
    final response = await _dio.get('/recommendations', queryParameters: queryParams);
    
    final tracks = response.data['tracks'] as List;
    return tracks.map((track) => SpotifyTrack.fromJson(track)).toList();
  }
  
  /// Create playlist
  Future<SpotifyPlaylist> createPlaylist({
    required String name,
    required String description,
    bool public = false,
  }) async {
    final user = await getCurrentUser();
    
    final response = await _dio.post('/users/${user.id}/playlists', data: {
      'name': name,
      'description': description,
      'public': public,
    });
    
    return SpotifyPlaylist.fromJson(response.data);
  }
  
  /// Add tracks to playlist
  Future<void> addTracksToPlaylist(String playlistId, List<String> trackUris) async {
    const batchSize = 100; // Spotify's maximum
    
    for (int i = 0; i < trackUris.length; i += batchSize) {
      final batch = trackUris.skip(i).take(batchSize).toList();
      
      await _dio.post('/playlists/$playlistId/tracks', data: {
        'uris': batch,
      });
    }
  }
  
  @override
  DioException _transformError(DioException error) {
    switch (error.response?.statusCode) {
      case 401:
        return DioException(
          requestOptions: error.requestOptions,
          type: DioExceptionType.badResponse,
          error: SpotifyAuthException('Access token expired or invalid'),
        );
      case 403:
        return DioException(
          requestOptions: error.requestOptions,
          type: DioExceptionType.badResponse,
          error: SpotifyPermissionException('Insufficient permissions'),
        );
      case 429:
        final retryAfter = error.response?.headers['retry-after']?.first;
        return DioException(
          requestOptions: error.requestOptions,
          type: DioExceptionType.badResponse,
          error: SpotifyRateLimitException('Rate limit exceeded', retryAfter: retryAfter),
        );
      default:
        return error;
    }
  }
}
```

### 2.3 Spotify Service Integration
```dart
class SpotifyService {
  final SpotifyWebApiClient _apiClient;
  final CacheService _cacheService;
  final DatabaseService _databaseService;
  
  SpotifyService(this._apiClient, this._cacheService, this._databaseService);
  
  /// Get mood-based recommendations
  Future<List<Song>> getRecommendationsForMood(
    Mood mood,
    UserProfile userProfile,
  ) async {
    try {
      // Get user's listening patterns
      final listeningPatterns = await _getUserListeningPatterns(userProfile);
      
      // Generate audio features based on mood
      final audioFeatures = _getMoodAudioFeatures(mood);
      
      // Combine with user preferences
      final targetFeatures = _combineFeatures(audioFeatures, listeningPatterns);
      
      // Get seed genres for the mood
      final seedGenres = _getMoodGenres(mood, listeningPatterns);
      
      // Get recommendations from Spotify
      final spotifyTracks = await _apiClient.getRecommendations(
        seedGenres: seedGenres,
        audioFeatures: targetFeatures,
        limit: 20,
      );
      
      // Transform to app Song models
      final songs = spotifyTracks.map(_transformToSong).toList();
      
      // Cache recommendations
      await _cacheService.cacheRecommendations(mood, songs);
      
      // Store in database for analytics
      await _databaseService.storeMusicRecommendations(songs, mood, userProfile.id);
      
      return songs;
    } catch (e) {
      debugPrint('Error getting Spotify recommendations: $e');
      
      // Return cached recommendations as fallback
      return await _cacheService.getCachedRecommendations(mood) ?? [];
    }
  }
  
  Map<String, double> _getMoodAudioFeatures(Mood mood) {
    switch (mood) {
      case Mood.happy:
        return {
          'valence': 0.8,        // High positivity
          'energy': 0.7,         // High energy
          'danceability': 0.7,   // Danceable
          'tempo': 120.0,        // Upbeat tempo
        };
      case Mood.sad:
        return {
          'valence': 0.2,        // Low positivity
          'energy': 0.3,         // Low energy
          'acousticness': 0.7,   // Acoustic preference
          'tempo': 80.0,         // Slower tempo
        };
      case Mood.calm:
        return {
          'valence': 0.5,        // Neutral positivity
          'energy': 0.3,         // Low energy
          'instrumentalness': 0.6, // Instrumental preference
          'tempo': 90.0,         // Relaxed tempo
        };
      case Mood.excited:
        return {
          'valence': 0.9,        // Very high positivity
          'energy': 0.9,         // Very high energy  
          'danceability': 0.8,   // Very danceable
          'tempo': 140.0,        // Fast tempo
        };
      case Mood.angry:
        return {
          'valence': 0.3,        // Low positivity
          'energy': 0.8,         // High energy
          'loudness': -5.0,      // Loud
          'tempo': 130.0,        // Aggressive tempo
        };
      case Mood.anxious:
        return {
          'valence': 0.4,        // Below neutral
          'energy': 0.4,         // Moderate energy
          'acousticness': 0.6,   // Prefer acoustic
          'tempo': 100.0,        // Moderate tempo
        };
    }
  }
  
  List<String> _getMoodGenres(Mood mood, ListeningPatterns patterns) {
    final moodGenres = mood.musicGenres;
    final userGenres = patterns.preferredGenres;
    
    // Combine mood genres with user preferences
    final combinedGenres = <String>[];
    
    // Add user's preferred genres that match the mood
    for (final genre in userGenres) {
      if (moodGenres.contains(genre)) {
        combinedGenres.add(genre);
      }
    }
    
    // Fill remaining slots with mood-appropriate genres
    for (final genre in moodGenres) {
      if (combinedGenres.length >= 5) break; // Spotify limit
      if (!combinedGenres.contains(genre)) {
        combinedGenres.add(genre);
      }
    }
    
    return combinedGenres.take(5).toList();
  }
  
  Song _transformToSong(SpotifyTrack track) {
    return Song(
      id: track.id,
      name: track.name,
      artist: track.artists.first.name,
      albumImageUrl: track.album.images.isNotEmpty ? track.album.images.first.url : null,
      previewUrl: track.previewUrl,
      spotifyUrl: track.externalUrls.spotify,
      popularity: track.popularity?.toDouble(),
      genres: [], // Would need additional API call for track features
      duration: track.durationMs,
    );
  }
}
```

---

## 3. AWS Rekognition Integration

### 3.1 AWS Configuration & Authentication
```dart
class AWSCredentialsProvider {
  final SecureStorageService _secureStorage;
  
  AWSCredentialsProvider(this._secureStorage);
  
  Future<AWSCredentials> getCredentials() async {
    // For production, use temporary credentials via AWS STS
    // For development, use long-term access keys (not recommended for production)
    
    if (Environment.current == Environment.prod) {
      return await _getTemporaryCredentials();
    } else {
      return await _getDevelopmentCredentials();
    }
  }
  
  Future<AWSCredentials> _getTemporaryCredentials() async {
    // Use AWS STS to get temporary credentials
    // This should be done through your backend service for security
    
    final response = await Dio().post(
      '${Environment.config.backendUrl}/aws/credentials',
      options: Options(headers: {
        'Authorization': 'Bearer ${await _getUserToken()}',
      }),
    );
    
    final data = response.data;
    return AWSCredentials(
      accessKeyId: data['accessKeyId'],
      secretAccessKey: data['secretAccessKey'],
      sessionToken: data['sessionToken'],
      expiration: DateTime.parse(data['expiration']),
    );
  }
  
  Future<AWSCredentials> _getDevelopmentCredentials() async {
    return AWSCredentials(
      accessKeyId: await _secureStorage.getSecurely('aws_access_key_id') ?? '',
      secretAccessKey: await _secureStorage.getSecurely('aws_secret_access_key') ?? '',
    );
  }
}
```

### 3.2 Rekognition Service Implementation
```dart
class AWSRekognitionService {
  static const String _region = 'us-east-1';
  static const String _service = 'rekognition';
  
  final AWSCredentialsProvider _credentialsProvider;
  final Dio _dio;
  
  AWSRekognitionService(this._credentialsProvider) : _dio = Dio();
  
  Future<EmotionAnalysisResult> detectEmotions(Uint8List imageBytes) async {
    try {
      // Optimize image before sending to AWS
      final optimizedImage = await _optimizeImage(imageBytes);
      
      // Prepare request
      final credentials = await _credentialsProvider.getCredentials();
      final endpoint = 'https://rekognition.$_region.amazonaws.com/';
      
      final headers = await _createAWSHeaders(
        credentials: credentials,
        region: _region,
        service: _service,
        payload: optimizedImage,
      );
      
      // Create request body
      final requestBody = {
        'Image': {
          'Bytes': base64Encode(optimizedImage),
        },
        'Attributes': ['ALL'],
      };
      
      final response = await _dio.post(
        endpoint,
        data: jsonEncode(requestBody),
        options: Options(
          headers: {
            ...headers,
            'Content-Type': 'application/x-amz-json-1.1',
            'X-Amz-Target': 'RekognitionService.DetectFaces',
          },
        ),
      );
      
      return _parseEmotionResponse(response.data);
    } catch (e) {
      debugPrint('AWS Rekognition error: $e');
      
      if (e is DioException && e.response?.statusCode == 429) {
        throw RekognitionRateLimitException('Rate limit exceeded');
      }
      
      throw RekognitionException('Failed to analyze emotions: $e');
    }
  }
  
  Future<Uint8List> _optimizeImage(Uint8List originalBytes) async {
    const maxDimension = 1024;
    const quality = 85;
    
    final image = img.decodeImage(originalBytes);
    if (image == null) {
      throw ImageProcessingException('Invalid image format');
    }
    
    // Resize if too large
    img.Image resized = image;
    if (image.width > maxDimension || image.height > maxDimension) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? maxDimension : null,
        height: image.height > image.width ? maxDimension : null,
        interpolation: img.Interpolation.linear,
      );
    }
    
    // Compress as JPEG
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
  
  EmotionAnalysisResult _parseEmotionResponse(Map<String, dynamic> response) {
    final faceDetails = response['FaceDetails'] as List?;
    
    if (faceDetails == null || faceDetails.isEmpty) {
      throw EmotionDetectionException('No faces detected in image');
    }
    
    // Use the first (most prominent) face
    final face = faceDetails.first as Map<String, dynamic>;
    final emotions = face['Emotions'] as List;
    
    final emotionMap = <String, double>{};
    for (final emotion in emotions) {
      final type = emotion['Type'] as String;
      final confidence = (emotion['Confidence'] as num).toDouble();
      emotionMap[type.toLowerCase()] = confidence;
    }
    
    // Additional face attributes
    final boundingBox = face['BoundingBox'] as Map<String, dynamic>?;
    final faceConfidence = (face['Confidence'] as num?)?.toDouble() ?? 0.0;
    
    return EmotionAnalysisResult(
      emotions: emotionMap,
      boundingBox: boundingBox != null ? 
          FaceBoundingBox.fromJson(boundingBox) : null,
      confidence: faceConfidence,
      timestamp: DateTime.now(),
    );
  }
  
  Future<Map<String, String>> _createAWSHeaders({
    required AWSCredentials credentials,
    required String region,
    required String service,
    required Uint8List payload,
  }) async {
    final now = DateTime.now().toUtc();
    final dateStamp = DateFormat('yyyyMMdd').format(now);
    final amzDate = DateFormat('yyyyMMddTHHmmssZ').format(now);
    
    // Create canonical request
    final canonicalRequest = _createCanonicalRequest(payload, amzDate);
    
    // Create string to sign
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}';
    
    // Calculate signature
    final signingKey = _getSignatureKey(credentials.secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();
    
    // Create authorization header
    final authorizationHeader = 'AWS4-HMAC-SHA256 Credential=${credentials.accessKeyId}/$credentialScope, SignedHeaders=host;x-amz-date, Signature=$signature';
    
    final headers = {
      'Authorization': authorizationHeader,
      'X-Amz-Date': amzDate,
      'Host': 'rekognition.$region.amazonaws.com',
    };
    
    if (credentials.sessionToken != null) {
      headers['X-Amz-Security-Token'] = credentials.sessionToken!;
    }
    
    return headers;
  }
}
```

---

## 4. Events API Integration

### 4.1 Ticketmaster API Client
```dart
class TicketmasterApiClient extends BaseApiClient {
  static const String _baseUrl = 'https://app.ticketmaster.com/discovery/v2';
  static const String _apiKey = String.fromEnvironment('TICKETMASTER_API_KEY');
  
  TicketmasterApiClient() : super(baseUrl: _baseUrl);
  
  @override
  Future<void> _addAuthHeaders(RequestOptions options) async {
    options.queryParameters['apikey'] = _apiKey;
  }
  
  Future<List<TicketmasterEvent>> searchEvents({
    required double latitude,
    required double longitude,
    String? genre,
    int radius = 25,
    int size = 20,
    DateTime? startDateTime,
    DateTime? endDateTime,
  }) async {
    final queryParams = <String, dynamic>{
      'latlong': '$latitude,$longitude',
      'radius': radius,
      'unit': 'miles',
      'size': size,
      'sort': 'date,asc',
    };
    
    if (genre != null) {
      queryParams['genreId'] = _getTicketmasterGenreId(genre);
    }
    
    if (startDateTime != null) {
      queryParams['startDateTime'] = DateFormat('yyyy-MM-ddTHH:mm:ssZ').format(startDateTime.toUtc());
    }
    
    if (endDateTime != null) {
      queryParams['endDateTime'] = DateFormat('yyyy-MM-ddTHH:mm:ssZ').format(endDateTime.toUtc());
    }
    
    final response = await _dio.get('/events.json', queryParameters: queryParams);
    
    final embedded = response.data['_embedded'] as Map<String, dynamic>?;
    if (embedded == null || embedded['events'] == null) {
      return [];
    }
    
    final events = embedded['events'] as List;
    return events.map((event) => TicketmasterEvent.fromJson(event)).toList();
  }
  
  Future<TicketmasterEventDetails> getEventDetails(String eventId) async {
    final response = await _dio.get('/events/$eventId.json');
    return TicketmasterEventDetails.fromJson(response.data);
  }
  
  String? _getTicketmasterGenreId(String genre) {
    const genreMap = {
      'rock': 'KnvZfZ7vAeA',
      'pop': 'KnvZfZ7vAev',
      'country': 'KnvZfZ7vAuA',
      'classical': 'KnvZfZ7vAeJ',
      'jazz': 'KnvZfZ7vAvJ',
      'blues': 'KnvZfZ7vAvv',
      'electronic': 'KnvZfZ7vAvF',
      'hip-hop': 'KnvZfZ7vAv6',
      'metal': 'KnvZfZ7vAun',
      'alternative': 'KnvZfZ7vAe7',
    };
    
    return genreMap[genre.toLowerCase()];
  }
}
```

### 4.2 Eventbrite API Client
```dart
class EventbriteApiClient extends BaseApiClient {
  static const String _baseUrl = 'https://www.eventbriteapi.com/v3';
  static const String _apiKey = String.fromEnvironment('EVENTBRITE_API_KEY');
  
  EventbriteApiClient() : super(baseUrl: _baseUrl);
  
  @override
  Future<void> _addAuthHeaders(RequestOptions options) async {
    options.headers['Authorization'] = 'Bearer $_apiKey';
  }
  
  Future<List<EventbriteEvent>> searchEvents({
    required double latitude,
    required double longitude,
    String? category,
    int radius = 25,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'location.latitude': latitude,
      'location.longitude': longitude,
      'location.within': '${radius}mi',
      'expand': 'venue,category',
      'sort_by': 'date',
    };
    
    if (category != null) {
      queryParams['categories'] = _getEventbriteCategory(category);
    }
    
    if (startDate != null) {
      queryParams['start_date.range_start'] = startDate.toIso8601String();
    }
    
    if (endDate != null) {
      queryParams['start_date.range_end'] = endDate.toIso8601String();
    }
    
    final response = await _dio.get('/events/search/', queryParameters: queryParams);
    
    final events = response.data['events'] as List? ?? [];
    return events.map((event) => EventbriteEvent.fromJson(event)).toList();
  }
  
  String? _getEventbriteCategory(String genre) {
    const categoryMap = {
      'music': '103',
      'performing-arts': '105',
      'nightlife': '116',
      'arts': '104',
      'community': '113',
    };
    
    return categoryMap[genre.toLowerCase()];
  }
}
```

### 4.3 Unified Events Service
```dart
class EventsService {
  final TicketmasterApiClient _ticketmasterClient;
  final EventbriteApiClient _eventbriteClient;
  final LocationService _locationService;
  final CacheService _cacheService;
  
  EventsService(
    this._ticketmasterClient,
    this._eventbriteClient,
    this._locationService,
    this._cacheService,
  );
  
  Future<List<Event>> getEventsForMood(
    Mood mood,
    UserProfile userProfile,
  ) async {
    try {
      // Get user's current location
      final location = await _locationService.getCurrentLocation();
      
      // Get mood-appropriate genres
      final genres = _getMoodEventGenres(mood);
      
      // Search both APIs concurrently
      final futures = <Future<List<Event>>>[];
      
      for (final genre in genres) {
        futures.add(_searchTicketmasterEvents(location, genre));
        futures.add(_searchEventbriteEvents(location, genre));
      }
      
      final results = await Future.wait(futures);
      
      // Combine and deduplicate results
      final allEvents = <Event>[];
      for (final eventList in results) {
        allEvents.addAll(eventList);
      }
      
      // Remove duplicates and sort by relevance
      final uniqueEvents = _deduplicateEvents(allEvents);
      final sortedEvents = _sortEventsByRelevance(uniqueEvents, mood, userProfile);
      
      // Cache results
      await _cacheService.cacheEvents(mood, sortedEvents);
      
      return sortedEvents.take(10).toList();
    } catch (e) {
      debugPrint('Error fetching events: $e');
      
      // Return cached events as fallback
      return await _cacheService.getCachedEvents(mood) ?? [];
    }
  }
  
  List<String> _getMoodEventGenres(Mood mood) {
    switch (mood) {
      case Mood.happy:
        return ['pop', 'dance', 'festival', 'comedy'];
      case Mood.sad:
        return ['acoustic', 'folk', 'indie', 'poetry'];
      case Mood.angry:
        return ['rock', 'metal', 'punk', 'hardcore'];
      case Mood.calm:
        return ['classical', 'ambient', 'meditation', 'spa'];
      case Mood.anxious:
        return ['acoustic', 'chill', 'therapy', 'wellness'];
      case Mood.excited:
        return ['electronic', 'festival', 'party', 'rave'];
    }
  }
  
  Future<List<Event>> _searchTicketmasterEvents(Location location, String genre) async {
    try {
      final tmEvents = await _ticketmasterClient.searchEvents(
        latitude: location.latitude,
        longitude: location.longitude,
        genre: genre,
        radius: 25,
        size: 10,
        startDateTime: DateTime.now(),
        endDateTime: DateTime.now().add(const Duration(days: 30)),
      );
      
      return tmEvents.map(_transformTicketmasterEvent).toList();
    } catch (e) {
      debugPrint('Ticketmaster search error: $e');
      return [];
    }
  }
  
  Future<List<Event>> _searchEventbriteEvents(Location location, String genre) async {
    try {
      final ebEvents = await _eventbriteClient.searchEvents(
        latitude: location.latitude,
        longitude: location.longitude,
        category: genre,
        radius: 25,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      
      return ebEvents.map(_transformEventbriteEvent).toList();
    } catch (e) {
      debugPrint('Eventbrite search error: $e');
      return [];
    }
  }
  
  List<Event> _deduplicateEvents(List<Event> events) {
    final seen = <String>{};
    final unique = <Event>[];
    
    for (final event in events) {
      final key = '${event.name.toLowerCase()}_${event.date.day}_${event.venue.toLowerCase()}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(event);
      }
    }
    
    return unique;
  }
  
  List<Event> _sortEventsByRelevance(
    List<Event> events,
    Mood mood,
    UserProfile userProfile,
  ) {
    return events
      ..sort((a, b) {
        final scoreA = _calculateEventRelevanceScore(a, mood, userProfile);
        final scoreB = _calculateEventRelevanceScore(b, mood, userProfile);
        return scoreB.compareTo(scoreA);
      });
  }
  
  double _calculateEventRelevanceScore(
    Event event,
    Mood mood,
    UserProfile userProfile,
  ) {
    double score = 0.0;
    
    // Distance factor (closer is better)
    final distance = _calculateDistance(
      userProfile.location.latitude,
      userProfile.location.longitude,
      event.latitude,
      event.longitude,
    );
    score += (25 - distance) / 25 * 30; // 30 points max for proximity
    
    // Date factor (sooner is better, but not too soon)
    final daysUntilEvent = event.date.difference(DateTime.now()).inDays;
    if (daysUntilEvent >= 1 && daysUntilEvent <= 14) {
      score += 20; // Sweet spot for event planning
    } else if (daysUntilEvent <= 30) {
      score += 10;
    }
    
    // Mood relevance (based on event categories/genres)
    final moodGenres = mood.musicGenres;
    for (final genre in moodGenres) {
      if (event.name.toLowerCase().contains(genre.toLowerCase()) ||
          (event.description?.toLowerCase().contains(genre.toLowerCase()) ?? false)) {
        score += 25;
        break;
      }
    }
    
    // User preference matching
    for (final preferredGenre in userProfile.preferredGenres) {
      if (event.name.toLowerCase().contains(preferredGenre.toLowerCase())) {
        score += 15;
      }
    }
    
    return score;
  }
}
```

---

## 5. Error Handling & Resilience

### 5.1 Comprehensive Error Handling
```dart
class ApiErrorHandler {
  static T handleApiCall<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } on DioException catch (e) {
      throw _transformDioException(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }
  
  static ApiException _transformDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkTimeoutException('Request timed out. Please check your connection.');
        
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ?? 'Unknown error occurred';
        
        switch (statusCode) {
          case 400:
            return BadRequestException(message);
          case 401:
            return UnauthorizedException('Authentication required');
          case 403:
            return ForbiddenException('Access denied');
          case 404:
            return NotFoundException('Resource not found');
          case 429:
            return RateLimitException('Too many requests. Please try again later.');
          case 500:
            return ServerException('Internal server error');
          case 503:
            return ServiceUnavailableException('Service temporarily unavailable');
          default:
            return ApiException('HTTP $statusCode: $message');
        }
        
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return NetworkException('No internet connection');
        }
        return ApiException('Network error: ${e.message}');
        
      default:
        return ApiException('Request failed: ${e.message}');
    }
  }
}
```

### 5.2 Rate Limiting Implementation
```dart
class RateLimiter {
  final int requestsPerSecond;
  final Queue<DateTime> _requestTimes = Queue<DateTime>();
  
  RateLimiter({required this.requestsPerSecond});
  
  Future<void> acquire() async {
    final now = DateTime.now();
    
    // Remove requests older than 1 second
    while (_requestTimes.isNotEmpty && 
           now.difference(_requestTimes.first).inMilliseconds > 1000) {
      _requestTimes.removeFirst();
    }
    
    if (_requestTimes.length >= requestsPerSecond) {
      // Calculate delay needed
      final oldestRequest = _requestTimes.first;
      final delay = 1000 - now.difference(oldestRequest).inMilliseconds;
      
      if (delay > 0) {
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    
    _requestTimes.add(DateTime.now());
  }
}
```

### 5.3 Retry Logic with Exponential Backoff
```dart
class RetryPolicy {
  final int maxRetries;
  final Duration baseDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  
  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    int attempt = 0;
    Duration delay = baseDelay;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries || !_shouldRetry(e)) {
          rethrow;
        }
        
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        ).clamp(baseDelay, maxDelay);
      }
    }
    
    throw StateError('Retry policy completed without result');
  }
  
  bool _shouldRetry(dynamic error) {
    if (error is NetworkTimeoutException ||
        error is NetworkException ||
        error is RateLimitException ||
        error is ServerException ||
        error is ServiceUnavailableException) {
      return true;
    }
    
    return false;
  }
}
```

---

## 6. Testing & Mocking

### 6.1 Mock API Clients for Testing
```dart
class MockSpotifyApiClient extends Mock implements SpotifyWebApiClient {
  @override
  Future<List<SpotifyTrack>> getRecommendations({
    required List<String> seedGenres,
    required Map<String, double> audioFeatures,
    int limit = 20,
  }) async {
    // Return mock data based on parameters
    return _generateMockTracks(seedGenres, limit);
  }
  
  List<SpotifyTrack> _generateMockTracks(List<String> genres, int count) {
    return List.generate(count, (index) {
      return SpotifyTrack(
        id: 'mock_track_$index',
        name: 'Mock Song $index',
        artists: [SpotifyArtist(id: 'mock_artist_$index', name: 'Mock Artist $index')],
        album: SpotifyAlbum(
          id: 'mock_album_$index',
          name: 'Mock Album $index',
          images: [SpotifyImage(url: 'https://mock.image.url/$index')],
        ),
        previewUrl: 'https://mock.preview.url/$index',
        externalUrls: SpotifyExternalUrls(spotify: 'https://open.spotify.com/track/mock_$index'),
        popularity: 70 + (index % 30),
        durationMs: 180000 + (index * 1000),
      );
    });
  }
}
```

### 6.2 Integration Test Helpers
```dart
class ApiIntegrationTestHelper {
  static Future<void> setupMockServer() async {
    // Setup mock server for integration tests
    final mockServer = MockWebServer();
    await mockServer.start();
    
    // Configure mock responses
    mockServer.enqueue(MockResponse()
      ..httpCode = 200
      ..body = jsonEncode({
        'tracks': [
          {
            'id': 'test_track_1',
            'name': 'Test Song',
            'artists': [{'id': 'test_artist_1', 'name': 'Test Artist'}],
            // ... other mock data
          }
        ]
      }));
  }
  
  static Future<void> teardownMockServer() async {
    // Cleanup mock server
  }
}
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-23  
**Next Review**: 2025-02-23  
**Owner**: Technical Integration Team