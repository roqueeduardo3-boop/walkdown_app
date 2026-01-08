import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
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
        print('❌ Erro: Ficheiro não existe: $imagePath');
        return null;
      }

      // 🔥 NO WINDOWS: Usa compressão nativa do Dart (mais confiável)
      if (Platform.isWindows || Platform.isLinux) {
        return await _compressWithDartImage(imagePath);
      }

      // 📱 ANDROID/iOS: Usa flutter_image_compress (mais rápido)
      return await _compressWithFlutterCompress(imagePath);
    } catch (e) {
      print('❌ Erro ao comprimir imagem: $e');
      return null;
    }
  }

  /// Compressão usando flutter_image_compress (Android/iOS)
  static Future<String?> _compressWithFlutterCompress(String imagePath) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = path.basename(imagePath);
      final String targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        print('⚠️ flutter_image_compress retornou null, usando fallback...');
        return await _compressWithDartImage(imagePath);
      }

      await _logCompressionStats(imagePath, compressedFile.path);
      return compressedFile.path;
    } catch (e) {
      print('⚠️ flutter_image_compress falhou: $e');
      print('🔄 Usando fallback (dart image)...');
      return await _compressWithDartImage(imagePath);
    }
  }

  /// Compressão usando biblioteca 'image' do Dart (fallback universal)
  static Future<String?> _compressWithDartImage(String imagePath) async {
    try {
      print('🖼️ Comprimindo com dart:image...');

      // Ler imagem
      final File imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();

      // Decodificar imagem
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        print('❌ Falha ao decodificar imagem');
        return null;
      }

      // Redimensionar se necessário
      if (image.width > maxWidth || image.height > maxHeight) {
        print('📏 Redimensionando de ${image.width}x${image.height}...');

        // Calcular novas dimensões mantendo aspect ratio
        double scale = 1.0;
        if (image.width > image.height) {
          scale = maxWidth / image.width;
        } else {
          scale = maxHeight / image.height;
        }

        final newWidth = (image.width * scale).round();
        final newHeight = (image.height * scale).round();

        image = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );

        print('   → ${image.width}x${image.height}');
      }

      // Criar ficheiro temporário
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = path.basenameWithoutExtension(imagePath);
      final String targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName.jpg',
      );

      // Comprimir e guardar como JPEG
      final compressedBytes = img.encodeJpg(image, quality: quality);
      final File outputFile = File(targetPath);
      await outputFile.writeAsBytes(compressedBytes);

      await _logCompressionStats(imagePath, targetPath);
      return targetPath;
    } catch (e) {
      print('❌ Erro na compressão dart:image: $e');
      return null;
    }
  }

  /// Mostra estatísticas de compressão
  static Future<void> _logCompressionStats(
    String originalPath,
    String compressedPath,
  ) async {
    try {
      final int originalSize = await File(originalPath).length();
      final int compressedSize = await File(compressedPath).length();
      final double reduction =
          ((originalSize - compressedSize) / originalSize * 100);

      print('✅ Compressão: ${(originalSize / 1024).toStringAsFixed(1)} KB → '
          '${(compressedSize / 1024).toStringAsFixed(1)} KB '
          '(${reduction.toStringAsFixed(1)}% redução)');
    } catch (e) {
      print('⚠️ Erro ao calcular stats: $e');
    }
  }

  /// Comprime múltiplas imagens em paralelo
  static Future<List<String>> compressMultipleImages(
    List<String> imagePaths,
  ) async {
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
