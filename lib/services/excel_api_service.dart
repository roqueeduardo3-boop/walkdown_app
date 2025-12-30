import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:walkdown_app/models.dart';
import 'package:walkdown_app/database.dart';
import 'package:intl/intl.dart';

class ExcelApiService {
  static const String baseUrl = 'https://edrwalkdown.pythonanywhere.com';
  static const String apiKey = 'WalkdownApp2025!SecureKey#MinhaChavePrivada';

  // Função auxiliar para converter imagem em Base64 a partir do path
  static Future<String?> _imageToBase64(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('⚠️ Imagem não existe: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('❌ Erro ao converter imagem: $e');
      return null;
    }
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
        String? photoBase64;

        // Se tem fotos, converte a primeira para Base64
        if (occ.photos.isNotEmpty) {
          try {
            photoBase64 = await _imageToBase64(occ.photos[0]);
            if (photoBase64 != null) {
              print('✅ Foto convertida: ${occ.photos[0]}');
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
