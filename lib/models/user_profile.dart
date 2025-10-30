import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus {
  free,
  premiumMonthly,
  premiumYearly,
  premiumLifetime,
}

enum OnboardingStatus {
  notStarted,
  inProgress,
  completed,
}

class Location {
  final double latitude;
  final double longitude;
  final String? address;
  
  const Location({
    required this.latitude,
    required this.longitude,
    this.address,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
  
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address;
  }
  
  @override
  int get hashCode => Object.hash(latitude, longitude, address);
}

class UserPreferences {
  final List<String> preferredGenres;
  final List<String> preferredArtists;
  final bool locationEnabled;
  final bool notificationsEnabled;
  final bool analyticsEnabled;
  final int privacyLevel; // 1 = minimal, 2 = balanced, 3 = full
  final bool darkModeEnabled;
  
  const UserPreferences({
    this.preferredGenres = const [],
    this.preferredArtists = const [],
    this.locationEnabled = true,
    this.notificationsEnabled = true,
    this.analyticsEnabled = true,
    this.privacyLevel = 2,
    this.darkModeEnabled = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'preferredGenres': preferredGenres,
      'preferredArtists': preferredArtists,
      'locationEnabled': locationEnabled,
      'notificationsEnabled': notificationsEnabled,
      'analyticsEnabled': analyticsEnabled,
      'privacyLevel': privacyLevel,
      'darkModeEnabled': darkModeEnabled,
    };
  }
  
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferredGenres: List<String>.from(json['preferredGenres'] ?? []),
      preferredArtists: List<String>.from(json['preferredArtists'] ?? []),
      locationEnabled: json['locationEnabled'] ?? true,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      analyticsEnabled: json['analyticsEnabled'] ?? true,
      privacyLevel: json['privacyLevel'] ?? 2,
      darkModeEnabled: json['darkModeEnabled'] ?? false,
    );
  }
  
  UserPreferences copyWith({
    List<String>? preferredGenres,
    List<String>? preferredArtists,
    bool? locationEnabled,
    bool? notificationsEnabled,
    bool? analyticsEnabled,
    int? privacyLevel,
    bool? darkModeEnabled,
  }) {
    return UserPreferences(
      preferredGenres: preferredGenres ?? this.preferredGenres,
      preferredArtists: preferredArtists ?? this.preferredArtists,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final SubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final OnboardingStatus onboardingStatus;
  final UserPreferences preferences;
  final Location? location;
  final Map<String, dynamic> metadata;
  
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    this.subscriptionStatus = SubscriptionStatus.free,
    this.subscriptionExpiresAt,
    this.onboardingStatus = OnboardingStatus.notStarted,
    this.preferences = const UserPreferences(),
    this.location,
    this.metadata = const {},
  });
  
  /// Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'subscriptionStatus': subscriptionStatus.name,
      'subscriptionExpiresAt': subscriptionExpiresAt != null 
          ? Timestamp.fromDate(subscriptionExpiresAt!) 
          : null,
      'onboardingStatus': onboardingStatus.name,
      'preferences': preferences.toJson(),
      'location': location?.toJson(),
      'metadata': metadata,
    };
  }
  
  /// Create from Firebase document
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp).toDate(),
      subscriptionStatus: SubscriptionStatus.values.firstWhere(
        (status) => status.name == json['subscriptionStatus'],
        orElse: () => SubscriptionStatus.free,
      ),
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
          ? (json['subscriptionExpiresAt'] as Timestamp).toDate()
          : null,
      onboardingStatus: OnboardingStatus.values.firstWhere(
        (status) => status.name == json['onboardingStatus'],
        orElse: () => OnboardingStatus.notStarted,
      ),
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : const UserPreferences(),
      location: json['location'] != null
          ? Location.fromJson(json['location'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  /// Create copy with updated fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    SubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
    OnboardingStatus? onboardingStatus,
    UserPreferences? preferences,
    Location? location,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      preferences: preferences ?? this.preferences,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Check if user has active premium subscription
  bool get isPremium {
    if (subscriptionStatus == SubscriptionStatus.free) return false;
    if (subscriptionStatus == SubscriptionStatus.premiumLifetime) return true;
    
    // Check if subscription has expired
    if (subscriptionExpiresAt != null) {
      return DateTime.now().isBefore(subscriptionExpiresAt!);
    }
    
    return false;
  }
  
  /// Check if onboarding is completed
  bool get isOnboardingCompleted => onboardingStatus == OnboardingStatus.completed;
  
  /// Get subscription display name
  String get subscriptionDisplayName {
    switch (subscriptionStatus) {
      case SubscriptionStatus.free:
        return 'Free';
      case SubscriptionStatus.premiumMonthly:
        return 'Premium Monthly';
      case SubscriptionStatus.premiumYearly:
        return 'Premium Annual';
      case SubscriptionStatus.premiumLifetime:
        return 'Premium Lifetime';
    }
  }
  
  /// Get days until subscription expires
  int? get daysUntilExpiration {
    if (subscriptionExpiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(subscriptionExpiresAt!)) return 0;
    return subscriptionExpiresAt!.difference(now).inDays;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.email == email &&
        other.subscriptionStatus == subscriptionStatus;
  }
  
  @override
  int get hashCode => Object.hash(id, email, subscriptionStatus);
  
  @override
  String toString() {
    return 'UserProfile(id: $id, email: $email, subscription: $subscriptionDisplayName)';
  }
}