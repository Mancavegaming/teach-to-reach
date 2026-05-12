import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../models/series.dart';
import '../../../services/auth_service.dart';
import '../../../services/lesson_service.dart';
import '../../../services/series_service.dart';
import '../../lessons/screens/lesson_editor_screen.dart';

/// Year planner: schedule lessons onto Sundays. Two views — an upcoming-Sundays
/// list (default) and a month-grid calendar — driven off the same underlying
/// flat lesson list loaded from LessonService.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  bool _calendarView = false;
  DateTime _focusedDay = _normalize(DateTime.now());
  DateTime? _selectedDay;
  bool _loadingFirst = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  Future<void> _initialLoad() async {
    final ownerId = context.read<AuthService>().user?.uid;
    if (ownerId == null) {
      setState(() => _loadingFirst = false);
      return;
    }
    final lessonSvc = context.read<LessonService>();
    final seriesSvc = context.read<SeriesService>();
    await Future.wait([
      lessonSvc.loadAllLessonsForOwner(ownerId),
      if (seriesSvc.series.isEmpty) seriesSvc.load(ownerId),
    ]);
    if (mounted) setState(() => _loadingFirst = false);
  }

  @override
  Widget build(BuildContext context) {
    final lessonSvc = context.watch<LessonService>();
    final seriesSvc = context.watch<SeriesService>();
    final lessons = lessonSvc.allLessons;
    final seriesById = {
      for (final s in seriesSvc.series)
        if (s.id != null) s.id!: s,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Planner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            ToggleButtons(
              isSelected: [!_calendarView, _calendarView],
              onPressed: (i) => setState(() => _calendarView = i == 1),
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
              children: const [
                Tooltip(
                  message: 'Upcoming Sundays list',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.view_list, size: 20),
                  ),
                ),
                Tooltip(
                  message: 'Month calendar',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.calendar_month, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingFirst)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_calendarView)
          _CalendarView(
            lessons: lessons,
            seriesById: seriesById,
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            onPageChanged: (d) => setState(() => _focusedDay = d),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _openDateSheet(selected);
            },
          )
        else
          _ListView(
            lessons: lessons,
            seriesById: seriesById,
            onTapSunday: _openDateSheet,
            onTapLesson: _openLessonEditor,
            onSchedule: _scheduleLesson,
          ),
      ],
    );
  }

  // ---- Date helpers ----

  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Returns the next [count] Sundays starting from today (inclusive if today
  /// is Sunday).
  static List<DateTime> _upcomingSundays(int count) {
    final today = _normalize(DateTime.now());
    var firstSun = today;
    while (firstSun.weekday != DateTime.sunday) {
      firstSun = firstSun.add(const Duration(days: 1));
    }
    return [
      for (var i = 0; i < count; i++) firstSun.add(Duration(days: 7 * i)),
    ];
  }

  // ---- Scheduling actions ----

  /// Show a sheet for a given calendar day with the lessons covering that day
  /// and an action to schedule a new one onto it.
  Future<void> _openDateSheet(DateTime day) async {
    final lessonSvc = context.read<LessonService>();
    final seriesSvc = context.read<SeriesService>();
    final lessonsOnDay = lessonSvc.allLessons.where((l) => _covers(l, day)).toList();
    final dateLabel = DateFormat.yMMMMEEEEd().format(day);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dateLabel,
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (lessonsOnDay.isEmpty)
                  const Text('Nothing scheduled on this day yet.')
                else
                  ...lessonsOnDay.map(
                    (l) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book),
                      title: Text(l.title),
                      subtitle: Text(
                        _seriesLabel(seriesSvc.series, l.seriesId) +
                            (l.isMultiWeek
                                ? ' • ${_rangeLabel(l)}'
                                : ''),
                      ),
                      trailing: IconButton(
                        tooltip: 'Unschedule',
                        icon: const Icon(Icons.event_busy),
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          await _unschedule(l);
                        },
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _openLessonEditor(l);
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await _pickLessonForDate(day);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule a lesson for this day'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Let the user pick a lesson, then pick a date (single or range) to assign.
  Future<void> _scheduleLesson(Lesson lesson) async {
    final result = await _pickDateRange(initial: lesson.scheduledDate);
    if (result == null || !mounted) return;
    final updated = lesson.copyWith(
      scheduledDate: result.start,
      scheduledEndDate: result.end,
    );
    await context.read<LessonService>().updateLesson(updated);
  }

  /// Assign one of the user's unscheduled lessons to [day] (single date).
  Future<void> _pickLessonForDate(DateTime day) async {
    final lessonSvc = context.read<LessonService>();
    final seriesSvc = context.read<SeriesService>();
    final candidates = lessonSvc.allLessons
        .where((l) => !l.isScheduled)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No unscheduled lessons. Create one first.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<Lesson>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Pick a lesson for ${DateFormat.yMMMd().format(day)}',
                    style: Theme.of(sheetCtx).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final l = candidates[i];
                      return ListTile(
                        title: Text(l.title),
                        subtitle: Text(_seriesLabel(seriesSvc.series, l.seriesId)),
                        onTap: () => Navigator.of(sheetCtx).pop(l),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    final updated = picked.copyWith(
      scheduledDate: day,
      scheduledEndDate: null,
    );
    await context.read<LessonService>().updateLesson(updated);
  }

  Future<void> _unschedule(Lesson lesson) async {
    final updated = lesson.copyWith(
      scheduledDate: null,
      scheduledEndDate: null,
    );
    await context.read<LessonService>().updateLesson(updated);
  }

  /// Date picker that supports both single-date and multi-week range.
  Future<DateTimeRange?> _pickDateRange({DateTime? initial}) async {
    final wantsRange = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule type'),
        content: const Text(
          'Is this a single Sunday or a multi-week series spanning several Sundays?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Single Sunday'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Multi-week range'),
          ),
        ],
      ),
    );
    if (wantsRange == null || !mounted) return null;

    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 5);

    if (wantsRange) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDateRange: initial == null
            ? null
            : DateTimeRange(start: initial, end: initial.add(const Duration(days: 14))),
      );
      if (range == null) return null;
      return DateTimeRange(
        start: _normalize(range.start),
        end: _normalize(range.end),
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDate: initial ?? _upcomingSundays(1).first,
      );
      if (picked == null) return null;
      return DateTimeRange(start: _normalize(picked), end: _normalize(picked));
    }
  }

  Future<void> _openLessonEditor(Lesson lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonEditorScreen(lesson: lesson),
      ),
    );
    if (!mounted) return;
    // Refresh in case schedule / title changed.
    final ownerId = context.read<AuthService>().user?.uid;
    if (ownerId != null) {
      await context.read<LessonService>().loadAllLessonsForOwner(ownerId);
    }
  }

  // ---- Lesson coverage check ----

  static bool _covers(Lesson l, DateTime day) {
    final start = l.scheduledDate;
    if (start == null) return false;
    final end = l.scheduledEndDate ?? start;
    final s = _normalize(start);
    final e = _normalize(end);
    final d = _normalize(day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  static String _seriesLabel(List<Series> all, String seriesId) {
    final hit = all.where((s) => s.id == seriesId).toList();
    return hit.isEmpty ? '(series)' : hit.first.title;
  }

  static String _rangeLabel(Lesson l) {
    if (l.scheduledDate == null) return '';
    final f = DateFormat('MMM d');
    final start = f.format(l.scheduledDate!);
    final end = l.scheduledEndDate == null ? '' : ' – ${f.format(l.scheduledEndDate!)}';
    return '$start$end';
  }
}

// ---- List view ----

class _ListView extends StatelessWidget {
  final List<Lesson> lessons;
  final Map<String, Series> seriesById;
  final ValueChanged<DateTime> onTapSunday;
  final ValueChanged<Lesson> onTapLesson;
  final Future<void> Function(Lesson) onSchedule;

  const _ListView({
    required this.lessons,
    required this.seriesById,
    required this.onTapSunday,
    required this.onTapLesson,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final sundays = _PlannerScreenState._upcomingSundays(12);
    final unscheduled = lessons.where((l) => !l.isScheduled).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sun in sundays) ...[
          _SundayRow(
            sunday: sun,
            covering:
                lessons.where((l) => _PlannerScreenState._covers(l, sun)).toList(),
            seriesById: seriesById,
            onTapSunday: () => onTapSunday(sun),
            onTapLesson: onTapLesson,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
        Text(
          'Unscheduled lessons (${unscheduled.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.0,
              ),
        ),
        const SizedBox(height: 8),
        if (unscheduled.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Every lesson has a date. Nice.'),
          )
        else
          ...unscheduled.map(
            (l) => Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(l.title),
                subtitle: Text(seriesById[l.seriesId]?.title ?? '(series)'),
                trailing: IconButton(
                  tooltip: 'Schedule',
                  icon: const Icon(Icons.event),
                  onPressed: () => onSchedule(l),
                ),
                onTap: () => onTapLesson(l),
              ),
            ),
          ),
      ],
    );
  }
}

