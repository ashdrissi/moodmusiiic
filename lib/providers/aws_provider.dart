import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AWSProvider extends ChangeNotifier {
  String? _accessKey;
  String? _secretKey;
  String? _region;
  String? _identityPoolId;
  bool _isDebugMode = true; // Start in debug mode for simulation
  bool _isConnected = false;
  String? _lastError;

  String? get accessKey => _accessKey;
  String? get secretKey => _secretKey;
  String? get region => _region;
  String? get identityPoolId => _identityPoolId;
  bool get isDebugMode => _isDebugMode;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  // Initialize AWS configuration from stored preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessKey = prefs.getString('aws_access_key');
    _secretKey = prefs.getString('aws_secret_key');
    _region = prefs.getString('aws_region') ?? 'us-east-1';
    _identityPoolId = prefs.getString('aws_identity_pool_id');
    _isDebugMode = prefs.getBool('aws_debug_mode') ?? true;
    
    notifyListeners();
    
    // Test connection if credentials are available
    if (_accessKey != null && _secretKey != null) {
      await testConnection();
    }
  }

  // Save AWS credentials securely
  Future<void> saveCredentials({
    required String accessKey,
    required String secretKey,
    required String region,
    required String identityPoolId,
  }) async {
    _accessKey = accessKey;
    _secretKey = secretKey;
    _region = region;
    _identityPoolId = identityPoolId;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aws_access_key', accessKey);
    await prefs.setString('aws_secret_key', secretKey);
    await prefs.setString('aws_region', region);
    await prefs.setString('aws_identity_pool_id', identityPoolId);
    
    notifyListeners();
    
    // Test the new credentials
    await testConnection();
  }

  // Test AWS connection
  Future<bool> testConnection() async {
    if (_isDebugMode) {
      // Simulate connection test in debug mode
      await Future.delayed(const Duration(seconds: 2));
      _isConnected = true;
      _lastError = null;
      notifyListeners();
      return true;
    }

    if (_accessKey == null || _secretKey == null) {
      _isConnected = false;
      _lastError = 'Missing AWS credentials';
      notifyListeners();
      return false;
    }

    try {
      // TODO: Implement actual AWS connection test
      // For now, simulate a successful connection
      await Future.delayed(const Duration(seconds: 2));
      _isConnected = true;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Toggle debug mode
  Future<void> toggleDebugMode() async {
    _isDebugMode = !_isDebugMode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aws_debug_mode', _isDebugMode);
    
    notifyListeners();
    
    // Re-test connection with new mode
    await testConnection();
  }

  // Clear all AWS credentials
  Future<void> clearCredentials() async {
    _accessKey = null;
    _secretKey = null;
    _region = 'us-east-1';
    _identityPoolId = null;
    _isConnected = false;
    _lastError = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('aws_access_key');
    await prefs.remove('aws_secret_key');
    await prefs.remove('aws_region');
    await prefs.remove('aws_identity_pool_id');
    
    notifyListeners();
  }

  // Get connection status text
  String get connectionStatusText {
    if (_isDebugMode) {
      return 'Debug Mode (Simulation)';
    } else if (_isConnected) {
      return 'Connected';
    } else if (_lastError != null) {
      return 'Error: $_lastError';
    } else {
      return 'Not Connected';
    }
  }

  // Get diagnostics info
  Map<String, dynamic> get diagnosticsInfo {
    return {
      'Mode': _isDebugMode ? 'Debug (Simulation)' : 'Production',
      'Region': _region ?? 'Not Set',
      'Identity Pool': _identityPoolId ?? 'Not Set',
      'Access Key': _accessKey != null ? '${_accessKey!.substring(0, 8)}...' : 'Not Set',
      'Connection Status': connectionStatusText,
      'Last Update': DateTime.now().toIso8601String(),
    };
  }
} 