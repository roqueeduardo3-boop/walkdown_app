import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';

import '../models.dart';
import '../translations.dart';

class ChecklistPdfService {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static final _translator = GoogleTranslator();

  static Future<void> _loadFonts() async {
    if (_regularFont != null && _boldFont != null) return;

    try {
      final regularFontData =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldFontData =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

      _regularFont = pw.Font.ttf(regularFontData);
      _boldFont = pw.Font.ttf(boldFontData);
    } catch (_) {
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
    }
  }

  static Future<String> _translateToEnglish(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return text;

    try {
      final t = await _translator.translate(cleaned, from: 'pt', to: 'en');
      final out = t.text.trim();
      if (out.isNotEmpty) return out;
      return cleaned;
    } catch (_) {
      // fallback dicionário interno
      try {
        return Translator.translate(cleaned);
      } catch (_) {
        return cleaned;
      }
    }
  }

  // Extrai "secção" do location: "HUB – ..." => "HUB"
  static String _extractSectionKey(String location) {
    final loc = location.trim();
    if (loc.isEmpty) return '';

    if (loc.contains(' – ')) return loc.split(' – ')[0].trim();
    if (loc.contains(' - ')) return loc.split(' - ')[0].trim();
    if (loc.contains(' → ')) return loc.split(' → ')[0].trim();
    return loc;
  }

  static Future<Map<String, List<Occurrence>>> _groupOccurrencesBySection(
    List<Occurrence> occurrences,
  ) async {
    // Tradução de occurrence (location/description) para EN (como fazes no PdfGenerator)
    final translated = <Occurrence>[];
    for (final o in occurrences) {
      translated.add(
        Occurrence(
          id: o.id,
          walkdownId: o.walkdownId,
          location: await _translateToEnglish(o.location),
          description: await _translateToEnglish(o.description),
          createdAt: o.createdAt,
          photos: o.photos,
        ),
      );
    }

    // Agrupar por secção (HUB/NACELE/etc.)
    final map = <String, List<Occurrence>>{};
    for (final o in translated) {
      final key = _extractSectionKey(o.location).toUpperCase();
      map.putIfAbsent(key, () => []).add(o);
    }

    // Ordenar por data
    for (final e in map.entries) {
      e.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return map;
  }

  static Future<File> generateChecklistPdf({
    required WalkdownData walkdown,
    required List<Occurrence> occurrences,
  }) async {
    await _loadFonts();

    // Logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo_2ws.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final occBySection = await _groupOccurrencesBySection(occurrences);
    final sections = buildChecklistForWalkdown(walkdown);

    // Traduz header fields (se quiseres tudo 100% EN, traduz labels fixas)
    final projectLabel = 'Project:';
    final siteLabel = 'Site:';
    final roadLabel = 'Road:';
    final towerLabel = 'Tower:';
    final supLabel = 'S.SUP:';
    final dateLabel = 'Date:';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
        build: (context) => [
          _buildHeader(
            walkdown: walkdown,
            logo: logoImage,
            projectLabel: projectLabel,
            siteLabel: siteLabel,
            roadLabel: roadLabel,
            towerLabel: towerLabel,
            supLabel: supLabel,
            dateLabel: dateLabel,
          ),
          pw.SizedBox(height: 10),
          _buildChecklistTable(
            walkdown: walkdown,
            sections: sections,
            occBySection: occBySection,
          ),
        ],
      ),
    );

    // Guardar (tal como fazes no PdfGenerator)
    Directory directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = Directory('/storage/emulated/0/Documents');
      }
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'checklist_${walkdown.projectInfo.towerNumber}_$ts.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    if (Platform.isAndroid || Platform.isIOS) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Checklist PDF - Tower ${walkdown.projectInfo.towerNumber}',
      );
    }

    return file;
  }

  static pw.Widget _buildHeader({
    required WalkdownData walkdown,
    required pw.ImageProvider? logo,
    required String projectLabel,
    required String siteLabel,
    required String roadLabel,
    required String towerLabel,
    required String supLabel,
    required String dateLabel,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            _headerCell(projectLabel, walkdown.projectInfo.projectNumber),
            _headerCell(siteLabel, walkdown.projectInfo.projectName),
            pw.Container(
              height: 50,
              alignment: pw.Alignment.center,
              child: logo != null
                  ? pw.Image(logo, height: 45, fit: pw.BoxFit.contain)
                  : pw.SizedBox(),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
              height: 40,
              padding: const pw.EdgeInsets.all(5),
              alignment: pw.Alignment.center,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    roadLabel,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(walkdown.projectInfo.road,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    towerLabel,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(walkdown.projectInfo.towerNumber,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            _headerCell(supLabel, walkdown.projectInfo.supervisorName),
            _headerCell(dateLabel, _formatDate(walkdown.projectInfo.date)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _headerCell(String label, String value) {
    return pw.Container(
      height: 40,
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(width: 5),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildChecklistTable({
    required WalkdownData walkdown,
    required List<ChecklistSection> sections,
    required Map<String, List<Occurrence>> occBySection,
  }) {
    final rows = <pw.TableRow>[];

    // Header da tabela (estilo “No | Check description | Y/N/NA | Findings”)
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey700),
        children: [
          _th('No'),
          _th('Check description'),
          _th('Y/N/NA'),
          _th('Findings'),
        ],
      ),
    );

    int globalNo = 1;

    for (final sec in sections) {
      final secTitle = (sec.titleEn ?? sec.titlePt).trim();

      // Linha de "secção" (tipo "6 Hub" no template)
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tc('', bold: true),
            _tc(secTitle, bold: true),
            _tc(''),
            _tc(''),
          ],
        ),
      );

      // occurrences desta secção (por key)
      final secKey = sec.id.toUpperCase();
      final secOcc = occBySection[secKey] ?? const [];

      // Para já: findings da secção = lista das descriptions (cada uma numa linha)
      final findingsText = secOcc.isEmpty
          ? ''
          : secOcc.map((o) => '- ${o.description}').join('\n');

      for (final item in sec.items) {
        final desc = (item.textEn ?? item.textPt).trim();

        rows.add(
          pw.TableRow(
            children: [
              _tc(globalNo.toString(), centered: true),
              _tc(desc),
              _tc('',
                  centered:
                      true), // se no futuro guardares Y/N/NA, preenche aqui
              _tc(findingsText),
            ],
          ),
        );

        globalNo++;
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(3.2),
        2: pw.FixedColumnWidth(48),
        3: pw.FlexColumnWidth(2.5),
      },
      children: rows,
    );
  }

  static pw.Widget _th(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tc(String text,
      {bool centered = false, bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: centered ? pw.Alignment.center : pw.Alignment.topLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year.toString().substring(2)}';
  }
}
