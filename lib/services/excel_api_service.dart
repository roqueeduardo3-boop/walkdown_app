import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// ✅ ADICIONAR
import 'package:walkdown_app/models.dart';
import 'package:walkdown_app/database.dart';
// ✅ ADICIONAR
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';

class ExcelApiService {
  static const String baseUrl = 'https://edrwalkdown.pythonanywhere.com';
  static const String apiKey = 'WalkdownApp2025!SecureKey#MinhaChavePrivada';

  // Função auxiliar para converter imagem em Base64 a partir do path
  static Future<String?> _imageToBase64(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      // 🔥 SE FOR URL, FAZ DOWNLOAD PRIMEIRO
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        print('📥 Baixando foto de: ${imagePath.substring(0, 80)}...');

        final response = await http.get(Uri.parse(imagePath));
        if (response.statusCode == 200) {
          print('✅ Download OK: ${response.bodyBytes.length} bytes');
          return base64Encode(response.bodyBytes);
        } else {
          print('❌ Erro download: ${response.statusCode}');
          return null;
        }
      }

      // 🔥 SE FOR CAMINHO LOCAL
      final file = File(imagePath);
      if (!await file.exists()) {
        print('⚠️ Imagem não existe: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      print('✅ Leitura local OK: ${bytes.length} bytes');
      return base64Encode(bytes);
    } catch (e) {
      print('❌ Erro ao converter imagem: $e');
      return null;
    }
  }

  /// 🚀 Excel LOCAL (usa os MESMOS dados, mas gera localmente)
  static Future<String> generateExcelLocal(WalkdownData walkdown) async {
    final occurrences =
        await WalkdownDatabase.instance.getOccurrencesForWalkdown(walkdown.id!);

    final excel = Excel.createExcel();
    final sheetName = 'Walkdown ${walkdown.projectInfo.towerNumber}';
    final Sheet sheet = excel[sheetName];

    // Helpers para não repetir boilerplate
    CellValue t(String v) => TextCellValue(v);
    CellValue n(num v) =>
        (v is int) ? IntCellValue(v) : DoubleCellValue(v.toDouble());

    // Headers
    sheet.appendRow([t('Projeto'), t(walkdown.projectInfo.projectName)]);
    sheet.appendRow([t('Estrada'), t(walkdown.projectInfo.road)]);
    sheet.appendRow([t('Torre'), t(walkdown.projectInfo.towerNumber)]);
    sheet.appendRow([t('Supervisor'), t(walkdown.projectInfo.supervisorName)]);
    sheet.appendRow([
      t('Data'),
      t(DateFormat('dd/MM/yy').format(walkdown.projectInfo.date))
    ]);
    sheet.appendRow([t('Total'), n(occurrences.length)]);
    sheet.appendRow([t(''), t('')]); // espaçador

    // Tabela
    sheet.appendRow(
        [t('Posição'), t('Descrição'), t('Foto Firebase (URL/caminho)')]);

    for (final occ in occurrences) {
      final fotoTexto = occ.photos.isEmpty ? 'Sem foto' : occ.photos.join('\n');
      sheet.appendRow([t(occ.location), t(occ.description), t(fotoTexto)]);
    }

    // Salvar
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'Walkdown_${walkdown.projectInfo.towerNumber}_${DateFormat('ddMMyy_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = '${dir.path}/$fileName';

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception(
          'Falha ao gerar bytes do Excel (excel.save() retornou null).');
    }

    await File(filePath).writeAsBytes(bytes);

