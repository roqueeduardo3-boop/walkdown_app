import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressionService {
  // Configurações de compressão
  static const int quality = 85; // 85% de qualidade
  static const int maxWidth = 1920; // Full HD
  static const int maxHeight = 1080;

  /// Comprime uma imagem e retorna o caminho do ficheiro comprimido
  static Future<String?> compressImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      // Verifica se o ficheiro existe
      if (!await imageFile.exists()) {
        print('Erro: Ficheiro não existe: $imagePath');
        return null;
      }

      // Diretório temporário para imagem comprimida
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = path.basename(imagePath);
      final String targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      // Comprimir imagem
      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg, // Força JPEG para melhor compressão
      );

      if (compressedFile == null) {
        print('Erro: Falha na compressão da imagem');
        return null;
      }

      // Comparar tamanhos
      final int originalSize = await imageFile.length();
      final int compressedSize = await File(compressedFile.path).length();
      final double reduction =
          ((originalSize - compressedSize) / originalSize * 100);

      print('Compressão: ${(originalSize / 1024).toStringAsFixed(1)} KB → '
          '${(compressedSize / 1024).toStringAsFixed(1)} KB '
          '(${reduction.toStringAsFixed(1)}% redução)');

      return compressedFile.path;
    } catch (e) {
      print('Erro ao comprimir imagem: $e');
      return null;
    }
  }

  /// Comprime múltiplas imagens em paralelo
  static Future<List<String>> compressMultipleImages(
      List<String> imagePaths) async {
    final List<String> compressedPaths = [];

    for (String imagePath in imagePaths) {
      final String? compressed = await compressImage(imagePath);
      if (compressed != null) {
        compressedPaths.add(compressed);
      }
    }

    return compressedPaths;
  }
}
