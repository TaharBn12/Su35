import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/aviation_data.dart';
import '../../../core/utils/app_date.dart';
import '../../../l10n/l10n.dart';
import '../../pages/domain/note_page.dart';
import '../data/attachment_repository.dart';
import '../domain/block.dart';
import '../domain/block_content.dart';

/// نتيجة بناء ملف PDF.
class PdfExportResult {
  const PdfExportResult({required this.bytes, required this.fontsReady});

  final Uint8List bytes;

  /// هل حُمّلت خطوط تدعم العربية؟ (إن لا، نُظهر تحذيرًا للمستخدم)
  final bool fontsReady;
}

/// تصدير صفحة (بياناتها الجوية + كل كتل محتواها) إلى ملف PDF.
///
/// ملاحظات مهمة:
/// • الخطوط: يُجرَّب أولًا خطّا Cairo المضمّنان في `assets/fonts/`، فإن لم
///   يوجدان يُنزَّلان من Google Fonts (مرة واحدة ثم يُخزَّنان مؤقتًا)، وإن فشل
///   ذلك يُستخدم خط PDF الافتراضي مع تحذير للمستخدم.
/// • الاتجاه: يُمرَّر `pw.TextDirection` الخاص بحزمة pdf (لا اتجاه Flutter) —
///   والحزمة تتولّى تشكيل العربية (Arabic shaping) تلقائيًا عند توفّر الخط.
class PdfExportService {
  PdfExportService(this._attachments);

  final AttachmentRepository _attachments;

  static const String _regularFontAsset = 'assets/fonts/Cairo-Regular.ttf';
  static const String _boldFontAsset = 'assets/fonts/Cairo-Bold.ttf';

  static const PdfColor _brandNavy = PdfColor.fromInt(0xFF0B3D91);
  static const PdfColor _brandSky = PdfColor.fromInt(0xFF4FA3E3);
  static const PdfColor _brandAmber = PdfColor.fromInt(0xFFF0A02A);

  pw.ThemeData? _theme;
  bool _fontsReady = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  الخطوط والثيم
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _resolveTheme() async {
    if (_theme != null) {
      return;
    }

    pw.Font? base = await _loadAssetFont(_regularFontAsset);
    pw.Font? bold = await _loadAssetFont(_boldFontAsset);

    if (base == null || bold == null) {
      try {
        base ??= await PdfGoogleFonts.cairoRegular();
        bold ??= await PdfGoogleFonts.cairoBold();
      } catch (_) {
        // لا اتصال بالإنترنت ولا خطوط مضمّنة — نكمل بالخط الافتراضي.
      }
    }

    _fontsReady = base != null && bold != null;

    if (_fontsReady) {
      _theme = pw.ThemeData.withFont(
        base: base,
        bold: bold,
        // Cairo لا يوفّر نسخة مائلة، فنستخدم العادي/العريض لتفادي فراغات الخطوط.
        italic: base,
        boldItalic: bold,
        fontFallback: <pw.Font>[base!, bold!],
      );
    } else {
      _theme = pw.ThemeData.base();
    }
  }

  Future<pw.Font?> _loadAssetFont(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  البناء الرئيسي
  // ─────────────────────────────────────────────────────────────────────────

  Future<PdfExportResult> buildPagePdf({
    required NotePage page,
    required String notebookTitle,
    required List<NoteBlock> blocks,
    required AppL10n l10n,
    required bool arabic,
  }) async {
    await _resolveTheme();

    final pw.ThemeData theme = _theme ?? pw.ThemeData.base();
    final pw.TextDirection direction =
        arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final Map<String, pw.MemoryImage> images = await _loadImages(blocks);

    final pw.Document document = pw.Document(
      title: page.title,
      author: AppInfo.name,
      creator: AppInfo.name,
      subject: notebookTitle,
    );

    final _BuildState state = _BuildState(
      theme: theme,
      l10n: l10n,
      arabic: arabic,
      direction: direction,
      images: images,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        theme: theme,
        textDirection: direction,
        header: (pw.Context context) => _buildHeader(context, page, notebookTitle, state),
        footer: (pw.Context context) => _buildFooter(context, state),
        build: (pw.Context context) => _buildBody(page, blocks, state),
      ),
    );

    final Uint8List bytes = await document.save();
    return PdfExportResult(bytes: bytes, fontsReady: _fontsReady);
  }

