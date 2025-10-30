import 'package:flutter/material.dart';
import '../models/app_state.dart';
import '../models/mood.dart';
import '../models/song.dart';
import '../models/event.dart';
import '../models/emotion_analysis_result.dart';

class AppStateProvider extends ChangeNotifier {
  AppState _currentState = AppState.start;
  Mood? _detectedMood;
  EmotionAnalysisResult? _emotionAnalysis; // Store full analysis result
  Song? _recommendedSong;
  Event? _recommendedEvent;

  AppState get currentState => _currentState;
  Mood? get detectedMood => _detectedMood;
  EmotionAnalysisResult? get emotionAnalysis => _emotionAnalysis;
  Song? get recommendedSong => _recommendedSong;
  Event? get recommendedEvent => _recommendedEvent;

  void goToScanning() {
    _currentState = AppState.scanning;
    notifyListeners();
  }

  void goToResults(Mood mood, Song? song, Event? event, [EmotionAnalysisResult? emotionAnalysis]) {
    _detectedMood = mood;
    _emotionAnalysis = emotionAnalysis;
    _recommendedSong = song;
    _recommendedEvent = event;
    _currentState = AppState.results;
    notifyListeners();
  }

  void goToHistory() {
    _currentState = AppState.history;
    notifyListeners();
  }

  void goToAWSDebug() {
    _currentState = AppState.awsDebug;
    notifyListeners();
  }

  void goToStart() {
    _currentState = AppState.start;
    _detectedMood = null;
    _emotionAnalysis = null;
    _recommendedSong = null;
    _recommendedEvent = null;
    notifyListeners();
  }

  void reset() {
    _currentState = AppState.start;
    _detectedMood = null;
    _emotionAnalysis = null;
    _recommendedSong = null;
    _recommendedEvent = null;
    notifyListeners();
  }
} 