    print('✅ Excel LOCAL: $filePath');
    return filePath;
  }

  static Future<String> generateExcel(WalkdownData walkdown) async {
    try {
      print('📤 Enviando dados para backend...');

      final occurrences = await WalkdownDatabase.instance
          .getOccurrencesForWalkdown(walkdown.id!);

      print('📊 ${occurrences.length} ocorrências encontradas');
      print('═══════════════════════════════════');
      print('🔍 DADOS QUE VÃO SER ENVIADOS:');
      print('Project Name: ${walkdown.projectInfo.projectName}');
      print('Road: ${walkdown.projectInfo.road}');
      print('Tower: ${walkdown.projectInfo.towerNumber}');
      print('Supervisor: ${walkdown.projectInfo.supervisorName}');
      print('═══════════════════════════════════');

      // Prepara JSON com as occurrences convertidas
      List<Map<String, dynamic>> occurrencesWithImages = [];

      for (var occ in occurrences) {
        print('🔍 Occurrence: ${occ.location}');
        print('   📸 Fotos array: ${occ.photos}');
        print('   📸 Total fotos: ${occ.photos.length}');

        String? photoBase64;

        // Se tem fotos, converte a primeira para Base64
        if (occ.photos.isNotEmpty) {
          print('   ✅ Tem ${occ.photos.length} foto(s)');
          print('   📂 Caminho: ${occ.photos[0]}');

          // Se tem fotos, converte a primeira para Base64
          if (occ.photos.isNotEmpty) {
            try {
              photoBase64 = await _imageToBase64(occ.photos[0]);
              if (photoBase64 != null) {
                print(
                    '   ✅ Foto convertida: ${photoBase64.substring(0, 50)}... (${photoBase64.length} chars)');
              } else {
                print('   ❌ Conversão retornou NULL');
              }
            } catch (e) {
              print('❌ Erro ao converter foto: $e');
            }
          }

          occurrencesWithImages.add({
            'position': occ.location,
            'observation': occ.description,
            'photoUrl': photoBase64 != null
                ? 'data:image/jpeg;base64,$photoBase64'
                : null,
          });
        }
      }

      final payload = {
        'project_name': walkdown.projectInfo.projectName,
        'project_number': walkdown.projectInfo.road,
        'road': walkdown.projectInfo.road,
        'tower_number': walkdown.projectInfo.towerNumber,
        'supervisor_name': walkdown.projectInfo.supervisorName,
        'date': DateFormat('dd.MM.yy').format(walkdown.projectInfo.date),
        'occurrences': occurrencesWithImages,
      };

      print('📡 Fazendo request para: $baseUrl/generate-excel');
      print('📦 Total de occurrences: ${occurrencesWithImages.length}');
      print('📦 Tamanho do payload: ${jsonEncode(payload).length} bytes');

      final response = await http
          .post(
            Uri.parse('$baseUrl/generate-excel'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'X-API-Key': apiKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      print('📨 Status Code: ${response.statusCode}');
      print('📨 Content-Type: ${response.headers['content-type']}');

      // VERIFICAR SE A RESPOSTA É HTML (ERRO)
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html')) {
        print('❌ Servidor retornou HTML em vez de Excel/JSON');
        print('Resposta: ${response.body.substring(0, 500)}...');
        throw Exception(
          'Servidor retornou erro HTML. Verifique se o servidor está online.',
        );
      }

      if (response.statusCode == 200) {
        // Verificar se realmente é um arquivo Excel
        if (!contentType.contains('spreadsheet') &&
            !contentType.contains('excel') &&
            !contentType.contains('octet-stream')) {
          print('⚠️ Content-Type inesperado: $contentType');
        }

        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'Walkdown_${walkdown.projectInfo.towerNumber}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('✅ Excel gerado: $filePath');
        print('📁 Tamanho do arquivo: ${response.bodyBytes.length} bytes');
        return filePath;
      } else {
        // Tentar parsear JSON de erro
        try {
          final error = jsonDecode(response.body);
          throw Exception(
            'Erro no servidor (${response.statusCode}): ${error['error'] ?? 'Erro desconhecido'}',
          );
        } catch (e) {
          // Se não conseguir parsear JSON, mostrar resposta raw
          throw Exception(
            'Erro no servidor (${response.statusCode}): ${response.body.substring(0, 200)}',
          );
        }
      }
    } on http.ClientException catch (e) {
      print('❌ Erro de conexão: $e');
      throw Exception(
        'Erro de conexão com o servidor. Verifique sua internet.',
      );
    } on SocketException catch (e) {
      print('❌ Erro de rede: $e');
      throw Exception(
        'Sem conexão com o servidor. Verifique sua internet.',
      );
    } on FormatException catch (e) {
      print('❌ Erro de formato: $e');
      throw Exception(
        'Servidor retornou resposta inválida. Ele pode estar offline ou com erro.',
      );
    } catch (e) {
      print('❌ Erro ao gerar Excel: $e');
      rethrow;
    }
  }

  // Método auxiliar para testar se o servidor está online
  static Future<bool> checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Servidor offline: $e');
      return false;
    }
  }
}
