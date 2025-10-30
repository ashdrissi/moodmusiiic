import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/mood.dart';
import '../theme/app_theme.dart';

class MoodHistoryEntry {
  final Mood mood;
  final DateTime timestamp;
  final double confidence;

  const MoodHistoryEntry({
    required this.mood,
    required this.timestamp,
    required this.confidence,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MoodHistoryEntry> _mockHistory = [];

  @override
  void initState() {
    super.initState();
    _generateMockHistory();
  }

  void _generateMockHistory() {
    final now = DateTime.now();
    final moods = Mood.values;
    
    _mockHistory = List.generate(10, (index) {
      final mood = moods[index % moods.length];
      final timestamp = now.subtract(Duration(hours: index * 2, minutes: index * 15));
      final confidence = 0.7 + (index % 3) * 0.1;
      
      return MoodHistoryEntry(
        mood: mood,
        timestamp: timestamp,
        confidence: confidence,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      context.read<AppStateProvider>().goToStart();
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      'Mood History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _mockHistory.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Clear History',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _mockHistory.isEmpty
                  ? _buildEmptyState()
                  : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: 60,
              color: Colors.grey[400],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'No Mood History Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Start scanning your mood to see\nyour emotional journey over time',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: () {
              context.read<AppStateProvider>().goToScanning();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Start First Scan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      children: [
        // Stats Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppTheme.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Scans',
                  _mockHistory.length.toString(),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  'Most Common',
                  _getMostCommonMood().emoji,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  'This Week',
                  _getThisWeekCount().toString(),
                ),
              ),
            ],
          ),
        ),

        // History List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _mockHistory.length,
            itemBuilder: (context, index) {
              final entry = _mockHistory[index];
              return _buildHistoryItem(entry, index == 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryItem(MoodHistoryEntry entry, bool isLatest) {
    final moodColor = AppTheme.moodColor(entry.mood.displayName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLatest ? Border.all(color: moodColor, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mood Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: moodColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                entry.mood.emoji,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.mood.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: moodColor,
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: moodColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Latest',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  _formatTimestamp(entry.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    Text(
                      'Confidence: ${(entry.confidence * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: entry.confidence,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(moodColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Time indicator
          Column(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.grey[400],
                size: 16,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(entry.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Mood _getMostCommonMood() {
    if (_mockHistory.isEmpty) return Mood.calm;
    
    final moodCounts = <Mood, int>{};
    for (final entry in _mockHistory) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }
    
    return moodCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  int _getThisWeekCount() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _mockHistory
        .where((entry) => entry.timestamp.isAfter(weekAgo))
        .length;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
} 