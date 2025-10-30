import 'mood.dart';
import 'mood_profile.dart';
import '../services/mood_engine.dart';

class EmotionAnalysisResult {
  final Mood mood;
  final double confidence;
  final Map<String, double> allEmotions;
  final MoodProfile? complexMood; // New sophisticated mood analysis
  final DateTime timestamp;

  const EmotionAnalysisResult({
    required this.mood,
    required this.confidence,
    required this.allEmotions,
    this.complexMood,
    required this.timestamp,
  });

  factory EmotionAnalysisResult.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysisResult(
      mood: Mood.values.firstWhere(
        (m) => m.displayName.toLowerCase() == json['mood'].toString().toLowerCase(),
        orElse: () => Mood.calm,
      ),
      confidence: json['confidence']?.toDouble() ?? 0.0,
      allEmotions: Map<String, double>.from(json['all_emotions'] ?? {}),
      complexMood: json['complex_mood'] != null 
          ? MoodProfile.fromJson(json['complex_mood'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mood': mood.displayName,
      'confidence': confidence,
      'all_emotions': allEmotions,
      'complex_mood': complexMood?.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static Future<EmotionAnalysisResult> createSimulated() async {
    final moods = Mood.values;
    final selectedMood = moods[DateTime.now().millisecond % moods.length];
    final confidence = 0.7 + (DateTime.now().millisecond % 25) / 100;
    
    final emotions = <String, double>{
      selectedMood.displayName: confidence * 100,
    };
    
    // Add some secondary emotions for realism
    final secondaryMoods = moods.where((m) => m != selectedMood).take(2);
    for (final mood in secondaryMoods) {
      emotions[mood.displayName] = (DateTime.now().millisecond % 25).toDouble();
    }

    // Create realistic raw emotion data for complex mood analysis
    final rawEmotions = <String, double>{
      'happy': selectedMood == Mood.happy ? confidence * 100 : (DateTime.now().millisecond % 15).toDouble(),
      'sad': selectedMood == Mood.sad ? confidence * 100 : (DateTime.now().millisecond % 10).toDouble(),
      'angry': selectedMood == Mood.angry ? confidence * 100 : (DateTime.now().millisecond % 8).toDouble(),
      'fear': selectedMood == Mood.anxious ? confidence * 50 : (DateTime.now().millisecond % 12).toDouble(),
      'surprised': selectedMood == Mood.excited ? confidence * 80 : (DateTime.now().millisecond % 20).toDouble(),
      'confused': (DateTime.now().millisecond % 15).toDouble(),
      'calm': selectedMood == Mood.calm ? confidence * 100 : (DateTime.now().millisecond % 10).toDouble(),
      'disgusted': (DateTime.now().millisecond % 5).toDouble(),
    };

    // Perform complex mood analysis
    final complexMood = await MoodEngine.matchMood(rawEmotions);

    return EmotionAnalysisResult(
      mood: selectedMood,
      confidence: confidence,
      allEmotions: emotions,
      complexMood: complexMood,
      timestamp: DateTime.now(),
    );
  }
} 