# MoodMusic - Testing Strategy

## 1. Testing Philosophy & Approach

### 1.1 Testing Pyramid
Our testing strategy follows the testing pyramid principle with emphasis on automated testing at all levels:

```
                    ┌─────────────┐
                    │     E2E     │ 5%
                    │    Tests    │
                ┌───┴─────────────┴───┐
                │   Integration Tests │ 25%
            ┌───┴─────────────────────┴───┐
            │       Unit Tests            │ 70%
        ┌───┴─────────────────────────────┴───┐
        │         Static Analysis             │
        └─────────────────────────────────────┘
```

### 1.2 Testing Principles
- **Test-Driven Mindset**: Write tests to drive design and catch regressions
- **Fast Feedback**: Tests should run quickly to enable rapid development
- **Reliability**: Tests should be deterministic and not flaky
- **Maintainability**: Tests should be easy to understand and modify
- **Real-World Scenarios**: Tests should reflect actual user behavior

### 1.3 Quality Gates
- **Minimum Code Coverage**: 80% overall, 90% for critical business logic
- **Performance Benchmarks**: All tests complete within 10 minutes
- **Zero Tolerance**: No failing tests in main branch
- **Automated**: All tests run automatically on CI/CD pipeline

---

## 2. Unit Testing Strategy

### 2.1 Framework & Tools
- **Primary Framework**: `flutter_test` (built-in testing framework)
- **Mocking**: `mockito` for creating test doubles
- **State Testing**: `provider_test` for testing Provider state management
- **Code Coverage**: `coverage` package for measuring test coverage

### 2.2 Unit Test Structure
```dart
// Example unit test structure
class MoodEngineTest {
  late MoodEngine moodEngine;
  late MockMoodProfileRepository mockRepository;
  
  @setUp
  void setUp() {
    mockRepository = MockMoodProfileRepository();
    moodEngine = MoodEngine(mockRepository);
  }
  
  @tearDown
  void tearDown() {
    reset(mockRepository);
  }
  
  group('MoodEngine', () {
    group('matchMood', () {
      test('should return correct mood profile for happy emotions', () async {
        // Arrange
        final emotionData = {'happy': 85.0, 'joy': 75.0};
        final expectedProfile = createMockHappyProfile();
        
        when(mockRepository.getProfiles()).thenAnswer((_) async => [expectedProfile]);
        
        // Act
        final result = await moodEngine.matchMood(emotionData);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.label, equals('Joyful Optimism'));
        expect(result.emotionTriggers, contains('happy'));
        
        verify(mockRepository.getProfiles()).called(1);
      });
      
      test('should return fallback profile when no match found', () async {
        // Arrange
        final emotionData = {'unknown': 50.0};
        
        when(mockRepository.getProfiles()).thenAnswer((_) async => []);
        
        // Act
        final result = await moodEngine.matchMood(emotionData);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.label, equals('Emotion Drift'));
        expect(result.patternType, equals('Adaptive'));
      });
      
      test('should handle empty emotion data gracefully', () async {
        // Arrange
        final emotionData = <String, double>{};
        
        // Act
        final result = await moodEngine.matchMood(emotionData);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.label, equals('Neutral Balance'));
      });
      
      test('should throw exception when repository fails', () async {
        // Arrange
        final emotionData = {'happy': 85.0};
        
        when(mockRepository.getProfiles()).thenThrow(DatabaseException('Connection failed'));
        
        // Act & Assert
        expect(
          () => moodEngine.matchMood(emotionData),
          throwsA(isA<MoodEngineException>()),
        );
      });
    });
  });
}
```

### 2.3 Unit Test Coverage Areas

