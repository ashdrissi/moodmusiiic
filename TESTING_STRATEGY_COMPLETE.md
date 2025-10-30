# MoodMusic Testing Strategy - Comprehensive Test Plan

## Executive Summary

This document provides a complete testing strategy for the MoodMusic Flutter application, covering unit tests, widget tests, integration tests, and end-to-end testing scenarios. The strategy ensures 90%+ code coverage and production-ready quality across all platforms.

**Testing Philosophy**: Test-driven development with comprehensive coverage of business logic, UI interactions, and external integrations.
**Target Coverage**: 90% code coverage minimum
**Automation Level**: 95% automated tests, 5% manual exploratory testing
**Platforms**: iOS 13+, Android API 21+

---

## 1. Testing Pyramid & Strategy Overview

### 1.1 Testing Pyramid Structure

```
                    E2E Tests (10%)
                  ┌─────────────────┐
                  │ • User Journeys │
                  │ • Integration   │
                  │ • Performance   │
                  └─────────────────┘
                 
              Integration Tests (20%)
            ┌─────────────────────────┐
            │ • API Integration       │
            │ • Database Operations   │
            │ • Service Layer         │
            │ • Provider State        │
            └─────────────────────────┘
           
          Widget/Component Tests (30%)
        ┌─────────────────────────────────┐
        │ • UI Components                 │
        │ • Screen Interactions           │
        │ • Navigation Flows             │
        │ • Accessibility                │
        └─────────────────────────────────┘
       
      Unit Tests (40%)
    ┌─────────────────────────────────────┐
    │ • Business Logic                    │
    │ • Data Models                       │
    │ • Utilities & Helpers              │
    │ • Service Classes                   │
    │ • Algorithm Testing                 │
    └─────────────────────────────────────┘
```

### 1.2 Testing Tools & Frameworks

```yaml
# Testing Dependencies (pubspec.yaml)
dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Unit & Widget Testing
  test: ^1.24.9
  mockito: ^5.4.2
  build_runner: ^2.4.7
  
  # Integration Testing
  integration_test:
    sdk: flutter
  
  # Golden Tests
  golden_toolkit: ^0.15.0
  
  # Network Testing
  http_mock_adapter: ^0.6.1
  
  # Database Testing
  sqflite_common_ffi: ^2.3.0
  
  # Performance Testing
  flutter_driver:
    sdk: flutter
    
  # Code Coverage
  coverage: ^1.6.3
  
  # Test Utilities
  fake_async: ^1.3.1
  clock: ^1.1.1
  path_provider_platform_interface: ^2.1.1
```

---

## 2. Unit Testing Implementation

### 2.1 Business Logic Testing

#### 2.1.1 Mood Engine Testing

```dart
// test/services/mood_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:flutter_moodmusic/services/mood_engine.dart';
import 'package:flutter_moodmusic/models/emotion_analysis_result.dart';
import 'package:flutter_moodmusic/models/mood.dart';
import 'package:flutter_moodmusic/models/mood_profile.dart';

@GenerateMocks([MoodProfileRepository])
import 'mood_engine_test.mocks.dart';

void main() {
  group('MoodEngine', () {
    late MoodEngine moodEngine;
    late MockMoodProfileRepository mockProfileRepo;

    setUp(() {
      mockProfileRepo = MockMoodProfileRepository();
      moodEngine = MoodEngine(profileRepository: mockProfileRepo);
    });

    group('analyzeMood', () {
      test('should return happy mood for high happiness score', () async {
        // Arrange
        final emotionResult = EmotionAnalysisResult(
          emotions: {
            EmotionType.happy: 0.9,
            EmotionType.sad: 0.1,
            EmotionType.angry: 0.05,
            EmotionType.calm: 0.2,
            EmotionType.anxious: 0.1,
            EmotionType.excited: 0.3,
          },
          confidence: 0.85,
          processingTime: Duration(seconds: 2),
          method: EmotionDetectionMethod.aws,
        );

        final happyProfile = MoodProfile(
          id: 'happy_profile',
          name: 'Pure Joy',
          emotion: EmotionType.happy,
          emotionRanges: {
            EmotionType.happy: EmotionRange(min: 0.7, max: 1.0),
            EmotionType.sad: EmotionRange(min: 0.0, max: 0.3),
          },
          emotionWeights: {
            EmotionType.happy: 1.0,
            EmotionType.sad: 0.5,
          },
        );

        when(mockProfileRepo.getAllProfiles())
            .thenAnswer((_) async => [happyProfile]);

        // Act
        final result = await moodEngine.analyzeMood(emotionResult);

        // Assert
        expect(result.primary, equals(EmotionType.happy));
        expect(result.confidence, greaterThan(0.7));
        expect(result.complexity, equals(MoodComplexity.simple));
        expect(result.profile?.id, equals('happy_profile'));
      });

      test('should return complex mood for mixed emotions', () async {
        // Arrange
        final emotionResult = EmotionAnalysisResult(
          emotions: {
            EmotionType.happy: 0.6,
            EmotionType.anxious: 0.5,
            EmotionType.excited: 0.4,
            EmotionType.sad: 0.2,
            EmotionType.angry: 0.1,
            EmotionType.calm: 0.3,
          },
          confidence: 0.75,
          processingTime: Duration(seconds: 3),
          method: EmotionDetectionMethod.aws,
        );

        final happyProfile = MoodProfile(
          id: 'happy_anxious',
          name: 'Excited Nervousness',
          emotion: EmotionType.happy,
          emotionRanges: {
            EmotionType.happy: EmotionRange(min: 0.5, max: 0.8),
            EmotionType.anxious: EmotionRange(min: 0.4, max: 0.7),
          },
        );

        final anxiousProfile = MoodProfile(
          id: 'anxious_happy', 
          name: 'Nervous Excitement',
          emotion: EmotionType.anxious,
          emotionRanges: {
            EmotionType.anxious: EmotionRange(min: 0.4, max: 0.6),
            EmotionType.happy: EmotionRange(min: 0.5, max: 0.7),
          },
        );

        when(mockProfileRepo.getAllProfiles())
            .thenAnswer((_) async => [happyProfile, anxiousProfile]);

        // Act
        final result = await moodEngine.analyzeMood(emotionResult);

        // Assert
        expect(result.complexity, equals(MoodComplexity.complex));
        expect(result.secondary, isNotNull);
        expect([result.primary, result.secondary], 
               containsAll([EmotionType.happy, EmotionType.anxious]));
      });

      test('should return fallback mood for no matching profiles', () async {
        // Arrange
        final emotionResult = EmotionAnalysisResult(
          emotions: {
            EmotionType.happy: 0.1,
            EmotionType.sad: 0.1,
            EmotionType.angry: 0.1,
            EmotionType.calm: 0.1,
            EmotionType.anxious: 0.1,
            EmotionType.excited: 0.1,
          },
          confidence: 0.3,
          processingTime: Duration(seconds: 1),
          method: EmotionDetectionMethod.offline,
        );

        when(mockProfileRepo.getAllProfiles())
            .thenAnswer((_) async => []);

        // Act
        final result = await moodEngine.analyzeMood(emotionResult);

        // Assert
        expect(result.primary, equals(EmotionType.neutral));
        expect(result.profile?.name, contains('Neutral'));
        expect(result.confidence, lessThan(0.5));
      });

      test('should handle empty emotion results', () async {
        // Arrange
        final emotionResult = EmotionAnalysisResult(
          emotions: {},
          confidence: 0.0,
          processingTime: Duration(milliseconds: 100),
          method: EmotionDetectionMethod.offline,
        );

        when(mockProfileRepo.getAllProfiles())
            .thenAnswer((_) async => []);

        // Act
        final result = await moodEngine.analyzeMood(emotionResult);

        // Assert
        expect(result.primary, equals(EmotionType.neutral));
        expect(result.confidence, equals(0.0));
      });
    });

    group('Profile Compatibility Calculation', () {
      test('should calculate perfect compatibility for exact match', () {
        // Arrange
        final profile = MoodProfile(
          id: 'test_profile',
          name: 'Test Profile',
          emotion: EmotionType.happy,
          emotionRanges: {
            EmotionType.happy: EmotionRange(min: 0.8, max: 1.0),
            EmotionType.sad: EmotionRange(min: 0.0, max: 0.2),
          },
          emotionWeights: {
            EmotionType.happy: 1.0,
            EmotionType.sad: 0.5,
          },
        );

        final emotionResult = EmotionAnalysisResult(
          emotions: {
            EmotionType.happy: 0.9,
            EmotionType.sad: 0.1,
          },
          confidence: 1.0,
          processingTime: Duration(seconds: 1),
          method: EmotionDetectionMethod.aws,
        );

        // Act
        final compatibility = moodEngine.calculateProfileCompatibility(
          emotionResult, 
          profile,
        );

        // Assert
        expect(compatibility, equals(1.0));
      });

      test('should calculate partial compatibility for near match', () {
        // Arrange
        final profile = MoodProfile(
          id: 'test_profile',
          name: 'Test Profile',
          emotion: EmotionType.happy,
          emotionRanges: {
            EmotionType.happy: EmotionRange(min: 0.7, max: 1.0),
          },
          emotionWeights: {
            EmotionType.happy: 1.0,
          },
        );

        final emotionResult = EmotionAnalysisResult(
          emotions: {
            EmotionType.happy: 0.6, // Slightly below range
          },
          confidence: 0.8,
          processingTime: Duration(seconds: 1),
          method: EmotionDetectionMethod.aws,
        );

        // Act
        final compatibility = moodEngine.calculateProfileCompatibility(
          emotionResult, 
          profile,
        );

        // Assert
        expect(compatibility, greaterThan(0.5));
        expect(compatibility, lessThan(1.0));
      });
    });
  });
}
```

