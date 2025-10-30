import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/firebase_service.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  UserProfile? _userProfile;
  String? _errorMessage;
  bool _isLoading = false;
  
  // Getters
  AuthState get state => _state;
  UserProfile? get userProfile => _userProfile;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated && _userProfile != null;
  bool get isOnboardingCompleted => _userProfile?.isOnboardingCompleted ?? false;
  bool get isPremium => _userProfile?.isPremium ?? false;
  
  /// Initialize auth provider
  Future<void> initialize() async {
    try {
      _setState(AuthState.loading);

      // Initialize auth service
      await AuthService.initialize();

      // Check if user is already signed in
      if (AuthService.isSignedIn) {
        final user = AuthService.currentFirebaseUser!;
        final userProfile = await UserService.getUserProfile(user.uid);

        if (userProfile != null) {
          _userProfile = userProfile;
          _setState(AuthState.authenticated);
        } else {
          // User exists in Firebase Auth but not in our database
          // This could happen if profile creation failed previously
          final newProfile = await UserService.createUserProfile(
            user,
            authMethod: 'unknown',
          );
          _userProfile = newProfile;
          _setState(AuthState.authenticated);
        }
      } else {
        _setState(AuthState.unauthenticated);
      }

      // Listen to auth state changes
      FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);

    } catch (e) {
      debugPrint('❌ AuthProvider initialization failed: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Try to record error if Firebase is available
      try {
        await FirebaseService.recordError(e, StackTrace.current,
            reason: 'AuthProvider initialization failed');
      } catch (firebaseError) {
        debugPrint('⚠️ Could not record error to Firebase: $firebaseError');
      }

      // Set unauthenticated state instead of error to allow app to continue
      _setState(AuthState.unauthenticated);
    }
  }
  
  /// Handle Firebase auth state changes
  void _onAuthStateChanged(User? user) async {
    try {
      if (user != null) {
        // User signed in
        final userProfile = await UserService.getUserProfile(user.uid);
        if (userProfile != null) {
          _userProfile = userProfile;
          _setState(AuthState.authenticated);
        }
      } else {
        // User signed out
        _userProfile = null;
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      debugPrint('❌ Error handling auth state change: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Auth state change handling failed');
    }
  }
  
  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _performAuthAction(() async {
      final result = await AuthService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      if (result.success && result.user != null) {
        _userProfile = result.user;
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError(result.error ?? 'Sign up failed');
        return false;
      }
    });
  }
  
  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _performAuthAction(() async {
      final result = await AuthService.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (result.success && result.user != null) {
        _userProfile = result.user;
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError(result.error ?? 'Sign in failed');
        return false;
      }
    });
  }
  
  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    return _performAuthAction(() async {
      final result = await AuthService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        _userProfile = result.user;
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError(result.error ?? 'Google sign in failed');
        return false;
      }
    });
  }
  
  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    return _performAuthAction(() async {
      final result = await AuthService.signInWithApple();
      
      if (result.success && result.user != null) {
        _userProfile = result.user;
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError(result.error ?? 'Apple sign in failed');
        return false;
      }
    });
  }
  
  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    return _performAuthAction(() async {
      final result = await AuthService.resetPassword(email);
      
      if (result.success) {
        return true;
      } else {
        _setError(result.error ?? 'Password reset failed');
        return false;
      }
    });
  }
  
  /// Sign out current user
  Future<void> signOut() async {
    try {
      _setLoading(true);
      
      await AuthService.signOut();
      
      _userProfile = null;
      _setState(AuthState.unauthenticated);
      
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Sign out failed');
      _setError('Sign out failed');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Delete user account
  Future<bool> deleteAccount() async {
    return _performAuthAction(() async {
      final result = await AuthService.deleteAccount();
      
      if (result.success) {
        _userProfile = null;
        _setState(AuthState.unauthenticated);
        return true;
      } else {
        _setError(result.error ?? 'Account deletion failed');
        return false;
      }
    });
  }
  
  /// Update user profile
  Future<bool> updateUserProfile(UserProfile updatedProfile) async {
    try {
      _setLoading(true);
      
      if (_userProfile == null) {
        _setError('No user is currently signed in');
        return false;
      }
      
      final updated = await UserService.updateUserProfile(
        _userProfile!.id,
        updatedProfile,
      );
      
      _userProfile = updated;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Update user profile failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Update user profile failed');
      _setError('Failed to update profile');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Update user preferences
  Future<bool> updateUserPreferences(UserPreferences preferences) async {
    try {
      _setLoading(true);
      
      if (_userProfile == null) {
        _setError('No user is currently signed in');
        return false;
      }
      
      await UserService.updateUserPreferences(_userProfile!.id, preferences);
      
      _userProfile = _userProfile!.copyWith(preferences: preferences);
      notifyListeners();
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Update user preferences failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Update user preferences failed');
      _setError('Failed to update preferences');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Update subscription status
  Future<bool> updateSubscriptionStatus(
    SubscriptionStatus status, {
    DateTime? expiresAt,
  }) async {
    try {
      _setLoading(true);
      
      if (_userProfile == null) {
        _setError('No user is currently signed in');
        return false;
      }
      
      await UserService.updateSubscriptionStatus(
        _userProfile!.id,
        status,
        expiresAt: expiresAt,
      );
      
      _userProfile = _userProfile!.copyWith(
        subscriptionStatus: status,
        subscriptionExpiresAt: expiresAt,
      );
      notifyListeners();
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Update subscription status failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Update subscription status failed');
      _setError('Failed to update subscription');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Complete onboarding
  Future<bool> completeOnboarding() async {
    try {
      _setLoading(true);
      
      if (_userProfile == null) {
        _setError('No user is currently signed in');
        return false;
      }
      
      await UserService.updateOnboardingStatus(
        _userProfile!.id,
        OnboardingStatus.completed,
      );
      
      _userProfile = _userProfile!.copyWith(
        onboardingStatus: OnboardingStatus.completed,
      );
      notifyListeners();
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Complete onboarding failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Complete onboarding failed');
      _setError('Failed to complete onboarding');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Add preferred genres
  Future<bool> addPreferredGenres(List<String> genres) async {
    try {
      _setLoading(true);
      
      if (_userProfile == null) {
        _setError('No user is currently signed in');
        return false;
      }
      
      await UserService.addPreferredGenres(_userProfile!.id, genres);
      
      // Update local profile
      final currentGenres = Set<String>.from(_userProfile!.preferences.preferredGenres);
      currentGenres.addAll(genres);
      
      final updatedPreferences = _userProfile!.preferences.copyWith(
        preferredGenres: currentGenres.toList(),
      );
      
      _userProfile = _userProfile!.copyWith(preferences: updatedPreferences);
      notifyListeners();
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Add preferred genres failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Add preferred genres failed');
      _setError('Failed to add preferred genres');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Check if user can perform mood scan
  Future<bool> canPerformMoodScan() async {
    try {
      if (_userProfile == null) return false;
      return await UserService.canPerformMoodScan(_userProfile!.id);
    } catch (e) {
      debugPrint('❌ Check mood scan eligibility failed: $e');
      return false;
    }
  }
  
  /// Get today's mood scan count
  Future<int> getTodayMoodScanCount() async {
    try {
      if (_userProfile == null) return 0;
      return await UserService.getTodayMoodScanCount(_userProfile!.id);
    } catch (e) {
      debugPrint('❌ Get today mood scan count failed: $e');
      return 0;
    }
  }
  
  /// Refresh user profile from database
  Future<void> refreshUserProfile() async {
    try {
      if (_userProfile == null) return;
      
      final updatedProfile = await UserService.getUserProfile(_userProfile!.id);
      if (updatedProfile != null) {
        _userProfile = updatedProfile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Refresh user profile failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Refresh user profile failed');
    }
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = _userProfile != null 
          ? AuthState.authenticated 
          : AuthState.unauthenticated;
    }
    notifyListeners();
  }
  
  /// Helper method to perform auth actions with loading state
  Future<bool> _performAuthAction(Future<bool> Function() action) async {
    try {
      _setLoading(true);
      return await action();
    } catch (e) {
      debugPrint('❌ Auth action failed: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Auth action failed');
      _setError('An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Set auth state
  void _setState(AuthState newState) {
    _state = newState;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Set error state
  void _setError(String error) {
    _errorMessage = error;
    _state = AuthState.error;
    _isLoading = false;
    notifyListeners();
  }
}