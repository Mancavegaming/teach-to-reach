import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/series.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_profile_service.dart';
import '../../../services/doctrinal_positions_service.dart';
import '../../../services/series_service.dart';
import '../../../services/teacher_profile_service.dart';
import '../../../services/voice_corpus_service.dart';
import '../../planner/screens/planner_screen.dart';
import '../../profile/screens/class_profile_screen.dart';
import '../../profile/screens/doctrinal_positions_screen.dart';
import '../../profile/screens/teacher_profile_screen.dart';
import '../../profile/screens/voice_corpus_screen.dart';
import '../../series/screens/series_detail_screen.dart';
import '../../series/widgets/series_form_dialog.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final displayName = auth.user?.displayName ?? auth.user?.email ?? 'Teacher';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teach to Reach'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmSignOut(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Lessons'),
              Tab(icon: Icon(Icons.event_note), text: 'Planner'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeHeader(name: displayName),
                    const SizedBox(height: 24),
                    const _SeriesSection(),
                    const SizedBox(height: 24),
                    Text(
                      'Profile & Foundations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const _ProfilesGrid(),
                    const SizedBox(height: 24),
                    const _PhaseRoadmap(),
                  ],
                ),
              ),
              const SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: PlannerScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You\'ll need to sign back in to author lessons.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthService>().signOut();
    }
  }
}

class _WelcomeHeader extends StatelessWidget {
  final String name;
  const _WelcomeHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.premiumCard,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child:
                const Icon(Icons.auto_stories, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Author curriculum that reaches young hearts',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesSection extends StatelessWidget {
  const _SeriesSection();

  Future<void> _newSeries(BuildContext context) async {
    final ownerId = context.read<AuthService>().user!.uid;
    final created = await showDialog<Series>(
      context: context,
      builder: (_) => SeriesFormDialog(ownerId: ownerId),
    );
    if (created == null || !context.mounted) return;
    final svc = context.read<SeriesService>();
    final id = await svc.create(created);
    if (id == null || !context.mounted) return;
    final series = created.copyWith(id: id);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(series: series),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SeriesService>();
    final series = svc.series;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Your Series',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${series.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.primary)),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _newSeries(context),
              icon: const Icon(Icons.add),
              label: const Text('New Series'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (svc.isLoading && series.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (series.isEmpty)
          _EmptySeries(onCreate: () => _newSeries(context))
        else
          Column(
            children: [
              for (final s in series.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SeriesTile(series: s),
                ),
            ],
          ),
      ],
    );
  }
}

class _EmptySeries extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptySeries({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.library_books_outlined,
              size: 56, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text("Let's build your first series",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'A series is a collection of lessons with a common thread — '
            'a book of the Bible, a topic, a character study.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Series'),
          ),
        ],
      ),
    );
  }
}

class _SeriesTile extends StatelessWidget {
  final Series series;
  const _SeriesTile({required this.series});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(series: series),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.premiumCard,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.library_books_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(series.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    if (series.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(series.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 4),
                    Text('Updated ${_relative(series.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

String _relative(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays == 0) return 'today';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(date);
}

class _ProfilesGrid extends StatelessWidget {
  const _ProfilesGrid();

  @override
  Widget build(BuildContext context) {
    final teacher = context.watch<TeacherProfileService>().profile;
    final classProfile = context.watch<ClassProfileService>().profile;
    final doctrine = context.watch<DoctrinalPositionsService>().positions;
    final corpus = context.watch<VoiceCorpusService>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        final crossAxis = isWide ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxis,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 1.4 : 1.1,
          children: [
            _ProfileTile(
              icon: Icons.person_outline,
              title: 'Teacher Profile',
              subtitle: teacher?.displayName.isNotEmpty == true
                  ? teacher!.displayName
                  : 'Set your teaching identity',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TeacherProfileScreen(),
              )),
            ),
            _ProfileTile(
              icon: Icons.groups_outlined,
              title: 'Class Profile',
              subtitle: classProfile?.className.isNotEmpty == true
                  ? classProfile!.className
                  : 'Tell the AI about your class',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ClassProfileScreen(),
              )),
            ),
            _ProfileTile(
              icon: Icons.menu_book_outlined,
              title: 'Doctrinal Positions',
              subtitle: doctrine?.coreTradition ?? 'Anchor what AI may teach',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const DoctrinalPositionsScreen(),
              )),
            ),
            _ProfileTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Voice Corpus',
              subtitle: corpus.items.isEmpty
                  ? 'Upload past sermons & lessons'
                  : '${corpus.items.length} items · ${corpus.totalWordCount} words',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const VoiceCorpusScreen(),
              )),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.premiumCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseRoadmap extends StatelessWidget {
  const _PhaseRoadmap();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Build Roadmap',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  )),
          const SizedBox(height: 10),
          const _RoadmapItem(label: 'Phase 0 — Scaffold', done: true),
          const _RoadmapItem(label: 'Phase 1 — Auth + Profiles', done: true),
          const _RoadmapItem(
              label: 'Phase 2 — Series, Lessons, Sections', done: true),
          const _RoadmapItem(
              label: 'Phase 3 — Sermon Mode + Pen Annotation', done: false),
          const _RoadmapItem(
              label: 'Phase 4 — AI Layer (Deep Dive, Support Docs)',
              done: false),
        ],
      ),
    );
  }
}

class _RoadmapItem extends StatelessWidget {
  final String label;
  final bool done;
  const _RoadmapItem({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppColors.success : AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: done
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  )),
        ],
      ),
    );
  }
}