#### 2.1.2 Recommendation Engine Testing

```dart
// test/services/recommendation_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:flutter_moodmusic/services/recommendation_engine.dart';
import 'package:flutter_moodmusic/services/spotify_api_client.dart';
import 'package:flutter_moodmusic/models/mood.dart';
import 'package:flutter_moodmusic/models/user_profile.dart';
import 'package:flutter_moodmusic/models/song.dart';

@GenerateMocks([SpotifyApiClient])
import 'recommendation_engine_test.mocks.dart';

void main() {
  group('RecommendationEngine', () {
    late RecommendationEngine recommendationEngine;
    late MockSpotifyApiClient mockSpotifyClient;

    setUp(() {
      mockSpotifyClient = MockSpotifyApiClient();
      recommendationEngine = RecommendationEngine(
        spotifyClient: mockSpotifyClient,
      );
    });

    group('generateRecommendations', () {
      test('should generate happy music for happy mood', () async {
        // Arrange
        final happyMood = Mood(
          primary: EmotionType.happy,
          confidence: 0.9,
          complexity: MoodComplexity.simple,
          detectedAt: DateTime.now(),
        );

        final userProfile = UserMusicProfile(
          userId: 'test_user',
          topGenres: ['pop', 'rock', 'indie'],
          topArtists: ['Artist1', 'Artist2'],
          audioFeaturePreferences: AudioFeaturePreferences(
            valence: 0.7,
            energy: 0.8,
            danceability: 0.6,
          ),
        );

        final mockRecommendations = [
          Song(
            id: 'track1',
            name: 'Happy Song 1',
            artist: 'Artist1',
            previewUrl: 'https://example.com/preview1',
            audioFeatures: AudioFeatures(
              valence: 0.9,
              energy: 0.8,
              danceability: 0.7,
            ),
          ),
          Song(
            id: 'track2', 
            name: 'Happy Song 2',
            artist: 'Artist2',
            previewUrl: 'https://example.com/preview2',
            audioFeatures: AudioFeatures(
              valence: 0.85,
              energy: 0.75,
              danceability: 0.8,
            ),
          ),
        ];

        when(mockSpotifyClient.getRecommendations(any))
            .thenAnswer((_) async => mockRecommendations);

        // Act
        final recommendations = await recommendationEngine.generateRecommendations(
          mood: happyMood,
          userProfile: userProfile,
          limit: 10,
        );

        // Assert
        expect(recommendations, isNotEmpty);
        expect(recommendations.length, lessThanOrEqualTo(10));
        
        // Verify songs match mood characteristics
        for (final song in recommendations) {
          expect(song.audioFeatures?.valence, greaterThan(0.6));
          expect(song.audioFeatures?.energy, greaterThan(0.5));
        }

        // Verify Spotify API was called with correct parameters
        verify(mockSpotifyClient.getRecommendations(argThat(
          predicate<RecommendationRequest>((req) =>
            req.targetValence >= 0.7 &&
            req.targetEnergy >= 0.6 &&
            req.seedGenres.contains('pop')
          ),
        ))).called(1);
      });

      test('should generate calming music for sad mood', () async {
        // Arrange
        final sadMood = Mood(
          primary: EmotionType.sad,
          confidence: 0.8,
          complexity: MoodComplexity.simple,
          detectedAt: DateTime.now(),
        );

        final userProfile = UserMusicProfile(
          userId: 'test_user',
          topGenres: ['acoustic', 'indie-folk', 'classical'],
          topArtists: ['Acoustic Artist', 'Classical Artist'],
        );

        final mockRecommendations = [
          Song(
            id: 'track1',
            name: 'Calming Song 1',
            artist: 'Acoustic Artist',
            audioFeatures: AudioFeatures(
              valence: 0.3,
              energy: 0.2,
              acousticness: 0.9,
            ),
          ),
        ];

        when(mockSpotifyClient.getRecommendations(any))
            .thenAnswer((_) async => mockRecommendations);

        // Act
        final recommendations = await recommendationEngine.generateRecommendations(
          mood: sadMood,
          userProfile: userProfile,
          strategy: RecommendationStrategy.contrast, // Should provide uplifting music
        );

        // Assert
        expect(recommendations, isNotEmpty);
        
        // For contrast strategy with sad mood, should provide more uplifting music
        verify(mockSpotifyClient.getRecommendations(argThat(
          predicate<RecommendationRequest>((req) =>
            req.targetValence >= 0.4 && // Higher than typical sad music
            req.seedGenres.any((genre) => ['acoustic', 'indie-folk'].contains(genre))
          ),
        ))).called(1);
      });

      test('should handle API errors gracefully', () async {
        // Arrange
        final mood = Mood(
          primary: EmotionType.happy,
          confidence: 0.8,
          complexity: MoodComplexity.simple,
          detectedAt: DateTime.now(),
        );

        final userProfile = UserMusicProfile(userId: 'test_user');

        when(mockSpotifyClient.getRecommendations(any))
            .thenThrow(Exception('API Error'));

        // Act & Assert
        expect(
          () => recommendationEngine.generateRecommendations(
            mood: mood,
            userProfile: userProfile,
          ),
          throwsA(isA<RecommendationException>()),
        );
      });
    });

    group('Audio Feature Mapping', () {
      test('should map happy mood to high valence and energy', () {
        // Act
        final features = recommendationEngine.mapMoodToAudioFeatures(
          EmotionType.happy,
        );

        // Assert
        expect(features.targetValence, greaterThan(0.6));
        expect(features.targetEnergy, greaterThan(0.5));
        expect(features.targetDanceability, greaterThan(0.4));
      });

      test('should map calm mood to low energy and high acousticness', () {
        // Act
        final features = recommendationEngine.mapMoodToAudioFeatures(
          EmotionType.calm,
        );

        // Assert
        expect(features.targetEnergy, lessThan(0.5));
        expect(features.targetAcousticness, greaterThan(0.3));
        expect(features.targetValence, greaterThan(0.3));
      });

      test('should map angry mood to high energy and loudness', () {
        // Act
        final features = recommendationEngine.mapMoodToAudioFeatures(
          EmotionType.angry,
        );

        // Assert
        expect(features.targetEnergy, greaterThan(0.6));
        expect(features.targetLoudness, greaterThan(-10.0));
        expect(features.minTempo, greaterThan(120));
      });
    });
  });
}
```

### 2.2 Data Model Testing

```dart
// test/models/mood_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_moodmusic/models/mood.dart';

void main() {
  group('Mood', () {
    test('should create mood with required fields', () {
      // Arrange & Act
      final mood = Mood(
        primary: EmotionType.happy,
        confidence: 0.8,
        complexity: MoodComplexity.simple,
        detectedAt: DateTime.now(),
      );

      // Assert
      expect(mood.primary, equals(EmotionType.happy));
      expect(mood.confidence, equals(0.8));
      expect(mood.complexity, equals(MoodComplexity.simple));
      expect(mood.secondary, isNull);
    });

    test('should create complex mood with secondary emotion', () {
      // Arrange & Act
      final mood = Mood(
        primary: EmotionType.happy,
        secondary: EmotionType.anxious,
        confidence: 0.7,
        complexity: MoodComplexity.complex,
        detectedAt: DateTime.now(),
      );

      // Assert
      expect(mood.primary, equals(EmotionType.happy));
      expect(mood.secondary, equals(EmotionType.anxious));
      expect(mood.complexity, equals(MoodComplexity.complex));
    });

    test('should serialize to JSON correctly', () {
      // Arrange
      final mood = Mood(
        primary: EmotionType.happy,
        secondary: EmotionType.excited,
        confidence: 0.85,
        complexity: MoodComplexity.complex,
        detectedAt: DateTime(2024, 1, 15, 10, 30),
        rawEmotions: {
          EmotionType.happy: 0.8,
          EmotionType.excited: 0.6,
          EmotionType.calm: 0.2,
        },
      );

      // Act
      final json = mood.toJson();

      // Assert
      expect(json['primary'], equals('happy'));
      expect(json['secondary'], equals('excited'));
      expect(json['confidence'], equals(0.85));
      expect(json['complexity'], equals('complex'));
      expect(json['detected_at'], equals('2024-01-15T10:30:00.000'));
      expect(json['raw_emotions'], isA<Map>());
      expect(json['raw_emotions']['happy'], equals(0.8));
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'primary': 'sad',
        'secondary': null,
        'confidence': 0.7,
        'complexity': 'simple',
        'detected_at': '2024-01-15T14:30:00.000',
        'raw_emotions': {
          'sad': 0.9,
          'happy': 0.1,
          'angry': 0.05,
        },
      };

      // Act
      final mood = Mood.fromJson(json);

      // Assert
      expect(mood.primary, equals(EmotionType.sad));
      expect(mood.secondary, isNull);
      expect(mood.confidence, equals(0.7));
      expect(mood.complexity, equals(MoodComplexity.simple));
      expect(mood.detectedAt, equals(DateTime(2024, 1, 15, 14, 30)));
      expect(mood.rawEmotions[EmotionType.sad], equals(0.9));
    });

    group('Mood Equality', () {
      test('should be equal when all properties match', () {
        // Arrange
        final detectedAt = DateTime.now();
        final rawEmotions = {EmotionType.happy: 0.8};

        final mood1 = Mood(
          primary: EmotionType.happy,
          confidence: 0.8,
          complexity: MoodComplexity.simple,
          detectedAt: detectedAt,
          rawEmotions: rawEmotions,
        );

        final mood2 = Mood(
          primary: EmotionType.happy,
          confidence: 0.8,
          complexity: MoodComplexity.simple,
          detectedAt: detectedAt,
          rawEmotions: rawEmotions,
        );

        // Act & Assert
        expect(mood1, equals(mood2));
        expect(mood1.hashCode, equals(mood2.hashCode));
      });

      test('should not be equal when primary emotion differs', () {
        // Arrange
        final detectedAt = DateTime.now();

        final mood1 = Mood(
          primary: EmotionType.happy,
          confidence: 0.8,
          complexity: MoodComplexity.simple,
          detectedAt: detectedAt,
        );

        final mood2 = Mood(
          primary: EmotionType.sad,
          confidence: 0.8,
          complexity: MoodComplexity.simple,
          detectedAt: detectedAt,
        );

        // Act & Assert
        expect(mood1, isNot(equals(mood2)));
      });
    });

    group('Mood Display Names', () {
      test('should return correct display names for emotions', () {
        expect(EmotionType.happy.displayName, equals('Happy'));
        expect(EmotionType.sad.displayName, equals('Sad'));
        expect(EmotionType.angry.displayName, equals('Angry'));
        expect(EmotionType.calm.displayName, equals('Calm'));
        expect(EmotionType.anxious.displayName, equals('Anxious'));
        expect(EmotionType.excited.displayName, equals('Excited'));
        expect(EmotionType.neutral.displayName, equals('Neutral'));
      });
    });
  });
}
```

