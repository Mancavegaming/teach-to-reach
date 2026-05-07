import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';

class SermonModeScreen extends StatefulWidget {
  final Lesson lesson;
  const SermonModeScreen({super.key, required this.lesson});

  @override
  State<SermonModeScreen> createState() => _SermonModeScreenState();
}

class _SermonModeScreenState extends State<SermonModeScreen> {
  Timer? _ticker;
  late DateTime _endTime;
  double _fontSize = 28;
  bool _showBar = true;

  static const double _minFont = 18;
  static const double _maxFont = 60;

  @override
  void initState() {
    super.initState();
    _endTime = DateTime.now().add(
      Duration(minutes: widget.lesson.targetDurationMinutes),
    );
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _adjustEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
      helpText: 'When should the sermon end?',
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    setState(() => _endTime = target);
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit Sermon Mode?'),
        content: const Text('The screen wakelock will be released.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.abs();
    final secs = (d.inSeconds.abs() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final hasText = lesson.finalizedSermonText.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showBar = !_showBar),
                child: hasText
                    ? _SermonText(text: lesson.finalizedSermonText, fontSize: _fontSize)
                    : const _NoTextEmptyState(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: _showBar ? 0 : -120,
                child: _ClockBar(
                  endTime: _endTime,
                  fontSize: _fontSize,
                  onChangeFont: (delta) => setState(() {
                    _fontSize = (_fontSize + delta).clamp(_minFont, _maxFont);
                  }),
                  onAdjustEnd: _adjustEndTime,
                  onExit: () async {
                    final navigator = Navigator.of(context);
                    if (await _confirmExit() && mounted) {
                      navigator.pop();
                    }
                  },
                  formatDuration: _formatDuration,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SermonText extends StatelessWidget {
  final String text;
  final double fontSize;
  const _SermonText({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 120, 40, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SelectableText(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              height: 1.55,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoTextEmptyState extends StatelessWidget {
  const _NoTextEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                color: AppColors.primary.withValues(alpha: 0.6), size: 80),
            const SizedBox(height: 20),
            Text('No finalized sermon yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Compose a finalized sermon in the lesson editor first, then come back here to teach.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockBar extends StatelessWidget {
  final DateTime endTime;
  final double fontSize;
  final ValueChanged<double> onChangeFont;
  final VoidCallback onAdjustEnd;
  final VoidCallback onExit;
  final String Function(Duration) formatDuration;

  const _ClockBar({
    required this.endTime,
    required this.fontSize,
    required this.onChangeFont,
    required this.onAdjustEnd,
    required this.onExit,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = endTime.difference(now);
    final isLate = remaining.isNegative;
    final isWarn = !isLate && remaining.inSeconds <= 300;
    final countdownColor = isLate
        ? AppColors.error
        : (isWarn ? AppColors.warning : AppColors.textPrimary);
    final remainingLabel = isLate
        ? '+${formatDuration(remaining)} OVER'
        : '${formatDuration(remaining)} left';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Exit Sermon Mode',
            icon: const Icon(Icons.close),
            onPressed: onExit,
          ),
          const SizedBox(width: 12),
          _Clock(
            label: 'Now',
            value: DateFormat.jm().format(now),
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 28),
          _Clock(
            label: 'Ends at',
            value: DateFormat.jm().format(endTime),
            color: AppColors.textPrimary,
            onTap: onAdjustEnd,
          ),
          const SizedBox(width: 28),
          _Clock(
            label: 'Countdown',
            value: remainingLabel,
            color: countdownColor,
            bold: true,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Smaller text',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => onChangeFont(-2),
          ),
          Text('${fontSize.round()}',
              style: Theme.of(context).textTheme.bodyMedium),
          IconButton(
            tooltip: 'Larger text',
            icon: const Icon(Icons.text_increase),
            onPressed: () => onChangeFont(2),
          ),
        ],
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final VoidCallback? onTap;

  const _Clock({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                )),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            letterSpacing: 0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: body,
      ),
    );
  }
}
