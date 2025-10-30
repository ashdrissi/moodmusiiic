import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';  
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';
import '../services/user_service.dart';

class AuthResult {
  final bool success;
  final UserProfile? user;
  final String? error;
  final String? errorCode;
  
  const AuthResult({
    required this.success,
    this.user,
    this.error,
    this.errorCode,
  });
  
  factory AuthResult.success(UserProfile user) {
    return AuthResult(success: true, user: user);
  }
  
  factory AuthResult.failure(String error, [String? errorCode]) {
    return AuthResult(success: false, error: error, errorCode: errorCode);
  }
}

class AuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'openid', 'profile'],
  );
  
  static User? get currentFirebaseUser => _firebaseAuth.currentUser;
  static bool get isSignedIn => _firebaseAuth.currentUser != null;
  
  /// Initialize auth service and set up listeners
  static Future<void> initialize() async {
    try {
      // Set up auth state listener
      _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
      
      // Set up ID token listener for token refresh
      _firebaseAuth.idTokenChanges().listen(_onIdTokenChanged);
      
      debugPrint('✅ AuthService initialized');
      
      await FirebaseService.logEvent('auth_service_initialized');
    } catch (e) {
      debugPrint('❌ AuthService initialization failed: $e');
      await FirebaseService.recordError(e, StackTrace.current, 
          reason: 'AuthService initialization failed');
      rethrow;
    }
  }
  
  /// Handle auth state changes
  static void _onAuthStateChanged(User? user) async {
    try {
      if (user != null) {
        debugPrint('✅ User signed in: ${user.email}');
        
        // Update last login time
        await UserService.updateLastLogin(user.uid);
        
        // Set user identifier for crash reporting
        await FirebaseService.setUserIdentifier(user.uid);
        await FirebaseService.setUserProperties(
          userId: user.uid,
          properties: {
            'email': user.email,
            'email_verified': user.emailVerified.toString(),
            'provider': user.providerData.first.providerId,
          },
        );
        
        await FirebaseService.logEvent('user_signed_in', parameters: {
          'method': user.providerData.first.providerId,
          'email_verified': user.emailVerified,
        });
      } else {
        debugPrint('🔐 User signed out');
        
        // Clear user data
        await FirebaseService.setUserIdentifier('');
        await FirebaseService.logEvent('user_signed_out');
      }
    } catch (e) {
      debugPrint('❌ Error handling auth state change: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Auth state change handler failed');
    }
  }
  
  /// Handle ID token changes for token refresh
  static void _onIdTokenChanged(User? user) async {
    try {
      if (user != null) {
        // Get fresh token for API calls
        final token = await user.getIdToken(true);
        debugPrint('🔄 ID token refreshed for user: ${user.uid}');
        
        // Store token securely if needed for API calls
        // This would be handled by individual API services
      }
    } catch (e) {
      debugPrint('❌ Error refreshing ID token: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'ID token refresh failed');
    }
  }
  
  /// Sign up with email and password
  static Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      await FirebaseService.logEvent('signup_attempt', parameters: {
        'method': 'email',
      });
      
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Failed to create user account');
      }
      
      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
      
      // Send email verification
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
      
      // Create user profile
      final userProfile = await UserService.createUserProfile(
        user,
        authMethod: 'email',
      );
      
      await FirebaseService.logEvent('signup_success', parameters: {
        'method': 'email',
        'user_id': user.uid,
      });
      
      return AuthResult.success(userProfile);
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email signup failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('signup_failed', parameters: {
        'method': 'email',
        'error_code': e.code,
        'error_message': e.message,
      });
      
      return AuthResult.failure(_getErrorMessage(e), e.code);
    } catch (e) {
      debugPrint('❌ Unexpected signup error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Email signup failed');
      return AuthResult.failure('An unexpected error occurred during signup');
    }
  }
  
  /// Sign in with email and password
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseService.logEvent('signin_attempt', parameters: {
        'method': 'email',
      });
      
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Failed to sign in');
      }
      
      // Get or create user profile
      final userProfile = await UserService.getUserProfile(user.uid) ??
          await UserService.createUserProfile(user, authMethod: 'email');
      
      await FirebaseService.logEvent('signin_success', parameters: {
        'method': 'email',
        'user_id': user.uid,
      });
      
      return AuthResult.success(userProfile);
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email signin failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('signin_failed', parameters: {
        'method': 'email',
        'error_code': e.code,
        'error_message': e.message,
      });
      
      return AuthResult.failure(_getErrorMessage(e), e.code);
    } catch (e) {
      debugPrint('❌ Unexpected signin error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Email signin failed');
      return AuthResult.failure('An unexpected error occurred during signin');
    }
  }
  
  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      await FirebaseService.logEvent('signin_attempt', parameters: {
        'method': 'google',
      });
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return AuthResult.failure('Sign in was cancelled');
      }
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user == null) {
        return AuthResult.failure('Failed to sign in with Google');
      }
      
      // Get or create user profile
      final userProfile = await UserService.getUserProfile(user.uid) ??
          await UserService.createUserProfile(user, authMethod: 'google');
      
      await FirebaseService.logEvent('signin_success', parameters: {
        'method': 'google',
        'user_id': user.uid,
      });
      
      return AuthResult.success(userProfile);
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Google signin failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('signin_failed', parameters: {
        'method': 'google',
        'error_code': e.code,
        'error_message': e.message,
      });
      
      return AuthResult.failure(_getErrorMessage(e), e.code);
    } catch (e) {
      debugPrint('❌ Unexpected Google signin error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Google signin failed');
      return AuthResult.failure('An unexpected error occurred during Google signin');
    }
  }
  
  /// Sign in with Apple (iOS only)
  static Future<AuthResult> signInWithApple() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.iOS) {
        return AuthResult.failure('Apple Sign In is only available on iOS');
      }
      
      await FirebaseService.logEvent('signin_attempt', parameters: {
        'method': 'apple',
      });
      
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      // Create OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      // Sign in to Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      
      if (user == null) {
        return AuthResult.failure('Failed to sign in with Apple');
      }
      
      // Update display name if provided and not already set
      if (user.displayName == null && appleCredential.givenName != null) {
        final fullName = '${appleCredential.givenName} ${appleCredential.familyName}'.trim();
        await user.updateDisplayName(fullName);
        await user.reload();
      }
      
      // Get or create user profile
      final userProfile = await UserService.getUserProfile(user.uid) ??
          await UserService.createUserProfile(user, authMethod: 'apple');
      
      await FirebaseService.logEvent('signin_success', parameters: {
        'method': 'apple',
        'user_id': user.uid,
      });
      
      return AuthResult.success(userProfile);
      
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('❌ Apple signin failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('signin_failed', parameters: {
        'method': 'apple',
        'error_code': e.code.toString(),
        'error_message': e.message,
      });
      
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure('Sign in was cancelled');
      }
      
      return AuthResult.failure('Apple Sign In failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Apple signin failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('signin_failed', parameters: {
        'method': 'apple',
        'error_code': e.code,
        'error_message': e.message,
      });
      
      return AuthResult.failure(_getErrorMessage(e), e.code);
    } catch (e) {
      debugPrint('❌ Unexpected Apple signin error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Apple signin failed');
      return AuthResult.failure('An unexpected error occurred during Apple signin');
    }
  }
  
  /// Send password reset email
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await FirebaseService.logEvent('password_reset_attempt', parameters: {
        'email': email.trim(),
      });
      
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      
      await FirebaseService.logEvent('password_reset_sent', parameters: {
        'email': email.trim(),
      });
      
      return AuthResult.success(
        UserProfile(
          id: '',
          email: email,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
      );
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Password reset failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('password_reset_failed', parameters: {
        'email': email.trim(),
        'error_code': e.code,
        'error_message': e.message,
      });
      
      return AuthResult.failure(_getErrorMessage(e), e.code);
    } catch (e) {
      debugPrint('❌ Unexpected password reset error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Password reset failed');
      return AuthResult.failure('An unexpected error occurred during password reset');
    }
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    try {
      final userId = _firebaseAuth.currentUser?.uid;
      
      await FirebaseService.logEvent('signout_attempt', parameters: {
        'user_id': userId,
      });
      
      // Sign out from all providers
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      await FirebaseService.logEvent('signout_success', parameters: {
        'user_id': userId,
      });
      
      debugPrint('✅ User signed out successfully');
      
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Sign out failed');
    }
  }
  
  /// Delete current user account
  static Future<AuthResult> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user is currently signed in');
      }
      
      final userId = user.uid;
      
      await FirebaseService.logEvent('account_deletion_attempt', parameters: {
        'user_id': userId,
      });
      
      // Delete user profile data
      await UserService.deleteUserProfile(userId);
      
      // Delete Firebase Auth user
      await user.delete();
      
      await FirebaseService.logEvent('account_deletion_success', parameters: {
        'user_id': userId,
      });
      
      return AuthResult.success(
        UserProfile(
          id: userId,
          email: user.email ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
      );
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Account deletion failed: ${e.code} - ${e.message}');
      
      await FirebaseService.logEvent('account_deletion_failed', parameters: {
        'error_code': e.code,
        'error_message': e.message,
      });
      
      if (e.code == 'requires-recent-login') {
        return AuthResult.failure(
          'This operation requires recent authentication. Please sign out and sign back in.',
          e.code,
        );
      }
      
      return AuthResult.failure(_getErrorMessage(e), e.code);
    } catch (e) {
      debugPrint('❌ Unexpected account deletion error: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Account deletion failed');
      return AuthResult.failure('An unexpected error occurred during account deletion');
    }
  }
  
  /// Get current user's ID token
  static Future<String?> getCurrentUserToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;
      
      return await user.getIdToken();
    } catch (e) {
      debugPrint('❌ Failed to get user token: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to get user token');
      return null;
    }
  }
  
  /// Refresh current user's ID token
  static Future<String?> refreshUserToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;
      
      return await user.getIdToken(true);
    } catch (e) {
      debugPrint('❌ Failed to refresh user token: $e');
      await FirebaseService.recordError(e, StackTrace.current,
          reason: 'Failed to refresh user token');
      return null;
    }
  }
  
  /// Convert Firebase Auth errors to user-friendly messages
  static String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been temporarily disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      case 'credential-already-in-use':
        return 'This account is already linked with another user.';
      case 'invalid-credential':
        return 'The provided credential is invalid.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}