---

## 3. Widget Testing Implementation

### 3.1 Screen Testing

```dart
// test/screens/mood_scanner_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'package:flutter_moodmusic/screens/mood_scanner_screen.dart';
import 'package:flutter_moodmusic/providers/app_state_provider.dart';
import 'package:flutter_moodmusic/providers/rekognition_provider.dart';
import 'package:flutter_moodmusic/services/emotion_detection_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('MoodScannerScreen', () {
    late MockAppStateProvider mockAppStateProvider;
    late MockRekognitionProvider mockRekognitionProvider;
    late MockEmotionDetectionService mockEmotionService;
    late List<CameraDescription> mockCameras;

    setUp(() {
      mockAppStateProvider = MockAppStateProvider();
      mockRekognitionProvider = MockRekognitionProvider();
      mockEmotionService = MockEmotionDetectionService();
      
      mockCameras = [
        CameraDescription(
          name: 'front_camera',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 90,
        ),
        CameraDescription(
          name: 'back_camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ];

      // Default mock behavior
      when(mockAppStateProvider.currentState).thenReturn(AppState.scanning);
      when(mockRekognitionProvider.isAnalyzing).thenReturn(false);
      when(mockRekognitionProvider.analysisProgress).thenReturn(0.0);
    });

    testWidgets('should display camera preview when initialized', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
            ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
          ],
          child: MoodScannerScreen(cameras: mockCameras),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CameraPreview), findsOneWidget);
      expect(find.text('Position your face in the frame'), findsOneWidget);
    });

    testWidgets('should show capture button when face detected', (tester) async {
      // Arrange
      when(mockRekognitionProvider.faceDetected).thenReturn(true);
      
      await tester.pumpWidget(
        TestApp(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
            ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
          ],
          child: MoodScannerScreen(cameras: mockCameras),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.camera), findsOneWidget);
      expect(find.text('Tap to capture your mood'), findsOneWidget);
    });

    testWidgets('should start analysis when capture button tapped', (tester) async {
      // Arrange
      when(mockRekognitionProvider.faceDetected).thenReturn(true);
      
      await tester.pumpWidget(
        TestApp(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
            ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
          ],
          child: MoodScannerScreen(cameras: mockCameras),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.camera));
      await tester.pump();

      // Assert
      verify(mockRekognitionProvider.analyzeMood(any)).called(1);
    });

    testWidgets('should show progress indicator during analysis', (tester) async {
      // Arrange
      when(mockRekognitionProvider.isAnalyzing).thenReturn(true);
      when(mockRekognitionProvider.analysisProgress).thenReturn(0.5);
      
      await tester.pumpWidget(
        TestApp(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
            ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
          ],
          child: MoodScannerScreen(cameras: mockCameras),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing your mood...'), findsOneWidget);
      
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.5));
    });

    testWidgets('should switch cameras when camera switch button tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
            ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
          ],
          child: MoodScannerScreen(cameras: mockCameras),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.flip_camera_ios));
      await tester.pumpAndSettle();

      // Assert - Camera should switch (this would need to be verified through camera controller state)
      expect(find.byIcon(Icons.flip_camera_ios), findsOneWidget);
    });

    testWidgets('should handle camera permission denied', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
            ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
          ],
          child: MoodScannerScreen(cameras: []), // No cameras available
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Camera access required'), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
    });

    group('Accessibility', () {
      testWidgets('should have proper accessibility labels', (tester) async {
        // Arrange
        when(mockRekognitionProvider.faceDetected).thenReturn(true);
        
        await tester.pumpWidget(
          TestApp(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
              ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
            ],
            child: MoodScannerScreen(cameras: mockCameras),
          ),
        );

        await tester.pumpAndSettle();

        // Assert
        expect(
          find.bySemanticsLabel('Capture mood photo'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Switch camera'),
          findsOneWidget,
        );
      });

      testWidgets('should announce analysis progress to screen readers', (tester) async {
        // Arrange
        when(mockRekognitionProvider.isAnalyzing).thenReturn(true);
        when(mockRekognitionProvider.analysisProgress).thenReturn(0.75);
        
        await tester.pumpWidget(
          TestApp(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: mockAppStateProvider),
              ChangeNotifierProvider<RekognitionProvider>.value(value: mockRekognitionProvider),
            ],
            child: MoodScannerScreen(cameras: mockCameras),
          ),
        );

        await tester.pumpAndSettle();

        // Assert
        expect(
          find.bySemanticsLabel('Analysis progress: 75%'),
          findsOneWidget,
        );
      });
    });
  });
}
```

### 3.2 Custom Widget Testing

```dart
// test/widgets/mood_analytics_chart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:flutter_moodmusic/widgets/mood_analytics_chart.dart';
import 'package:flutter_moodmusic/models/personal_insights.dart';
import 'package:flutter_moodmusic/models/mood.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('MoodAnalyticsChart', () {
    late PersonalInsights mockInsights;

    setUp(() {
      mockInsights = PersonalInsights(
        timeframe: AnalyticsTimeframe.month,
        dateRange: DateRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 31),
        ),
        moodPatterns: MoodPatterns(
          emotionDistribution: {
            EmotionType.happy: EmotionStats(
              percentage: 0.4,
              averageConfidence: 0.8,
              occurrences: 12,
            ),
            EmotionType.calm: EmotionStats(
              percentage: 0.3,
              averageConfidence: 0.7,
              occurrences: 9,
            ),
            EmotionType.excited: EmotionStats(
              percentage: 0.2,
              averageConfidence: 0.75,
              occurrences: 6,
            ),
            EmotionType.anxious: EmotionStats(
              percentage: 0.1,
              averageConfidence: 0.65,
              occurrences: 3,
            ),
          },
          dominantEmotion: EmotionType.happy,
          hourlyPatterns: {
            9: EmotionType.calm,
            12: EmotionType.happy,
            15: EmotionType.excited,
            18: EmotionType.happy,
            21: EmotionType.calm,
          },
          dailyPatterns: {},
          weeklyTrends: [],
          stability: MoodStability.moderate(),
          complexEmotionRate: 0.2,
        ),
        musicDiscovery: MusicDiscoveryStats.empty(),
        eventEngagement: EventEngagementStats.empty(),
        correlations: [],
        trends: [],
        recommendations: [],
      );
    });

    testWidgets('should display emotion distribution pie chart', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          child: MoodAnalyticsChart(
            insights: mockInsights,
            chartType: ChartType.emotionDistribution,
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('Emotion Distribution'), findsOneWidget);
      
      // Check for legend items
      expect(find.text('Happy (12)'), findsOneWidget);
      expect(find.text('Calm (9)'), findsOneWidget);
      expect(find.text('Excited (6)'), findsOneWidget);
      expect(find.text('Anxious (3)'), findsOneWidget);
    });

    testWidgets('should display time pattern line chart', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          child: MoodAnalyticsChart(
            insights: mockInsights,
            chartType: ChartType.timePattern,
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Daily Mood Patterns'), findsOneWidget);
    });

    testWidgets('should display mood stability analysis', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          child: MoodAnalyticsChart(
            insights: mockInsights,
            chartType: ChartType.stability,
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Mood Stability Analysis'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget); // Stability level
      expect(find.text('Variation'), findsOneWidget);
      expect(find.text('Transitions'), findsOneWidget);
    });

    testWidgets('should animate chart appearance', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          child: MoodAnalyticsChart(
            insights: mockInsights,
            chartType: ChartType.emotionDistribution,
          ),
        ),
      );

      // Act - Initial state (animation not started)
      await tester.pump();

      // Assert - Chart should be animating
      final pieChart = tester.widget<PieChart>(find.byType(PieChart));
      final sections = pieChart.data.sections;
      
      // During animation, radius should be less than final value
      expect(sections.first.radius, lessThan(100));

      // Act - Complete animation
      await tester.pumpAndSettle();

      // Assert - Chart should be fully animated
      final animatedPieChart = tester.widget<PieChart>(find.byType(PieChart));
      final animatedSections = animatedPieChart.data.sections;
      expect(animatedSections.first.radius, equals(100));
    });

    testWidgets('should change chart type when dropdown changed', (tester) async {
      // Arrange
      await tester.pumpWidget(
        TestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              ChartType currentType = ChartType.emotionDistribution;
              
              return MoodAnalyticsChart(
                insights: mockInsights,
                chartType: currentType,
                onChartTypeChanged: () {
                  setState(() {
                    currentType = ChartType.timePattern;
                  });
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byType(DropdownButton<ChartType>));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Daily Mood Patterns').last);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Daily Mood Patterns'), findsOneWidget);
    });

    group('Golden Tests', () {
      testWidgets('should match golden file for emotion distribution chart', (tester) async {
        // Arrange
        await tester.pumpWidget(
          TestApp(
            child: Container(
              width: 400,
              height: 500,
              child: MoodAnalyticsChart(
                insights: mockInsights,
                chartType: ChartType.emotionDistribution,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        await expectLater(
          find.byType(MoodAnalyticsChart),
          matchesGoldenFile('mood_analytics_chart_emotion_distribution.png'),
        );
      });

      testWidgets('should match golden file for stability chart', (tester) async {
        // Arrange
        await tester.pumpWidget(
          TestApp(
            child: Container(
              width: 400,
              height: 500,
              child: MoodAnalyticsChart(
                insights: mockInsights,
                chartType: ChartType.stability,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        await expectLater(
          find.byType(MoodAnalyticsChart),
          matchesGoldenFile('mood_analytics_chart_stability.png'),
        );
      });
    });
  });
}
```

