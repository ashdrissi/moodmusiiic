import '../models/mood.dart';
import '../models/song.dart';
import '../models/event.dart';
import '../providers/spotify_provider.dart';

class RecommendationResult {
  final Song? song;
  final Event? event;
  final String reasoning;

  const RecommendationResult({
    required this.song,
    required this.event,
    required this.reasoning,
  });
}

class RecommendationEngine {
  static Future<RecommendationResult> getRecommendations(
    Mood mood,
    SpotifyProvider spotifyProvider,
  ) async {
    // Get music recommendations
    final songs = await spotifyProvider.getRecommendationsForMood(mood);
    final selectedSong = songs.isNotEmpty ? songs.first : Song.mockSong;

    // Get event recommendations (mock for now)
    final event = _getEventRecommendation(mood);

    // Generate reasoning
    final reasoning = _generateReasoning(mood, spotifyProvider);

    return RecommendationResult(
      song: selectedSong,
      event: event,
      reasoning: reasoning,
    );
  }

  static Event _getEventRecommendation(Mood mood) {
    final eventTypes = {
      Mood.happy: ['Pop Concert', 'Dance Party', 'Music Festival'],
      Mood.sad: ['Acoustic Night', 'Jazz Club', 'Piano Recital'],
      Mood.angry: ['Rock Concert', 'Metal Show', 'Punk Gig'],
      Mood.calm: ['Classical Concert', 'Meditation Session', 'Ambient Show'],
      Mood.anxious: ['Chill Lounge', 'Soft Rock Night', 'Acoustic Session'],
      Mood.excited: ['EDM Festival', 'Hip-Hop Concert', 'Rave Party'],
    };

    final venues = {
      Mood.happy: ['Festival Grounds', 'Dance Club', 'Arena'],
      Mood.sad: ['Intimate Venue', 'Coffee House', 'Small Theater'],
      Mood.angry: ['Rock Club', 'Underground Venue', 'Concert Hall'],
      Mood.calm: ['Symphony Hall', 'Meditation Center', 'Garden Venue'],
      Mood.anxious: ['Lounge Bar', 'Acoustic Cafe', 'Small Club'],
      Mood.excited: ['Mega Club', 'Stadium', 'Festival Site'],
    };

    final eventNames = eventTypes[mood] ?? ['Live Music'];
    final venueNames = venues[mood] ?? ['Local Venue'];

    return Event(
      id: 'event_${mood.displayName.toLowerCase()}',
      name: eventNames.first,
      date: DateTime.now().add(Duration(days: 3 + mood.index)),
      venue: venueNames.first,
      location: 'Downtown',
      imageUrl: null,
      ticketUrl: null,
      latitude: 37.7749 + (mood.index * 0.01),
      longitude: -122.4194 + (mood.index * 0.01),
    );
  }

  static String _generateReasoning(Mood mood, SpotifyProvider spotifyProvider) {
    final patterns = spotifyProvider.listeningPatterns;
    final dominantGenres = patterns['dominant_genres'] as List<String>;
    final favoriteArtists = patterns['favorite_artists'] as List<String>;

    final baseReasonings = {
      Mood.happy: [
        'You\'re feeling great! Let\'s amplify that joy with upbeat music.',
        'Your positive energy calls for celebratory tunes.',
        'Time to dance and embrace the happiness!',
      ],
      Mood.sad: [
        'Sometimes we need music that understands our feelings.',
        'Let\'s find comfort in gentle, emotional melodies.',
        'Music can be a healing companion during tough times.',
      ],
      Mood.angry: [
        'Channel that energy with powerful, intense music.',
        'Sometimes we need to let it all out through music.',
        'Raw, powerful sounds to match your current intensity.',
      ],
      Mood.calm: [
        'Perfect time for peaceful, soothing sounds.',
        'Let\'s maintain this zen with tranquil music.',
        'Gentle melodies to complement your peaceful state.',
      ],
      Mood.anxious: [
        'Calming music can help ease worried thoughts.',
        'Let\'s find some musical comfort for your nerves.',
        'Soothing sounds to help you find your center.',
      ],
      Mood.excited: [
        'Your energy is electric! Let\'s match it with high-energy beats.',
        'Time to celebrate with pumping, energetic music.',
        'Your excitement deserves the most dynamic sounds!',
      ],
    };

    final moodReasonings = baseReasonings[mood] ?? ['Great mood for discovering new music!'];
    var reasoning = moodReasonings.first;

    // Add personalization based on listening patterns
    if (spotifyProvider.isAuthenticated && dominantGenres.isNotEmpty) {
      reasoning += ' Since you love ${dominantGenres.first}, I\'ve found something that blends perfectly with your taste.';
    }

    if (favoriteArtists.isNotEmpty && favoriteArtists.first != 'Various Artists') {
      reasoning += ' Fans of ${favoriteArtists.first} often enjoy this style too.';
    }

    return reasoning;
  }

  // Advanced recommendation strategies (matching iOS version)
  static String _getRecommendationStrategy(
    Mood detectedMood,
    SpotifyProvider spotifyProvider,
  ) {
    final patterns = spotifyProvider.listeningPatterns;
    final dominantGenres = patterns['dominant_genres'] as List<String>;

    // Cross-matching logic similar to iOS version
    if (detectedMood == Mood.sad && dominantGenres.contains('melancholy')) {
      return 'CONTRAST_BOOST'; // Give upbeat music to counter sadness
    } else if (detectedMood == Mood.happy && dominantGenres.contains('pop')) {
      return 'MOOD_REINFORCEMENT'; // Amplify the good mood
    } else if (detectedMood == Mood.angry && dominantGenres.contains('metal')) {
      return 'PERSONAL_TASTE'; // Match their preferred intense music
    } else if (detectedMood == Mood.calm && dominantGenres.contains('classical')) {
      return 'PERFECT_MATCH'; // Ideal alignment
    } else {
      return 'DISCOVERY'; // Introduce them to new genres
    }
  }
} 