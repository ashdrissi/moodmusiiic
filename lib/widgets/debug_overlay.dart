import 'package:flutter/material.dart';
import '../providers/aws_provider.dart';
import '../providers/rekognition_provider.dart';
import '../models/mood.dart';

class DebugOverlay extends StatelessWidget {
  final AWSProvider awsProvider;
  final RekognitionProvider rekognitionProvider;

  const DebugOverlay({
    super.key,
    required this.awsProvider,
    required this.rekognitionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔧 Debug Info',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // AWS Status
            _buildStatusRow(
              'AWS Mode',
              awsProvider.isDebugMode ? 'Simulation' : 'Production',
              awsProvider.isDebugMode ? Colors.orange : Colors.green,
            ),
            
            _buildStatusRow(
              'Connection',
              awsProvider.connectionStatusText,
              awsProvider.isConnected ? Colors.green : Colors.red,
            ),
            
            if (awsProvider.region != null)
              _buildStatusRow(
                'Region',
                awsProvider.region!,
                Colors.blue,
              ),
            
            // Analysis Status
            if (rekognitionProvider.isAnalyzing)
              _buildStatusRow(
                'Status',
                'Analyzing...',
                Colors.orange,
              ),
            
            if (rekognitionProvider.lastResult != null)
              _buildStatusRow(
                'Last Result',
                '${rekognitionProvider.lastResult!.mood.emoji} ${rekognitionProvider.lastResult!.mood.displayName}',
                Colors.green,
              ),
            
            if (rekognitionProvider.lastError != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Last Error:',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                rekognitionProvider.lastError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
} 