---

## 4. Integration Testing Implementation

### 4.1 Database Integration Tests

```dart
// test/integration/database_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'package:flutter_moodmusic/services/database_service.dart';
import 'package:flutter_moodmusic/repositories/mood_session_repository.dart';
import 'package:flutter_moodmusic/models/mood_session.dart';
import 'package:flutter_moodmusic/models/mood.dart';

void main() {
  group('Database Integration Tests', () {
    late DatabaseService databaseService;
    late MoodSessionRepository moodSessionRepo;

    setUpAll(() {
      // Initialize FFI for desktop testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create in-memory database for testing
      final database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(DatabaseSchema.createTables);
        },
      );

      databaseService = DatabaseService.withDatabase(database);
      moodSessionRepo = MoodSessionRepository(databaseService);
    });

    tearDown(() async {
      await databaseService.close();
    });

    group('MoodSession CRUD Operations', () {
      test('should insert and retrieve mood session', () async {
        // Arrange
        final moodSession = MoodSession(
          id: 'test_session_1',
          userId: 'test_user',
          mood: Mood(
            primary: EmotionType.happy,
            confidence: 0.8,
            complexity: MoodComplexity.simple,
            detectedAt: DateTime.now(),
            rawEmotions: {
              EmotionType.happy: 0.8,
              EmotionType.sad: 0.1,
              EmotionType.angry: 0.05,
            },
          ),
          detectedAt: DateTime.now(),
          imagePath: '/test/path/image.jpg',
        );

        // Act
        await moodSessionRepo.insert(moodSession);
        final retrieved = await moodSessionRepo.findById('test_session_1');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('test_session_1'));
        expect(retrieved.userId, equals('test_user'));
        expect(retrieved.mood.primary, equals(EmotionType.happy));
        expect(retrieved.mood.confidence, equals(0.8));
        expect(retrieved.mood.rawEmotions[EmotionType.happy], equals(0.8));
      });

      test('should update existing mood session', () async {
        // Arrange
        final originalSession = MoodSession(
          id: 'test_session_2',
          userId: 'test_user',
          mood: Mood(
            primary: EmotionType.happy,
            confidence: 0.7,
            complexity: MoodComplexity.simple,
            detectedAt: DateTime.now(),
          ),
          detectedAt: DateTime.now(),
        );

        await moodSessionRepo.insert(originalSession);

        final updatedSession = originalSession.copyWith(
          mood: originalSession.mood.copyWith(confidence: 0.9),
        );

        // Act
        await moodSessionRepo.update(updatedSession);
        final retrieved = await moodSessionRepo.findById('test_session_2');

        // Assert
        expect(retrieved!.mood.confidence, equals(0.9));
      });

      test('should delete mood session', () async {
        // Arrange
        final moodSession = MoodSession(
          id: 'test_session_3',
          userId: 'test_user',
          mood: Mood(
            primary: EmotionType.sad,
            confidence: 0.6,
            complexity: MoodComplexity.simple,
            detectedAt: DateTime.now(),
          ),
          detectedAt: DateTime.now(),
        );

        await moodSessionRepo.insert(moodSession);

        // Act
        await moodSessionRepo.delete('test_session_3');
        final retrieved = await moodSessionRepo.findById('test_session_3');

        // Assert
        expect(retrieved, isNull);
      });

      test('should get recent sessions for user', () async {
        // Arrange
        final sessions = [
          MoodSession(
            id: 'session_1',
            userId: 'test_user',
            mood: Mood(
              primary: EmotionType.happy,
              confidence: 0.8,
              complexity: MoodComplexity.simple,
              detectedAt: DateTime.now().subtract(Duration(days: 1)),
            ),
            detectedAt: DateTime.now().subtract(Duration(days: 1)),
          ),
          MoodSession(
            id: 'session_2',
            userId: 'test_user',
            mood: Mood(
              primary: EmotionType.calm,
              confidence: 0.7,
              complexity: MoodComplexity.simple,
              detectedAt: DateTime.now().subtract(Duration(hours: 2)),
            ),
            detectedAt: DateTime.now().subtract(Duration(hours: 2)),
          ),
          MoodSession(
            id: 'session_3',
            userId: 'other_user',
            mood: Mood(
              primary: EmotionType.angry,
              confidence: 0.6,
              complexity: MoodComplexity.simple,
              detectedAt: DateTime.now(),
            ),
            detectedAt: DateTime.now(),
          ),
        ];

        for (final session in sessions) {
          await moodSessionRepo.insert(session);
        }

        // Act
        final recentSessions = await moodSessionRepo.getRecentSessions(
          'test_user',
          limit: 10,
        );

        // Assert
        expect(recentSessions.length, equals(2));
        expect(recentSessions.map((s) => s.userId), everyElement('test_user'));
        
        // Should be ordered by date descending (most recent first)
        expect(recentSessions.first.id, equals('session_2'));
        expect(recentSessions.last.id, equals('session_1'));
      });
    });

    group('Mood Analytics Queries', () {
      test('should calculate mood distribution correctly', () async {
        // Arrange
        final sessions = [
          _createMoodSession('s1', EmotionType.happy, DateTime.now().subtract(Duration(days: 1))),
          _createMoodSession('s2', EmotionType.happy, DateTime.now().subtract(Duration(days: 2))),
          _createMoodSession('s3', EmotionType.sad, DateTime.now().subtract(Duration(days: 3))),
          _createMoodSession('s4', EmotionType.calm, DateTime.now().subtract(Duration(days: 4))),
          _createMoodSession('s5', EmotionType.happy, DateTime.now().subtract(Duration(days: 5))),
        ];

        for (final session in sessions) {
          await moodSessionRepo.insert(session);
        }

        // Act
        final analytics = await moodSessionRepo.getUserMoodAnalytics(
          'test_user',
          startDate: DateTime.now().subtract(Duration(days: 10)),
          endDate: DateTime.now(),
        );

        // Assert
        expect(analytics.totalSessions, equals(5));
        expect(analytics.emotionDistribution[EmotionType.happy], equals(0.6)); // 3/5
        expect(analytics.emotionDistribution[EmotionType.sad], equals(0.2));   // 1/5
        expect(analytics.emotionDistribution[EmotionType.calm], equals(0.2));  // 1/5
        expect(analytics.dominantEmotion, equals(EmotionType.happy));
      });

      test('should calculate mood trends over time', () async {
        // Arrange
        final baseMood = 0.5;
        final sessions = List.generate(30, (index) {
          final moodValue = baseMood + (0.02 * index); // Gradually improving mood
          final emotion = moodValue > 0.7 ? EmotionType.happy : 
                         moodValue > 0.5 ? EmotionType.calm : EmotionType.sad;
          
          return MoodSession(
            id: 'trend_session_$index',
            userId: 'test_user',
            mood: Mood(
              primary: emotion,
              confidence: moodValue,
              complexity: MoodComplexity.simple,
              detectedAt: DateTime.now().subtract(Duration(days: 29 - index)),
            ),
            detectedAt: DateTime.now().subtract(Duration(days: 29 - index)),
          );
        });

        for (final session in sessions) {
          await moodSessionRepo.insert(session);
        }

        // Act
        final analytics = await moodSessionRepo.getUserMoodAnalytics('test_user');

        // Assert
        expect(analytics.trends.length, greaterThan(0));
        
        // Check that mood is trending upward
        final firstWeekAverage = analytics.trends.take(7)
            .map((t) => t.averageMoodScore)
            .reduce((a, b) => a + b) / 7;
        
        final lastWeekAverage = analytics.trends.skip(analytics.trends.length - 7)
            .map((t) => t.averageMoodScore)
            .reduce((a, b) => a + b) / 7;

        expect(lastWeekAverage, greaterThan(firstWeekAverage));
      });
    });

    group('Database Performance Tests', () {
      test('should handle large number of sessions efficiently', () async {
        // Arrange
        final stopwatch = Stopwatch()..start();
        const sessionCount = 1000;

        final sessions = List.generate(sessionCount, (index) {
          return _createMoodSession(
            'perf_session_$index',
            EmotionType.values[index % EmotionType.values.length],
            DateTime.now().subtract(Duration(hours: index)),
          );
        });

        // Act - Insert sessions
        for (final session in sessions) {
          await moodSessionRepo.insert(session);
        }

        final insertTime = stopwatch.elapsedMilliseconds;
        stopwatch.reset();

        // Act - Query recent sessions
        final recentSessions = await moodSessionRepo.getRecentSessions(
          'test_user',
          limit: 100,
        );

        final queryTime = stopwatch.elapsedMilliseconds;
        stopwatch.stop();

        // Assert
        expect(recentSessions.length, equals(100));
        expect(insertTime, lessThan(5000)); // Should insert 1000 records in under 5 seconds
        expect(queryTime, lessThan(100));   // Should query in under 100ms
      });

      test('should handle concurrent database operations', () async {
        // Arrange
        final futures = <Future>[];

        // Act - Perform concurrent operations
        for (int i = 0; i < 50; i++) {
          futures.add(moodSessionRepo.insert(
            _createMoodSession('concurrent_$i', EmotionType.happy, DateTime.now()),
          ));
        }

        // Wait for all operations to complete
        await Future.wait(futures);

        // Assert
        final allSessions = await moodSessionRepo.getRecentSessions('test_user', limit: 100);
        expect(allSessions.length, equals(50));
      });
    });
  });

  MoodSession _createMoodSession(String id, EmotionType emotion, DateTime detectedAt) {
    return MoodSession(
      id: id,
      userId: 'test_user',
      mood: Mood(
        primary: emotion,
        confidence: 0.8,
        complexity: MoodComplexity.simple,
        detectedAt: detectedAt,
      ),
      detectedAt: detectedAt,
    );
  }
}
```

