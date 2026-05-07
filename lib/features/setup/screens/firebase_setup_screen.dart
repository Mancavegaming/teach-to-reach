import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.error});

  final String? error;

  static const _setupSteps = [
    '1. Create a Firebase project named "teach-to-reach" at console.firebase.google.com',
    '2. Enable Email/Password and Google sign-in providers',
    '3. Create a Firestore database (start in test mode)',
    '4. Run the commands below in this project folder',
  ];

  static const _setupCmds = '''dart pub global activate flutterfire_cli
flutterfire configure --project=teach-to-reach''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 24),
                Text('Firebase setup needed',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                Text(
                  'Teach to Reach needs a Firebase backend before sign-in '
                  'will work. Take these steps once, then restart the app.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ..._setupSteps.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(s,
                          style: Theme.of(context).textTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                _CommandBlock(text: _setupCmds),
                if (error != null) ...[
                  const SizedBox(height: 32),
                  Text('Initialization error',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: SelectableText(
                      error!,
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandBlock extends StatelessWidget {
  const _CommandBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
