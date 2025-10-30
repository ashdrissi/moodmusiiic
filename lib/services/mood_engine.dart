
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mood_profile.dart';

class MoodEngine {
  static const double _noiseThreshold = 1.0; // Ignore emotions below 1%
  static List<MoodProfile>? _cachedProfiles;

  /// Analyzes emotion data and returns the best matching mood profile
  static Future<MoodProfile?> matchMood(Map<String, double> emotionData) async {
    debugPrint('🧠 Starting mood matching with data: $emotionData');
    
    // Step 1: Preprocess input data
    final processedEmotions = _preprocessEmotions(emotionData);
    debugPrint('🔍 Processed emotions: $processedEmotions');
    
    // Step 2: Load mood profiles
    final profiles = await _loadMoodProfiles();
    if (profiles.isEmpty) {
      debugPrint('❌ No mood profiles loaded');
      return null;
    }
    
    // Step 3: Find best matching profile
    final bestMatch = _findBestMatch(processedEmotions, profiles);
    
    if (bestMatch != null) {
      debugPrint('🎯 Best match found: ${bestMatch.label}');
      debugPrint('📖 Pattern: ${bestMatch.patternType}');
      debugPrint('💡 Suggestion: ${bestMatch.suggestionNote}');
    } else {
      debugPrint('❌ No suitable match found');
    }
    
    return bestMatch;
  }