#### Services Layer Testing
```dart
// SpotifyService unit tests
class SpotifyServiceTest {
  test('should return cached recommendations when API fails', () async {
    // Arrange
    final mood = Mood.happy;
    final cachedSongs = [createMockSong()];
    
    when(mockSpotifyApi.getRecommendations(any)).thenThrow(NetworkException());
    when(mockCacheService.getCachedRecommendations(mood))
        .thenAnswer((_) async => cachedSongs);
    
    // Act
    final result = await spotifyService.getRecommendationsForMood(mood, mockUserProfile);
    
    // Assert
    expect(result, equals(cachedSongs));
    verify(mockCacheService.getCachedRecommendations(mood)).called(1);
  });
  
  test('should combine user preferences with mood features', () async {
    // Arrange
    final mood = Mood.calm;
    final userProfile = createUserProfile(preferredGenres: ['classical', 'ambient']);
    
    when(mockSpotifyApi.getRecommendations(
      seedGenres: argThat(contains('classical'), named: 'seedGenres'),
      audioFeatures: argThat(containsPair('valence', lessThan(0.6)), named: 'audioFeatures'),
    )).thenAnswer((_) async => [createMockSpotifyTrack()]);
    
    // Act
    await spotifyService.getRecommendationsForMood(mood, userProfile);
    
    // Assert
    verify(mockSpotifyApi.getRecommendations(
      seedGenres: argThat(containsAll(['classical', 'ambient']), named: 'seedGenres'),
      audioFeatures: argThat(containsPair('energy', lessThan(0.4)), named: 'audioFeatures'),
    )).called(1);
  });
}
```

#### Provider State Testing
```dart
class AppStateProviderTest {
  late AppStateProvider provider;
  
  setUp(() {
    provider = AppStateProvider();
  });
  
  test('should notify listeners when state changes', () {
    // Arrange
    bool notified = false;
    provider.addListener(() => notified = true);
    
    // Act
    provider.goToScanning();
    
    // Assert
    expect(notified, isTrue);
    expect(provider.currentState, equals(AppState.scanning));
  });
  
  test('should clear data when resetting to start', () {
    // Arrange
    provider.goToResults(Mood.happy, createMockSong(), createMockEvent());
    
    // Act
    provider.goToStart();
    
    // Assert
    expect(provider.currentState, equals(AppState.start));
    expect(provider.detectedMood, isNull);
    expect(provider.recommendedSong, isNull);
    expect(provider.recommendedEvent, isNull);
  });
}
```

#### Data Model Testing
```dart
class MoodProfileTest {
  test('should correctly parse from CSV row', () {
    // Arrange
    final csvRow = [
      'Joyful Optimism',
      'High energy positive state with social tendencies',
      'happy,joy,excitement',
      'happy:80,joy:70',
      'Social',
      '"Dancing through life with infectious positivity"',
      'upbeat,dance,pop',
      'Perfect for celebrating life\'s moments'
    ];
    
    // Act
    final profile = MoodProfile.fromCsvRow(csvRow);
    
    // Assert
    expect(profile.label, equals('Joyful Optimism'));
    expect(profile.emotionTriggers, containsAll(['happy', 'joy', 'excitement']));
    expect(profile.percentConditions['happy'], equals(80.0));
    expect(profile.percentConditions['joy'], equals(70.0));
    expect(profile.patternType, equals('Social'));
    expect(profile.musicTags, containsAll(['upbeat', 'dance', 'pop']));
  });
  
  test('should handle malformed CSV data gracefully', () {
    // Arrange
    final invalidRow = ['Incomplete'];
    
    // Act & Assert
    expect(
      () => MoodProfile.fromCsvRow(invalidRow),
      throwsA(isA<FormatException>()),
    );
  });
}
```

### 2.4 Test Data Management
```dart
class TestDataFactory {
  static MoodProfile createMockHappyProfile() {
    return const MoodProfile(
      label: 'Joyful Optimism',
      description: 'High energy positive state',
      emotionTriggers: ['happy', 'joy'],
      percentConditions: {'happy': 80.0, 'joy': 70.0},
      patternType: 'Social',
      quotes: ['Life is beautiful!'],
      musicTags: ['upbeat', 'dance', 'pop'],
      suggestionNote: 'Perfect for celebrating',
    );
  }
  
  static Song createMockSong({
    String? id,
    String? name,
    String? artist,
  }) {
    return Song(
      id: id ?? 'mock_song_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Mock Song',
      artist: artist ?? 'Mock Artist',
      albumImageUrl: 'https://mock.image.url/album.jpg',
      previewUrl: 'https://mock.preview.url/preview.mp3',
      spotifyUrl: 'https://open.spotify.com/track/mock',
      popularity: 75.0,
      genres: ['pop'],
      duration: 180000,
    );
  }
  
  static UserProfile createUserProfile({
    String? id,
    List<String>? preferredGenres,
    List<String>? preferredArtists,
  }) {
    return UserProfile(
      id: id ?? 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: 'test@example.com',
      displayName: 'Test User',
      preferredGenres: preferredGenres ?? ['pop', 'rock'],
      preferredArtists: preferredArtists ?? ['Test Artist'],
      location: const Location(latitude: 37.7749, longitude: -122.4194),
      subscriptionStatus: SubscriptionStatus.free,
    );
  }
}
```

