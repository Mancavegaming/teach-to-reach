import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_wrapper.dart';
import 'features/setup/screens/firebase_setup_screen.dart';
import 'firebase_options.dart';
import 'services/annotation_service.dart';
import 'services/auth_service.dart';
import 'services/class_profile_service.dart';
import 'services/doctrinal_positions_service.dart';
import 'services/lesson_service.dart';
import 'services/series_service.dart';
import 'services/teacher_profile_service.dart';
import 'services/voice_corpus_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    firebaseError = e.toString();
    debugPrint('Firebase not initialized: $e');
  }

  runApp(TeachToReachApp(
    firebaseReady: firebaseReady,
    firebaseError: firebaseError,
  ));
}

class TeachToReachApp extends StatelessWidget {
  const TeachToReachApp({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return MaterialApp(
        title: 'Teach to Reach',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: FirebaseSetupScreen(error: firebaseError),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TeacherProfileService()),
        ChangeNotifierProvider(create: (_) => ClassProfileService()),
        ChangeNotifierProvider(create: (_) => DoctrinalPositionsService()),
        ChangeNotifierProvider(create: (_) => VoiceCorpusService()),
        ChangeNotifierProvider(create: (_) => SeriesService()),
        ChangeNotifierProvider(create: (_) => LessonService()),
        ChangeNotifierProvider(create: (_) => AnnotationService()),
      ],
      child: MaterialApp(
        title: 'Teach to Reach',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}
