import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/aws_provider.dart';
import '../providers/rekognition_provider.dart';
import '../providers/spotify_provider.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/face_detection_overlay.dart';
import '../widgets/debug_overlay.dart';
import '../services/recommendation_engine.dart';

class MoodScannerScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MoodScannerScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<MoodScannerScreen> createState() => _MoodScannerScreenState();
}

class _MoodScannerScreenState extends State<MoodScannerScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _showDebug = false;
  
  late AnimationController _scanningAnimationController;
  late Animation<double> _scanningAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupAnimations();
  }

  void _setupAnimations() {
    _scanningAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanningAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanningAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimationController.repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      debugPrint('❌ No cameras available');
      return;
    }

    try {
      // Use front camera if available, otherwise use first camera
      final camera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Camera initialization failed: $e');
    }
  }

  Future<void> _scanMood() async {
    if (_isScanning || _cameraController == null) return;

    setState(() {
      _isScanning = true;
    });

    _scanningAnimationController.repeat();

    try {
      final awsProvider = context.read<AWSProvider>();
      final rekognitionProvider = context.read<RekognitionProvider>();
      final spotifyProvider = context.read<SpotifyProvider>();
      
      // Capture image
      final image = await _cameraController!.takePicture();
      final imageBytes = await image.readAsBytes();

      // Analyze emotion
      final result = await rekognitionProvider.analyzeEmotion(
        Uint8List.fromList(imageBytes),
        awsProvider,
      );

      if (result != null && mounted) {
        // Get recommendations
        final recommendations = await RecommendationEngine.getRecommendations(
          result.mood,
          spotifyProvider,
        );

        // Navigate to results
        context.read<AppStateProvider>().goToResults(
          result.mood,
          recommendations.song,
          recommendations.event,
          result, // Pass full emotion analysis result
        );
      }
    } catch (e) {
      debugPrint('❌ Mood scanning failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanning failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _scanningAnimationController.stop();
        _scanningAnimationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanningAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_isInitialized && _cameraController != null)
              CameraPreviewWidget(
                controller: _cameraController!,
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Face detection overlay
            if (_isInitialized)
              FaceDetectionOverlay(
                isScanning: _isScanning,
                scanningAnimation: _scanningAnimation,
              ),

            // Debug overlay
            if (_showDebug)
              DebugOverlay(
                awsProvider: context.watch<AWSProvider>(),
                rekognitionProvider: context.watch<RekognitionProvider>(),
              ),

            // Top controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () {
                        context.read<AppStateProvider>().goToStart();
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  // Title
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Mood Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  // Debug toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _showDebug = !_showDebug;
                        });
                      },
                      icon: Icon(
                        _showDebug ? Icons.bug_report : Icons.info_outline,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Instructions
            Positioned(
              top: 100,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Position your face in the frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Look directly at the camera for best results',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Scan button
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: GestureDetector(
                    onTap: _isScanning ? null : _scanMood,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isScanning 
                            ? Colors.orange 
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isScanning ? Icons.hourglass_empty : Icons.camera_alt,
                        color: _isScanning ? Colors.white : Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Status text
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Consumer<RekognitionProvider>(
                  builder: (context, rekognitionProvider, child) {
                    String statusText = 'Tap to scan your mood';
                    
                    if (rekognitionProvider.isAnalyzing) {
                      statusText = 'Analyzing your emotions...';
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 