---

## 3. Widget Testing Strategy

### 3.1 Widget Testing Approach
Widget tests verify that UI components render correctly and respond to user interactions appropriately.

```dart
class MoodResultsScreenTest {
  late MockAppStateProvider mockAppStateProvider;
  
  setUp(() {
    mockAppStateProvider = MockAppStateProvider();
  });
  
  testWidgets('should display mood information correctly', (WidgetTester tester) async {
    // Arrange
    final mood = Mood.happy;
    final song = TestDataFactory.createMockSong(name: 'Test Song', artist: 'Test Artist');
    final event = TestDataFactory.createMockEvent(name: 'Test Event');
    
    // Act
    await tester.pumpWidget(
      createTestWidget(
        MoodResultsScreen(
          mood: mood,
          song: song,
          event: event,
        ),
      ),
    );
    
    // Assert
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('😊'), findsOneWidget);
    expect(find.text('Test Song by Test Artist'), findsOneWidget);
    expect(find.text('Test Event'), findsOneWidget);
  });
  
  testWidgets('should navigate back when back button pressed', (WidgetTester tester) async {
    // Arrange
    when(mockAppStateProvider.currentState).thenReturn(AppState.results);
    
    await tester.pumpWidget(
      createTestWidget(
        MoodResultsScreen(mood: Mood.happy),
      ),
    );
    
    // Act
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    
    // Assert
    verify(mockAppStateProvider.goToStart()).called(1);
  });
  
  testWidgets('should show scan again button', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      createTestWidget(
        MoodResultsScreen(mood: Mood.happy),
      ),
    );
    
    // Act
    final scanAgainButton = find.text('Scan Again');
    
    // Assert
    expect(scanAgainButton, findsOneWidget);
    
    // Test button interaction
    await tester.tap(scanAgainButton);
    await tester.pump();
    
    verify(mockAppStateProvider.goToScanning()).called(1);
  });
  
  testWidgets('should animate mood result appearance', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      createTestWidget(
        MoodResultsScreen(mood: Mood.happy),
      ),
    );
    
    // Act - pump through animation
    await tester.pump(); // Initial frame
    await tester.pump(const Duration(milliseconds: 750)); // Mid-animation
    await tester.pump(const Duration(milliseconds: 750)); // Complete animation
    
    // Assert - verify animation completed
    final scaleTransition = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).first,
    );
    expect(scaleTransition.scale.value, equals(1.0));
  });
}
```

### 3.2 Camera Widget Testing
```dart
class MoodScannerScreenTest {
  testWidgets('should show camera preview when camera available', (WidgetTester tester) async {
    // Arrange
    final mockCameras = [
      const CameraDescription(
        name: 'Front Camera',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 90,
      ),
    ];
    
    // Act
    await tester.pumpWidget(
      createTestWidget(
        MoodScannerScreen(cameras: mockCameras),
      ),
    );
    
    // Assert
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.text('Position your face in the circle'), findsOneWidget);
  });
  
  testWidgets('should show error when no cameras available', (WidgetTester tester) async {
    // Arrange
    const emptyCameras = <CameraDescription>[];
    
    // Act
    await tester.pumpWidget(
      createTestWidget(
        MoodScannerScreen(cameras: emptyCameras),
      ),
    );
    
    // Assert
    expect(find.text('Camera not available'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
  });
  
  testWidgets('should capture photo when capture button tapped', (WidgetTester tester) async {
    // Note: This test requires camera mocking at a higher level
    // Implementation would depend on camera controller mocking strategy
  });
}
```