  pw.Widget _buildHeader(
    pw.Context context,
    NotePage page,
    String notebookTitle,
    _BuildState state,
  ) {
    final pw.TextStyle base = state.theme.defaultTextStyle;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _brandSky, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  AppInfo.name,
                  style: base.copyWith(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandNavy,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${page.displayIcon}  $notebookTitle',
                  style: base.copyWith(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.Text(
            state.l10n.pdfExportedOn(
              AppDate.display(DateTime.now(), arabic: state.arabic),
            ),
            style: base.copyWith(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context, _BuildState state) {
    final pw.TextStyle base = state.theme.defaultTextStyle;
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            AppInfo.name,
            style: base.copyWith(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            state.l10n.pdfPageOf(context.pageNumber, context.pagesCount),
            style: base.copyWith(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildBody(
    NotePage page,
    List<NoteBlock> blocks,
    _BuildState state,
  ) {
    final pw.TextStyle base = state.theme.defaultTextStyle;
    final List<pw.Widget> widgets = <pw.Widget>[];

    // 1) عنوان الصفحة
    widgets.add(
      pw.Text(
        page.title,
        style: base.copyWith(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: _brandNavy,
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 10));

    // 2) جدول البيانات الجوية
    final List<List<String>> metaRows = _metaRows(page, state);
    if (metaRows.isNotEmpty) {
      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: const <String>[],
          headerCount: 0,
          data: metaRows,
          border: null,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          cellStyle: base.copyWith(fontSize: 9),
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(120),
          },
          tableDirection: state.direction,
        ),
      );
      widgets.add(pw.SizedBox(height: 12));
    }

    // 3) الملخص
    final String summary = (page.summary ?? '').trim();
    if (summary.isNotEmpty) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            summary,
            style: base.copyWith(fontSize: 9, color: PdfColors.grey800),
            textDirection: state.direction,
          ),
        ),
      );
    }

    // 4) كتل المحتوى
    final List<NoteBlock> visibleBlocks = blocks
        .where((NoteBlock block) => !(block.isEmpty && block.type != BlockType.divider))
        .toList(growable: false);

    if (visibleBlocks.isEmpty) {
      widgets.add(
        pw.Text(
          state.l10n.pdfNoContent,
          style: base.copyWith(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    } else {
      for (final NoteBlock block in visibleBlocks) {
        widgets.addAll(_buildBlock(block, state));
      }
    }

    return widgets;
  }

  List<List<String>> _metaRows(NotePage page, _BuildState state) {
    final AppL10n l10n = state.l10n;
    final List<List<String>> rows = <List<String>>[];

    void add(String label, String? value) {
      final String text = (value ?? '').trim();
      if (text.isNotEmpty) {
        rows.add(<String>[label, text]);
      }
    }

    add(l10n.fieldAircraftType, page.aircraftType);
    add(l10n.fieldTailNumber, page.tailNumber);
    add(
      l10n.fieldAtaChapter,
      (page.ataChapter ?? '').trim().isEmpty
          ? null
          : AviationData.ataLabel(page.ataChapter, arabic: state.arabic),
    );
    add(l10n.fieldAirport, page.airportIcao);
    add(
      l10n.fieldFlightDate,
      page.flightDate == null
          ? null
          : AppDate.display(page.flightDate!, arabic: state.arabic),
    );
    return rows;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  بناء الكتل
  // ─────────────────────────────────────────────────────────────────────────

  List<pw.Widget> _buildBlock(NoteBlock block, _BuildState state) =>
      switch (block.type) {
        BlockType.divider => <pw.Widget>[
            pw.Divider(color: PdfColors.grey300, thickness: 0.7, height: 14),
          ],
        BlockType.heading => _headingWidgets(block.heading, state),
        BlockType.text => _richTextWidgets(block.richText, state),
        BlockType.quote => _quoteWidgets(block.quote, state),
        BlockType.callout => _calloutWidgets(block.callout, state),
        BlockType.checklist => _checklistWidgets(block.checklist, state),
        BlockType.table => _tableWidgets(block.table, state),
        BlockType.code => _codeWidgets(block.code, state),
        BlockType.image => _imageWidgets(block.media, state),
        BlockType.pdf => _pdfWidgets(block.media, state),
      };

  List<pw.Widget> _headingWidgets(HeadingData data, _BuildState state) {
    final String text = data.text.trim();
    if (text.isEmpty) {
      return const <pw.Widget>[];
    }
    final double size = switch (data.level) {
      1 => 16,
      2 => 14,
      _ => 12,
    };
    return <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Text(
        text,
        style: state.theme.defaultTextStyle.copyWith(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          color: _brandNavy,
        ),
        textDirection: state.direction,
      ),
      pw.SizedBox(height: 6),
    ];
  }

  /// تحويل Delta إلى مقاطع سطرية مع أنماطها (عناوين/قوائم/اقتباس).
  List<pw.Widget> _richTextWidgets(RichTextData data, _BuildState state) {
    if (data.isEmpty) {
      return const <pw.Widget>[];
    }
    final List<_RichLine> lines = _parseDeltaLines(data.delta);
    final List<pw.Widget> widgets = <pw.Widget>[];

    int orderedCounter = 0;
    for (final _RichLine line in lines) {
      if (line.runs.isEmpty) {
        // سطر فارغ: نحفظ الفراغ بدل إسقاطه.
        widgets.add(const pw.SizedBox(height: 8));
        continue;
      }
      final int ordinal =
          line.attributes['list'] == 'ordered' ? ++orderedCounter : 0;
      widgets.add(_lineWidget(line, state, ordinal: ordinal));
      widgets.add(pw.SizedBox(height: line.isList ? 2 : 4));
    }
    return widgets;
  }

  pw.Widget _lineWidget(_RichLine line, _BuildState state, {int ordinal = 0}) {
    final pw.TextStyle base = state.theme.defaultTextStyle;
    final pw.TextStyle style = _resolveLineStyle(line, base);
    final pw.InlineSpan span = pw.TextSpan(
      children: line.runs
          .map(
            (_RichRun run) => pw.TextSpan(
              text: run.text,
              style: _resolveRunStyle(run.attributes, style),
            ),
          )
          .toList(growable: false),
    );

    final pw.Widget text = pw.RichText(
      text: span,
      textDirection: state.direction,
      textAlign: state.arabic ? pw.TextAlign.right : pw.TextAlign.left,
    );

    final Object? listType = line.attributes['list'];
    if (listType == null) {
      if (line.attributes['blockquote'] == true) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: _brandAmber, width: 2),
            ),
          ),
          child: pw.DefaultTextStyle(
            style: base.copyWith(fontStyle: pw.FontStyle.italic),
            child: text,
          ),
        );
      }
      return text;
    }

