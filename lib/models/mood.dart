enum Mood {
  happy,
  sad,
  angry,
  calm,
  anxious,
  excited,
}

extension MoodExtension on Mood {
  String get displayName {
    switch (this) {
      case Mood.happy:
        return 'Happy';
      case Mood.sad:
        return 'Sad';
      case Mood.angry:
        return 'Angry';
      case Mood.calm:
        return 'Calm';
      case Mood.anxious:
        return 'Anxious';
      case Mood.excited:
        return 'Excited';
    }
  }

  String get emoji {
    switch (this) {
      case Mood.happy:
        return '😊';
      case Mood.sad:
        return '😢';
      case Mood.angry:
        return '😠';
      case Mood.calm:
        return '😌';
      case Mood.anxious:
        return '😰';
      case Mood.excited:
        return '🤩';
    }
  }

  String get colorHex {
    switch (this) {
      case Mood.happy:
        return '#FFD700'; // yellow
      case Mood.sad:
        return '#4682B4'; // blue
      case Mood.angry:
        return '#DC143C'; // red
      case Mood.calm:
        return '#32CD32'; // green
      case Mood.anxious:
        return '#9370DB'; // purple
      case Mood.excited:
        return '#FF8C00'; // orange
    }
  }

  List<String> get musicGenres {
    switch (this) {
      case Mood.happy:
        return ['pop', 'dance', 'disco'];
      case Mood.sad:
        return ['acoustic', 'piano', 'ambient'];
      case Mood.angry:
        return ['metal', 'rock', 'hardcore'];
      case Mood.calm:
        return ['classical', 'chill', 'lofi'];
      case Mood.anxious:
        return ['ambient', 'meditation', 'soft rock'];
      case Mood.excited:
        return ['edm', 'hip-hop', 'trap'];
    }
  }
} 