### 3.3 Paywall Widget Testing
```dart
class PaywallModalTest {
  testWidgets('should display pricing tiers correctly', (WidgetTester tester) async {
    // Arrange
    const trigger = PaywallTrigger.dailyLimitReached;
    
    // Act
    await tester.pumpWidget(
      createTestWidget(
        PaywallModal(
          trigger: trigger,
          onUpgrade: (_) {},
          onDismiss: () {},
        ),
      ),
    );
    
    // Assert
    expect(find.text('Upgrade for unlimited daily scans'), findsOneWidget);
    expect(find.text('Try Premium Free for 7 Days'), findsOneWidget);
    expect(find.text('\$4.99/month'), findsOneWidget);
    expect(find.text('\$39.99/year'), findsOneWidget);
  });
  
  testWidgets('should call onUpgrade when premium selected', (WidgetTester tester) async {
    // Arrange
    SubscriptionTier? selectedTier;
    
    await tester.pumpWidget(
      createTestWidget(
        PaywallModal(
          trigger: PaywallTrigger.dailyLimitReached,
          onUpgrade: (tier) => selectedTier = tier,
          onDismiss: () {},
        ),
      ),
    );
    
    // Act
    await tester.tap(find.text('Start Monthly Premium'));
    await tester.pump();
    
    // Assert
    expect(selectedTier, equals(SubscriptionTier.premiumMonthly));
  });
}
```

### 3.4 Test Utilities
```dart
class WidgetTestUtils {
  static Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => MockAppStateProvider(),
        ),
        ChangeNotifierProvider<SpotifyProvider>(
          create: (_) => MockSpotifyProvider(),
        ),
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (_) => MockSubscriptionProvider(),
        ),
      ],
      child: MaterialApp(
        home: child,
        theme: AppTheme.lightTheme,
      ),
    );
  }
  
  static Future<void> pumpAndSettle(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(createTestWidget(widget));
    await tester.pumpAndSettle();
  }
  
  static Finder findByTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.contains(text) == true,
    );
  }
  
  static Future<void> tapAndPump(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }
}
```

---

## 4. Integration Testing Strategy

### 4.1 Integration Test Architecture
Integration tests verify that different parts of the system work together correctly, focusing on critical user journeys.

```dart
void main() {
  group('Mood Detection Integration Tests', () {
    late IntegrationTestHelper helper;
    
    setUpAll(() async {
      helper = IntegrationTestHelper();
      await helper.initialize();
    });
    
    tearDownAll(() async {
      await helper.cleanup();
    });
    
    testWidgets('complete mood detection flow', (WidgetTester tester) async {
      // Arrange
      await helper.setupMockEmotionDetection();
      await helper.setupMockMusicRecommendations();
      
      // Act - Start the app
      await tester.pumpWidget(const MoodMusicApp());
      await tester.pumpAndSettle();
      
      // Navigate to scanner
      await tester.tap(find.text('Start Mood Scan'));
      await tester.pumpAndSettle();
      
      // Simulate camera capture
      await helper.simulateCameraCapture();
      await tester.tap(find.byIcon(Icons.camera));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // Verify results screen
      expect(find.byType(MoodResultsScreen), findsOneWidget);
      expect(find.textContaining('You\'re feeling'), findsOneWidget);
      expect(find.textContaining('recommendations'), findsOneWidget);
      
      // Verify music recommendation displayed
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.textContaining('by'), findsOneWidget); // Artist info
      
      // Test navigation back to start
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();
      
      expect(find.byType(StartScreen), findsOneWidget);
    });
    
    testWidgets('paywall flow for free user hitting limit', (WidgetTester tester) async {
      // Arrange
      await helper.setupFreeUserAtScanLimit();
      
      await tester.pumpWidget(const MoodMusicApp());
      await tester.pumpAndSettle();
      
      // Act - Try to exceed scan limit
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Start Mood Scan'));
        await tester.pumpAndSettle();
        
        if (i < 3) {
          // First 3 scans should work
          expect(find.byType(MoodScannerScreen), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        } else {
          // 4th scan should show paywall
          expect(find.byType(PaywallModal), findsOneWidget);
          expect(find.text('You\'ve reached your daily scan limit'), findsOneWidget);
        }
      }
      
      // Test paywall interaction
      await tester.tap(find.text('Try Premium Free for 7 Days'));
      await tester.pumpAndSettle();
      
      // Verify subscription flow initiated
      expect(helper.subscriptionUpgradeTriggered, isTrue);
    });
    
    testWidgets('offline mode fallback behavior', (WidgetTester tester) async {
      // Arrange
      await helper.simulateOfflineMode();
      
      await tester.pumpWidget(const MoodMusicApp());
      await tester.pumpAndSettle();
      
      // Act
      await tester.tap(find.text('Start Mood Scan'));
      await tester.pumpAndSettle();
      
      await helper.simulateCameraCapture();
      await tester.tap(find.byIcon(Icons.camera));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // Assert - Should use cached/fallback data
      expect(find.byType(MoodResultsScreen), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
```

