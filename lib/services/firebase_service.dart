import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

class FirebaseService {
  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;
  
  static FirebaseAnalytics get analytics => _analytics!;
  static FirebaseCrashlytics get crashlytics => _crashlytics!;
  
  /// Initialize Firebase services
  static Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Analytics
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);
      
      // Initialize Crashlytics
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Set up Crashlytics
      if (kDebugMode) {
        // Disable Crashlytics collection while in debug mode
        await _crashlytics!.setCrashlyticsCollectionEnabled(false);
      } else {
        // Enable Crashlytics collection in release mode
        await _crashlytics!.setCrashlyticsCollectionEnabled(true);
        
        // Pass all uncaught "fatal" errors from the framework to Crashlytics
        FlutterError.onError = (errorDetails) {
          _crashlytics!.recordFlutterFatalError(errorDetails);
        };
        
        // Pass all uncaught asynchronous errors to Crashlytics
        PlatformDispatcher.instance.onError = (error, stack) {
          _crashlytics!.recordError(error, stack, fatal: true);
          return true;
        };
      }
      
      debugPrint('✅ Firebase initialized successfully');
      
      // Log successful initialization
      await logEvent('firebase_initialized', parameters: {
        'timestamp': DateTime.now().toIso8601String(),
        'debug_mode': kDebugMode,
      });
      
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization failed: $e');
      
      // In production, we still want to record this error if possible
      if (!kDebugMode) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Firebase initialization failed',
          fatal: false,
        );
      }
      
      rethrow;
    }
  }
  
  
  /// Log analytics event
  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    try {
      if (_analytics != null) {
        // Filter out any null values and ensure the map is of type Map<String, Object>
        Map<String, Object>? nonNullParams;
        if (parameters != null) {
          final filtered = <String, Object>{};
          parameters.forEach((key, value) {
            if (value != null) {
              filtered[key] = value;
            }
          });
          nonNullParams = filtered;
        }

        await _analytics!.logEvent(
          name: name,
          parameters: nonNullParams,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to log analytics event: $e');
    }
  }
  
  /// Set user properties for analytics
  static Future<void> setUserProperties({
    String? userId,
    Map<String, String?>? properties,
  }) async {
    try {
      if (_analytics != null) {
        if (userId != null) {
          await _analytics!.setUserId(id: userId);
        }
        
        if (properties != null) {
          for (final entry in properties.entries) {
            await _analytics!.setUserProperty(
              name: entry.key,
              value: entry.value,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to set user properties: $e');
    }
  }
  
  /// Record custom error
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      if (_crashlytics != null) {
        await _crashlytics!.recordError(
          exception,
          stackTrace,
          reason: reason,
          fatal: fatal,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to record error: $e');
    }
  }
  
  /// Set custom key for debugging
  static Future<void> setCustomKey(String key, Object value) async {
    try {
      if (_crashlytics != null) {
        await _crashlytics!.setCustomKey(key, value);
      }
    } catch (e) {
      debugPrint('❌ Failed to set custom key: $e');
    }
  }
  
  /// Set user identifier for debugging
  static Future<void> setUserIdentifier(String identifier) async {
    try {
      if (_crashlytics != null) {
        await _crashlytics!.setUserIdentifier(identifier);
      }
    } catch (e) {
      debugPrint('❌ Failed to set user identifier: $e');
    }
  }
}