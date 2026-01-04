import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/firebase_storage_service.dart';

class CacheCleanupService {
  static const String _cacheDirName = 'inspection_cache';
  static const int _maxCacheAgeDays = 7;
  static const int _maxCacheSizeMB = 100;

  /// Diretório principal do cache
  static Future<Directory?> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, _cacheDirName));

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Limpa cache antigo (mais de 7 dias)
  static Future<void> cleanupOldCache() async {
    try {
      final cacheDir = await _cacheDir;
      if (cacheDir == null) return;

      final files = cacheDir.listSync(recursive: true);
      final now = DateTime.now();

      int deletedCount = 0;
      for (final fileEntity in files) {
        if (fileEntity is File && await fileEntity.exists()) {
          final stat = await fileEntity.stat();
          if (now.difference(stat.modified).inDays > _maxCacheAgeDays) {
            await fileEntity.delete();
            deletedCount++;
          }
        }
      }
      print('✅ Cleanup antigo: $deletedCount ficheiros removidos');
    } catch (e) {
      print('⚠️ Erro cleanup antigo: $e');
    }
  }

  /// Limpa cache acima do limite de tamanho
  static Future<void> cleanupLargeCache() async {
    try {
      final cacheDir = await _cacheDir;
      if (cacheDir == null) return;

      // Lista todos os ficheiros e calcula tamanhos
      final List<File> files = [];
      int totalSize = 0;

      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File && await entity.exists()) {
          files.add(entity);
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      final maxSizeBytes = _maxCacheSizeMB * 1024 * 1024;
      if (totalSize <= maxSizeBytes) {
        print(
            '✅ Cache dentro do limite: ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB');
        return;
      }

      // ✅ CORRIGIDO - sort() síncrono
      files.sort((a, b) {
        final statA = a.lastModifiedSync();
        final statB = b.lastModifiedSync();
        return statA.compareTo(statB);
      });

      // Remove ficheiros antigos até atingir limite
      int currentSize = totalSize;
      int deletedCount = 0;
      for (final file in files) {
        if (currentSize <= maxSizeBytes) break;

        final stat = file.statSync();
        file.deleteSync();
        currentSize -= stat.size;
        deletedCount++;
      }

      print(
          '✅ Cleanup grande: $deletedCount ficheiros, agora ${(currentSize / 1024 / 1024).toStringAsFixed(1)}MB');
    } catch (e) {
      print('⚠️ Erro cleanup grande: $e');
    }
  }

  /// Limpa cache LOCAL de um walkdown específico (SEM Firebase)
  static Future<void> clearWalkdownCache(String walkdownId) async {
    if (walkdownId.isEmpty) {
      print('⚠️ walkdownId vazio');
      return;
    }

    try {
      final cacheDir = await _cacheDir;
      if (cacheDir == null) return;

      final walkdownDir = Directory(path.join(cacheDir.path, walkdownId));
      if (await walkdownDir.exists()) {
        await walkdownDir.delete(recursive: true);
        print('🗑️ Cache LOCAL $walkdownId REMOVIDO');
        return;
      }
      print('ℹ️  Cache $walkdownId já não existe');
    } catch (e) {
      print('⚠️ Erro cache $walkdownId: $e');
    }
  }

  /// Tamanho atual do cache em MB
  static Future<double> getCacheSizeMB() async {
    try {
      final cacheDir = await _cacheDir;
      if (cacheDir == null) return 0.0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File && await entity.exists()) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize / 1024 / 1024;
    } catch (e) {
      print('⚠️ Erro calcular cache size: $e');
      return 0.0;
    }
  }

  /// Cleanup completo (usa no startup da app)
  static Future<void> fullCleanup() async {
    print('🧹=== INICIANDO CLEANUP COMPLETO ===');
    await cleanupOldCache();
    await cleanupLargeCache();
    final sizeMB = await getCacheSizeMB();
    print('✅=== CLEANUP CONCLUÍDO: ${sizeMB.toStringAsFixed(1)}MB ===');
  }

  /// Verifica se ficheiro existe no cache
  static Future<bool> hasCachedFile(String walkdownId, String photoName) async {
    final cacheDir = await _cacheDir;
    if (cacheDir == null) return false;

    final filePath = path.join(cacheDir.path, walkdownId, photoName);
    return await File(filePath).exists();
  }
}