### 4.2 API Integration Testing
```dart
class SpotifyIntegrationTest {
  late SpotifyService spotifyService;
  late MockHttpClient mockHttpClient;
  
  setUp(() async {
    mockHttpClient = MockHttpClient();
    spotifyService = SpotifyService(
      SpotifyWebApiClient(mockHttpClient),
      CacheService(),
      DatabaseService(),
    );
  });
  
  test('should handle Spotify OAuth flow end-to-end', () async {
    // Arrange
    mockHttpClient.when(
      method: 'POST',
      url: 'https://accounts.spotify.com/api/token',
    ).thenReturn(MockResponse(
      statusCode: 200,
      data: {
        'access_token': 'mock_access_token',
        'refresh_token': 'mock_refresh_token',
        'expires_in': 3600,
      },
    ));
    
    // Act
    final success = await spotifyService.authenticate();
    
    // Assert
    expect(success, isTrue);
    expect(await spotifyService.isAuthenticated(), isTrue);
  });
  
  test('should retry on rate limit and succeed', () async {
    // Arrange
    var attemptCount = 0;
    mockHttpClient.when(
      method: 'GET',
      url: contains('/recommendations'),
    ).thenAnswer((_) {
      attemptCount++;
      if (attemptCount == 1) {
        return MockResponse(statusCode: 429, headers: {'retry-after': '1'});
      }
      return MockResponse(statusCode: 200, data: {'tracks': []});
    });
    
    // Act
    final recommendations = await spotifyService.getRecommendationsForMood(
      Mood.happy,
      TestDataFactory.createUserProfile(),
    );
    
    // Assert
    expect(attemptCount, equals(2));
    expect(recommendations, isNotNull);
  });
}
```

### 4.3 Database Integration Testing
```dart
class DatabaseIntegrationTest {
  late DatabaseService databaseService;
  late String testDatabasePath;
  
  setUp(() async {
    testDatabasePath = '${await getDatabasesPath()}/test_moodmusic.db';
    databaseService = DatabaseService(testDatabasePath);
    await databaseService.initialize();
  });
  
  tearDown(() async {
    await databaseService.close();
    await File(testDatabasePath).delete();
  });
  
  test('should store and retrieve mood sessions correctly', () async {
    // Arrange
    final userId = 'test_user_123';
    final moodSession = MoodSession(
      id: 'session_123',
      userId: userId,
      mood: Mood.happy,
      confidence: 0.85,
      timestamp: DateTime.now(),
      emotionData: {'happy': 85.0, 'joy': 70.0},
    );
    
    // Act
    await databaseService.storeMoodSession(moodSession);
    final retrieved = await databaseService.getMoodSessions(userId);
    
    // Assert
    expect(retrieved.length, equals(1));
    expect(retrieved.first.id, equals('session_123'));
    expect(retrieved.first.mood, equals(Mood.happy));
    expect(retrieved.first.confidence, equals(0.85));
  });
  
  test('should handle database migration correctly', () async {
    // Arrange - Create database with old schema
    final oldDb = await openDatabase(
      testDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mood_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            mood TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
    
    await oldDb.insert('mood_sessions', {
      'id': 'old_session',
      'user_id': 'test_user',
      'mood': 'happy',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await oldDb.close();
    
    // Act - Open with new service (should trigger migration)
    final newService = DatabaseService(testDatabasePath);
    await newService.initialize();
    
    // Assert - Verify data preserved and new columns added
    final sessions = await newService.getMoodSessions('test_user');
    expect(sessions.length, equals(1));
    expect(sessions.first.id, equals('old_session'));
    expect(sessions.first.confidence, isNotNull); // New column should exist
    
    await newService.close();
  });
}
```

