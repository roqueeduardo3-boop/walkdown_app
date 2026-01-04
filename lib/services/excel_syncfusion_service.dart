import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:walkdown_app/models.dart';
import 'package:walkdown_app/database.dart';
import 'package:walkdown_app/services/firebase_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';

// ✅ IMPORT DO DICIONÁRIO OFFLINE (ajusta se o path for diferente)
import 'package:walkdown_app/translations.dart';

class ExcelSyncfusionService {
  static final GoogleTranslator _onlineTranslator = GoogleTranslator();

  static Future<String> generateExcelWithEmbeddedImages(
      WalkdownData walkdown) async {
    print('📊 Gerando Excel com template 2WS...');

    final occurrences =
        await WalkdownDatabase.instance.getOccurrencesForWalkdown(walkdown.id!);

    print('📥 Download das fotos...');
    final occurrencesWithLocalPhotos = <Occurrence>[];

    for (final occ in occurrences) {
      final localPhotos = <String>[];

      for (final photoPath in occ.photos) {
        if (photoPath.startsWith('http')) {
          try {
            final localFile =
                await FirebaseStorageService.downloadPhoto(photoPath);
            localPhotos.add(localFile.path);
          } catch (_) {
            localPhotos.add('');
          }
        } else {
          localPhotos.add(photoPath);
        }
      }

      occurrencesWithLocalPhotos.add(
        Occurrence(
          id: occ.id,
          walkdownId: occ.walkdownId,
          location: occ.location,
          description: occ.description,
          createdAt: occ.createdAt,
          photos: localPhotos,
        ),
      );
    }

    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'T';

    // ✅ ORIENTAÇÃO VERTICAL (PORTRAIT)
    sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.portrait;

    // ✅ LARGURAS EXATAS
    sheet.getRangeByIndex(1, 1).columnWidth = 3.60;
    sheet.getRangeByIndex(1, 2).columnWidth = 5.50;
    sheet.getRangeByIndex(1, 3).columnWidth = 2.70;
    sheet.getRangeByIndex(1, 4).columnWidth = 8.0;
    sheet.getRangeByIndex(1, 5).columnWidth = 6.50;
    sheet.getRangeByIndex(1, 6).columnWidth = 5.36;
    sheet.getRangeByIndex(1, 7).columnWidth = 15.18;
    sheet.getRangeByIndex(1, 8).columnWidth = 5.00;
    sheet.getRangeByIndex(1, 9).columnWidth = 9.55;
    sheet.getRangeByIndex(1, 10).columnWidth = 2.91;
    sheet.getRangeByIndex(1, 11).columnWidth = 2.55;
    sheet.getRangeByIndex(1, 12).columnWidth = 19.50;

    // ✅ LINHA 1
    sheet.getRangeByIndex(1, 1).rowHeight = 20.5;

    _mergeCellsWithBorders(sheet, 1, 1, 1, 2);
    _setCell(sheet, 1, 1, 'Project:',
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    _mergeCellsWithBorders(sheet, 1, 3, 1, 4);
    _setCell(sheet, 1, 3, walkdown.projectInfo.projectNumber,
        vAlign: xlsio.VAlignType.center);

    _mergeCellsWithBorders(sheet, 1, 5, 1, 6);
    _setCell(sheet, 1, 5, 'Site: ',
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    _mergeCellsWithBorders(sheet, 1, 7, 1, 9);
    _setCell(sheet, 1, 7, walkdown.projectInfo.projectName,
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    // LOGO
    _mergeCellsWithBorders(sheet, 1, 10, 3, 12);
    try {
      final logoData = await rootBundle.load('assets/logo_2ws.png');
      final logoBytes = logoData.buffer.asUint8List();
      final xlsio.Picture logo = sheet.pictures.addStream(1, 10, logoBytes);
      logo.height = 63;
      logo.width = 190;
    } catch (e) {
      print('⚠️ Logo: $e');
    }

    // ✅ LINHA 2
    sheet.getRangeByIndex(2, 1).rowHeight = 5.15;
    _mergeCellsWithBorders(sheet, 2, 1, 2, 9);

    // ✅ LINHA 3
    sheet.getRangeByIndex(3, 1).rowHeight = 21.0;

    _setCell(sheet, 3, 1, 'Road:  ',
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    _mergeCellsWithBorders(sheet, 3, 2, 3, 3);
    _setCell(sheet, 3, 2, walkdown.projectInfo.road,
        vAlign: xlsio.VAlignType.center);

    _setCell(sheet, 3, 4, 'Tower:  ',
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    _setCell(sheet, 3, 5, walkdown.projectInfo.towerNumber,
        vAlign: xlsio.VAlignType.center);

    _setCell(sheet, 3, 6, 'S.SUP: ',
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    _setCell(sheet, 3, 7, walkdown.projectInfo.supervisorName,
        vAlign: xlsio.VAlignType.center);

    _setCell(sheet, 3, 8, 'Date: ',
        vAlign: xlsio.VAlignType.center, hAlign: xlsio.HAlignType.center);

    _setCell(
        sheet, 3, 9, DateFormat('dd.MM.yy').format(walkdown.projectInfo.date),
        vAlign: xlsio.VAlignType.center);

    // ✅ LINHA 4
    sheet.getRangeByIndex(4, 1).rowHeight = 5.15;
    _mergeCellsWithBorders(sheet, 4, 1, 4, 12);

    // ✅ LINHA 5 - HEADER
    sheet.getRangeByIndex(5, 1).rowHeight = 15.0;

    final headerStyle = workbook.styles.add('TableHeader');
    headerStyle.backColor = '#76E3FF';
    headerStyle.fontColor = '#000000';
    headerStyle.bold = true;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thick;

    _setCellWithStyle(sheet, 5, 1, 'N.', headerStyle);
    _setCellWithStyle(sheet, 5, 2, 'Pos:', headerStyle);

    _mergeCellsWithBorders(sheet, 5, 3, 5, 6);
    _setCellWithStyle(sheet, 5, 3, 'Observation:', headerStyle);

    _setCellWithStyle(sheet, 5, 7, 'Before:', headerStyle);

    _mergeCellsWithBorders(sheet, 5, 8, 5, 9);
    _setCellWithStyle(sheet, 5, 8, 'After:', headerStyle);

    _setCellWithStyle(sheet, 5, 10, 'Y/N', headerStyle);

    _mergeCellsWithBorders(sheet, 5, 11, 5, 12);
    _setCellWithStyle(sheet, 5, 11, 'Observation:', headerStyle);

    // ✅ LINHA 6
    sheet.getRangeByIndex(6, 1).rowHeight = 5.15;
    _mergeCellsWithBorders(sheet, 6, 1, 6, 12);

    // ✅ OCORRÊNCIAS
    int currentRow = 7;

    for (int i = 0; i < occurrencesWithLocalPhotos.length; i++) {
      final occ = occurrencesWithLocalPhotos[i];

      sheet.getRangeByIndex(currentRow, 1).rowHeight = 70.0;

      // N.
      _setCell(sheet, currentRow, 1, (i + 1).toString(),
          hAlign: xlsio.HAlignType.center, vAlign: xlsio.VAlignType.center);

      // Pos: (traduz)
      final positionPt = _extractPosition(occ.location ?? '');
      final positionEn = await _translatePtToEnHybrid(positionPt);
      _setCell(sheet, currentRow, 2, positionEn,
          hAlign: xlsio.HAlignType.center, vAlign: xlsio.VAlignType.center);

      // Observation: (traduz)
      _mergeCellsWithBorders(sheet, currentRow, 3, currentRow, 6);
      final descriptionEn = await _translatePtToEnHybrid(occ.description ?? '');
      _setCell(sheet, currentRow, 3, descriptionEn,
          hAlign: xlsio.HAlignType.center,
          vAlign: xlsio.VAlignType.center,
          wrapText: true);

      // FOTO Before (G)
      if (occ.photos.isNotEmpty && occ.photos[0].isNotEmpty) {
        try {
          final photoFile = File(occ.photos[0]);
          if (await photoFile.exists()) {
            final bytes = await photoFile.readAsBytes();
            final xlsio.Picture picture =
                sheet.pictures.addStream(currentRow, 7, bytes);
            picture.height = 94;
            picture.width = 112;
          }
        } catch (e) {
          print('   ❌ Foto #${i + 1}: $e');
        }
      }
      _addBorder(sheet.getRangeByIndex(currentRow, 7));

      // After:
      _mergeCellsWithBorders(sheet, currentRow, 8, currentRow, 9);

      // Y/N:
      _setCell(sheet, currentRow, 10, '',
          hAlign: xlsio.HAlignType.center, vAlign: xlsio.VAlignType.center);

      // Observation (final):
      _mergeCellsWithBorders(sheet, currentRow, 11, currentRow, 12);

      currentRow++;
    }

    // ✅ LINHAS VAZIAS
    while (currentRow <= 26) {
      sheet.getRangeByIndex(currentRow, 1).rowHeight = 90.0;

      _addBorder(sheet.getRangeByIndex(currentRow, 1));
      _addBorder(sheet.getRangeByIndex(currentRow, 2));

      _mergeCellsWithBorders(sheet, currentRow, 3, currentRow, 6);
      _addBorder(sheet.getRangeByIndex(currentRow, 7));

      _mergeCellsWithBorders(sheet, currentRow, 8, currentRow, 9);
      _addBorder(sheet.getRangeByIndex(currentRow, 10));

      _mergeCellsWithBorders(sheet, currentRow, 11, currentRow, 12);

      currentRow++;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'Walkdown_${walkdown.projectInfo.towerNumber}_${DateFormat('ddMMyy_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = '${directory.path}/$fileName';

    await File(filePath).writeAsBytes(bytes);

    print('✅ Excel: $filePath');
    return filePath;
  }

  // =====================
  // TRADUÇÃO HÍBRIDA
  // =====================

  static Future<String> _translatePtToEnHybrid(String textPt) async {
    final cleaned = textPt.trim();
    if (cleaned.isEmpty) return textPt;

    // 1) tenta online
    try {
      final translation =
          await _onlineTranslator.translate(cleaned, from: 'pt', to: 'en');
      final out = translation.text.trim();
      if (out.isNotEmpty) return out;
      return cleaned;
    } catch (_) {
      // 2) fallback offline: dicionário interno (translations.dart)
      try {
        return Translator.translate(cleaned);
      } catch (_) {
        return cleaned;
      }
    }
  }

  static void _mergeCellsWithBorders(
    xlsio.Worksheet sheet,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
  ) {
    sheet.getRangeByIndex(startRow, startCol, endRow, endCol).merge();

    for (int row = startRow; row <= endRow; row++) {
      for (int col = startCol; col <= endCol; col++) {
        _addBorder(sheet.getRangeByIndex(row, col));
      }
    }
  }

  static void _setCell(
    xlsio.Worksheet sheet,
    int row,
    int col,
    String text, {
    xlsio.HAlignType? hAlign,
    xlsio.VAlignType? vAlign,
    bool wrapText = false,
  }) {
    final cell = sheet.getRangeByIndex(row, col);
    cell.setText(text);

    if (hAlign != null) cell.cellStyle.hAlign = hAlign;
    if (vAlign != null) cell.cellStyle.vAlign = vAlign;
    if (wrapText) cell.cellStyle.wrapText = true;

    _addBorder(cell);
  }

  static void _setCellWithStyle(
    xlsio.Worksheet sheet,
    int row,
    int col,
    String text,
    xlsio.Style style,
  ) {
    final cell = sheet.getRangeByIndex(row, col);
    cell.setText(text);
    cell.cellStyle = style;
  }

  static void _addBorder(xlsio.Range cell) {
    cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thick;
  }

  static String _extractPosition(String location) {
    if (location.contains(' – ')) return location.split(' – ')[0].trim();
    if (location.contains(' - ')) return location.split(' - ')[0].trim();
    if (location.contains(' → ')) return location.split(' → ')[0].trim();
    return location;
  }
}
