import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/doctrinal_positions.dart';
import '../../../services/doctrinal_positions_service.dart';

class DoctrinalPositionsScreen extends StatefulWidget {
  const DoctrinalPositionsScreen({super.key});

  @override
  State<DoctrinalPositionsScreen> createState() =>
      _DoctrinalPositionsScreenState();
}

class _DoctrinalPositionsScreenState extends State<DoctrinalPositionsScreen> {
  late final TextEditingController _traditionController;
  late final TextEditingController _translationController;
  late final TextEditingController _notesController;
  late List<String> _nonNegotiables;
  late List<String> _pastoralEmphases;
  late List<String> _avoidance;
  bool _continuationist = true;
  bool _gospelCentered = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<DoctrinalPositionsService>().positions;
    _traditionController = TextEditingController(
      text: p?.coreTradition ?? 'Baptist + Pentecostal/Charismatic',
    );
    _translationController =
        TextEditingController(text: p?.preferredTranslation ?? 'KJV');
    _notesController = TextEditingController(text: p?.additionalNotes ?? '');
    _nonNegotiables = List<String>.from(
        p?.nonNegotiables ?? DoctrinalPositions.defaultNonNegotiables);
    _pastoralEmphases = List<String>.from(
        p?.pastoralEmphases ?? DoctrinalPositions.defaultPastoralEmphases);
    _avoidance = List<String>.from(
        p?.avoidanceList ?? DoctrinalPositions.defaultAvoidanceList);
    _continuationist = p?.continuationist ?? true;
    _gospelCentered = p?.gospelCentered ?? true;
  }

  @override
  void dispose() {
    _traditionController.dispose();
    _translationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final svc = context.read<DoctrinalPositionsService>();
    final current = svc.positions;
    if (current == null) return;
    setState(() => _saving = true);
    final updated = current.copyWith(
      coreTradition: _traditionController.text.trim(),
      preferredTranslation: _translationController.text.trim(),
      additionalNotes: _notesController.text.trim(),
      continuationist: _continuationist,
      gospelCentered: _gospelCentered,
      nonNegotiables: _nonNegotiables,
      pastoralEmphases: _pastoralEmphases,
      avoidanceList: _avoidance,
    );
    final ok = await svc.save(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Doctrinal positions saved' : 'Save failed')),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctrinal Positions')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IntroCard(
                    title: 'Anchor what the AI may teach',
                    description:
                        'These positions feed into every AI prompt as guardrails. Defaults are pre-filled for Baptist + Pentecostal/Charismatic, continuationist, and gospel-centered.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _traditionController,
                    decoration: const InputDecoration(
                      labelText: 'Core Tradition',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _translationController,
                    decoration: const InputDecoration(
                      labelText: 'Preferred Translation',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: AppDecorations.premiumCard,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Continuationist'),
                          subtitle: const Text(
                              'Spiritual gifts (tongues, prophecy, healing) are active today'),
                          value: _continuationist,
                          onChanged: (v) =>
                              setState(() => _continuationist = v),
                        ),
                        SwitchListTile(
                          title: const Text('Gospel-Centered'),
                          subtitle: const Text(
                              'Every lesson should connect to Christ and the gospel'),
                          value: _gospelCentered,
                          onChanged: (v) =>
                              setState(() => _gospelCentered = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ChipListEditor(
                    title: 'Non-Negotiables',
                    description: 'Doctrines the AI must never deny or hedge.',
                    items: _nonNegotiables,
                    onChanged: (next) => setState(() => _nonNegotiables = next),
                  ),
                  const SizedBox(height: 16),
                  _ChipListEditor(
                    title: 'Pastoral Emphases',
                    description:
                        'Truths the AI should foreground naturally when appropriate.',
                    items: _pastoralEmphases,
                    onChanged: (next) =>
                        setState(() => _pastoralEmphases = next),
                  ),
                  const SizedBox(height: 16),
                  _ChipListEditor(
                    title: 'Things to Avoid',
                    description: 'Framings or doctrines the AI must not assert.',
                    items: _avoidance,
                    onChanged: (next) => setState(() => _avoidance = next),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      alignLabelWithHint: true,
                      hintText:
                          'Other distinctives, eschatology positions, or any guidance you want the AI to follow...',
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

class _ChipListEditor extends StatefulWidget {
  final String title;
  final String description;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  const _ChipListEditor({
    required this.title,
    required this.description,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<_ChipListEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final next = [...widget.items, text];
    widget.onChanged(next);
    _controller.clear();
  }

  void _remove(int idx) {
    final next = [...widget.items]..removeAt(idx);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(widget.description,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                Chip(
                  label: Text(widget.items[i]),
                  onDeleted: () => _remove(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Add new...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _add,
                icon: const Icon(Icons.add_circle, size: 28),
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