---

## 5. End-to-End Testing Strategy

### 5.1 E2E Test Framework Setup
```dart
// integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('MoodMusic E2E Tests', () {
    testWidgets('complete user journey from onboarding to premium', (tester) async {
      // This test covers the entire user journey
      await _testCompleteUserJourney(tester);
    });
    
    testWidgets('offline and recovery scenarios', (tester) async {
      await _testOfflineScenarios(tester);
    });
    
    testWidgets('subscription and payment flows', (tester) async {
      await _testSubscriptionFlows(tester);
    });
  });
}

Future<void> _testCompleteUserJourney(WidgetTester tester) async {
  // Start app
  app.main();
  await tester.pumpAndSettle();
  
  // First-time user onboarding
  expect(find.text('Welcome to MoodMusic'), findsOneWidget);
  await tester.tap(find.text('Get Started'));
  await tester.pumpAndSettle();
  
  // Permission requests
  await tester.tap(find.text('Allow Camera Access'));
  await tester.pumpAndSettle();
  
  // Music preference setup
  await tester.tap(find.text('Pop'));
  await tester.tap(find.text('Rock'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  
  // Main screen
  expect(find.text('Start Mood Scan'), findsOneWidget);
  await tester.tap(find.text('Start Mood Scan'));
  await tester.pumpAndSettle();
  
  // Camera screen
  expect(find.byType(CameraPreview), findsOneWidget);
  await tester.tap(find.byIcon(Icons.camera));
  
  // Wait for emotion analysis
  await tester.pumpAndSettle(const Duration(seconds: 10));
  
  // Results screen
  expect(find.byType(MoodResultsScreen), findsOneWidget);
  expect(find.textContaining('You\'re feeling'), findsOneWidget);
  
  // Test music recommendation
  expect(find.byIcon(Icons.music_note), findsOneWidget);
  await tester.tap(find.byIcon(Icons.music_note));
  await tester.pumpAndSettle();
  
  // Should open music player or Spotify
  // (Implementation depends on specific music integration)
  
  // Navigate to history
  await tester.tap(find.byIcon(Icons.history));
  await tester.pumpAndSettle();
  
  expect(find.byType(HistoryScreen), findsOneWidget);
  expect(find.textContaining('Total Scans'), findsOneWidget);
  
  // Test multiple scans to trigger paywall
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  
  // Perform scans until paywall
  for (int i = 0; i < 4; i++) {
    await tester.tap(find.text('Start Mood Scan'));
    await tester.pumpAndSettle();
    
    if (find.byType(PaywallModal).evaluate().isNotEmpty) {
      // Paywall triggered
      expect(find.text('Upgrade for unlimited daily scans'), findsOneWidget);
      await tester.tap(find.text('Try Premium Free for 7 Days'));
      await tester.pumpAndSettle();
      break;
    } else {
      // Complete scan
      await tester.tap(find.byIcon(Icons.camera));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();
    }
  }
}
```

