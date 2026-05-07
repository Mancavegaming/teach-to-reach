import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/class_profile_service.dart';

class ClassProfileScreen extends StatefulWidget {
  const ClassProfileScreen({super.key});

  @override
  State<ClassProfileScreen> createState() => _ClassProfileScreenState();
}

class _ClassProfileScreenState extends State<ClassProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageMinController;
  late final TextEditingController _ageMaxController;
  late final TextEditingController _attendanceController;
  late final TextEditingController _maturityController;
  late final TextEditingController _challengesController;
  late final TextEditingController _cultureController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<ClassProfileService>().profile;
    _nameController = TextEditingController(text: p?.className ?? '');
    _ageMinController =
        TextEditingController(text: (p?.ageRangeMin ?? 11).toString());
    _ageMaxController =
        TextEditingController(text: (p?.ageRangeMax ?? 18).toString());
    _attendanceController =
        TextEditingController(text: (p?.typicalAttendance ?? 0).toString());
    _maturityController =
        TextEditingController(text: p?.spiritualMaturityNotes ?? '');
    _challengesController =
        TextEditingController(text: p?.knownChallenges ?? '');
    _cultureController =
        TextEditingController(text: p?.culturalContext ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    _attendanceController.dispose();
    _maturityController.dispose();
    _challengesController.dispose();
    _cultureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final svc = context.read<ClassProfileService>();
    final current = svc.profile;
    if (current == null) return;
    setState(() => _saving = true);
    final updated = current.copyWith(
      className: _nameController.text.trim(),
      ageRangeMin: int.tryParse(_ageMinController.text.trim()) ?? 11,
      ageRangeMax: int.tryParse(_ageMaxController.text.trim()) ?? 18,
      typicalAttendance:
          int.tryParse(_attendanceController.text.trim()) ?? 0,
      spiritualMaturityNotes: _maturityController.text.trim(),
      knownChallenges: _challengesController.text.trim(),
      culturalContext: _cultureController.text.trim(),
    );
    final ok = await svc.save(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Class profile saved' : 'Save failed')),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Profile')),
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
                    _IntroCard(
                      title: 'Tell the AI about your class',
                      description:
                          'Class-level context only — no individual student tracking. The AI uses this to pick examples, language level, and applications appropriate to your group.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Class Name',
                        prefixIcon: Icon(Icons.groups_outlined),
                        hintText: 'e.g. Wednesday Night Youth',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageMinController,
                            decoration: const InputDecoration(
                              labelText: 'Youngest Age',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                (int.tryParse(v ?? '') == null)
                                    ? 'Number required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _ageMaxController,
                            decoration: const InputDecoration(
                              labelText: 'Oldest Age',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                (int.tryParse(v ?? '') == null)
                                    ? 'Number required'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _attendanceController,
                      decoration: const InputDecoration(
                        labelText: 'Typical Attendance',
                        prefixIcon: Icon(Icons.people_alt_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maturityController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Spiritual Maturity Notes',
                        alignLabelWithHint: true,
                        hintText:
                            'Mostly church kids, a few new believers, two unsaved students...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _challengesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Known Challenges',
                        alignLabelWithHint: true,
                        hintText:
                            'Anxiety, broken homes, screen addiction, academic pressure...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cultureController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Cultural / Local Context',
                        alignLabelWithHint: true,
                        hintText:
                            'Rural church, urban school district, regional language patterns...',
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

class _IntroCard extends StatelessWidget {
  final String title;
  final String description;
  const _IntroCard({required this.title, required this.description});

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
