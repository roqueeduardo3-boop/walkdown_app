import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:walkdown_app/models.dart';
import 'package:walkdown_app/database.dart';
import 'package:walkdown_app/services/firebase_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';
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
    sheet.showGridlines = false; // ✅ Desliga gridlines
    sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.portrait;

    // ✅ STYLES SEM BORDAS (bordas aplicadas depois)
    final styleTopGrey = workbook.styles.add('TopGrey');
    styleTopGrey.backColor = '#E6E6E6';
    styleTopGrey.fontColor = '#000000';
    styleTopGrey.bold = true;
    styleTopGrey.hAlign = xlsio.HAlignType.center;
    styleTopGrey.vAlign = xlsio.VAlignType.center;

    final styleInfoGrey = workbook.styles.add('InfoGrey');
    styleInfoGrey.backColor = '#E6E6E6';
    styleInfoGrey.fontColor = '#000000';
    styleInfoGrey.bold = true;
    styleInfoGrey.hAlign = xlsio.HAlignType.left;
    styleInfoGrey.vAlign = xlsio.VAlignType.center;

    final styleValueGrey = workbook.styles.add('ValueGrey');
    styleValueGrey.backColor = '#E6E6E6';
    styleValueGrey.fontColor = '#000000';
    styleValueGrey.bold = false;
    styleValueGrey.hAlign = xlsio.HAlignType.center;
    styleValueGrey.vAlign = xlsio.VAlignType.center;

    final headerStyle = workbook.styles.add('TableHeader');
    headerStyle.backColor = '#76E3FF';
    headerStyle.fontColor = '#000000';
    headerStyle.bold = true;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    final styleCell = workbook.styles.add('Cell');
    styleCell.fontColor = '#000000';
    styleCell.hAlign = xlsio.HAlignType.center;
    styleCell.vAlign = xlsio.VAlignType.center;
    styleCell.wrapText = true;

    final separatorWhiteStyle = workbook.styles.add('SeparatorWhite');
    separatorWhiteStyle.backColor = '#FFFFFF';
    separatorWhiteStyle.fontColor = '#FFFFFF';
    separatorWhiteStyle.wrapText = false;

    // Larguras das colunas
    sheet.getRangeByIndex(1, 1).columnWidth = 3.64;
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

    // LINHA 1
    sheet.getRangeByIndex(1, 1).rowHeight = 20.5;

    _mergeAndSet(sheet, 1, 1, 1, 2, 'Project:', styleTopGrey);
    _mergeAndSet(
        sheet, 1, 3, 1, 4, walkdown.projectInfo.projectNumber, styleTopGrey);
    _mergeAndSet(sheet, 1, 5, 1, 6, 'Site:', styleTopGrey);
    _mergeAndSet(
        sheet, 1, 7, 1, 9, walkdown.projectInfo.projectName, styleTopGrey);

    // Logo
    _mergeWithStyle(sheet, 1, 10, 3, 12, styleTopGrey);
    try {
      final logoData = await rootBundle.load('assets/logo_2ws.png');
      final logoBytes = logoData.buffer.asUint8List();
      final xlsio.Picture logo = sheet.pictures.addStream(1, 10, logoBytes);
      logo.height = 63;
      logo.width = 190;
    } catch (e) {
      print('⚠️ Logo: $e');
    }

    // LINHA 2 (separator)
    sheet.getRangeByIndex(2, 1).rowHeight = 5.15;
    _mergeWithStyle(sheet, 2, 1, 2, 9, styleTopGrey);

    // LINHA 3
    sheet.getRangeByIndex(3, 1).rowHeight = 21.0;
    _setCellWithStyle(sheet, 3, 1, 'Road', styleInfoGrey);
    _mergeAndSet(sheet, 3, 2, 3, 3, walkdown.projectInfo.road, styleValueGrey);
    _setCellWithStyle(sheet, 3, 4, 'Tower:', styleInfoGrey);
    _setCellWithStyle(
        sheet, 3, 5, walkdown.projectInfo.towerNumber, styleValueGrey);
    _setCellWithStyle(sheet, 3, 6, 'S.SUP:', styleInfoGrey);
    _setCellWithStyle(
        sheet, 3, 7, walkdown.projectInfo.supervisorName, styleValueGrey);
    _setCellWithStyle(sheet, 3, 8, 'Date:', styleInfoGrey);
    _setCellWithStyle(
        sheet,
        3,
        9,
        DateFormat('dd.MM.yy').format(walkdown.projectInfo.date),
        styleValueGrey);

    // Caixa grande 1: A1:I1
    _applyOuterBorder(sheet, 1, 1, 1, 9);

