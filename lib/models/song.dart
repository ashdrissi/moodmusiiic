class Song {
  final String id;
  final String name;
  final String artist;
  final String? albumImageUrl;
  final String? previewUrl;
  final String? spotifyUrl;
  final double? popularity;
  final List<String> genres;

  const Song({
    required this.id,
    required this.name,
    required this.artist,
    this.albumImageUrl,
    this.previewUrl,
    this.spotifyUrl,
    this.popularity,
    this.genres = const [],
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      artist: json['artist'] ?? '',
      albumImageUrl: json['album_image_url'],
      previewUrl: json['preview_url'],
      spotifyUrl: json['spotify_url'],
      popularity: json['popularity']?.toDouble(),
      genres: List<String>.from(json['genres'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'album_image_url': albumImageUrl,
      'preview_url': previewUrl,
      'spotify_url': spotifyUrl,
      'popularity': popularity,
      'genres': genres,
    };
  }

  static Song get mockSong => const Song(
        id: 'mock_song_1',
        name: 'Good Vibes Only',
        artist: 'Happy Beats',
        albumImageUrl: null,
        previewUrl: null,
        spotifyUrl: null,
        popularity: 85.0,
        genres: ['pop', 'dance'],
      );
} 