### 5.2 Performance Testing
```dart
void main() {
  group('Performance Tests', () {
    testWidgets('app launch performance', (tester) async {
      final stopwatch = Stopwatch()..start();
      
      app.main();
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      // App should launch within 3 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      
      // Verify main screen is visible
      expect(find.text('MoodMusic'), findsOneWidget);
    });
    
    testWidgets('emotion analysis performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Start Mood Scan'));
      await tester.pumpAndSettle();
      
      final stopwatch = Stopwatch()..start();
      
      // Simulate camera capture
      await tester.tap(find.byIcon(Icons.camera));
      
      // Wait for analysis to complete
      await tester.pumpUntil(
        find.byType(MoodResultsScreen),
        const Duration(seconds: 10),
      );
      
      stopwatch.stop();
      
      // Analysis should complete within 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
    
    testWidgets('memory usage during extended use', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      final initialMemory = await _getCurrentMemoryUsage();
      
      // Perform multiple mood scans
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.text('Start Mood Scan'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.byIcon(Icons.camera));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        await tester.tap(find.text('Back to Home'));
        await tester.pumpAndSettle();
      }
      
      final finalMemory = await _getCurrentMemoryUsage();
      final memoryIncrease = finalMemory - initialMemory;
      
      // Memory increase should be reasonable (less than 50MB)
      expect(memoryIncrease, lessThan(50 * 1024 * 1024));
    });
  });
}
```

---

## 6. Testing Infrastructure

### 6.1 Continuous Integration Setup
```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        
    - name: Get dependencies
      run: flutter pub get
      
    - name: Analyze code
      run: flutter analyze
      
    - name: Run unit tests
      run: flutter test --coverage
      
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: coverage/lcov.info
        
  widget_tests:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        
    - name: Run widget tests
      run: flutter test test/widget_test
      
  integration_tests:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      
    - name: Run iOS integration tests
      run: |
        cd example
        flutter drive \
          --driver=test_driver/integration_test.dart \
          --target=integration_test/app_test.dart \
          -d iPhone
```

### 6.2 Test Data Management
```dart
class TestDataManager {
  static const String _testAssetsPath = 'test/assets';
  
  static Future<Uint8List> getTestImage(String filename) async {
    final file = File('$_testAssetsPath/images/$filename');
    return await file.readAsBytes();
  }
  
  static Future<Map<String, dynamic>> getTestApiResponse(String filename) async {
    final file = File('$_testAssetsPath/api_responses/$filename');
    final content = await file.readAsString();
    return jsonDecode(content);
  }
  
  static Future<void> setupTestDatabase() async {
    final testDbPath = '${await getDatabasesPath()}/test_moodmusic.db';
    
    // Delete existing test database
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
    
    // Create fresh test database with sample data
    final db = await openDatabase(testDbPath, version: 1, onCreate: _createTestTables);
    await _insertTestData(db);
    await db.close();
  }
  
  static Future<void> _createTestTables(Database db, int version) async {
    // Create all necessary tables for testing
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        display_name TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Additional table creation...
  }
  
  static Future<void> _insertTestData(Database db) async {
    // Insert test users
    await db.insert('users', {
      'id': 'test_user_1',
      'email': 'test1@example.com',
      'display_name': 'Test User 1',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Insert additional test data...
  }
}
```

### 6.3 Mock Services
```dart
class MockServiceContainer {
  static void registerMocks() {
    GetIt.instance.registerLazySingleton<SpotifyService>(
      () => MockSpotifyService(),
    );
    
    GetIt.instance.registerLazySingleton<AWSRekognitionService>(
      () => MockAWSRekognitionService(),
    );
    
    GetIt.instance.registerLazySingleton<EventsService>(
      () => MockEventsService(),
    );
    
    GetIt.instance.registerLazySingleton<DatabaseService>(
      () => MockDatabaseService(),
    );
  }
  
  static void reset() {
    GetIt.instance.reset();
  }
}

class MockSpotifyService extends Mock implements SpotifyService {
  @override
  Future<List<Song>> getRecommendationsForMood(Mood mood, UserProfile user) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    return [
      TestDataFactory.createMockSong(
        name: 'Mock ${mood.displayName} Song',
        artist: 'Test Artist',
      ),
    ];
  }
  
  @override
  Future<bool> authenticate() async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
  
  @override
  Future<bool> isAuthenticated() async => true;
}
```

---

## 7. Test Execution & Reporting

