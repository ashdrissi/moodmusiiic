import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  
  /// Create a new user profile
  static Future<UserProfile> createUserProfile(
    User firebaseUser, {
    required String authMethod,
  }) async {
    try {
      final now = DateTime.now();
      
      final userProfile = UserProfile(
        id: firebaseUser.uid,
        email: firebaseUser.email!,
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: now,
        lastLoginAt: now,
        subscriptionStatus: SubscriptionStatus.free,
        onboardingStatus: OnboardingStatus.notStarted,
        preferences: const UserPreferences(),
        metadata: {
          'authMethod': authMethod,
          'emailVerified': firebaseUser.emailVerified,
          'createdVia': 'mobile_app',
          'version': '1.0.0',
        },
      );
      
      // Save to Firestore
      await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .set(userProfile.toJson());
      
      debugPrint('✅ User profile created: ${firebaseUser.uid}');
      
      await FirebaseService.logEvent('user_profile_created', parameters: {
        'user_id': firebaseUser.uid,
        'auth_method': authMethod,
        'email_verified': firebaseUser.emailVerified,
      });
      
      return userProfile;
      
    } catch (e) {
      debugPrint('❌ Failed to create user profile: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'User profile creation failed');
      rethrow;
    }
  }
  
  /// Get user profile by ID
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        debugPrint('⚠️ User profile not found: $userId');
        return null;
      }
      
      final data = doc.data()!;
      return UserProfile.fromJson(data);
      
    } catch (e) {
      debugPrint('❌ Failed to get user profile: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to get user profile');
      return null;
    }
  }
  
  /// Update user profile
  static Future<UserProfile> updateUserProfile(
    String userId,
    UserProfile updatedProfile,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updatedProfile.toJson());
      
      debugPrint('✅ User profile updated: $userId');
      
      await FirebaseService.logEvent('user_profile_updated', parameters: {
        'user_id': userId,
      });
      
      return updatedProfile;
      
    } catch (e) {
      debugPrint('❌ Failed to update user profile: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'User profile update failed');
      rethrow;
    }
  }
  
  /// Update user preferences
  static Future<void> updateUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'preferences': preferences.toJson(),
      });
      
      debugPrint('✅ User preferences updated: $userId');
      
      await FirebaseService.logEvent('user_preferences_updated', parameters: {
        'user_id': userId,
        'location_enabled': preferences.locationEnabled,
        'notifications_enabled': preferences.notificationsEnabled,
        'analytics_enabled': preferences.analyticsEnabled,
        'privacy_level': preferences.privacyLevel,
      });
      
    } catch (e) {
      debugPrint('❌ Failed to update user preferences: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'User preferences update failed');
      rethrow;
    }
  }
  
  /// Update subscription status
  static Future<void> updateSubscriptionStatus(
    String userId,
    SubscriptionStatus status, {
    DateTime? expiresAt,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'subscriptionStatus': status.name,
      };
      
      if (expiresAt != null) {
        updateData['subscriptionExpiresAt'] = Timestamp.fromDate(expiresAt);
      }
      
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updateData);
      
      debugPrint('✅ Subscription status updated: $userId -> ${status.name}');
      
      await FirebaseService.logEvent('subscription_status_updated', parameters: {
        'user_id': userId,
        'subscription_status': status.name,
        'expires_at': expiresAt?.toIso8601String(),
      });
      
    } catch (e) {
      debugPrint('❌ Failed to update subscription status: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Subscription status update failed');
      rethrow;
    }
  }
  
  /// Update onboarding status
  static Future<void> updateOnboardingStatus(
    String userId,
    OnboardingStatus status,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'onboardingStatus': status.name,
      });
      
      debugPrint('✅ Onboarding status updated: $userId -> ${status.name}');
      
      await FirebaseService.logEvent('onboarding_status_updated', parameters: {
        'user_id': userId,
        'onboarding_status': status.name,
      });
      
    } catch (e) {
      debugPrint('❌ Failed to update onboarding status: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Onboarding status update failed');
      rethrow;
    }
  }
  
  /// Update user location
  static Future<void> updateUserLocation(
    String userId,
    Location location,
  ) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'location': location.toJson(),
      });
      
      debugPrint('✅ User location updated: $userId');
      
      await FirebaseService.logEvent('user_location_updated', parameters: {
        'user_id': userId,
        'has_address': location.address != null,
      });
      
    } catch (e) {
      debugPrint('❌ Failed to update user location: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'User location update failed');
      rethrow;
    }
  }
  
  /// Update last login time
  static Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      });
      
      debugPrint('✅ Last login updated: $userId');
      
    } catch (e) {
      debugPrint('❌ Failed to update last login: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Last login update failed');
      // Don't rethrow as this is not critical
    }
  }
  
  /// Add preferred genres
  static Future<void> addPreferredGenres(
    String userId,
    List<String> genres,
  ) async {
    try {
      final userProfile = await getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      final currentGenres = Set<String>.from(userProfile.preferences.preferredGenres);
      currentGenres.addAll(genres);
      
      final updatedPreferences = userProfile.preferences.copyWith(
        preferredGenres: currentGenres.toList(),
      );
      
      await updateUserPreferences(userId, updatedPreferences);
      
      await FirebaseService.logEvent('preferred_genres_added', parameters: {
        'user_id': userId,
        'genres_count': genres.length,
        'total_genres': currentGenres.length,
      });
      
    } catch (e) {
      debugPrint('❌ Failed to add preferred genres: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to add preferred genres');
      rethrow;
    }
  }
  
  /// Add preferred artists
  static Future<void> addPreferredArtists(
    String userId,
    List<String> artists,
  ) async {
    try {
      final userProfile = await getUserProfile(userId);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }
      
      final currentArtists = Set<String>.from(userProfile.preferences.preferredArtists);
      currentArtists.addAll(artists);
      
      final updatedPreferences = userProfile.preferences.copyWith(
        preferredArtists: currentArtists.toList(),
      );
      
      await updateUserPreferences(userId, updatedPreferences);
      
      await FirebaseService.logEvent('preferred_artists_added', parameters: {
        'user_id': userId,
        'artists_count': artists.length,
        'total_artists': currentArtists.length,
      });
      
    } catch (e) {
      debugPrint('❌ Failed to add preferred artists: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to add preferred artists');
      rethrow;
    }
  }
  
  /// Get user's mood scan count for today
  static Future<int> getTodayMoodScanCount(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moodSessions')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      return querySnapshot.docs.length;
      
    } catch (e) {
      debugPrint('❌ Failed to get today mood scan count: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to get today mood scan count');
      return 0;
    }
  }
  
  /// Check if user can perform mood scan (respects free tier limits)
  static Future<bool> canPerformMoodScan(String userId) async {
    try {
      final userProfile = await getUserProfile(userId);
      if (userProfile == null) return false;
      
      // Premium users have unlimited scans
      if (userProfile.isPremium) return true;
      
      // Free users get 3 scans per day
      const freeTierDailyLimit = 3;
      final todayCount = await getTodayMoodScanCount(userId);
      
      return todayCount < freeTierDailyLimit;
      
    } catch (e) {
      debugPrint('❌ Failed to check mood scan eligibility: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to check mood scan eligibility');
      return false;
    }
  }
  
  /// Delete user profile and all associated data
  static Future<void> deleteUserProfile(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete main user document
      final userDoc = _firestore.collection(_usersCollection).doc(userId);
      batch.delete(userDoc);
      
      // Delete user's mood sessions
      final moodSessions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moodSessions')
          .get();
      
      for (final doc in moodSessions.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's music recommendations
      final musicRecommendations = await _firestore
          .collection('users')
          .doc(userId)
          .collection('musicRecommendations')
          .get();
      
      for (final doc in musicRecommendations.docs) {
        batch.delete(doc.reference);
      }
      
      // Commit all deletions
      await batch.commit();
      
      debugPrint('✅ User profile and data deleted: $userId');
      
      await FirebaseService.logEvent('user_profile_deleted', parameters: {
        'user_id': userId,
        'mood_sessions_count': moodSessions.docs.length,
        'music_recommendations_count': musicRecommendations.docs.length,
      });
      
    } catch (e) {
      debugPrint('❌ Failed to delete user profile: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'User profile deletion failed');
      rethrow;
    }
  }
  
  /// Export user data (GDPR compliance)
  static Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      final userData = <String, dynamic>{};
      
      // Get user profile
      final userProfile = await getUserProfile(userId);
      if (userProfile != null) {
        userData['profile'] = userProfile.toJson();
      }
      
      // Get mood sessions
      final moodSessions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('moodSessions')
          .orderBy('timestamp', descending: true)
          .get();
      
      userData['moodSessions'] = moodSessions.docs
          .map((doc) => doc.data())
          .toList();
      
      // Get music recommendations
      final musicRecommendations = await _firestore
          .collection('users')
          .doc(userId)
          .collection('musicRecommendations')
          .orderBy('timestamp', descending: true)
          .get();
      
      userData['musicRecommendations'] = musicRecommendations.docs
          .map((doc) => doc.data())
          .toList();
      
      userData['exportedAt'] = DateTime.now().toIso8601String();
      userData['version'] = '1.0.0';
      
      await FirebaseService.logEvent('user_data_exported', parameters: {
        'user_id': userId,
        'mood_sessions_count': moodSessions.docs.length,
        'music_recommendations_count': musicRecommendations.docs.length,
      });
      
      return userData;
      
    } catch (e) {
      debugPrint('❌ Failed to export user data: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'User data export failed');
      rethrow;
    }
  }
}