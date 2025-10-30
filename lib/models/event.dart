class Event {
  final String id;
  final String name;
  final DateTime date;
  final String venue;
  final String location;
  final String? imageUrl;
  final String? ticketUrl;
  final double? latitude;
  final double? longitude;

  const Event({
    required this.id,
    required this.name,
    required this.date,
    required this.venue,
    required this.location,
    this.imageUrl,
    this.ticketUrl,
    this.latitude,
    this.longitude,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      date: DateTime.parse(json['date']),
      venue: json['venue'] ?? '',
      location: json['location'] ?? '',
      imageUrl: json['image_url'],
      ticketUrl: json['ticket_url'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'venue': venue,
      'location': location,
      'image_url': imageUrl,
      'ticket_url': ticketUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static Event get mockEvent => Event(
        id: 'mock_event_1',
        name: 'Live Music Night',
        date: DateTime.now().add(const Duration(days: 7)),
        venue: 'The Music Hall',
        location: 'Downtown',
        imageUrl: null,
        ticketUrl: null,
        latitude: 37.7749,
        longitude: -122.4194,
      );
} 