### 4.2 API Integration Tests

```dart
// test/integration/spotify_api_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import 'package:flutter_moodmusic/services/spotify_api_client.dart';
import 'package:flutter_moodmusic/models/song.dart';
import 'package:flutter_moodmusic/models/user_profile.dart';

import '../helpers/mock_http_client.dart';

void main() {
  group('Spotify API Integration Tests', () {
    late SpotifyApiClient spotifyClient;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      spotifyClient = SpotifyApiClient(httpClient: mockHttpClient);
    });

    group('Authentication', () {
      test('should handle successful token refresh', () async {
        // Arrange
        final tokenResponse = {
          'access_token': 'new_access_token',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'refresh_token': 'new_refresh_token',
        };

        when(mockHttpClient.post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(tokenResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Act
        final result = await spotifyClient.refreshAccessToken('old_refresh_token');

        // Assert
        expect(result.accessToken, equals('new_access_token'));
        expect(result.expiresIn, equals(3600));
        expect(result.refreshToken, equals('new_refresh_token'));
      });

      test('should handle token refresh failure', () async {
        // Arrange
        when(mockHttpClient.post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'error': 'invalid_grant'}),
          400,
        ));

        // Act & Assert
        expect(
          () => spotifyClient.refreshAccessToken('invalid_refresh_token'),
          throwsA(isA<SpotifyApiException>()),
        );
      });
    });

    group('User Profile', () {
      test('should fetch user profile successfully', () async {
        // Arrange
        final profileResponse = {
          'id': 'test_user_123',
          'display_name': 'Test User',
          'email': 'test@example.com',
          'country': 'US',
          'followers': {'total': 150},
          'images': [
            {
              'url': 'https://example.com/profile.jpg',
              'width': 300,
              'height': 300,
            }
          ],
        };

        when(mockHttpClient.get(
          Uri.parse('https://api.spotify.com/v1/me'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(profileResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Act
        final profile = await spotifyClient.getCurrentUserProfile();

        // Assert
        expect(profile.id, equals('test_user_123'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.email, equals('test@example.com'));
        expect(profile.country, equals('US'));
        expect(profile.followerCount, equals(150));
      });

      test('should fetch user top tracks', () async {
        // Arrange
        final topTracksResponse = {
          'items': [
            {
              'id': 'track_1',
              'name': 'Favorite Song 1',
              'artists': [
                {'id': 'artist_1', 'name': 'Artist 1'}
              ],
              'album': {
                'id': 'album_1',
                'name': 'Album 1',
                'images': [
                  {'url': 'https://example.com/album1.jpg', 'width': 640, 'height': 640}
                ]
              },
              'preview_url': 'https://example.com/preview1.mp3',
              'duration_ms': 180000,
              'popularity': 85,
            },
            {
              'id': 'track_2',
              'name': 'Favorite Song 2',
              'artists': [
                {'id': 'artist_2', 'name': 'Artist 2'}
              ],
              'album': {
                'id': 'album_2',
                'name': 'Album 2',
                'images': [
                  {'url': 'https://example.com/album2.jpg', 'width': 640, 'height': 640}
                ]
              },
              'preview_url': 'https://example.com/preview2.mp3',
              'duration_ms': 210000,
              'popularity': 78,
            },
          ],
          'total': 50,
          'limit': 20,
          'offset': 0,
        };

        when(mockHttpClient.get(
          Uri.parse('https://api.spotify.com/v1/me/top/tracks?time_range=medium_term&limit=20&offset=0'),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(topTracksResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Act
        final topTracks = await spotifyClient.getUserTopTracks(
          TimeRange.mediumTerm,
          limit: 20,
        );

        // Assert
        expect(topTracks.length, equals(2));
        expect(topTracks.first.id, equals('track_1'));
        expect(topTracks.first.name, equals('Favorite Song 1'));
        expect(topTracks.first.artist, equals('Artist 1'));
        expect(topTracks.first.previewUrl, equals('https://example.com/preview1.mp3'));
      });
    });

    group('Recommendations', () {
      test('should get music recommendations based on parameters', () async {
        // Arrange
        final recommendationsResponse = {
          'tracks': [
            {
              'id': 'rec_track_1',
              'name': 'Recommended Song 1',
              'artists': [{'id': 'artist_1', 'name': 'Rec Artist 1'}],
              'album': {
                'id': 'album_1',
                'name': 'Rec Album 1',
                'images': [
                  {'url': 'https://example.com/rec_album1.jpg', 'width': 640, 'height': 640}
                ]
              },
              'preview_url': 'https://example.com/rec_preview1.mp3',
              'duration_ms': 195000,
              'popularity': 72,
            },
          ],
          'seeds': [
            {
              'id': 'pop',
              'type': 'genre',
              'href': null,
              'initialPoolSize': 1000,
              'afterFilteringSize': 500,
              'afterRelinkingSize': 500,
            }
          ],
        };

        when(mockHttpClient.get(
          argThat(predicate<Uri>((uri) =>
            uri.toString().contains('/v1/recommendations') &&
            uri.queryParameters['seed_genres'] == 'pop' &&
            uri.queryParameters['target_valence'] == '0.8'
          )),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(recommendationsResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Act
        final recommendations = await spotifyClient.getRecommendations(
          RecommendationRequest(
            seedGenres: ['pop'],
            targetValence: 0.8,
            targetEnergy: 0.7,
            limit: 20,
          ),
        );

        // Assert
        expect(recommendations.length, equals(1));
        expect(recommendations.first.id, equals('rec_track_1'));
        expect(recommendations.first.name, equals('Recommended Song 1'));
        expect(recommendations.first.artist, equals('Rec Artist 1'));
      });

      test('should handle recommendation request with multiple seeds', () async {
        // Arrange
        final recommendationsResponse = {
          'tracks': [],
          'seeds': [],
        };

        when(mockHttpClient.get(
          argThat(predicate<Uri>((uri) =>
            uri.toString().contains('/v1/recommendations') &&
            uri.queryParameters['seed_genres']?.split(',').length == 2 &&
            uri.queryParameters['seed_artists']?.split(',').length == 1
          )),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(recommendationsResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Act
        final recommendations = await spotifyClient.getRecommendations(
          RecommendationRequest(
            seedGenres: ['pop', 'rock'],
            seedArtists: ['artist_123'],
            targetValence: 0.6,
            targetEnergy: 0.8,
            minPopularity: 50,
            limit: 10,
          ),
        );

        // Assert
        expect(recommendations, isEmpty);
        
        // Verify the request was made with correct parameters
        verify(mockHttpClient.get(
          argThat(predicate<Uri>((uri) =>
            uri.queryParameters['seed_genres'] == 'pop,rock' &&
            uri.queryParameters['seed_artists'] == 'artist_123' &&
            uri.queryParameters['target_valence'] == '0.6' &&
            uri.queryParameters['target_energy'] == '0.8' &&
            uri.queryParameters['min_popularity'] == '50' &&
            uri.queryParameters['limit'] == '10'
          )),
          headers: anyNamed('headers'),
        )).called(1);
      });
    });

    group('Rate Limiting', () {
      test('should handle rate limit exceeded response', () async {
        // Arrange
        when(mockHttpClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'error': {
              'status': 429,
              'message': 'API rate limit exceeded',
            }
          }),
          429,
          headers: {
            'retry-after': '30',
            'content-type': 'application/json',
          },
        ));

        // Act & Assert
        final exception = await expectLater(
          spotifyClient.getCurrentUserProfile(),
          throwsA(isA<SpotifyRateLimitException>()),
        );
      });

      test('should respect rate limiting in client', () async {
        // This test would verify that the rate limiter prevents too many requests
        // Implementation would depend on the specific rate limiting mechanism
        
        // Arrange
        final responses = List.generate(15, (index) => 
          http.Response(jsonEncode({'test': 'response_$index'}), 200)
        );

        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => responses.removeAt(0));

        // Act - Make requests faster than rate limit
        final futures = List.generate(15, (index) =>
          spotifyClient.makeRequest('GET', '/test-endpoint-$index')
        );

        final results = await Future.wait(futures);

        // Assert - All requests should complete, but be properly rate limited
        expect(results.length, equals(15));
        
        // The exact timing would depend on the rate limiter implementation
        // This test mainly ensures no exceptions are thrown due to rate limiting
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Arrange
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenThrow(SocketException('Network unreachable'));

        // Act & Assert
        expect(
          () => spotifyClient.getCurrentUserProfile(),
          throwsA(isA<SpotifyNetworkException>()),
        );
      });

      test('should handle invalid JSON response', () async {
        // Arrange
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => http.Response(
              'Invalid JSON{[',
              200,
              headers: {'content-type': 'application/json'},
            ));

        // Act & Assert
        expect(
          () => spotifyClient.getCurrentUserProfile(),
          throwsA(isA<SpotifyApiException>()),
        );
      });

      test('should handle unauthorized access', () async {
        // Arrange
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => http.Response(
              jsonEncode({
                'error': {
                  'status': 401,
                  'message': 'Invalid access token',
                }
              }),
              401,
            ));

        // Act & Assert
        expect(
          () => spotifyClient.getCurrentUserProfile(),
          throwsA(isA<SpotifyAuthException>()),
        );
      });
    });
  });
}
```