// Caixa grande 2: A3:I3
    _applyOuterBorder(sheet, 3, 1, 3, 9);

// Divisórias internas verticais (na linha 3):
// entre C|D  => right border da coluna C (3)
    sheet.getRangeByIndex(3, 3).cellStyle.borders.right.lineStyle =
        xlsio.LineStyle.medium;
    sheet.getRangeByIndex(3, 3).cellStyle.borders.right.color = '#000000';

// entre D|E  => right border da coluna D (4)
    sheet.getRangeByIndex(3, 4).cellStyle.borders.right.lineStyle =
        xlsio.LineStyle.medium;
    sheet.getRangeByIndex(3, 4).cellStyle.borders.right.color = '#000000';

// entre E|F  => right border da coluna E (5)
    sheet.getRangeByIndex(3, 5).cellStyle.borders.right.lineStyle =
        xlsio.LineStyle.medium;
    sheet.getRangeByIndex(3, 5).cellStyle.borders.right.color = '#000000';

// entre G|H  => right border da coluna G (7)
    sheet.getRangeByIndex(3, 7).cellStyle.borders.right.lineStyle =
        xlsio.LineStyle.medium;
    sheet.getRangeByIndex(3, 7).cellStyle.borders.right.color = '#000000';

    // LINHA 4 (separator)
    sheet.getRangeByIndex(4, 1).rowHeight = 5.15;
    _mergeWithStyle(sheet, 4, 1, 4, 12, styleTopGrey);

    // LINHA 5 - HEADER
    sheet.getRangeByIndex(5, 1).rowHeight = 15.0;
    _setCellWithStyle(sheet, 5, 1, 'N.', headerStyle);
    _setCellWithStyle(sheet, 5, 2, 'Pos:', headerStyle);
    _mergeAndSet(sheet, 5, 3, 5, 6, 'Observation:', headerStyle);
    _setCellWithStyle(sheet, 5, 7, 'Before:', headerStyle);
    _mergeAndSet(sheet, 5, 8, 5, 9, 'After:', headerStyle);
    _setCellWithStyle(sheet, 5, 10, 'Y/N', headerStyle);
    _mergeAndSet(sheet, 5, 11, 5, 12, 'Observation:', headerStyle);

    // LINHA 6 (separator)
    sheet.getRangeByIndex(6, 1).rowHeight = 5.15;
    _mergeWithStyle(sheet, 6, 1, 6, 12, styleTopGrey);

    // OCORRÊNCIAS
    int currentRow = 7;

    for (int i = 0; i < occurrencesWithLocalPhotos.length; i++) {
      final occ = occurrencesWithLocalPhotos[i];
      sheet.getRangeByIndex(currentRow, 1).rowHeight = 70.0;

      _setCellWithStyle(sheet, currentRow, 1, (i + 1).toString(), styleCell);

      final positionPt = _extractPosition(occ.location ?? '');
      final positionEn = await _translatePtToEnHybrid(positionPt);
      _setCellWithStyle(sheet, currentRow, 2, positionEn, styleCell);

      final descriptionEn = await _translatePtToEnHybrid(occ.description ?? '');
      _mergeAndSet(
          sheet, currentRow, 3, currentRow, 6, descriptionEn, styleCell);

      _applyCellStyle(sheet, currentRow, 7, styleCell);
      if (occ.photos.isNotEmpty && occ.photos[0].isNotEmpty) {
        try {
          final photoFile = File(occ.photos[0]);
          if (await photoFile.exists()) {
            final bytes = await photoFile.readAsBytes();
            final xlsio.Picture picture =
                sheet.pictures.addStream(currentRow, 7, bytes);
            picture.height = 94;
            picture.width = 111;
          }
        } catch (e) {
          print('   ❌ Foto #${i + 1}: $e');
        }
      }

      _mergeWithStyle(sheet, currentRow, 8, currentRow, 9, styleCell);
      _setCellWithStyle(sheet, currentRow, 10, '', styleCell);
      _mergeWithStyle(sheet, currentRow, 11, currentRow, 12, styleCell);

      currentRow++;
    }

    // Linhas vazias
    while (currentRow <= 26) {
      sheet.getRangeByIndex(currentRow, 1).rowHeight = 90.0;

      _applyCellStyle(sheet, currentRow, 1, styleCell);
      _applyCellStyle(sheet, currentRow, 2, styleCell);
      _mergeWithStyle(sheet, currentRow, 3, currentRow, 6, styleCell);
      _applyCellStyle(sheet, currentRow, 7, styleCell);
      _mergeWithStyle(sheet, currentRow, 8, currentRow, 9, styleCell);
      _applyCellStyle(sheet, currentRow, 10, styleCell);
      _mergeWithStyle(sheet, currentRow, 11, currentRow, 12, styleCell);

      currentRow++;
    }