### 7.1 Test Execution Strategy
```bash
#!/bin/bash
# run_tests.sh

echo "🧪 Running MoodMusic Test Suite"
echo "================================"

# Clean previous test artifacts
flutter clean
flutter pub get

echo "\n📊 Running static analysis..."
flutter analyze
if [ $? -ne 0 ]; then
    echo "❌ Static analysis failed"
    exit 1
fi

echo "\n🔬 Running unit tests..."
flutter test --coverage --reporter=expanded
if [ $? -ne 0 ]; then
    echo "❌ Unit tests failed"
    exit 1
fi

echo "\n🎨 Running widget tests..."
flutter test test/widget_test --reporter=expanded
if [ $? -ne 0 ]; then
    echo "❌ Widget tests failed"
    exit 1
fi

# Generate coverage report
echo "\n📈 Generating coverage report..."
genhtml coverage/lcov.info -o coverage/html
echo "Coverage report generated: coverage/html/index.html"

# Check coverage threshold
coverage_percentage=$(lcov --summary coverage/lcov.info | grep -o 'lines......: [0-9.]*%' | grep -o '[0-9.]*')
echo "Code coverage: ${coverage_percentage}%"

if (( $(echo "$coverage_percentage < 80" | bc -l) )); then
    echo "❌ Coverage below threshold (80%)"
    exit 1
fi

echo "\n🚀 Running integration tests..."
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart

if [ $? -ne 0 ]; then
    echo "❌ Integration tests failed"
    exit 1
fi

echo "\n✅ All tests passed!"
echo "📊 Test Results Summary:"
echo "  - Static Analysis: ✅"
echo "  - Unit Tests: ✅"
echo "  - Widget Tests: ✅"
echo "  - Integration Tests: ✅"
echo "  - Code Coverage: ${coverage_percentage}%"
```

### 7.2 Test Reporting
```dart
class TestReporter {
  static void generateTestReport() {
    final report = TestReport();
    
    // Collect test results
    report.addSection('Unit Tests', _getUnitTestResults());
    report.addSection('Widget Tests', _getWidgetTestResults());
    report.addSection('Integration Tests', _getIntegrationTestResults());
    report.addSection('Coverage', _getCoverageResults());
    
    // Generate HTML report
    final html = report.toHtml();
    File('test_report.html').writeAsStringSync(html);
    
    // Generate JSON report for CI/CD
    final json = report.toJson();
    File('test_report.json').writeAsStringSync(json);
  }
  
  static Map<String, dynamic> _getUnitTestResults() {
    return {
      'total_tests': 150,
      'passed': 148,
      'failed': 2,
      'skipped': 0,
      'duration': '45.2s',
      'failure_details': [
        {
          'test': 'MoodEngine.matchMood should handle network errors',
          'error': 'Expected exception not thrown',
          'file': 'test/services/mood_engine_test.dart:123'
        }
      ]
    };
  }
}
```

---

## 8. Testing Best Practices

### 8.1 Test Writing Guidelines

#### DO's
- **Write tests first** when possible (TDD approach)
- **Use descriptive test names** that explain the scenario
- **Follow AAA pattern** (Arrange, Act, Assert)
- **Test edge cases** and error conditions
- **Use proper test data** that reflects real-world scenarios
- **Mock external dependencies** to ensure test isolation
- **Keep tests independent** - each test should be able to run alone

#### DON'Ts
- **Don't test implementation details** - focus on behavior
- **Don't write tests that are too complex** - if a test is hard to understand, split it
- **Don't ignore failing tests** - fix them immediately or remove them
- **Don't use real external services** in tests - always mock
- **Don't write flaky tests** - ensure deterministic behavior

### 8.2 Code Coverage Guidelines
- **Minimum 80% overall coverage**
- **90% coverage for critical business logic** (emotion detection, recommendations)
- **100% coverage for utility functions** and data transformations
- **Focus on meaningful coverage** not just line coverage
- **Use coverage reports** to identify untested code paths

### 8.3 Performance Testing Guidelines
- **Set performance benchmarks** for critical operations
- **Test on different device configurations** (low-end, high-end)
- **Monitor memory usage** during extended test runs
- **Test network timeout scenarios** and recovery
- **Verify UI responsiveness** during heavy operations

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-23  
**Next Review**: 2025-02-23  
**Owner**: Quality Assurance Team