    final String prefix = switch (listType) {
      'ordered' => '$ordinal.  ',
      'checked' => '[x]  ',
      'unchecked' => '[ ]  ',
      _ => '•  ',
    };

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.SizedBox(
          width: 22,
          child: pw.Text(
            prefix,
            style: base.copyWith(fontSize: base.fontSize ?? 12, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(child: text),
      ],
    );
  }

  pw.TextStyle _resolveLineStyle(_RichLine line, pw.TextStyle base) {
    final Object? header = line.attributes['header'];
    if (header is num) {
      final double size = switch (header.toInt()) {
        1 => 15,
        2 => 13,
        3 => 12,
        _ => 11,
      };
      return base.copyWith(
        fontSize: size,
        fontWeight: pw.FontWeight.bold,
        color: _brandNavy,
      );
    }
    if (line.attributes['code-block'] == true) {
      return base.copyWith(
        fontSize: (base.fontSize ?? 12) - 1,
        color: PdfColors.blueGrey900,
      );
    }
    if (line.attributes['blockquote'] == true) {
      return base.copyWith(fontStyle: pw.FontStyle.italic, color: PdfColors.grey800);
    }
    return base;
  }

  pw.TextStyle _resolveRunStyle(Map<String, dynamic> attributes, pw.TextStyle base) {
    pw.TextStyle style = base;

    if (attributes['bold'] == true) {
      style = style.copyWith(fontWeight: pw.FontWeight.bold);
    }
    if (attributes['italic'] == true) {
      style = style.copyWith(fontStyle: pw.FontStyle.italic);
    }

    final List<pw.TextDecoration> decorations = <pw.TextDecoration>[
      if (attributes['underline'] == true) pw.TextDecoration.underline,
      if (attributes['strike'] == true) pw.TextDecoration.lineThrough,
    ];
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: pw.TextDecoration.combine(decorations));
    }

    if (attributes['code'] == true || attributes['inline-code'] == true) {
      style = style.copyWith(
        background: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(2)),
      );
    }

    final Object? color = attributes['color'];
    if (color is String) {
      final PdfColor? parsed = _hexToPdfColor(color);
      if (parsed != null) {
        style = style.copyWith(color: parsed);
      }
    }

    final Object? size = attributes['size'];
    if (size is String) {
      final double? parsed = double.tryParse(size.replaceAll('px', '').trim());
      if (parsed != null && parsed > 4 && parsed < 72) {
        style = style.copyWith(fontSize: parsed);
      }
    }

    final Object? link = attributes['link'];
    if (link is String && link.isNotEmpty) {
      style = style.copyWith(
        color: _brandSky,
        decoration: pw.TextDecoration.underline,
      );
    }

    return style;
  }

  List<pw.Widget> _quoteWidgets(QuoteData data, _BuildState state) {
    final String text = data.text.trim();
    if (text.isEmpty) {
      return const <pw.Widget>[];
    }
    return <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _brandAmber, width: 3)),
        ),
        child: pw.Text(
          text,
          style: state.theme.defaultTextStyle.copyWith(
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey800,
          ),
          textDirection: state.direction,
        ),
      ),
    ];
  }

  List<pw.Widget> _calloutWidgets(CalloutData data, _BuildState state) {
    if (data.isEmpty) {
      return const <pw.Widget>[];
    }
    final (PdfColor background, PdfColor border) = switch (data.tone) {
      CalloutTone.warning => (PdfColors.amber100, _brandAmber),
      CalloutTone.danger => (PdfColors.red100, PdfColors.red700),
      CalloutTone.info => (PdfColors.lightBlue100, _brandSky),
    };

    final pw.TextStyle base = state.theme.defaultTextStyle;
    return <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          color: background,
          border: pw.Border(left: pw.BorderSide(color: border, width: 3)),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            if (data.title.trim().isNotEmpty)
              pw.Text(
                data.title.trim(),
                style: base.copyWith(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: (base.fontSize ?? 12) + 1,
                ),
                textDirection: state.direction,
              ),
            if (data.text.trim().isNotEmpty)
              pw.Text(
                data.text.trim(),
                style: base.copyWith(fontSize: (base.fontSize ?? 12) - 0.5),
                textDirection: state.direction,
              ),
          ],
        ),
      ),
    ];
  }

  List<pw.Widget> _checklistWidgets(ChecklistData data, _BuildState state) {
    if (data.isEmpty) {
      return const <pw.Widget>[];
    }
    final pw.TextStyle base = state.theme.defaultTextStyle;
    final List<pw.Widget> widgets = <pw.Widget>[];

    widgets.add(
      pw.Text(
        state.l10n.blockChecklistProgress(data.doneCount, data.total),
        style: base.copyWith(fontSize: 8, color: PdfColors.grey600),
      ),
    );
    widgets.add(pw.SizedBox(height: 4));

    for (final ChecklistItem item in data.items) {
      if (item.text.trim().isEmpty) {
        continue;
      }
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              // مربّع مرسوم بدل رمز ✓ حتى لا يعتمد على توفّر الرمز في الخط
              pw.Container(
                width: 8,
                height: 8,
                margin: const pw.EdgeInsets.only(top: 2, right: 6, left: 6),
                decoration: pw.BoxDecoration(
                  color: item.checked ? _brandSky : null,
                  border: pw.Border.all(color: PdfColors.grey600, width: 0.7),
                  borderRadius: pw.BorderRadius.circular(1.5),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  item.text.trim(),
                  style: base.copyWith(
                    decoration: item.checked ? pw.TextDecoration.lineThrough : null,
                    color: item.checked ? PdfColors.grey600 : null,
                  ),
                  textDirection: state.direction,
                ),
              ),
            ],
          ),
        ),
      );
    }
    widgets.add(pw.SizedBox(height: 6));
    return widgets;
  }

  List<pw.Widget> _tableWidgets(TableData data, _BuildState state) {
    if (data.isEmpty) {
      return const <pw.Widget>[];
    }
    final pw.TextStyle base = state.theme.defaultTextStyle;
    final bool hasHeader = data.columns.any((String column) => column.trim().isNotEmpty);

    return <pw.Widget>[
      pw.TableHelper.fromTextArray(
        headers: hasHeader ? data.columns : const <String>[],
        headerCount: hasHeader ? 1 : 0,
        data: data.rows.map((List<String> row) => row.cast<Object>()).toList(growable: false),
        headerStyle: base.copyWith(fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellStyle: base.copyWith(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        headerDirection: state.direction,
        tableDirection: state.direction,
      ),
      pw.SizedBox(height: 8),
    ];
  }

  List<pw.Widget> _codeWidgets(CodeData data, _BuildState state) {
    final String code = data.code.trimRight();
    if (code.isEmpty) {
      return const <pw.Widget>[];
    }
    final pw.TextStyle base = state.theme.defaultTextStyle;

    // نحافظ على المسافات البادئة عبر مسافة غير فاصلة (مدعومة في خطوط عربية/لاتينية)
    final String preserved = code
        .split('\n')
        .map((String line) => line.replaceFirstMapped(
              RegExp(r'^( +)'),
              (Match match) => '\u00A0' * match.group(1)!.length,
            ))
        .join('\n');

    return <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            if ((data.language ?? '').trim().isNotEmpty)
              pw.Text(
                data.language!.trim(),
                style: base.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
            pw.Text(
              preserved,
              style: base.copyWith(fontSize: 8.5, color: PdfColors.blueGrey900),
              textDirection: pw.TextDirection.ltr,
            ),
          ],
        ),
      ),
    ];
  }

  List<pw.Widget> _imageWidgets(MediaData data, _BuildState state) {
    final List<pw.Widget> widgets = <pw.Widget>[];
    final String? path = data.storagePath;
    final pw.MemoryImage? image = path == null ? null : state.images[path];

    if (image != null) {
      widgets.add(
        pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Image(image, fit: pw.BoxFit.contain, height: 240),
        ),
      );
    } else if (data.hasFile) {
      widgets.add(
        pw.Text(
          state.l10n.blockMediaLoadFailed,
          style: state.theme.defaultTextStyle.copyWith(
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
      );
    }

    final String caption = (data.caption ?? '').trim();
    if (caption.isNotEmpty) {
      widgets.add(
        pw.Text(
          caption,
          style: state.theme.defaultTextStyle.copyWith(
            fontSize: 8,
            color: PdfColors.grey700,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );
    }
    widgets.add(pw.SizedBox(height: 8));
    return widgets;
  }

  List<pw.Widget> _pdfWidgets(MediaData data, _BuildState state) {
    if (!data.hasFile) {
      return const <pw.Widget>[];
    }
    final pw.TextStyle base = state.theme.defaultTextStyle;
    return <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              state.l10n.pdfLinkedFile(data.displayName.isEmpty ? '—' : data.displayName),
              style: base.copyWith(fontSize: 9, color: PdfColors.blueGrey900),
              textDirection: state.direction,
            ),
            if ((data.caption ?? '').trim().isNotEmpty)
              pw.Text(
                data.caption!.trim(),
                style: base.copyWith(fontSize: 8, color: PdfColors.grey700),
                textDirection: state.direction,
              ),
          ],
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  أدوات Delta
  // ─────────────────────────────────────────────────────────────────────────

  static List<_RichLine> _parseDeltaLines(List<dynamic> delta) {
    final List<_RichLine> lines = <_RichLine>[];
    List<_RichRun> runs = <_RichRun>[];
    Map<String, dynamic> lineAttributes = <String, dynamic>{};

    void pushLine({bool force = false}) {
      if (force || runs.isNotEmpty || lineAttributes.isNotEmpty) {
        lines.add(_RichLine(runs: runs, attributes: lineAttributes));
      }
      runs = <_RichRun>[];
      lineAttributes = <String, dynamic>{};
    }

    for (final dynamic operation in delta) {
      if (operation is! Map) {
        continue;
      }
      final Object? insert = operation['insert'];
      if (insert is! String) {
        continue; // الوسائط المضمّنة (صور Quill) لا تُحمَّل هنا
      }

      final Object? rawAttributes = operation['attributes'];
      final Map<String, dynamic> attributes = rawAttributes is Map
          ? rawAttributes.map(
              (Object? key, Object? value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            )
          : <String, dynamic>{};

      final List<String> parts = insert.split('\n');
      for (int index = 0; index < parts.length; index++) {
        if (index > 0) {
          // سمات السطر تُحمَل على عملية الإدراج التي تحتوي على '\n'
          if (attributes.isNotEmpty) {
            lineAttributes = attributes;
          }
          pushLine(force: true);
        }
        if (parts[index].isNotEmpty) {
          runs.add(_RichRun(text: parts[index], attributes: attributes));
        }
      }
    }
    pushLine();
    return lines;
  }

  static PdfColor? _hexToPdfColor(String value) {
    final RegExpMatch? match =
        RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int? rgb = int.tryParse(match.group(1)!, radix: 16);
    if (rgb == null) {
      return null;
    }
    return PdfColor.fromInt(0xFF000000 | rgb);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  المرفقات: تنزيل الصور لإدراجها في الملف
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, pw.MemoryImage>> _loadImages(List<NoteBlock> blocks) async {
    final Map<String, pw.MemoryImage> images = <String, pw.MemoryImage>{};

    for (final NoteBlock block in blocks) {
      if (block.type != BlockType.image) {
        continue;
      }
      final String? path = block.media.storagePath;
      if (path == null || path.isEmpty || images.containsKey(path)) {
        continue;
      }
      try {
        final Uint8List bytes = await _attachments.downloadBytes(path);
        images[path] = pw.MemoryImage(bytes);
      } catch (_) {
        // صورة غير قابلة للتنزيل — يُذكر ذلك في مكانها داخل الملف.
      }
    }
    return images;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  المشاركة والطباعة
  // ─────────────────────────────────────────────────────────────────────────

  /// مشاركة الملف (واتساب، بريد، حفظ في الملفات...) عبر الحزمة printing.
  Future<bool> sharePdf({
    required PdfExportResult result,
    required String fileName,
  }) =>
      Printing.sharePdf(bytes: result.bytes, filename: fileName);

  /// فتح معاينة الطباعة/الطباعة الفعلية.
  Future<bool> printPdf({
    required PdfExportResult result,
    required String fileName,
  }) =>
      Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async => result.bytes,
      );

  /// اسم ملف مقترح مبني على عنوان الصفحة وتاريخ اليوم.
  static String suggestedFileName(NotePage page) {
    final String base = page.title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final String safeBase = base.isEmpty ? 'page' : base;
    return '${safeBase}_${AppDate.isoDate(DateTime.now())}.pdf';
  }
}

/// حالة تُمرَّر داخليًا لبنّاءات الكتل.
class _BuildState {
  const _BuildState({
    required this.theme,
    required this.l10n,
    required this.arabic,
    required this.direction,
    required this.images,
  });

  final pw.ThemeData theme;
  final AppL10n l10n;
  final bool arabic;
  final pw.TextDirection direction;
  final Map<String, pw.MemoryImage> images;
}

/// مقطع نصي داخل سطر (نص + سمات تنسيقه).
class _RichRun {
  const _RichRun({required this.text, required this.attributes});

  final String text;
  final Map<String, dynamic> attributes;
}

/// سطر داخل كتلة نصية (مقاطع + سمات السطر: عنوان/قائمة/اقتباس).
class _RichLine {
  const _RichLine({required this.runs, required this.attributes});

  final List<_RichRun> runs;
  final Map<String, dynamic> attributes;

  bool get isList => attributes['list'] != null;
}
