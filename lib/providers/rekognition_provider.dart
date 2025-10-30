import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aws_rekognition_api/rekognition-2016-06-27.dart' as aws;
import '../models/emotion_analysis_result.dart';
import '../models/mood.dart';

import '../services/mood_engine.dart';
import 'aws_provider.dart';

class RekognitionProvider extends ChangeNotifier {
  bool _isAnalyzing = false;
  EmotionAnalysisResult? _lastResult;
  String? _lastError;

  bool get isAnalyzing => _isAnalyzing;
  EmotionAnalysisResult? get lastResult => _lastResult;
  String? get lastError => _lastError;

  // Analyze emotion from image data
  Future<EmotionAnalysisResult?> analyzeEmotion(
    Uint8List imageData,
    AWSProvider awsProvider,
  ) async {
    _isAnalyzing = true;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint('🔍 Starting emotion analysis...');

      if (awsProvider.isDebugMode) {
        return await _simulateEmotionAnalysis();
      } else {
        return await _performRealEmotionAnalysis(imageData, awsProvider);
      }
    } catch (e) {
      debugPrint('❌ Emotion analysis failed: $e');
      _lastError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  // Simulate emotion analysis for debug mode
  Future<EmotionAnalysisResult> _simulateEmotionAnalysis() async {
    debugPrint('🎭 Running emotion analysis in simulation mode...');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    final result = await EmotionAnalysisResult.createSimulated();
    _lastResult = result;
    
    debugPrint('✅ Simulated emotion analysis complete: ${result.mood.displayName} (${(result.confidence * 100).toStringAsFixed(1)}%)');
    
    notifyListeners();
    return result;
  }

  // Perform real emotion analysis using AWS Rekognition
  Future<EmotionAnalysisResult> _performRealEmotionAnalysis(
    Uint8List imageData,
    AWSProvider awsProvider,
  ) async {
    debugPrint('🔗 Connecting to AWS Rekognition...');

    if (!awsProvider.isConnected) {
      throw Exception('AWS Rekognition not connected');
    }

    if (awsProvider.accessKey == null || awsProvider.secretKey == null) {
      throw Exception('Missing AWS credentials');
    }

    try {
      // Initialize AWS Rekognition client
      final rekognition = aws.Rekognition(
        region: awsProvider.region ?? 'us-east-1',
        credentials: aws.AwsClientCredentials(
          accessKey: awsProvider.accessKey!,
          secretKey: awsProvider.secretKey!,
        ),
      );

      debugPrint('📷 Analyzing image with AWS Rekognition...');

      // Call AWS Rekognition to detect faces and emotions
      final response = await rekognition.detectFaces(
        image: aws.Image(bytes: imageData),
        attributes: [aws.Attribute.all], // Include emotion analysis
      );

      debugPrint('📊 Rekognition response: ${response.faceDetails?.length} faces detected');

      if (response.faceDetails == null || response.faceDetails!.isEmpty) {
        throw Exception('No faces detected in the image');
      }

      // Get the first detected face
      final face = response.faceDetails!.first;
      
      if (face.emotions == null || face.emotions!.isEmpty) {
        throw Exception('No emotions detected for the face');
      }

      // Process emotions and convert to our format
      final emotions = <String, double>{};
      final rawEmotions = <String, double>{}; // For complex mood analysis
      String? dominantEmotion;
      double maxConfidence = 0.0;

      debugPrint('📊 Processing ${face.emotions!.length} detected emotions:');
      for (final emotion in face.emotions!) {
        final emotionType = emotion.type?.toString() ?? 'UNKNOWN';
        final confidence = emotion.confidence ?? 0.0;
        
        // Clean emotion name for display
        final cleanName = emotionType.replaceAll('EmotionName.', '');
        emotions[cleanName] = confidence;
        
        // Store raw emotions for complex mood analysis (lowercased for consistency)
        rawEmotions[cleanName.toLowerCase()] = confidence;
        
        debugPrint('   $cleanName: ${confidence.toStringAsFixed(1)}%');
        
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          dominantEmotion = emotionType;
        }
      }

      debugPrint('🎯 Dominant emotion: $dominantEmotion (${maxConfidence.toStringAsFixed(1)}%)');

      // Map AWS emotion to our Mood enum (for backward compatibility)
      final mood = _mapAwsEmotionToMood(dominantEmotion ?? 'CALM');
      final confidence = maxConfidence / 100.0; // Convert percentage to decimal
      
      debugPrint('🎭 Final mood mapping: ${dominantEmotion} -> ${mood.displayName} (${(confidence * 100).toStringAsFixed(1)}% confidence)');

      // Perform complex mood analysis
      debugPrint('🧠 Starting complex mood analysis with emotions: $rawEmotions');
      final complexMood = await MoodEngine.matchMood(rawEmotions);
      
      if (complexMood != null) {
        debugPrint('🎯 Complex mood match: ${complexMood.label} (${complexMood.patternType})');
      } else {
        debugPrint('💭 No complex mood match found');
      }

      final result = EmotionAnalysisResult(
        mood: mood,
        confidence: confidence,
        allEmotions: emotions,
        complexMood: complexMood,
        timestamp: DateTime.now(),
      );

      _lastResult = result;
      
      debugPrint('✅ Real emotion analysis complete: ${result.mood.displayName} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      
      notifyListeners();
      return result;

    } catch (e) {
      debugPrint('❌ AWS Rekognition error: $e');
      throw Exception('AWS Rekognition failed: $e');
    }
  }

  // Map AWS emotion types to our Mood enum
  Mood _mapAwsEmotionToMood(String awsEmotion) {
    // Remove "EmotionName." prefix if present and normalize
    final cleanEmotion = awsEmotion
        .replaceAll('EmotionName.', '')
        .toUpperCase();
    
    debugPrint('🎯 Mapping emotion: "$awsEmotion" -> "$cleanEmotion"');
    
    switch (cleanEmotion) {
      case 'HAPPY':
        debugPrint('😊 Mapped to HAPPY mood');
        return Mood.happy;
      case 'SAD':
        debugPrint('😢 Mapped to SAD mood');
        return Mood.sad;
      case 'ANGRY':
        debugPrint('😠 Mapped to ANGRY mood');
        return Mood.angry;
      case 'CALM':
        debugPrint('😌 Mapped to CALM mood');
        return Mood.calm;
      case 'CONFUSED':
      case 'FEAR':
        debugPrint('😰 Mapped to ANXIOUS mood (was $cleanEmotion)');
        return Mood.anxious;
      case 'SURPRISED':
        debugPrint('🤩 Mapped to EXCITED mood');
        return Mood.excited;
      case 'DISGUSTED':
        debugPrint('😠 Mapped to ANGRY mood (was DISGUSTED)');
        return Mood.angry; // Map disgusted to angry as closest match
      default:
        debugPrint('😌 Unknown emotion "$cleanEmotion", defaulting to CALM');
        return Mood.calm; // Default fallback
    }
  }

  // Get detailed emotion breakdown for debugging
  String getEmotionBreakdown() {
    if (_lastResult == null) return 'No analysis available';

    final breakdown = StringBuffer();
    breakdown.writeln('🎭 Emotion Analysis Results:');
    breakdown.writeln('Primary Mood: ${_lastResult!.mood.emoji} ${_lastResult!.mood.displayName}');
    breakdown.writeln('Confidence: ${(_lastResult!.confidence * 100).toStringAsFixed(1)}%');
    breakdown.writeln('Timestamp: ${_lastResult!.timestamp.toLocal()}');
    breakdown.writeln('\nAll Emotions:');
    
    final sortedEmotions = _lastResult!.allEmotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (final entry in sortedEmotions) {
      breakdown.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(1)}%');
    }

    return breakdown.toString();
  }

  // Clear the last result
  void clearLastResult() {
    _lastResult = null;
    _lastError = null;
    notifyListeners();
  }

  // Generate random emotion for testing
  static Mood getRandomMood() {
    final moods = Mood.values;
    final index = DateTime.now().millisecond % moods.length;
    return moods[index];
  }
} 