  /// Preprocesses emotion data by removing noise and sorting
  static Map<String, double> _preprocessEmotions(Map<String, double> emotions) {
    final processed = <String, double>{};
    
    // Remove emotions below noise threshold and normalize names
    for (final entry in emotions.entries) {
      final cleanName = entry.key.toLowerCase().trim();
      if (entry.value >= _noiseThreshold) {
        processed[cleanName] = entry.value;
      }
    }
    
    // Sort by percentage descending
    final sortedEntries = processed.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries);
  }

  /// Loads mood profiles from CSV asset
  static Future<List<MoodProfile>> _loadMoodProfiles() async {
    if (_cachedProfiles != null) {
      return _cachedProfiles!;
    }
    
    try {
      debugPrint('📚 Loading mood profiles from CSV...');
      final csvString = await rootBundle.loadString('assets/data/mood_profiles.csv');
      final lines = csvString.split('\n');
      
      final profiles = <MoodProfile>[];
      
      // Skip header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          try {
            final row = _parseCsvRow(line);
            if (row.length >= 6) {
              final profile = MoodProfile.fromCsvRow(row);
              profiles.add(profile);
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing CSV row $i: $e');
          }
        }
      }
      
      _cachedProfiles = profiles;
      debugPrint('✅ Loaded ${profiles.length} mood profiles');
      return profiles;
    } catch (e) {
      debugPrint('❌ Error loading mood profiles: $e');
      return [];
    }
  }

  /// Simple CSV parser that handles quotes
  static List<String> _parseCsvRow(String row) {
    final columns = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < row.length; i++) {
      final char = row[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        columns.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    // Add the last column
    columns.add(buffer.toString().trim());
    
    return columns;
  }

  /// Finds the best matching mood profile using scoring algorithm
  static MoodProfile? _findBestMatch(
    Map<String, double> emotions, 
    List<MoodProfile> profiles
  ) {
    MoodProfile? bestProfile;
    double bestScore = 0.0;
    
    for (final profile in profiles) {
      final score = _calculateMatchScore(emotions, profile);
      debugPrint('📊 Profile "${profile.label}" score: ${score.toStringAsFixed(2)}');
      
      if (score > bestScore) {
        bestScore = score;
        bestProfile = profile;
      }
    }
    
    // Only return a match if the score is above a minimum threshold
    if (bestScore >= 0.3) {
      debugPrint('🏆 Best profile: "${bestProfile?.label}" with score: ${bestScore.toStringAsFixed(2)}');
      return bestProfile;
    }
    
    debugPrint('💭 No profile met minimum threshold (${bestScore.toStringAsFixed(2)} < 0.3)');
    return _getFallbackProfile(emotions);
  }

  /// Calculates match score between emotions and profile
  static double _calculateMatchScore(
    Map<String, double> emotions, 
    MoodProfile profile
  ) {
    double score = 0.0;
    int totalChecks = 0;
    
    // Check trigger emotions presence
    for (final trigger in profile.emotionTriggers) {
      final triggerLower = trigger.toLowerCase().trim();
      totalChecks++;
      
      if (emotions.containsKey(triggerLower)) {
        score += 0.3; // Base score for having the emotion
        debugPrint('  ✅ Found trigger: $triggerLower');
      } else {
        debugPrint('  ❌ Missing trigger: $triggerLower');
      }
    }
    
    // Check percentage conditions
    for (final entry in profile.percentConditions.entries) {
      final emotion = entry.key.toLowerCase();
      final requiredPercent = entry.value;
      totalChecks++;
      
      if (emotions.containsKey(emotion)) {
        final actualPercent = emotions[emotion]!;
        if (actualPercent >= requiredPercent) {
          // Higher score for exceeding requirements
          final excess = actualPercent - requiredPercent;
          score += 0.5 + (excess / 100.0); // Bonus for higher confidence
          debugPrint('  ✅ $emotion: ${actualPercent.toStringAsFixed(1)}% >= ${requiredPercent.toStringAsFixed(1)}%');
        } else {
          // Partial score if close to requirement
          final ratio = actualPercent / requiredPercent;
          if (ratio >= 0.7) {
            score += 0.2 * ratio;
            debugPrint('  ⚠️ $emotion: ${actualPercent.toStringAsFixed(1)}% < ${requiredPercent.toStringAsFixed(1)}% (partial match)');
          } else {
            debugPrint('  ❌ $emotion: ${actualPercent.toStringAsFixed(1)}% << ${requiredPercent.toStringAsFixed(1)}%');
          }
        }
      } else {
        debugPrint('  ❌ Missing condition emotion: $emotion');
      }
    }
    
    // Normalize score by total possible checks
    if (totalChecks > 0) {
      score = score / totalChecks;
    }
    
    return score;
  }

  /// Creates a fallback profile for unmatched emotions
  static MoodProfile _getFallbackProfile(Map<String, double> emotions) {
    if (emotions.isEmpty) {
      return _createNeutralProfile();
    }
    
    // Use the dominant emotion for fallback
    final dominantEmotion = emotions.keys.first;
    final dominantPercent = emotions.values.first;
    
    return MoodProfile(
      label: 'Emotion Drift',
      description: 'A unique emotional state dominated by $dominantEmotion.',
      emotionTriggers: [dominantEmotion],
      percentConditions: {dominantEmotion: dominantPercent * 0.8},
      patternType: 'Adaptive',
      quotes: [
        'Every emotion is temporary, but each one teaches us something.',
        'Your feelings are valid, even when they\'re hard to categorize.',
        'Sometimes the most interesting emotions are the ones that don\'t fit into boxes.',
      ],
      musicTags: ['adaptive', 'introspective', 'unique'],
      suggestionNote: 'Your emotional state is unique - exploring diverse music might help you discover what resonates.',
    );
  }

  /// Creates a neutral profile when no emotions are detected
  static MoodProfile _createNeutralProfile() {
    return const MoodProfile(
      label: 'Neutral Balance',
      description: 'A balanced emotional state with no dominant feelings.',
      emotionTriggers: ['calm'],
      percentConditions: {},
      patternType: 'Balanced',
      quotes: [
        'In stillness, we find our center.',
        'Peace is not the absence of emotion, but the presence of balance.',
        'Sometimes the best state is simply being present.',
      ],
      musicTags: ['ambient', 'peaceful', 'neutral'],
      suggestionNote: 'You\'re in a balanced state - gentle, ambient music might complement your calm energy.',
    );
  }

  /// Get random quote from a profile
  static String getRandomQuote(MoodProfile profile) {
    if (profile.quotes.isEmpty) {
      return 'Take a moment to breathe and feel your emotions.';
    }
    final random = Random();
    return profile.quotes[random.nextInt(profile.quotes.length)];
  }

  /// Clear cached profiles (useful for testing)
  static void clearCache() {
    _cachedProfiles = null;
  }
} 