// ✅ APLICA BORDAS DEPOIS DE TUDO

// Header (rows 1..3): NÃO usar borders.all por célula
// porque já estás a desenhar as caixas A1:I1 e A3:I3 com _applyOuterBorder.
// Além disso, vais limpar a row 2 no fim com _applyWhiteGapRow.
// _applyBordersToRange(sheet, 1, 1, 3, 12); // Header completo

// Logo block (J1:L3) com caixa própria (opcional mas recomendado)
    _applyOuterBorder(sheet, 1, 10, 3, 12);

// Separators 4 e 6: podes deixar, porque depois limpas com _applyWhiteGapRow
    _applyBordersToRange(sheet, 4, 1, 4, 12); // Separator
    _applyBordersToRange(sheet, 6, 1, 6, 12); // Separator

// Table header row 5: NÃO usar borders.all (tem merges). Faz por blocos:
    _applyOuterBorder(sheet, 5, 1, 5, 1); // N.
    _applyOuterBorder(sheet, 5, 2, 5, 2); // Pos
    _applyOuterBorder(sheet, 5, 3, 5, 6); // Observation (merged)
    _applyOuterBorder(sheet, 5, 7, 5, 7); // Before
    _applyOuterBorder(sheet, 5, 8, 5, 9); // After (merged)
    _applyOuterBorder(sheet, 5, 10, 5, 10); // Y/N
    _applyOuterBorder(sheet, 5, 11, 5, 12); // Observation (merged)

    // Linhas de dados
    for (int row = 7; row <= 26; row++) {
      for (int col = 1; col <= 12; col++) {
        _applySingleBorder(sheet, row, col);
      }
    }
    // Gaps limpos (branco puro, sem linhas) — aplicar no FIM
// Row 2: só A..I (porque J..L é o logo)
    _applyWhiteGapRow(sheet, 2, 1, 9, 5.15, separatorWhiteStyle);

