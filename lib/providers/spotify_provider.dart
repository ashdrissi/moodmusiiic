import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/mood.dart';

class SpotifyProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiryDate;
  List<Song> _recentTracks = [];
  List<Song> _topTracks = [];

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  List<Song> get recentTracks => _recentTracks;
  List<Song> get topTracks => _topTracks;

  // Initialize Spotify authentication state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_access_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    
    final expiryString = prefs.getString('spotify_token_expiry');
    if (expiryString != null) {
      _tokenExpiryDate = DateTime.parse(expiryString);
    }

    // Check if token is still valid
    if (_accessToken != null && _tokenExpiryDate != null) {
      if (DateTime.now().isBefore(_tokenExpiryDate!)) {
        _isAuthenticated = true;
        await _loadUserData();
      } else if (_refreshToken != null) {
        await _refreshAccessToken();
      }
    }

    notifyListeners();
  }

  // Authenticate with Spotify
  Future<bool> authenticate() async {
    try {
      // TODO: Implement actual Spotify OAuth flow
      // For now, simulate successful authentication
      await Future.delayed(const Duration(seconds: 2));
      
      _isAuthenticated = true;
      _accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
      _tokenExpiryDate = DateTime.now().add(const Duration(hours: 1));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spotify_access_token', _accessToken!);
      await prefs.setString('spotify_token_expiry', _tokenExpiryDate!.toIso8601String());
      
      await _loadUserData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Spotify authentication failed: $e');
      return false;
    }
  }

  // Load user's Spotify data
  Future<void> _loadUserData() async {
    if (!_isAuthenticated) return;

    try {
      // TODO: Implement actual Spotify API calls
      // For now, simulate loading data
      await Future.delayed(const Duration(seconds: 1));
      
      _recentTracks = _generateMockSongs('recent');
      _topTracks = _generateMockSongs('top');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to load Spotify data: $e');
    }
  }

  // Refresh access token
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) return;

    try {
      // TODO: Implement actual token refresh
      await Future.delayed(const Duration(seconds: 1));
      
      _accessToken = 'refreshed_token_${DateTime.now().millisecondsSinceEpoch}';
      _tokenExpiryDate = DateTime.now().add(const Duration(hours: 1));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spotify_access_token', _accessToken!);
      await prefs.setString('spotify_token_expiry', _tokenExpiryDate!.toIso8601String());
      
      _isAuthenticated = true;
      await _loadUserData();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to refresh Spotify token: $e');
      await logout();
    }
  }

  // Get music recommendations based on mood
  Future<List<Song>> getRecommendationsForMood(Mood mood) async {
    if (!_isAuthenticated) {
      return _generateMockRecommendations(mood);
    }

    try {
      // TODO: Implement actual Spotify recommendations API
      await Future.delayed(const Duration(seconds: 1));
      return _generateMockRecommendations(mood);
    } catch (e) {
      debugPrint('❌ Failed to get recommendations: $e');
      return _generateMockRecommendations(mood);
    }
  }

  // Generate mock songs for testing
  List<Song> _generateMockSongs(String type) {
    final songs = <Song>[];
    final artists = ['The Weeknd', 'Taylor Swift', 'Drake', 'Billie Eilish', 'Ed Sheeran'];
    final genres = ['pop', 'rock', 'hip-hop', 'electronic', 'indie'];

    for (int i = 0; i < 5; i++) {
      songs.add(Song(
        id: '${type}_song_$i',
        name: '$type Song ${i + 1}',
        artist: artists[i % artists.length],
        albumImageUrl: null,
        previewUrl: null,
        spotifyUrl: 'https://open.spotify.com/track/mock_$i',
        popularity: 70.0 + (i * 5),
        genres: [genres[i % genres.length]],
      ));
    }

    return songs;
  }

  // Generate mock recommendations based on mood
  List<Song> _generateMockRecommendations(Mood mood) {
    final moodArtists = {
      Mood.happy: ['Pharrell Williams', 'Bruno Mars', 'Justin Timberlake'],
      Mood.sad: ['Adele', 'Sam Smith', 'Johnny Cash'],
      Mood.angry: ['Eminem', 'Rage Against The Machine', 'Metallica'],
      Mood.calm: ['Norah Jones', 'Jack Johnson', 'Bon Iver'],
      Mood.anxious: ['Radiohead', 'The National', 'Sigur Rós'],
      Mood.excited: ['Calvin Harris', 'David Guetta', 'Skrillex'],
    };

    final moodSongs = {
      Mood.happy: ['Happy', 'Uptown Funk', 'Can\'t Stop the Feeling'],
      Mood.sad: ['Someone Like You', 'Stay With Me', 'Hurt'],
      Mood.angry: ['Lose Yourself', 'Killing in the Name', 'Enter Sandman'],
      Mood.calm: ['Come Away With Me', 'Better Together', 'Holocene'],
      Mood.anxious: ['Creep', 'I Need My Girl', 'Hoppípolla'],
      Mood.excited: ['Feel So Close', 'Titanium', 'Bangarang'],
    };

    final artists = moodArtists[mood] ?? ['Unknown Artist'];
    final songs = moodSongs[mood] ?? ['Unknown Song'];
    final genres = mood.musicGenres;

    final recommendations = <Song>[];
    for (int i = 0; i < 3; i++) {
      recommendations.add(Song(
        id: '${mood.displayName.toLowerCase()}_rec_$i',
        name: songs[i % songs.length],
        artist: artists[i % artists.length],
        albumImageUrl: null,
        previewUrl: null,
        spotifyUrl: 'https://open.spotify.com/track/${mood.displayName.toLowerCase()}_$i',
        popularity: 80.0 + (i * 2),
        genres: [genres[i % genres.length]],
      ));
    }

    return recommendations;
  }

  // Logout from Spotify
  Future<void> logout() async {
    _isAuthenticated = false;
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiryDate = null;
    _recentTracks.clear();
    _topTracks.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_token_expiry');

    notifyListeners();
  }

  // Get user's listening patterns for recommendation engine
  Map<String, dynamic> get listeningPatterns {
    if (!_isAuthenticated || _topTracks.isEmpty) {
      return {
        'dominant_genres': ['pop'],
        'avg_popularity': 75.0,
        'favorite_artists': ['Various Artists'],
      };
    }

    final allGenres = _topTracks.expand((song) => song.genres).toList();
    final genreCounts = <String, int>{};
    for (final genre in allGenres) {
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }

    final dominantGenres = genreCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(3)
        .map((e) => e.key)
        .toList();

    final avgPopularity = _topTracks
        .map((song) => song.popularity ?? 0)
        .reduce((a, b) => a + b) / _topTracks.length;

    final favoriteArtists = _topTracks
        .map((song) => song.artist)
        .toSet()
        .take(3)
        .toList();

    return {
      'dominant_genres': dominantGenres,
      'avg_popularity': avgPopularity,
      'favorite_artists': favoriteArtists,
    };
  }
} 