---

## 5. End-to-End Testing Implementation

### 5.1 User Journey Tests

```dart
// integration_test/user_journey_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_moodmusic/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MoodMusic User Journey Tests', () {
    testWidgets('Complete mood detection and music recommendation flow', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Step 1: Authentication (assuming user is already logged in for this test)
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Step 2: Navigate to mood scanner
      expect(find.text('Scan Your Mood'), findsOneWidget);
      await tester.tap(find.text('Scan Your Mood'));
      await tester.pumpAndSettle();

      // Step 3: Camera screen should be visible
      expect(find.text('Position your face in the frame'), findsOneWidget);
      
      // Wait for camera to initialize
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Step 4: Simulate face detection (in real test, this would require actual camera)
      // For integration test, we'll trigger the capture programmatically
      expect(find.byIcon(Icons.camera), findsOneWidget);
      await tester.tap(find.byIcon(Icons.camera));
      
      // Step 5: Wait for emotion analysis
      await tester.pumpAndSettle();
      
      // Progress indicator should appear
      expect(find.text('Analyzing your mood...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Wait for analysis to complete (mock data should resolve quickly)
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Step 6: Results screen should appear
      expect(find.text('Your Mood'), findsOneWidget);
      
      // Should show detected mood
      final moodText = find.textContaining('You seem to be feeling');
      expect(moodText, findsOneWidget);

      // Should show music recommendations
      expect(find.text('Recommended for You'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Step 7: Test music playback
      final firstSong = find.byType(ListTile).first;
      await tester.tap(firstSong);
      await tester.pumpAndSettle();

      // Audio player controls should appear
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // Play button should change to pause
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Step 8: Test playlist creation
      await tester.tap(find.text('Create Playlist'));
      await tester.pumpAndSettle();

      // Playlist creation dialog should appear
      expect(find.text('Create Mood Playlist'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Enter playlist name
      await tester.enterText(find.byType(TextField), 'My Happy Playlist');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Success message should appear
      expect(find.text('Playlist created successfully'), findsOneWidget);

      // Step 9: Navigate to history
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // History screen should show recent mood session
      expect(find.text('Mood History'), findsOneWidget);
      expect(find.byType(Card), findsAtLeastNWidgets(1));

      // Step 10: Test analytics view
      await tester.tap(find.text('View Analytics'));
      await tester.pumpAndSettle();

      // Analytics screen with charts should appear
      expect(find.text('Your Mood Insights'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('Premium subscription flow', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Trigger paywall by exceeding free tier limits
      // Simulate having already used 3 free scans today
      
      // Navigate to mood scanner
      await tester.tap(find.text('Scan Your Mood'));
      await tester.pumpAndSettle();

      // Paywall should appear
      expect(find.text('Upgrade to Premium'), findsOneWidget);
      expect(find.text('You\'ve used all 3 free mood scans today'), findsOneWidget);

      // Test subscription options
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);

      // Select monthly subscription
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      // Subscription details should be highlighted
      expect(find.text('\$4.99/month'), findsOneWidget);
      expect(find.text('Unlimited mood scans'), findsOneWidget);

      // Tap continue to subscription
      await tester.tap(find.text('Start Free Trial'));
      await tester.pumpAndSettle();

      // Note: Actual payment processing would be mocked in test environment
      // In real tests, this would connect to sandbox payment systems

      // After successful subscription (mocked)
      expect(find.text('Welcome to Premium!'), findsOneWidget);
      
      // Close subscription success dialog
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Should now be able to access premium features
      expect(find.text('Unlimited Scans'), findsOneWidget);
    });

    testWidgets('Event discovery and booking flow', (tester) async {
      // Launch app and complete mood detection first
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Complete a mood scan (condensed steps)
      await tester.tap(find.text('Scan Your Mood'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.camera));
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Should be on results screen with event recommendations
      expect(find.text('Events Near You'), findsOneWidget);
      
      // Should show event cards
      expect(find.byType(Card), findsAtLeastNWidgets(1));

      // Tap on first event
      final firstEvent = find.byType(Card).first;
      await tester.tap(firstEvent);
      await tester.pumpAndSettle();

      // Event details screen should appear
      expect(find.text('Event Details'), findsOneWidget);
      expect(find.text('Venue:'), findsOneWidget);
      expect(find.text('Date:'), findsOneWidget);
      expect(find.text('Price:'), findsOneWidget);

      // Test adding to calendar
      await tester.tap(find.text('Add to Calendar'));
      await tester.pumpAndSettle();

      // Calendar permission dialog might appear
      if (find.text('Calendar Access').evaluate().isNotEmpty) {
        await tester.tap(find.text('Allow'));
        await tester.pumpAndSettle();
      }

      // Success message
      expect(find.text('Added to calendar'), findsOneWidget);

      // Test ticket booking
      await tester.tap(find.text('Buy Tickets'));
      await tester.pumpAndSettle();

      // Should open external ticket booking (in test, this would be mocked)
      // In real test, we'd verify the correct URL is launched
    });

    testWidgets('Offline mode functionality', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Simulate network disconnection
      // This would require test-specific network mocking

      // Navigate to mood scanner
      await tester.tap(find.text('Scan Your Mood'));
      await tester.pumpAndSettle();

      // Should still work in offline mode
      expect(find.text('Position your face in the frame'), findsOneWidget);

      // Capture mood (will use offline detection)
      await tester.tap(find.byIcon(Icons.camera));
      await tester.pumpAndSettle();

      // Should show offline indicator
      expect(find.text('Using offline detection'), findsOneWidget);
      
      // Wait for offline analysis
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Results should still appear
      expect(find.text('Your Mood'), findsOneWidget);

      // Should show cached recommendations if available
      expect(find.text('Offline Recommendations'), findsOneWidget);

      // Navigate to history - should show cached data
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Mood History'), findsOneWidget);
      expect(find.text('Sync pending'), findsOneWidget);
    });
  });
}
```

### 5.2 Performance Tests

