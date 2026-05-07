import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/teacher_profile_service.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _voiceController;
  late final TextEditingController _translationController;
  late final TextEditingController _backgroundController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<TeacherProfileService>().profile;
    _nameController = TextEditingController(text: p?.displayName ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _voiceController = TextEditingController(text: p?.voicePersona ?? '');
    _translationController =
        TextEditingController(text: p?.preferredTranslation ?? 'KJV');
    _backgroundController =
        TextEditingController(text: p?.pastoralBackground ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _voiceController.dispose();
    _translationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final svc = context.read<TeacherProfileService>();
    final current = svc.profile;
    if (current == null) return;
    setState(() => _saving = true);
    final updated = current.copyWith(
      displayName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      voicePersona: _voiceController.text.trim(),
      preferredTranslation: _translationController.text.trim(),
      pastoralBackground: _backgroundController.text.trim(),
    );
    final ok = await svc.save(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Teacher profile saved' : 'Save failed')),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionIntro(
                      title: 'Who you are as a teacher',
                      description:
                          'This shapes how the AI greets you and frames first-person voice. The voice description below feeds your identity into every prompt.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _translationController,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Bible Translation',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                        helperText:
                            'KJV is bundled. AI will quote in this translation.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _voiceController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Your Voice / Teaching Style',
                        alignLabelWithHint: true,
                        hintText:
                            'Direct, story-driven, lots of scripture cross-references, never preachy. Speaks to teens like a respected coach...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _backgroundController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Pastoral Background (optional)',
                        alignLabelWithHint: true,
                        hintText:
                            'Years in ministry, formal training, key influences...',
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  final String title;
  final String description;
  const _SectionIntro({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

