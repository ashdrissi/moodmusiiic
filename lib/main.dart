import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'providers/app_state_provider.dart';
import 'providers/aws_provider.dart';
import 'providers/spotify_provider.dart';
import 'providers/rekognition_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/start_screen.dart';
import 'screens/mood_scanner_screen.dart';
import 'screens/mood_results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/aws_debug_screen.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';
import 'models/app_state.dart';
import 'services/firebase_service.dart';

List<CameraDescription> cameras = [];

bool _firebaseInitialized = false;

Future<void> main() async {
  debugPrint('🚀 === MOODMUSIC APP STARTING ===');

  try {
    debugPrint('📱 Initializing WidgetsFlutterBinding...');
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('✅ WidgetsFlutterBinding initialized');
  } catch (e) {
    debugPrint('❌ WidgetsFlutterBinding failed: $e');
  }

  try {
    debugPrint('🔥 Initializing Firebase...');
    await FirebaseService.initialize();
    _firebaseInitialized = true;
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('⚠️ App will continue without Firebase features');
  }

  try {
    debugPrint('📷 Initializing cameras...');
    cameras = await availableCameras();
    debugPrint('✅ Cameras initialized: ${cameras.length} found');
  } catch (e) {
    debugPrint('❌ Camera initialization failed: $e');
  }

  debugPrint('🎨 Running MoodMusic app (Firebase: $_firebaseInitialized)');
  runApp(MoodMusicApp(firebaseInitialized: _firebaseInitialized));
  debugPrint('✅ runApp() called');
}

class MoodMusicApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MoodMusicApp({
    super.key,
    required this.firebaseInitialized,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building MoodMusicApp widget');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            debugPrint('🔐 Creating AuthProvider');
            return AuthProvider()..initialize();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            debugPrint('📊 Creating AppStateProvider');
            return AppStateProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            debugPrint('☁️ Creating AWSProvider');
            return AWSProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            debugPrint('🎵 Creating SpotifyProvider');
            return SpotifyProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            debugPrint('👁️ Creating RekognitionProvider');
            return RekognitionProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'MoodMusic',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: AppNavigator(firebaseInitialized: firebaseInitialized),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          debugPrint('🏗️ MaterialApp builder called');
          return child ?? const SizedBox();
        },
      ),
    );
  }
}

class AppNavigator extends StatefulWidget {
  final bool firebaseInitialized;

  const AppNavigator({
    super.key,
    required this.firebaseInitialized,
  });

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  static const int _maxInitializationTime = 10; // seconds
  bool _initializationTimedOut = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 AppNavigator initState called');
    debugPrint('Firebase initialized: ${widget.firebaseInitialized}');

    // Set a timeout for initialization
    Future.delayed(const Duration(seconds: _maxInitializationTime), () {
      if (mounted) {
        debugPrint('⏰ Initialization timeout reached');
        setState(() {
          _initializationTimedOut = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ AppNavigator build called (Firebase: ${widget.firebaseInitialized})');

    // If Firebase didn't initialize, skip auth and go straight to the app
    if (!widget.firebaseInitialized) {
      debugPrint('⚠️ Skipping auth - Firebase not initialized');
      return Consumer<AppStateProvider>(
        builder: (context, appStateProvider, child) {
          debugPrint('📱 AppStateProvider state: ${appStateProvider.currentState}');
          switch (appStateProvider.currentState) {
            case AppState.start:
              debugPrint('🎬 Showing StartScreen');
              return const StartScreen();
            case AppState.scanning:
              debugPrint('📷 Showing MoodScannerScreen');
              return MoodScannerScreen(cameras: cameras);
            case AppState.results:
              debugPrint('📊 Showing MoodResultsScreen');
              return MoodResultsScreen(
                mood: appStateProvider.detectedMood!,
                song: appStateProvider.recommendedSong,
                event: appStateProvider.recommendedEvent,
                emotionAnalysis: appStateProvider.emotionAnalysis,
              );
            case AppState.history:
              debugPrint('📜 Showing HistoryScreen');
              return const HistoryScreen();
            case AppState.awsDebug:
              debugPrint('🐛 Showing AWSDebugScreen');
              return const AWSDebugScreen();
          }
        },
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading screen while initializing
        if (authProvider.state == AuthState.initial || authProvider.state == AuthState.loading) {
          // If initialization is taking too long, show error
          if (_initializationTimedOut) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Initialization timeout',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Authentication is taking longer than expected',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Skip to main app
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const StartScreen(),
                          ),
                        );
                      },
                      child: const Text('Continue without auth'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Initializing MoodMusic...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Skip auth screen and go straight to the app (login bypassed)
        if (authProvider.state == AuthState.unauthenticated || authProvider.state == AuthState.error) {
          debugPrint('⚠️ Bypassing auth - going to main app');
          return Consumer<AppStateProvider>(
            builder: (context, appStateProvider, child) {
              debugPrint('📱 AppStateProvider state: ${appStateProvider.currentState}');
              switch (appStateProvider.currentState) {
                case AppState.start:
                  debugPrint('🎬 Showing StartScreen (no auth)');
                  return const StartScreen();
                case AppState.scanning:
                  debugPrint('📷 Showing MoodScannerScreen (no auth)');
                  return MoodScannerScreen(cameras: cameras);
                case AppState.results:
                  debugPrint('📊 Showing MoodResultsScreen (no auth)');
                  return MoodResultsScreen(
                    mood: appStateProvider.detectedMood!,
                    song: appStateProvider.recommendedSong,
                    event: appStateProvider.recommendedEvent,
                    emotionAnalysis: appStateProvider.emotionAnalysis,
                  );
                case AppState.history:
                  debugPrint('📜 Showing HistoryScreen (no auth)');
                  return const HistoryScreen();
                case AppState.awsDebug:
                  debugPrint('🐛 Showing AWSDebugScreen (no auth)');
                  return const AWSDebugScreen();
              }
            },
          );
        }

        // Show main app if authenticated
        if (authProvider.state == AuthState.authenticated) {
          return Consumer<AppStateProvider>(
            builder: (context, appStateProvider, child) {
              switch (appStateProvider.currentState) {
                case AppState.start:
                  return const StartScreen();
                case AppState.scanning:
                  return MoodScannerScreen(cameras: cameras);
                case AppState.results:
                  return MoodResultsScreen(
                    mood: appStateProvider.detectedMood!,
                    song: appStateProvider.recommendedSong,
                    event: appStateProvider.recommendedEvent,
                    emotionAnalysis: appStateProvider.emotionAnalysis,
                  );
                case AppState.history:
                  return const HistoryScreen();
                case AppState.awsDebug:
                  return const AWSDebugScreen();
              }
            },
          );
        }

        // Fallback error screen
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Please restart the app',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 