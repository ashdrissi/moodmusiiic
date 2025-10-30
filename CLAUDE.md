# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands for Development

### Building and Running
```bash
# Install dependencies
flutter pub get

# Run the app (iOS/Android)
flutter run

# Run with hot reload for development
flutter run --hot

# Build for release
flutter build apk       # Android
flutter build ios       # iOS
```

### Code Quality and Testing
```bash
# Run static analysis
flutter analyze

# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Format code
dart format .

# Check for outdated dependencies
flutter pub outdated
```

### Debugging and Development
```bash
# Run in debug mode with verbose logging
flutter run --verbose

# Clean build cache
flutter clean && flutter pub get

# Generate build files
flutter packages get
```

## Project Architecture

This is a **MoodMusic Flutter app** that detects emotions through facial analysis and recommends music accordingly. It follows a **Provider-based state management** pattern with clean separation of concerns.

### Core Architecture Layers

1. **State Management**: Provider pattern with centralized app state
   - `AppStateProvider`: Main app navigation and state
   - `AWSProvider`: AWS Rekognition integration
   - `SpotifyProvider`: Spotify API integration  
   - `RekognitionProvider`: Emotion detection services

2. **Navigation Flow**: State-driven navigation through `AppState` enum
   - `start` → `scanning` → `results` → `history/awsDebug`
   - Centralized in `AppNavigator` widget consuming `AppStateProvider`

3. **Emotion Detection Pipeline**:
   - Camera capture → AWS Rekognition API → `MoodEngine` processing
   - Fallback simulation mode for development/testing
   - CSV-based mood profile matching with scoring algorithm

4. **Data Models**:
   - `Mood`: 6 core emotions (happy, sad, angry, calm, anxious, excited)
   - `MoodProfile`: Complex emotion pattern matching from CSV data
   - `EmotionAnalysisResult`: Raw emotion detection results
   - `Song`/`Event`: Recommendation data structures

### Key Services

- **MoodEngine** (`services/mood_engine.dart`): Core emotion analysis and mood matching logic
- **RecommendationEngine** (`services/recommendation_engine.dart`): Music and event suggestions
- **Provider Classes**: Handle external API integrations (AWS, Spotify)

### Directory Structure
```
lib/
├── main.dart                    # App entry point with MultiProvider setup
├── models/                      # Data models and enums
├── providers/                   # State management (Provider pattern)
├── screens/                     # UI screens following AppState flow
├── services/                    # Business logic (MoodEngine, RecommendationEngine)
├── theme/                       # App theming and colors
└── widgets/                     # Reusable UI components
```

## Configuration and Setup

### Development Mode
- App starts in **simulation mode** by default
- Debug screen available for AWS credential configuration
- Mock data used when external APIs unavailable

### External Integrations
- **AWS Rekognition**: Facial emotion detection (requires credentials)
- **Spotify API**: Music recommendations (OAuth integration)
- **Location Services**: For local event suggestions

### Assets and Data
- Mood profiles loaded from `assets/data/mood_profiles.csv`
- Emotion matching uses CSV-based scoring algorithm
- Images, animations, and icons in respective asset folders

## Development Notes

### Emotion Detection Flow
1. Camera captures image → `RekognitionProvider`
2. AWS API returns emotion percentages → `MoodEngine.matchMood()`
3. CSV-based profile matching with confidence scoring
4. Fallback profiles for unmatched emotions ("Emotion Drift", "Neutral Balance")

### State Management Pattern
- Single source of truth via `AppStateProvider`
- Screen transitions through state changes, not navigation
- Each provider handles specific domain (AWS, Spotify, etc.)

### Testing and Debugging
- Debug overlay available in camera screen
- AWS debug screen for testing connections
- Simulation mode with mock emotion data
- Extensive logging throughout emotion detection pipeline

### Theme System
- Material 3 design with custom color schemes
- Mood-specific colors defined in `AppTheme.moodColor()`
- Support for light/dark themes following system preferences