import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/aws_provider.dart';
import '../providers/rekognition_provider.dart';

class AWSDebugScreen extends StatefulWidget {
  const AWSDebugScreen({super.key});

  @override
  State<AWSDebugScreen> createState() => _AWSDebugScreenState();
}

class _AWSDebugScreenState extends State<AWSDebugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _regionController = TextEditingController();
  final _identityPoolController = TextEditingController();
  
  bool _isObscured = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final awsProvider = context.read<AWSProvider>();
    _accessKeyController.text = awsProvider.accessKey ?? '';
    _secretKeyController.text = awsProvider.secretKey ?? '';
    _regionController.text = awsProvider.region ?? 'us-east-1';
    _identityPoolController.text = awsProvider.identityPoolId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AWS Debug Console'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<AppStateProvider>().goToStart(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            Consumer<AWSProvider>(
              builder: (context, awsProvider, child) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                      awsProvider.isConnected ? Icons.check_circle : Icons.error,
                      color: awsProvider.isConnected ? Colors.green : Colors.red,
                    ),
                    title: Text(awsProvider.connectionStatusText),
                    subtitle: Text('Mode: ${awsProvider.isDebugMode ? 'Debug' : 'Production'}'),
                    trailing: Switch(
                      value: awsProvider.isDebugMode,
                      onChanged: (_) => awsProvider.toggleDebugMode(),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Configuration Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _accessKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Access Key ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _secretKeyController,
                    obscureText: _isObscured,
                    decoration: InputDecoration(
                      labelText: 'Secret Access Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isObscured = !_isObscured),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _regionController,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _identityPoolController,
                    decoration: const InputDecoration(
                      labelText: 'Identity Pool ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveConfiguration,
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isTesting ? null : _testConnection,
                          child: _isTesting 
                            ? const CircularProgressIndicator()
                            : const Text('Test'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveConfiguration() async {
    await context.read<AWSProvider>().saveCredentials(
      accessKey: _accessKeyController.text,
      secretKey: _secretKeyController.text,
      region: _regionController.text,
      identityPoolId: _identityPoolController.text,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration saved')),
    );
  }

  void _testConnection() async {
    setState(() => _isTesting = true);
    
    final success = await context.read<AWSProvider>().testConnection();
    
    setState(() => _isTesting = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Connection successful' : 'Connection failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _regionController.dispose();
    _identityPoolController.dispose();
    super.dispose();
  }
} 