import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<User> ensureStorageUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      print('🔐 Storage: Re-auth anonymous...');
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user!;
    }
    print('✅ Storage User: ${user.uid}');
    return user;
  }

  /// Faz upload de uma foto para Firebase Storage e retorna a URL de download
  static Future<String> uploadPhoto({
    required String localPath,
    required int walkdownId,
    required String occurrenceId,
  }) async {
    try {
      final user = await FirebaseStorageService.ensureStorageUser();

      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $localPath');
      }

      // Gerar nome único para o ficheiro
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(localPath);
      final fileName =
          '${user.uid}_w${walkdownId}_${occurrenceId}_$timestamp$extension';

      // Criar referência no Firebase Storage
      final ref = _storage
          .ref()
          .child('walkdowns')
          .child(user.uid)
          .child('walkdown_$walkdownId')
          .child('occurrence_$occurrenceId')
          .child(fileName);

      print('📤 Uploading: $fileName');

      // Upload do ficheiro
      final uploadTask = await ref.putFile(file);

      // Obter URL de download
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('✅ Upload completo: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Erro no upload: $e');
      rethrow;
    }
  }

  /// Faz download de uma foto do Firebase Storage para cache local
  static Future<File> downloadPhoto(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);

      // Criar ficheiro temporário
      final tempDir = Directory.systemTemp;
      final fileName = ref.name;
      final localFile = File('${tempDir.path}/$fileName');

      // Download apenas se não existir em cache
      if (await localFile.exists()) {
        print('✅ Foto em cache: $fileName');
        return localFile;
      }

      print('📥 Downloading: $fileName');
      await ref.writeToFile(localFile);
      print('✅ Download completo: $fileName');

      return localFile;
    } catch (e) {
      print('❌ Erro no download: $e');
      rethrow;
    }
  }

  /// Apaga uma foto do Firebase Storage
  static Future<void> deletePhoto(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('🗑️ Foto apagada: ${ref.name}');
    } catch (e) {
      print('⚠️ Erro ao apagar foto: $e');
    }
  }

  /// Apaga todas as fotos de um walkdown
  static Future<void> deleteWalkdownPhotos(int walkdownId) async {
    try {
      final user = await FirebaseStorageService.ensureStorageUser();

      final ref = _storage
          .ref()
          .child('walkdowns')
          .child(user.uid)
          .child('walkdown_$walkdownId');

      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      for (final prefix in listResult.prefixes) {
        final subList = await prefix.listAll();
        for (final subItem in subList.items) {
          await subItem.delete();
        }
      }

      print('🗑️ Todas as fotos do walkdown $walkdownId apagadas');
    } catch (e) {
      print('⚠️ Erro ao apagar fotos do walkdown: $e');
    }
  }
}
