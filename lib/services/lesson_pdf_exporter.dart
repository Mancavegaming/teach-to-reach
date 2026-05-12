import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/lesson.dart';
import '../models/section.dart';

/// Generates a printable / shareable PDF of a single lesson — the way it was
/// authored, NOT an AI-generated handout. Renders cover page (title, scripture,
/// series, big idea), each section with optional speaker notes, and the
/// finalized sermon text on its own pages if present.
class LessonPdfExporter {
  static const PdfColor _ink = PdfColor.fromInt(0xFF111111);
  static const PdfColor _muted = PdfColor.fromInt(0xFF555555);
  static const PdfColor _accent = PdfColor.fromInt(0xFFD4AF37);
  static const PdfColor _band = PdfColor.fromInt(0xFFF2EBD2);

  /// Returns PDF bytes. Hand to `Printing.layoutPdf` / `Printing.sharePdf`.
  static Future<Uint8List> export({
    required Lesson lesson,
    required List<Section> sections,
    String? seriesTitle,
    bool includeSpeakerNotes = true,
    bool includeFinalizedSermon = true,
  }) async {
    final doc = pw.Document(
      title: lesson.title,
      author: 'Teach to Reach',
      subject: lesson.scriptureReference,
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : _runningHeader(lesson, seriesTitle),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _coverBlock(lesson, seriesTitle),
        pw.SizedBox(height: 24),
        if (sections.isNotEmpty) ...[
          _sectionHeading('Lesson sections'),
          pw.SizedBox(height: 12),
          for (var i = 0; i < sections.length; i++) ...[
            _sectionBlock(sections[i], i + 1, includeSpeakerNotes),
            pw.SizedBox(height: 18),
          ],
        ],
      ],
    ));

    if (includeFinalizedSermon &&
        lesson.finalizedSermonText.trim().isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
        header: (ctx) => _runningHeader(lesson, seriesTitle),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _sectionHeading('Finalized sermon'),
          pw.SizedBox(height: 12),
          pw.Text(
            lesson.finalizedSermonText,
            style: pw.TextStyle(
              fontSize: 11.5,
              color: _ink,
              lineSpacing: 4,
            ),
          ),
        ],
      ));
    }

    return doc.save();
  }

  // ---- Building blocks ----

  static pw.Widget _coverBlock(Lesson lesson, String? seriesTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 64, height: 4, color: _accent),
        pw.SizedBox(height: 14),
        pw.Text(
          lesson.title,
          style: pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        if (lesson.scriptureReference.trim().isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            lesson.scriptureReference,
            style: pw.TextStyle(
              fontSize: 14,
              color: _muted,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
        if ((seriesTitle ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Series: ${seriesTitle!}',
            style: pw.TextStyle(fontSize: 11, color: _muted),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          'Target ${lesson.targetDurationMinutes} min',
          style: pw.TextStyle(fontSize: 11, color: _muted),
        ),
        if (lesson.bigIdea.trim().isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _band,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border(
                left: pw.BorderSide(color: _accent, width: 3),
              ),
            ),
            padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BIG IDEA',
                  style: pw.TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: _muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  lesson.bigIdea,
                  style: pw.TextStyle(
                    fontSize: 13,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (lesson.summary.trim().isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            lesson.summary,
            style: pw.TextStyle(fontSize: 11, color: _ink, lineSpacing: 3),
          ),
        ],
      ],
    );
  }

  static pw.Widget _sectionHeading(String text) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 28, height: 2, color: _accent),
        pw.SizedBox(width: 8),
        pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: _muted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionBlock(
    Section s,
    int index,
    bool includeSpeakerNotes,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: _accent,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                '$index',
                style: pw.TextStyle(
                  color: PdfColors.black,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                s.title.trim().isEmpty ? '(untitled section)' : s.title,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        if (s.content.trim().isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4),
            child: pw.Text(
              s.content,
              style: pw.TextStyle(
                fontSize: 11.5,
                color: _ink,
                lineSpacing: 3,
              ),
            ),
          ),
        ],
        if (includeSpeakerNotes && s.speakerNotes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: _muted, width: 1),
              ),
            ),
            padding: const pw.EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SPEAKER NOTES',
                  style: pw.TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.4,
                    color: _muted,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  s.speakerNotes,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _muted,
                    fontStyle: pw.FontStyle.italic,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _runningHeader(Lesson lesson, String? seriesTitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _muted, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              lesson.title,
              style: pw.TextStyle(
                fontSize: 9,
                color: _muted,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if ((seriesTitle ?? '').trim().isNotEmpty)
            pw.Text(
              seriesTitle!,
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Teach to Reach',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    );
  }
}
