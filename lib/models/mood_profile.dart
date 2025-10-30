class MoodProfile {
  final String label;
  final String description;
  final List<String> emotionTriggers;
  final Map<String, double> percentConditions; // emotion -> minimum percentage
  final String patternType;
  final List<String> quotes;
  final List<String> musicTags;
  final String suggestionNote;

  const MoodProfile({
    required this.label,
    required this.description,
    required this.emotionTriggers,
    required this.percentConditions,
    required this.patternType,
    required this.quotes,
    required this.musicTags,
    required this.suggestionNote,
  });

  factory MoodProfile.fromCsvRow(List<String> row) {
    // Parse emotion triggers
    final triggers = row[1]
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Parse percent conditions like "Sad > 21%, Surprised > 15%"
    final conditions = <String, double>{};
    final conditionsText = row[2];
    final conditionParts = conditionsText.split(',');
    
    for (final condition in conditionParts) {
      final trimmed = condition.trim();
      if (trimmed.contains('>')) {
        final parts = trimmed.split('>');
        if (parts.length == 2) {
          final emotion = parts[0].trim().toLowerCase();
          final percentText = parts[1].trim().replaceAll('%', '');
          final percent = double.tryParse(percentText);
          if (percent != null) {
            // Keep the highest threshold for duplicate emotions
            if (!conditions.containsKey(emotion) || conditions[emotion]! < percent) {
              conditions[emotion] = percent;
            }
          }
        }
      }
    }

    // Parse quotes from string representation of array
    final quotesText = row[5];
    final quotes = <String>[];
    
    // Remove the outer brackets and quotes, then split
    if (quotesText.startsWith('[') && quotesText.endsWith(']')) {
      final content = quotesText.substring(1, quotesText.length - 1);
      final parts = content.split("', '");
      for (final part in parts) {
        final clean = part.replaceAll("'", "").replaceAll('"', '').trim();
        if (clean.isNotEmpty) {
          quotes.add(clean);
        }
      }
    }

    // Generate music tags based on pattern type
    final musicTags = _getMusicTagsForPattern(row[3]);

    return MoodProfile(
      label: row[0],
      description: row[4],
      emotionTriggers: triggers,
      percentConditions: conditions,
      patternType: row[3],
      quotes: quotes.isNotEmpty ? quotes : ['Stay strong, emotions are temporary.'],
      musicTags: musicTags,
      suggestionNote: _getSuggestionNote(row[3]),
    );
  }

  static List<String> _getMusicTagsForPattern(String patternType) {
    switch (patternType.toLowerCase()) {
      case 'contrast blend':
        return ['alternative', 'indie rock', 'experimental', 'art rock'];
      case 'subtle tension':
        return ['ambient', 'post-rock', 'minimal', 'atmospheric'];
      case 'uplifted':
        return ['pop', 'upbeat', 'indie pop', 'feel-good'];
      case 'fog state':
        return ['dream pop', 'ethereal', 'shoegaze', 'ambient'];
      case 'disoriented state':
        return ['experimental', 'electronic', 'glitch', 'industrial'];
      case 'reflective blend':
        return ['singer-songwriter', 'folk', 'acoustic', 'contemplative'];
      case 'melancholic peace':
        return ['neo-classical', 'ambient', 'melancholic', 'peaceful'];
      case 'blended (triad)':
        return ['progressive', 'complex', 'multi-genre', 'eclectic'];
      case 'dominant + shadow':
        return ['dynamic', 'orchestral', 'cinematic', 'dramatic'];
      default:
        return ['chill', 'versatile', 'adaptive'];
    }
  }

  static String _getSuggestionNote(String patternType) {
    switch (patternType.toLowerCase()) {
      case 'contrast blend':
        return 'Your emotions are creating an interesting contrast - music that embraces complexity might resonate with you.';
      case 'subtle tension':
        return 'There\'s an underlying tension in your emotional state - atmospheric music might help you process these feelings.';
      case 'uplifted':
        return 'You\'re experiencing positive emotional energy - upbeat music can amplify these good vibes.';
      case 'fog state':
        return 'Your emotions are in a dreamy, unclear state - ethereal music might match your current headspace.';
      case 'disoriented state':
        return 'You\'re feeling emotionally scattered - experimental music might help you explore these complex feelings.';
      case 'reflective blend':
        return 'You\'re in a contemplative mood - thoughtful, introspective music could complement your state.';
      case 'melancholic peace':
        return 'You\'re experiencing bittersweet emotions - music that balances sadness and beauty might resonate.';
      case 'blended (triad)':
        return 'You have multiple strong emotions - complex, layered music might match your emotional richness.';
      case 'dominant + shadow':
        return 'You have a strong primary emotion with subtle undertones - dynamic music with depth might suit you.';
      default:
        return 'Your emotional state is unique - exploring diverse music might help you discover what resonates.';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'description': description,
      'emotion_triggers': emotionTriggers,
      'percent_conditions': percentConditions,
      'pattern_type': patternType,
      'quotes': quotes,
      'music_tags': musicTags,
      'suggestion_note': suggestionNote,
    };
  }

  factory MoodProfile.fromJson(Map<String, dynamic> json) {
    return MoodProfile(
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      emotionTriggers: List<String>.from(json['emotion_triggers'] ?? []),
      percentConditions: Map<String, double>.from(json['percent_conditions'] ?? {}),
      patternType: json['pattern_type'] ?? '',
      quotes: List<String>.from(json['quotes'] ?? []),
      musicTags: List<String>.from(json['music_tags'] ?? []),
      suggestionNote: json['suggestion_note'] ?? '',
    );
  }
} 