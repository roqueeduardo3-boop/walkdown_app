import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:walkdown_app/models.dart';
import 'package:walkdown_app/database.dart';
import 'package:intl/intl.dart';

class ExcelApiService {
  static const String baseUrl = 'https://edrwalkdown.pythonanywhere.com';

  // Função auxiliar para converter imagem em Base64 a partir do path
  static Future<String?> _imageToBase64(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      final bytes = await File(imagePath).readAsBytes();
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

        // Se tem fotos, converte a primeira para Base64 (usa path String)
        if (occ.photos.isNotEmpty) {
          try {
            photoBase64 = await _imageToBase64(occ.photos[0]);
          } catch (e) {
            print('Erro ao converter foto: $e');
          }
        }

        occurrencesWithImages.add({
          'position': occ.location,
          'observation': occ.description,
          'imageBase64': photoBase64,
        });
      }

      final payload = {
        'projectName': walkdown.projectInfo.projectName,
        'siteNumber': walkdown.projectInfo.road,
        'towerNumber': walkdown.projectInfo.towerNumber,
        'supervisorName': walkdown.projectInfo.supervisorName,
        'date': DateFormat('dd.MM.yy').format(walkdown.projectInfo.date),
        'occurrences': occurrencesWithImages,
      };

      print('📡 Fazendo request...');
      print('📦 Tamanho do payload: ${jsonEncode(payload).length} bytes');

      final response = await http
          .post(
            Uri.parse('$baseUrl/generate-excel'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'Walkdown_${walkdown.projectInfo.towerNumber}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('✅ Excel gerado: $filePath');
        return filePath;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          'Erro no servidor: ${error['error'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Erro ao gerar Excel: $e');
      rethrow;
    }
  }
}
