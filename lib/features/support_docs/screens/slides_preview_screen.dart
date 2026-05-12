import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../services/ai_support_doc_service.dart';
import '../../../services/pexels_service.dart';
import '../../../services/teacher_profile_service.dart';

/// Slide-by-slide preview where the teacher chooses an image for each slide
/// from Pexels, the iPad photo library, or skips it. Once images are
/// finalized, taps "Export PDF" to render and share.
class SlidesPreviewScreen extends StatefulWidget {
  final Lesson lesson;
  final String? seriesTitle;
  final Map<String, dynamic> data;

  const SlidesPreviewScreen({
    super.key,
    required this.lesson,
    required this.data,
    this.seriesTitle,
  });

  @override
  State<SlidesPreviewScreen> createState() => _SlidesPreviewScreenState();
}

class _SlidesPreviewScreenState extends State<SlidesPreviewScreen> {
  /// Editable working copy of the slide data — image bytes live here per slide.
  late Map<String, dynamic> _data;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _data = _deepCloneJson(widget.data);
  }

  List<Map<String, dynamic>> get _slides =>
      (_data['slides'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

  int get _slidesWithImages =>
      _slides.where((s) => s['imageBytes'] is Uint8List).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Slides: ${widget.lesson.title}',
            overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_slidesWithImages / ${_slides.length} with images',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              itemCount: _slides.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SlideCard(
                  index: i + 1,
                  slide: _slides[i],
                  onImageChosen: (bytes, label) =>
                      _setImage(i, bytes, label),
                  onClearImage: () => _setImage(i, null, null),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting ? null : _clearAllImages,
                          icon: const Icon(Icons.image_not_supported_outlined),
                          label: const Text('Clear all images'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _exporting ? null : _exportPdf,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(
                              _exporting ? 'Building PDF…' : 'Export PDF'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setImage(int slideIndex, Uint8List? bytes, String? sourceLabel) {
    setState(() {
      final s = _slides[slideIndex];
      if (bytes == null) {
        s.remove('imageBytes');
        s.remove('imageSource');
      } else {
        s['imageBytes'] = bytes;
        s['imageSource'] = sourceLabel ?? '';
      }
    });
  }

  void _clearAllImages() {
    setState(() {
      for (final s in _slides) {
        s.remove('imageBytes');
        s.remove('imageSource');
      }
    });
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    final teacher = context.read<TeacherProfileService>().profile;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await AiSupportDocService.renderFromData(
        type: SupportDocType.slides,
        lesson: widget.lesson,
        seriesTitle: widget.seriesTitle,
        teacher: teacher,
        data: _data,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${widget.lesson.title} - Slides.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  static Map<String, dynamic> _deepCloneJson(Map<String, dynamic> src) {
    final clone = <String, dynamic>{};
    src.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        clone[k] = _deepCloneJson(v);
      } else if (v is List) {
        clone[k] = v
            .map((e) => e is Map<String, dynamic> ? _deepCloneJson(e) : e)
            .toList();
      } else {
        clone[k] = v;
      }
    });
    return clone;
  }
}

class _SlideCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> slide;
  final void Function(Uint8List bytes, String sourceLabel) onImageChosen;
  final VoidCallback onClearImage;

  const _SlideCard({
    required this.index,
    required this.slide,
    required this.onImageChosen,
    required this.onClearImage,
  });

  @override
  State<_SlideCard> createState() => _SlideCardState();
}

class _SlideCardState extends State<_SlideCard> {
  bool _busy = false;

  Uint8List? get _imageBytes =>
      widget.slide['imageBytes'] is Uint8List
          ? widget.slide['imageBytes'] as Uint8List
          : null;

  String get _imageSource =>
      (widget.slide['imageSource'] as String?) ?? '';

  String get _title => (widget.slide['title'] as String?) ?? '';
  String get _imageHint => (widget.slide['imageHint'] as String?) ?? '';
  List<String> get _bullets =>
      (widget.slide['bullets'] as List<dynamic>? ?? const [])
          .map((b) => b.toString())
          .toList();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${widget.index}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final b in _bullets)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text('• $b',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 10),
            if (_imageHint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Image hint: $_imageHint',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                ),
              ),
            _imageBytes == null
                ? _imagePickerRow()
                : _imagePreviewRow(),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickFromPexels,
          icon: const Icon(Icons.image_search, size: 18),
          label: const Text('Pexels search'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _uploadFromDevice,
          icon: const Icon(Icons.upload, size: 18),
          label: const Text('Upload from iPad'),
        ),
      ],
    );
  }

  Widget _imagePreviewRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _imageBytes!,
            width: 120,
            height: 70,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(_imageSource,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        IconButton(
          tooltip: 'Replace image',
          icon: const Icon(Icons.refresh),
          onPressed: _busy ? null : _pickFromPexels,
        ),
        IconButton(
          tooltip: 'Remove image',
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : widget.onClearImage,
        ),
      ],
    );
  }

  Future<void> _pickFromPexels() async {
    final initial = _imageHint.isEmpty ? _title : _imageHint;
    final picked = await Navigator.of(context).push<_PexelsPick>(
      MaterialPageRoute(
        builder: (_) => _PexelsSearchScreen(initialQuery: initial),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await PexelsService.downloadBytes(picked.photo.fullUrl);
      widget.onImageChosen(
        bytes,
        'Pexels · ${picked.photo.photographer}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pexels download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadFromDevice() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    widget.onImageChosen(bytes, 'Uploaded from iPad');
  }
}

/// Pexels search screen — type a query, see thumbnails, pick one.
class _PexelsSearchScreen extends StatefulWidget {
  final String initialQuery;
  const _PexelsSearchScreen({required this.initialQuery});

  @override
  State<_PexelsSearchScreen> createState() => _PexelsSearchScreenState();
}

class _PexelsSearchScreenState extends State<_PexelsSearchScreen> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;
  List<PexelsPhoto> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await PexelsService.search(q);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pexels image search')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'shepherd holding lamb',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _search,
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 16 / 11,
                ),
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final p = _results[i];
                  return InkWell(
                    onTap: () => Navigator.of(context)
                        .pop(_PexelsPick(photo: p)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.network(
                              p.thumbnailUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Text(
                              p.photographer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PexelsPick {
  final PexelsPhoto photo;
  const _PexelsPick({required this.photo});
}
