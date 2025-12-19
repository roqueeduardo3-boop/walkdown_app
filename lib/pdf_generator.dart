import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:translator/translator.dart';
import 'models.dart';
import 'translations.dart';

class PdfGenerator {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static final _translator = GoogleTranslator();

  static Future<void> _loadFonts() async {
    try {
      final regularFontData =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldFontData =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

      _regularFont = pw.Font.ttf(regularFontData);
      _boldFont = pw.Font.ttf(boldFontData);
      print('✅ Fontes carregadas com sucesso');
    } catch (e) {
      print('⚠️ Erro ao carregar fontes: $e');
      _regularFont = pw.Font.helvetica();
      _boldFont = pw.Font.helveticaBold();
    }
  }

  static Future<String> _translateToEnglish(String text) async {
    if (text.trim().isEmpty) return text;

    try {
      final translation = await _translator.translate(
        text,
        from: 'pt',
        to: 'en',
      );
      print('✅ Traduzido: "$text" → "${translation.text}"');
      return translation.text;
    } catch (e) {
      print('⚠️ Erro na tradução online, usando dicionário interno: $e');
      try {
        final local = Translator.translate(text);
        print('✅ Dicionário interno: "$text" → "$local"');
        return local;
      } catch (e2) {
        print('❌ Erro no dicionário interno, a usar texto original: $e2');
        return text;
      }
    }
  }

  static Future<List<Occurrence>> _translateOccurrences(
    List<Occurrence> occurrences,
  ) async {
    final translated = <Occurrence>[];

    for (final occ in occurrences) {
      final translatedLocation = await _translateToEnglish(occ.location);
      final translatedDescription = await _translateToEnglish(occ.description);

      translated.add(
        Occurrence(
          id: occ.id,
          walkdownId: occ.walkdownId,
          location: translatedLocation,
          description: translatedDescription,
          createdAt: occ.createdAt,
          photos: occ.photos,
        ),
      );
    }

    return translated;
  }

  static Future<File> generateWalkdownPdf({
    required WalkdownData walkdown,
    required List<Occurrence> occurrences,
  }) async {
    await _loadFonts();

    print('🔄 Traduzindo ${occurrences.length} ocorrências...');
    final translatedOccurrences = await _translateOccurrences(occurrences);
    print('✅ Tradução concluída!');

    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo_2ws.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('⚠️ Falha ao carregar logo: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
        build: (context) => [
          _buildHeader(walkdown, logoImage),
          pw.SizedBox(height: 10),
          _buildOccurrencesTable(translatedOccurrences),
        ],
      ),
    );

    Directory? directory;

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

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName =
        'walkdown_${walkdown.projectInfo.towerNumber}_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');

    print('📄 PDF path: ${file.path}');
    await file.writeAsBytes(await pdf.save());
    print('✅ PDF criado: ${file.path}');

    if (Platform.isAndroid || Platform.isIOS) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Walkdown PDF - Torre ${walkdown.projectInfo.towerNumber}',
      );
      print('✅ Menu de partilha aberto!');
    }

    return file;
  }

  static pw.Widget _buildHeader(
    WalkdownData walkdown,
    pw.ImageProvider? logo,
  ) {
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
            _buildHeaderCell(
              'Project:',
              walkdown.projectInfo.projectNumber,
            ),
            _buildHeaderCell(
              'Site:',
              walkdown.projectInfo.projectName,
            ),
            pw.Container(
              height: 50,
              padding: pw.EdgeInsets.zero, // sem margem interna
              alignment: pw.Alignment.center,
              child: logo != null
                  ? pw.SizedBox(
                      width: double.infinity, // largura total da célula
                      height: 50, // igual à altura da linha
                      child: pw.Image(
                        logo,
                        fit: pw.BoxFit.contain, // mantém o texto inteiro
                      ),
                    )
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
                    'Road: ',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    walkdown.projectInfo.road,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'Tower: ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  pw.Text(
                    walkdown.projectInfo.towerNumber,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            _buildHeaderCell('S.SUP:', walkdown.projectInfo.supervisorName),
            _buildHeaderCell(
              'Date:',
              _formatDate(walkdown.projectInfo.date),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String label, String value) {
    return pw.Container(
      height: 40,
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildOccurrencesTable(List<Occurrence> occurrences) {
    if (occurrences.isEmpty) {
      return pw.Center(
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Text(
            'No occurrences found',
            style: pw.TextStyle(
              fontSize: 16,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final sorted = List<Occurrence>.from(occurrences)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FixedColumnWidth(50),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FixedColumnWidth(30),
        6: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue),
          children: [
            _buildTableHeader('N.'),
            _buildTableHeader('Pos:'),
            _buildTableHeader('Observation:'),
            _buildTableHeader('Before:'),
            _buildTableHeader('After:'),
            _buildTableHeader('Y/N'),
            _buildTableHeader('Observation:'),
          ],
        ),
        for (int i = 0; i < sorted.length; i++)
          _buildOccurrenceRow(i + 1, sorted[i]),
      ],
    );
  }

  static pw.TableRow _buildOccurrenceRow(int number, Occurrence occ) {
    final position = _extractPosition(occ.location);

    return pw.TableRow(
      children: [
        _buildTableCell(number.toString(), centered: true),
        _buildTableCell(position, centered: true),
        _buildTableCell(occ.description, centered: false),
        _buildPhotosCell(occ.photos),
        _buildEmptyCell(),
        _buildEmptyCell(),
        _buildEmptyCell(),
      ],
    );
  }

  static String _extractPosition(String location) {
    if (location.contains(' – ')) {
      return location.split(' – ')[0].trim();
    }
    if (location.contains(' - ')) {
      return location.split(' - ')[0].trim();
    }
    if (location.contains(' → ')) {
      return location.split(' → ')[0].trim();
    }
    return location;
  }

  static pw.Widget _buildTableCell(String text, {bool centered = false}) {
    return pw.Container(
      height: 40,
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
        maxLines: 10,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildPhotosCell(List<String> photos) {
    if (photos.isEmpty) {
      return pw.Container(
        height: 70,
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(
          '-',
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      alignment: pw.Alignment.center,
      child: pw.Wrap(
        // ou Row, conforme usas
        spacing: 4,
        runSpacing: 4,
        children: photos.take(4).map((photoPath) {
          final file = File(photoPath);
          pw.ImageProvider? imageProvider;
          try {
            final bytes = file.readAsBytesSync();
            imageProvider = pw.MemoryImage(bytes);
          } catch (_) {}

          return pw.SizedBox(
            width: 90, // tamanho do “quadrado”
            height: 70,
            child: imageProvider != null
                ? pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(
                      imageProvider,
                      fit: pw.BoxFit.cover,
                    ),
                  )
                : pw.Center(
                    child: pw.Text('X', style: const pw.TextStyle(fontSize: 8)),
                  ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildEmptyCell() {
    return pw.Container(
      height: 70,
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      color: PdfColors.grey100,
      child: pw.Text(
        '-',
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      height: 40,
      padding: const pw.EdgeInsets.all(4),
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

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year.toString().substring(2)}';
  }

  static Future<void> previewPdf({
    required WalkdownData walkdown,
    required List<Occurrence> occurrences,
  }) async {
    await _loadFonts();

    print('🔄 Traduzindo para preview...');
    final translatedOccurrences = await _translateOccurrences(occurrences);

    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo_2ws.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('⚠️ Não foi possível carregar o logo: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
        build: (context) => [
          _buildHeader(walkdown, logoImage),
          pw.SizedBox(height: 10),
          _buildOccurrencesTable(translatedOccurrences),
        ],
      ),
    );
  }
}
