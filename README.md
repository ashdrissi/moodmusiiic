# MoodMusic Flutter App

A Flutter implementation of the MoodMusic iOS app that detects your mood through facial analysis and recommends music accordingly.

## Features

- 🎭 Emotion Detection with 6 moods
- 🎵 Smart Music Recommendations  
- 🎪 Local Event Discovery
- 📊 Mood History & Analytics
- 🔧 Debug & Development Tools

## Getting Started

```bash
cd flutter_moodmusic
flutter pub get
flutter run
```

## Architecture

- Models: Mood, Song, Event data structures
- Providers: State management with Provider pattern
- Screens: Start, Scanner, Results, History, Debug
- Widgets: Camera, overlays, debug components
- Services: Recommendation engine

## Configuration

The app starts in simulation mode. For real AWS integration:
1. Go to Debug screen
2. Toggle off Debug Mode
3. Enter AWS credentials

## Key Features

### Mood Detection
- Real-time camera analysis
- 6 emotions: Happy, Sad, Angry, Calm, Anxious, Excited
- AWS Rekognition with simulation fallback

### Music Recommendations  
- Spotify integration (mock data)
- Cross-matching emotions with listening patterns
- Multiple recommendation strategies

### Debug Tools
- AWS connection testing
- Simulation mode
- Real-time debug overlay
- Configuration management

This Flutter version provides cross-platform compatibility while maintaining feature parity with the iOS app. 