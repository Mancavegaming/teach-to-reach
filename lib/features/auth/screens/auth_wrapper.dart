import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/annotation_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/teacher_profile_service.dart';
import '../../../services/class_profile_service.dart';
import '../../../services/doctrinal_positions_service.dart';
import '../../../services/voice_corpus_service.dart';
import '../../../services/series_service.dart';
import '../../../services/lesson_service.dart';
import '../../home/screens/home_dashboard.dart';
import 'login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _hydratedForUid;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          final uid = auth.user!.uid;
          if (_hydratedForUid != uid) {
            _hydratedForUid = uid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _hydrate(context, uid, auth.user?.email, auth.user?.displayName);
            });
          }
          return const HomeDashboard();
        }

        if (_hydratedForUid != null) {
          _hydratedForUid = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<TeacherProfileService>().clear();
            context.read<ClassProfileService>().clear();
            context.read<DoctrinalPositionsService>().clear();
            context.read<VoiceCorpusService>().clear();
            context.read<SeriesService>().clear();
            context.read<LessonService>().clear();
            context.read<AnnotationService>().clear();
          });
        }
        return const LoginScreen();
      },
    );
  }

  Future<void> _hydrate(
    BuildContext context,
    String uid,
    String? email,
    String? displayName,
  ) async {
    final teacher = context.read<TeacherProfileService>();
    final classProfile = context.read<ClassProfileService>();
    final doctrine = context.read<DoctrinalPositionsService>();
    final corpus = context.read<VoiceCorpusService>();
    final series = context.read<SeriesService>();

    await Future.wait([
      teacher.loadOrCreate(uid, email: email, displayName: displayName),
      classProfile.loadOrCreate(uid),
      doctrine.loadOrCreate(uid),
      corpus.load(uid),
      series.load(uid),
    ]);
  }
}