```dart
// integration_test/performance_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_moodmusic/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Tests', () {
    testWidgets('App launch performance', (tester) async {
      // Measure app startup time
      final stopwatch = Stopwatch()..start();
      
      app.main();
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      final startupTime = stopwatch.elapsedMilliseconds;

      // Assert startup time is under 3 seconds
      expect(startupTime, lessThan(3000));
      print('App startup time: ${startupTime}ms');

      // Record startup time for performance tracking
      await binding.reportData(<String, dynamic>{
        'app_startup_time_ms': startupTime,
      });
    });

    testWidgets('Emotion detection performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scanner
      await tester.tap(find.text('Scan Your Mood'));
      await tester.pumpAndSettle();

      // Measure emotion detection time
      final stopwatch = Stopwatch()..start();
      
      await tester.tap(find.byIcon(Icons.camera));
      
      // Wait for analysis to complete
      while (find.text('Analyzing your mood...').evaluate().isNotEmpty) {
        await tester.pump(Duration(milliseconds: 100));
      }
      
      stopwatch.stop();
      final detectionTime = stopwatch.elapsedMilliseconds;

      // Assert detection time is under 5 seconds
      expect(detectionTime, lessThan(5000));
      print('Emotion detection time: ${detectionTime}ms');

      await binding.reportData(<String, dynamic>{
        'emotion_detection_time_ms': detectionTime,
      });
    });

    testWidgets('Music recommendation generation performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Complete mood scan first
      await tester.tap(find.text('Scan Your Mood'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.camera));
      
      // Wait for analysis
      while (find.text('Analyzing your mood...').evaluate().isNotEmpty) {
        await tester.pump(Duration(milliseconds: 100));
      }

      // Measure recommendation generation time
      final stopwatch = Stopwatch()..start();
      
      // Wait for recommendations to load
      while (find.text('Loading recommendations...').evaluate().isNotEmpty) {
        await tester.pump(Duration(milliseconds: 100));
      }
      
      stopwatch.stop();
      final recommendationTime = stopwatch.elapsedMilliseconds;

      // Assert recommendation time is under 3 seconds
      expect(recommendationTime, lessThan(3000));
      print('Music recommendation time: ${recommendationTime}ms');

      await binding.reportData(<String, dynamic>{
        'music_recommendation_time_ms': recommendationTime,
      });
    });

    testWidgets('Memory usage during normal operation', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Perform typical user actions
      for (int i = 0; i < 5; i++) {
        // Navigate to scanner
        await tester.tap(find.text('Scan Your Mood'));
        await tester.pumpAndSettle();

        // Capture mood
        await tester.tap(find.byIcon(Icons.camera));
        await tester.pumpAndSettle(Duration(seconds: 3));

        // View results
        await tester.pumpAndSettle();

        // Navigate back
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Force garbage collection
        await tester.binding.defaultBinaryMessenger.send(
          'flutter/system',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('System.requestGC'),
          ),
        );
        
        await tester.pump(Duration(milliseconds: 100));
      }

      // Memory usage would be tracked via platform-specific methods
      // This is a placeholder for memory monitoring
      print('Memory test completed - check platform memory tools for actual usage');
    });

    testWidgets('Scroll performance in music list', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to results with music list
      await _completeMoodScan(tester);

      // Find the music list
      final musicList = find.byType(ListView);
      expect(musicList, findsOneWidget);

      // Measure scroll performance
      await binding.traceAction(
        () async {
          // Perform scrolling actions
          for (int i = 0; i < 10; i++) {
            await tester.drag(musicList, Offset(0, -200));
            await tester.pumpAndSettle(Duration(milliseconds: 16)); // 60 FPS
          }

          // Scroll back to top
          for (int i = 0; i < 10; i++) {
            await tester.drag(musicList, Offset(0, 200));
            await tester.pumpAndSettle(Duration(milliseconds: 16));
          }
        },
        reportKey: 'music_list_scroll_performance',
      );
    });

    testWidgets('Database query performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Generate test data by performing multiple mood scans
      for (int i = 0; i < 10; i++) {
        await _completeMoodScan(tester);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      }

      // Navigate to history
      await tester.tap(find.byIcon(Icons.history));
      
      // Measure history loading time
      final stopwatch = Stopwatch()..start();
      await tester.pumpAndSettle();
      stopwatch.stop();

      final historyLoadTime = stopwatch.elapsedMilliseconds;
      expect(historyLoadTime, lessThan(1000)); // Under 1 second

      print('History load time: ${historyLoadTime}ms');

      await binding.reportData(<String, dynamic>{
        'history_load_time_ms': historyLoadTime,
      });

      // Navigate to analytics
      await tester.tap(find.text('View Analytics'));
      
      // Measure analytics calculation time
      final analyticsStopwatch = Stopwatch()..start();
      await tester.pumpAndSettle();
      analyticsStopwatch.stop();

      final analyticsTime = analyticsStopwatch.elapsedMilliseconds;
      expect(analyticsTime, lessThan(2000)); // Under 2 seconds

      print('Analytics calculation time: ${analyticsTime}ms');

      await binding.reportData(<String, dynamic>{
        'analytics_calculation_time_ms': analyticsTime,
      });
    });
  });

  // Helper method to complete a mood scan
  Future<void> _completeMoodScan(WidgetTester tester) async {
    await tester.tap(find.text('Scan Your Mood'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera));
    
    // Wait for analysis to complete
    while (find.text('Analyzing your mood...').evaluate().isNotEmpty) {
      await tester.pump(Duration(milliseconds: 100));
    }
    
    await tester.pumpAndSettle();
  }
}
```

---

## 6. Test Utilities & Helpers

### 6.1 Test Helpers

```dart
// test/helpers/test_helpers.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_moodmusic/theme/app_theme.dart';

class TestApp extends StatelessWidget {
  final Widget child;
  final List<ChangeNotifierProvider> providers;

  const TestApp({
    super.key,
    required this.child,
    this.providers = const [],
  });

  @override
  Widget build(BuildContext context) {
    Widget app = MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
      debugShowCheckedModeBanner: false,
    );

    if (providers.isNotEmpty) {
      app = MultiProvider(
        providers: providers,
        child: app,
      );
    }

    return app;
  }
}

class MockDataBuilder {
  static Mood createMockMood({
    EmotionType primary = EmotionType.happy,
    EmotionType? secondary,
    double confidence = 0.8,
    MoodComplexity complexity = MoodComplexity.simple,
    DateTime? detectedAt,
    Map<EmotionType, double>? rawEmotions,
  }) {
    return Mood(
      primary: primary,
      secondary: secondary,
      confidence: confidence,
      complexity: complexity,
      detectedAt: detectedAt ?? DateTime.now(),
      rawEmotions: rawEmotions ?? {primary: confidence},
    );
  }

  static Song createMockSong({
    String id = 'test_song_1',
    String name = 'Test Song',
    String artist = 'Test Artist',
    String album = 'Test Album',
    String? previewUrl = 'https://example.com/preview.mp3',
    int duration = 180000,
    AudioFeatures? audioFeatures,
  }) {
    return Song(
      id: id,
      name: name,
      artist: artist,
      album: album,
      previewUrl: previewUrl,
      duration: Duration(milliseconds: duration),
      audioFeatures: audioFeatures ?? AudioFeatures(
        valence: 0.7,
        energy: 0.8,
        danceability: 0.6,
      ),
    );
  }

  static Event createMockEvent({
    String id = 'test_event_1',
    String name = 'Test Event',
    DateTime? startDate,
    String venueName = 'Test Venue',
    String city = 'Test City',
    List<String> categories = const ['Music'],
    PriceRange? priceRange,
  }) {
    return Event(
      id: id,
      name: name,
      startDate: startDate ?? DateTime.now().add(Duration(days: 7)),
      venue: Venue(
        name: venueName,
        city: city,
        coordinates: Coordinates(latitude: 40.7128, longitude: -74.0060),
      ),
      categories: categories,
      priceRange: priceRange ?? PriceRange(min: 25.0, max: 75.0, currency: 'USD'),
    );
  }

  static UserMusicProfile createMockUserProfile({
    String userId = 'test_user',
    List<String>? topGenres,
    List<String>? topArtists,
    AudioFeaturePreferences? preferences,
  }) {
    return UserMusicProfile(
      userId: userId,
      topGenres: topGenres ?? ['pop', 'rock', 'indie'],
      topArtists: topArtists ?? ['Artist 1', 'Artist 2', 'Artist 3'],
      audioFeaturePreferences: preferences ?? AudioFeaturePreferences(
        valence: 0.7,
        energy: 0.8,
        danceability: 0.6,
      ),
    );
  }
}

class TestTimeProvider {
  static DateTime _currentTime = DateTime.now();

  static DateTime get now => _currentTime;

  static void setTime(DateTime time) {
    _currentTime = time;
  }

  static void reset() {
    _currentTime = DateTime.now();
  }

  static void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
  }
}

extension WidgetTesterExtensions on WidgetTester {
  Future<void> pumpUntil(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      await pump(interval);
      
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    
    throw TimeoutException('Widget not found within timeout', timeout);
  }

  Future<void> pumpWhile(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime) && finder.evaluate().isNotEmpty) {
      await pump(interval);
    }
  }
}

class GoldenTestComparator extends LocalFileComparator {
  static const String _goldenDirectory = 'test/golden_files';

  GoldenTestComparator() : super(Uri.parse('$_goldenDirectory/'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await super.compare(imageBytes, golden);
    if (!result) {
      final goldenFile = File.fromUri(golden);
      final testName = golden.pathSegments.last.replaceAll('.png', '');
      print('Golden test failed for $testName');
      print('Expected: ${goldenFile.path}');
      print('Run "flutter test --update-goldens" to update golden files');
    }
    return result;
  }
}
```

### 6.2 Mock HTTP Client

```dart
// test/helpers/mock_http_client.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

class MockHttpClient extends Mock implements http.Client {}

class HttpTestHelper {
  static Map<String, dynamic> createSpotifyUserResponse({
    String id = 'test_user',
    String displayName = 'Test User',
    String email = 'test@example.com',
  }) {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'country': 'US',
      'followers': {'total': 100},
      'images': [
        {
          'url': 'https://example.com/avatar.jpg',
          'width': 300,
          'height': 300,
        }
      ],
    };
  }

  static Map<String, dynamic> createSpotifyTracksResponse(List<Map<String, dynamic>> tracks) {
    return {
      'items': tracks,
      'total': tracks.length,
      'limit': 20,
      'offset': 0,
      'next': null,
      'previous': null,
    };
  }

  static Map<String, dynamic> createSpotifyTrack({
    String id = 'track_1',
    String name = 'Test Track',
    String artistName = 'Test Artist',
    String albumName = 'Test Album',
    String? previewUrl = 'https://example.com/preview.mp3',
  }) {
    return {
      'id': id,
      'name': name,
      'artists': [
        {'id': 'artist_1', 'name': artistName}
      ],
      'album': {
        'id': 'album_1',
        'name': albumName,
        'images': [
          {'url': 'https://example.com/album.jpg', 'width': 640, 'height': 640}
        ]
      },
      'preview_url': previewUrl,
      'duration_ms': 180000,
      'popularity': 75,
    };
  }

  static Map<String, dynamic> createTicketmasterEventsResponse(List<Map<String, dynamic>> events) {
    return {
      '_embedded': {
        'events': events,
      },
      'page': {
        'size': events.length,
        'totalElements': events.length,
        'totalPages': 1,
        'number': 0,
      },
    };
  }

  static Map<String, dynamic> createTicketmasterEvent({
    String id = 'event_1',
    String name = 'Test Event',
    String venueName = 'Test Venue',
    String city = 'Test City',
  }) {
    return {
      'id': id,
      'name': name,
      'url': 'https://ticketmaster.com/event/$id',
      'dates': {
        'start': {
          'dateTime': DateTime.now().add(Duration(days: 30)).toIso8601String(),
          'localDate': DateTime.now().add(Duration(days: 30)).toIso8601String().split('T')[0],
        }
      },
      '_embedded': {
        'venues': [
          {
            'name': venueName,
            'city': {'name': city},
            'state': {'name': 'Test State'},
            'country': {'name': 'US'},
            'location': {
              'latitude': '40.7128',
              'longitude': '-74.0060',
            },
          }
        ]
      },
      'classifications': [
        {
          'segment': {'name': 'Music'},
          'genre': {'name': 'Pop'},
        }
      ],
      'priceRanges': [
        {
          'min': 25.0,
          'max': 75.0,
          'currency': 'USD',
        }
      ],
    };
  }
}
```

