import 'package:flutter/material.dart';

class FaceDetectionOverlay extends StatelessWidget {
  final bool isScanning;
  final Animation<double> scanningAnimation;

  const FaceDetectionOverlay({
    super.key,
    required this.isScanning,
    required this.scanningAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 300,
        child: Stack(
          children: [
            // Face outline
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isScanning ? Colors.orange : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
            
            // Corner indicators
            ..._buildCornerIndicators(),
            
            // Scanning line
            if (isScanning)
              AnimatedBuilder(
                animation: scanningAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: scanningAnimation.value * 250,
                    left: 25,
                    right: 25,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.orange.withOpacity(0.8),
                            Colors.orange,
                            Colors.orange.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerIndicators() {
    const cornerSize = 20.0;
    const cornerThickness = 3.0;
    final color = isScanning ? Colors.orange : Colors.white;

    return [
      // Top left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
      
      // Top right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
      
      // Bottom left
      Positioned(
        bottom: 50,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 50,
        left: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
      
      // Bottom right
      Positioned(
        bottom: 50,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 50,
        right: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
    ];
  }
} 