// Row 4 e 6: A..L
    _applyWhiteGapRow(sheet, 4, 1, 12, 5.15, separatorWhiteStyle);
    _applyWhiteGapRow(sheet, 6, 1, 12, 5.15, separatorWhiteStyle);

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

  // Helpers
  static Future<String> _translatePtToEnHybrid(String textPt) async {
    final cleaned = textPt.trim();
    if (cleaned.isEmpty) return textPt;

    try {
      final translation =
          await _onlineTranslator.translate(cleaned, from: 'pt', to: 'en');
      final out = translation.text.trim();
      if (out.isNotEmpty) return out;
      return cleaned;
    } catch (_) {
      try {
        return Translator.translate(cleaned);
      } catch (_) {
        return cleaned;
      }
    }
  }

  static String _extractPosition(String location) {
    if (location.contains(' – ')) return location.split(' – ')[0].trim();
    if (location.contains(' - ')) return location.split(' - ')[0].trim();
    if (location.contains(' → ')) return location.split(' → ')[0].trim();
    return location;
  }

  // ✅ Merge e aplica estilo SEM bordas
  static void _mergeWithStyle(
    xlsio.Worksheet sheet,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
    xlsio.Style style,
  ) {
    final range = sheet.getRangeByIndex(startRow, startCol, endRow, endCol);
    range.merge();
    range.cellStyle.backColor = style.backColor;
    range.cellStyle.fontColor = style.fontColor;
    range.cellStyle.bold = style.bold;
    range.cellStyle.hAlign = style.hAlign;
    range.cellStyle.vAlign = style.vAlign;
    range.cellStyle.wrapText = style.wrapText;
  }

  // ✅ Merge, set texto e aplica estilo
  static void _mergeAndSet(
    xlsio.Worksheet sheet,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
    String text,
    xlsio.Style style,
  ) {
    _mergeWithStyle(sheet, startRow, startCol, endRow, endCol, style);
    sheet.getRangeByIndex(startRow, startCol).setText(text);
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

  static void _applyCellStyle(
    xlsio.Worksheet sheet,
    int row,
    int col,
    xlsio.Style style,
  ) {
    final cell = sheet.getRangeByIndex(row, col);
    cell.cellStyle.backColor = style.backColor;
    cell.cellStyle.fontColor = style.fontColor;
    cell.cellStyle.hAlign = style.hAlign;
    cell.cellStyle.vAlign = style.vAlign;
    cell.cellStyle.wrapText = style.wrapText;
  }

  static void _applyOuterBorder(
    xlsio.Worksheet sheet,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
  ) {
    // top
    for (int c = startCol; c <= endCol; c++) {
      final cell = sheet.getRangeByIndex(startRow, c);
      cell.cellStyle.borders.top.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.top.color = '#000000';
    }
    // bottom
    for (int c = startCol; c <= endCol; c++) {
      final cell = sheet.getRangeByIndex(endRow, c);
      cell.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.bottom.color = '#000000';
    }
    // left
    for (int r = startRow; r <= endRow; r++) {
      final cell = sheet.getRangeByIndex(r, startCol);
      cell.cellStyle.borders.left.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.left.color = '#000000';
    }
    // right
    for (int r = startRow; r <= endRow; r++) {
      final cell = sheet.getRangeByIndex(r, endCol);
      cell.cellStyle.borders.right.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.right.color = '#000000';
    }
  }

  // ✅ Aplica bordas em TODAS as células do range
  static void _applyBordersToRange(
    xlsio.Worksheet sheet,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
  ) {
    for (int row = startRow; row <= endRow; row++) {
      for (int col = startCol; col <= endCol; col++) {
        _applySingleBorder(sheet, row, col);
      }
    }
  }

  // ✅ Aplica borda grossa em célula única
  static void _applySingleBorder(xlsio.Worksheet sheet, int row, int col) {
    final cell = sheet.getRangeByIndex(row, col);
    cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
    cell.cellStyle.borders.all.color = '#000000';
  }

  static void _applyWhiteGapRow(
    xlsio.Worksheet sheet,
    int gapRow,
    int startCol,
    int endCol,
    double rowHeight,
    xlsio.Style whiteStyle,
  ) {
    sheet.getRangeByIndex(gapRow, 1).rowHeight = rowHeight;

    for (int c = startCol; c <= endCol; c++) {
      // Linha do gap
      final gapCell = sheet.getRangeByIndex(gapRow, c);
      gapCell.cellStyle = whiteStyle;
      gapCell.cellStyle.borders.top.lineStyle = xlsio.LineStyle.none;
      gapCell.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.none;
      gapCell.cellStyle.borders.left.lineStyle = xlsio.LineStyle.none;
      gapCell.cellStyle.borders.right.lineStyle = xlsio.LineStyle.none;

      // Linha de cima: remove o que “entra” no gap
      final topCell = sheet.getRangeByIndex(gapRow - 1, c);
      topCell.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.none;
      topCell.cellStyle.borders.left.lineStyle = xlsio.LineStyle.none;
      topCell.cellStyle.borders.right.lineStyle = xlsio.LineStyle.none;

      // Linha de baixo: remove o que “entra” no gap
      final bottomCell = sheet.getRangeByIndex(gapRow + 1, c);
      bottomCell.cellStyle.borders.top.lineStyle = xlsio.LineStyle.none;
      bottomCell.cellStyle.borders.left.lineStyle = xlsio.LineStyle.none;
      bottomCell.cellStyle.borders.right.lineStyle = xlsio.LineStyle.none;
    }
  }
}