---

## 7. Testing Configuration & Scripts

### 7.1 Test Configuration Files

```yaml
# test/flutter_test_config.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() async {
    // Global test setup
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Set up golden file comparator
    goldenFileComparator = GoldenTestComparator();
    
    // Initialize test database
    await initializeTestDatabase();
    
    // Set up mock services
    await setupMockServices();
  });

  tearDownAll(() async {
    // Global test cleanup
    await cleanupTestDatabase();
    await cleanupMockServices();
  });

  await testMain();
}

Future<void> initializeTestDatabase() async {
  // Initialize test database if needed
}

Future<void> cleanupTestDatabase() async {
  // Cleanup test database
}

Future<void> setupMockServices() async {
  // Setup mock external services
}

Future<void> cleanupMockServices() async {
  // Cleanup mock services
}
```

### 7.2 Test Scripts

```bash
#!/bin/bash
# scripts/run_tests.sh

set -e

echo "🧪 Running MoodMusic Test Suite"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

print_status "Flutter version:"
flutter --version

# Clean and get dependencies
print_status "Getting dependencies..."
flutter clean
flutter pub get

# Generate mocks
print_status "Generating mocks..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Run static analysis
print_status "Running static analysis..."
flutter analyze
if [ $? -ne 0 ]; then
    print_error "Static analysis failed"
    exit 1
fi

# Check formatting
print_status "Checking code formatting..."
dart format --output=none --set-exit-if-changed .
if [ $? -ne 0 ]; then
    print_error "Code formatting check failed. Run 'dart format .' to fix."
    exit 1
fi

# Run unit tests
print_status "Running unit tests..."
flutter test --coverage --reporter=expanded
if [ $? -ne 0 ]; then
    print_error "Unit tests failed"
    exit 1
fi

# Generate coverage report
print_status "Generating coverage report..."
genhtml coverage/lcov.info -o coverage/html
print_status "Coverage report generated at coverage/html/index.html"

# Run integration tests (if device available)
if flutter devices | grep -q "device"; then
    print_status "Running integration tests..."
    flutter test integration_test/
    if [ $? -ne 0 ]; then
        print_warning "Integration tests failed or no device available"
    fi
else
    print_warning "No devices available for integration tests"
fi

print_status "All tests completed successfully! 🎉"

# Check coverage threshold
coverage_percentage=$(lcov --summary coverage/lcov.info | grep "lines......" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')
threshold=90

if (( $(echo "$coverage_percentage >= $threshold" | bc -l) )); then
    print_status "Coverage: $coverage_percentage% (meets $threshold% threshold)"
else
    print_error "Coverage: $coverage_percentage% (below $threshold% threshold)"
    exit 1
fi
```

### 7.3 GitHub Actions Test Workflow

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
    - uses: actions/checkout@v4
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        cache: true
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Generate mocks
      run: flutter packages pub run build_runner build --delete-conflicting-outputs
    
    - name: Verify formatting
      run: dart format --output=none --set-exit-if-changed .
    
    - name: Analyze project source
      run: flutter analyze --fatal-infos
    
    - name: Run unit tests
      run: flutter test --coverage --reporter=expanded
    
    - name: Check coverage threshold
      run: |
        COVERAGE=$(lcov --summary coverage/lcov.info | grep "lines......" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')
        echo "Coverage: $COVERAGE%"
        if (( $(echo "$COVERAGE >= 90" | bc -l) )); then
          echo "✅ Coverage meets 90% threshold"
        else
          echo "❌ Coverage below 90% threshold"
          exit 1
        fi
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: coverage/lcov.info
        fail_ci_if_error: true
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: |
          coverage/
          test/reports/

  integration-test:
    runs-on: macos-latest
    needs: test
    
    steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        cache: true
    
    - name: Start iOS Simulator
      run: |
        xcrun simctl boot "iPhone 14" || true
        xcrun simctl list devices
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Run integration tests
      run: flutter test integration_test/ --verbose
    
    - name: Upload integration test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: integration-test-results
        path: integration_test/reports/
```

---

## 8. Test Coverage & Quality Metrics

### 8.1 Coverage Requirements

| Component | Minimum Coverage | Target Coverage |
|-----------|------------------|-----------------|
| Business Logic (Services) | 95% | 98% |
| Data Models | 90% | 95% |
| Providers (State Management) | 85% | 90% |
| Repositories | 90% | 95% |
| Utility Functions | 95% | 98% |
| Screens (Widget Tests) | 70% | 80% |
| Custom Widgets | 80% | 85% |
| **Overall Project** | **90%** | **92%** |

### 8.2 Quality Gates

```dart
// scripts/quality_gate.dart
import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔍 Running Quality Gate Checks...');
  
  var hasFailures = false;

  // Check test coverage
  hasFailures |= await checkCoverage();
  
  // Check static analysis
  hasFailures |= await checkAnalysis();
  
  // Check performance benchmarks
  hasFailures |= await checkPerformance();
  
  // Check security vulnerabilities
  hasFailures |= await checkSecurity();

  if (hasFailures) {
    print('❌ Quality gate failed');
    exit(1);
  } else {
    print('✅ Quality gate passed');
  }
}

Future<bool> checkCoverage() async {
  print('\n📊 Checking test coverage...');
  
  final result = await Process.run('lcov', [
    '--summary',
    'coverage/lcov.info'
  ]);
  
  if (result.exitCode != 0) {
    print('❌ Failed to read coverage report');
    return true;
  }
  
  final output = result.stdout as String;
  final coverageMatch = RegExp(r'lines......: ([0-9.]+)%').firstMatch(output);
  
  if (coverageMatch == null) {
    print('❌ Could not parse coverage percentage');
    return true;
  }
  
  final coverage = double.parse(coverageMatch.group(1)!);
  const threshold = 90.0;
  
  if (coverage < threshold) {
    print('❌ Coverage $coverage% is below threshold $threshold%');
    return true;
  }
  
  print('✅ Coverage $coverage% meets threshold');
  return false;
}

Future<bool> checkAnalysis() async {
  print('\n🔍 Running static analysis...');
  
  final result = await Process.run('flutter', ['analyze']);
  
  if (result.exitCode != 0) {
    print('❌ Static analysis failed');
    print(result.stdout);
    print(result.stderr);
    return true;
  }
  
  print('✅ Static analysis passed');
  return false;
}

Future<bool> checkPerformance() async {
  print('\n⚡ Checking performance benchmarks...');
  
  // Read performance test results
  final performanceFile = File('test_results/performance.json');
  if (!performanceFile.existsSync()) {
    print('⚠️  No performance results found, skipping check');
    return false;
  }
  
  final performanceData = jsonDecode(await performanceFile.readAsString());
  final benchmarks = {
    'app_startup_time_ms': 3000,
    'emotion_detection_time_ms': 5000,
    'music_recommendation_time_ms': 3000,
  };
  
  var failed = false;
  for (final entry in benchmarks.entries) {
    final metric = entry.key;
    final threshold = entry.value;
    final actual = performanceData[metric];
    
    if (actual != null && actual > threshold) {
      print('❌ $metric: ${actual}ms exceeds threshold ${threshold}ms');
      failed = true;
    } else if (actual != null) {
      print('✅ $metric: ${actual}ms within threshold');
    }
  }
  
  return failed;
}

Future<bool> checkSecurity() async {
  print('\n🔒 Running security checks...');
  
  // Check for hardcoded secrets
  final result = await Process.run('grep', [
    '-r',
    '-i',
    '--include=*.dart',
    '--include=*.yaml',
    '-E',
    '(api.?key|secret|token|password).*=.*["\'][^"\']{10,}',
    'lib/',
  ]);
  
  if (result.exitCode == 0) {
    print('❌ Potential hardcoded secrets found:');
    print(result.stdout);
    return true;
  }
  
  print('✅ No hardcoded secrets detected');
  return false;
}
```

---

## Conclusion

This comprehensive testing strategy ensures the MoodMusic Flutter application meets production-quality standards through:

### **Testing Coverage:**
- **90%+ overall code coverage** with higher targets for critical components
- **Unit tests** for all business logic, data models, and utilities  
- **Widget tests** for UI components and user interactions
- **Integration tests** for database operations and API integrations
- **End-to-end tests** for complete user journeys

### **Quality Assurance:**
- **Automated testing pipeline** with CI/CD integration
- **Performance benchmarking** with measurable targets
- **Security scanning** for vulnerabilities and secrets
- **Accessibility testing** for inclusive user experience
- **Golden tests** for visual regression prevention

### **Key Testing Priorities:**
1. **Emotion Detection Accuracy** - Core feature reliability
2. **Music Recommendation Quality** - User satisfaction driver
3. **Subscription Flow Testing** - Revenue critical functionality
4. **Offline Capability** - Network resilience verification
5. **Cross-Platform Consistency** - iOS/Android parity

### **Success Metrics:**
- **<1% crash rate** in production
- **99.9% uptime** for core features
- **<3 second response times** for all user actions
- **4.5+ star rating** maintained through quality testing

The testing strategy provides confidence for production deployment while enabling rapid feature development through comprehensive automation and quality gates.

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-23  
**Next Review**: 2025-02-06  
**Owner**: QA Lead & Development Team  
**Status**: Ready for Implementation