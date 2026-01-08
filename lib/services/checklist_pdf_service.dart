import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';

import '../database.dart';
import '../models.dart';
import '../translations.dart';
import 'package:open_filex/open_filex.dart';

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

  static Future<List<Occurrence>> _translateOccurrences(
    List<Occurrence> occurrences,
  ) async {
    final translated = <Occurrence>[];

    for (final occ in occurrences) {
      final translatedLoc = await _translateToEnglish(occ.location);
      final translatedDesc = await _translateToEnglish(occ.description);

      translated.add(
        Occurrence(
          id: occ.id,
          walkdownId: occ.walkdownId,
          location: translatedLoc,
          description: translatedDesc,
          createdAt: occ.createdAt,
          photos: occ.photos,
          checkItemId: occ.checkItemId,
        ),
      );
    }

    return translated;
  }

  static Future<String> _translateToEnglish(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return text;

    try {
      final translation =
          await _translator.translate(cleaned, from: 'pt', to: 'en');
      final result = translation.text.trim();

      if (result.isNotEmpty) {
        return result;
      }

      return cleaned;
    } catch (e) {
      try {
        return Translator.translate(cleaned);
      } catch (e2) {
        return cleaned;
      }
    }
  }

  static Future<File> generateChecklistPdf({
    required WalkdownData walkdown,
    required List<Occurrence> occurrences,
  }) async {
    await _loadFonts();

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo_2ws.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final sections = buildChecklistForWalkdown(walkdown);

    final pdf = pw.Document();

    final checklistTable = await _buildChecklistTable(
      walkdown: walkdown,
      sections: sections,
      occurrences: occurrences,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
        build: (context) => [
          _buildHeader(
            walkdown: walkdown,
            logo: logoImage,
            projectLabel: 'Project:',
            siteLabel: 'Site:',
            roadLabel: 'Road:',
            towerLabel: 'Tower:',
            supLabel: 'S.SUP:',
            dateLabel: 'Date:',
          ),
          pw.SizedBox(height: 10),
          checklistTable,
        ],
      ),
    );

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
                  pw.Text(
                    walkdown.projectInfo.road,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    towerLabel,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    walkdown.projectInfo.towerNumber,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
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

  static Future<pw.Widget> _buildChecklistTable({
    required WalkdownData walkdown,
    required List<ChecklistSection> sections,
    required List<Occurrence> occurrences,
  }) async {
    final rows = <pw.TableRow>[];

    final answersByItemId =
        await WalkdownDatabase.instance.getChecklistAnswers(walkdown.id!);

    final translatedOccurrences = await _translateOccurrences(occurrences);

    final occurrencesByItemId = <String, List<Occurrence>>{};
    final orphanOccurrences = <Occurrence>[];

    for (final occ in translatedOccurrences) {
      if (occ.checkItemId != null && occ.checkItemId!.isNotEmpty) {
        occurrencesByItemId.putIfAbsent(occ.checkItemId!, () => []).add(occ);
      } else {
        orphanOccurrences.add(occ);
      }
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey700),
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

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tc('', bold: true),
            _tc(secTitle, bold: true),
            _tc(''),
            _tc(''),
          ],
        ),
      );

      for (final item in sec.items) {
        final desc = (item.textEn ?? item.textPt).trim();
        final itemAnswer = answersByItemId[item.id] ?? '';
        final matchingOccs = occurrencesByItemId[item.id] ?? [];

        if (matchingOccs.isEmpty) {
          rows.add(
            pw.TableRow(
              children: [
                _tc(globalNo.toString(), centered: true),
                _tc(desc),
                _tc(itemAnswer, centered: true),
                _tc(''),
              ],
            ),
          );
        } else if (matchingOccs.length == 1) {
          rows.add(
            pw.TableRow(
              children: [
                _tc(globalNo.toString(), centered: true),
                _tc(desc),
                _tc(itemAnswer, centered: true),
                _tc('• ${matchingOccs[0].description}'),
              ],
            ),
          );
        } else {
          for (int i = 0; i < matchingOccs.length; i++) {
            final occ = matchingOccs[i];
            if (i == 0) {
              rows.add(
                pw.TableRow(
                  children: [
                    _tc(globalNo.toString(), centered: true),
                    _tc(desc),
                    _tc(itemAnswer, centered: true),
                    _tc('• ${occ.description}'),
                  ],
                ),
              );
            } else {
              rows.add(
                pw.TableRow(
                  children: [
                    _tc('', centered: true),
                    _tc(''),
                    _tc('', centered: true),
                    _tc('• ${occ.description}'),
                  ],
                ),
              );
            }
          }
        }

        globalNo++;
      }
    }

    if (orphanOccurrences.isNotEmpty) {
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.orange100),
          children: [
            _tc('', bold: true),
            _tc('OTHER FINDINGS', bold: true),
            _tc(''),
            _tc(''),
          ],
        ),
      );

      for (final occ in orphanOccurrences) {
        rows.add(
          pw.TableRow(
            children: [
              _tc(''),
              _tc(occ.location),
              _tc(''),
              _tc('• ${occ.description}'),
            ],
          ),
        );
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

  static pw.Widget _tc(
    String text, {
    bool centered = false,
    bool bold = false,
  }) {
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

  static Future<void> previewChecklistPdf({
    required WalkdownData walkdown,
    required List<Occurrence> occurrences,
  }) async {
    final file = await generateChecklistPdf(
      walkdown: walkdown,
      occurrences: occurrences,
    );

    await OpenFilex.open(file.path);
  }
}