class _SundayRow extends StatelessWidget {
  final DateTime sunday;
  final List<Lesson> covering;
  final Map<String, Series> seriesById;
  final VoidCallback onTapSunday;
  final ValueChanged<Lesson> onTapLesson;

  const _SundayRow({
    required this.sunday,
    required this.covering,
    required this.seriesById,
    required this.onTapSunday,
    required this.onTapLesson,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _PlannerScreenState._normalize(DateTime.now()) == sunday;
    final dateLabel = DateFormat('EEE MMM d').format(sunday);
    return Card(
      elevation: isToday ? 3 : 0,
      color: isToday ? AppColors.primary.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.15),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTapSunday,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: covering.isEmpty
                    ? const Text('— tap to schedule',
                        style: TextStyle(fontStyle: FontStyle.italic))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final l in covering)
                            InkWell(
                              onTap: () => onTapLesson(l),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (l.isMultiWeek)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2, right: 6),
                                        child: Icon(
                                          Icons.linear_scale,
                                          size: 14,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(l.title,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                          Text(
                                            seriesById[l.seriesId]?.title ??
                                                '(series)',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Calendar view ----

class _CalendarView extends StatelessWidget {
  final List<Lesson> lessons;
  final Map<String, Series> seriesById;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime selected, DateTime focused) onDaySelected;

  const _CalendarView({
    required this.lessons,
    required this.seriesById,
    required this.focusedDay,
    required this.selectedDay,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  List<Lesson> _eventsForDay(DateTime day) {
    return lessons.where((l) => _PlannerScreenState._covers(l, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TableCalendar<Lesson>(
          firstDay: DateTime(now.year - 1),
          lastDay: DateTime(now.year + 5),
          focusedDay: focusedDay,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          eventLoader: _eventsForDay,
          selectedDayPredicate: (d) =>
              selectedDay != null && isSameDay(d, selectedDay),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (selectedDay != null)
          _SelectedDayPanel(
            day: selectedDay!,
            covering: _eventsForDay(selectedDay!),
            seriesById: seriesById,
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Tap a date to see lessons scheduled for it.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  final DateTime day;
  final List<Lesson> covering;
  final Map<String, Series> seriesById;

  const _SelectedDayPanel({
    required this.day,
    required this.covering,
    required this.seriesById,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMMEEEEd().format(day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    )),
            const SizedBox(height: 8),
            if (covering.isEmpty)
              const Text('Nothing scheduled on this day yet.')
            else
              for (final l in covering)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.menu_book),
                  title: Text(l.title),
                  subtitle: Text(seriesById[l.seriesId]?.title ?? '(series)'),
                ),
          ],
        ),
      ),
    );
  }
}
