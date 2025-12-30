import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalkdownDatabase {
  WalkdownDatabase._privateConstructor();
  static final WalkdownDatabase instance =
      WalkdownDatabase._privateConstructor();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  // 🔥 RESET DB (1x só!)
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'walkdowns.db');
    await deleteDatabase(path);
    print('🗑️ DB APAGADA!');
  }

  // ========== CRIAÇÃO E UPGRADE DA BASE DE DADOS ==========
  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'walkdowns.db');

    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE walkdowns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_name TEXT NOT NULL,
            project_number TEXT NOT NULL,
            supervisor_name TEXT NOT NULL,
            road TEXT NOT NULL,
            tower_number TEXT NOT NULL,
            date TEXT NOT NULL,
            tower_type INTEGER NOT NULL,
            turbine_name TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            firestore_id TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE checklist_answers (
            walkdown_id INTEGER NOT NULL,
            item_id TEXT NOT NULL,
            answer TEXT NOT NULL,
            PRIMARY KEY (walkdown_id, item_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE occurrences (
            id TEXT PRIMARY KEY,
            walkdown_id INTEGER NOT NULL,
            location TEXT NOT NULL,
            description TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE occurrence_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            occurrence_id TEXT NOT NULL,
            photo_path TEXT NOT NULL,
            FOREIGN KEY (occurrence_id) REFERENCES occurrences(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE walkdowns ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0',
          );
        }

        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS occurrence_photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              occurrence_id TEXT NOT NULL,
              photo_path TEXT NOT NULL,
              FOREIGN KEY (occurrence_id) REFERENCES occurrences(id) ON DELETE CASCADE
            )
          ''');
        }

        if (oldVersion < 7) {
          await db
              .execute('ALTER TABLE walkdowns ADD COLUMN firestore_id TEXT');
        }
      },
    );
  }

  // ========== OPERAÇÕES COM WALKDOWNS ==========
  Future<void> markWalkdownCompleted(int walkdownId) async {
    final db = await database;
    await db.update(
      'walkdowns',
      {'is_completed': 1},
      where: 'id = ?',
      whereArgs: [walkdownId],
    );
  }

  Future<List<WalkdownData>> getAllWalkdowns() async {
    final db = await database;
    final maps = await db.query('walkdowns', orderBy: 'date DESC');

    final List<WalkdownData> walkdowns = [];

    for (final map in maps) {
      final walkdownData = WalkdownData.fromMap(map);

      if (walkdownData.id != null) {
        final occs = await getOccurrencesForWalkdown(walkdownData.id!);
        walkdowns.add(walkdownData.copyWith(occurrences: occs));
      } else {
        walkdowns.add(walkdownData);
      }
    }

    return walkdowns;
  }

  Future<int> insertWalkdown(WalkdownData data) async {
    final db = await database;
    return await db.insert(
      'walkdowns',
      {
        'project_name': data.projectInfo.projectName,
        'project_number': data.projectInfo.projectNumber,
        'supervisor_name': data.projectInfo.supervisorName,
        'road': data.projectInfo.road,
        'tower_number': data.projectInfo.towerNumber,
        'date': data.projectInfo.date.toIso8601String(),
        'turbine_name': data.turbineName,
        'tower_type': data.towerType.index,
        'is_completed': data.isCompleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWalkdown(int id) async {
    final db = await database;
    await db.delete('walkdowns', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ ADICIONA AQUI (logo após deleteWalkdown)
  /// Limpa TODOS os dados locais (para logout)
  Future<void> clearAllData() async {
    final db = await database;

    print('🗑️ Limpando todas as tabelas...');

    await db.delete('occurrence_photos');
    await db.delete('occurrences');
    await db.delete('checklist_answers');
    await db.delete('walkdowns');

    print('✅ Base de dados local limpa');
  }

  // ========== OPERAÇÕES COM OCORRÊNCIAS ==========
  Future<void> insertOccurrence(Occurrence occ, int walkdownId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert('occurrences', {
        'id': occ.id,
        'walkdown_id': walkdownId,
        'location': occ.location,
        'description': occ.description,
        'created_at': occ.createdAt.toIso8601String(),
      });

      for (final photoPath in occ.photos) {
        await txn.insert('occurrence_photos', {
          'occurrence_id': occ.id,
          'photo_path': photoPath,
        });
      }
    });
  }

  Future<void> updateOccurrence(Occurrence occ, int walkdownId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'occurrences',
        {
          'location': occ.location,
          'description': occ.description,
          'created_at': occ.createdAt.toIso8601String(),
        },
        where: 'id = ? AND walkdown_id = ?',
        whereArgs: [occ.id, walkdownId],
      );

      await txn.delete(
        'occurrence_photos',
        where: 'occurrence_id = ?',
        whereArgs: [occ.id],
      );

      for (final photoPath in occ.photos) {
        await txn.insert('occurrence_photos', {
          'occurrence_id': occ.id,
          'photo_path': photoPath,
        });
      }
    });
  }

  Future<List<Occurrence>> getOccurrencesForWalkdown(int walkdownId) async {
    final db = await database;

    final occurrenceMaps = await db.query(
      'occurrences',
      where: 'walkdown_id = ?',
      whereArgs: [walkdownId],
      orderBy: 'created_at ASC',
    );

    final List<Occurrence> occurrences = [];

    for (final map in occurrenceMaps) {
      final photoMaps = await db.query(
        'occurrence_photos',
        where: 'occurrence_id = ?',
        whereArgs: [map['id']],
      );

      final photos = photoMaps.map((p) => p['photo_path'] as String).toList();

      occurrences.add(
        Occurrence(
          id: map['id'] as String,
          walkdownId: map['walkdown_id'] as int,
          location: map['location'] as String,
          description: map['description'] as String,
          createdAt: DateTime.parse(map['created_at'] as String),
          photos: photos,
        ),
      );
    }

    return occurrences;
  }

  Future<void> deleteOccurrence(String occurrenceId) async {
    final db = await database;
    await db.delete('occurrences', where: 'id = ?', whereArgs: [occurrenceId]);
  }

  // ========== OPERAÇÕES COM CHECKLIST ==========
  Future<void> saveChecklistAnswer(
    int walkdownId,
    String itemId,
    String answer,
  ) async {
    final db = await database;

    print(
        '🔵 SAVING: walkdownId=$walkdownId, itemId=$itemId, answer=$answer'); // ← ADICIONA

    await db.insert(
      'checklist_answers',
      {
        'walkdown_id': walkdownId,
        'item_id': itemId,
        'answer': answer,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ SAVED!'); // ← ADICIONA
  }

  Future<Map<String, String>> getChecklistAnswers(int walkdownId) async {
    final db = await database;
    final maps = await db.query(
      'checklist_answers',
      where: 'walkdown_id = ?',
      whereArgs: [walkdownId],
    );

    return {
      for (final map in maps) map['item_id'] as String: map['answer'] as String,
    };
  }

  // ========== SINCRONIZAÇÃO COM FIRESTORE ==========
  static final _firestore = FirebaseFirestore.instance;

  /// Guarda um walkdown no Firestore (PUSH)
  Future<void> saveWalkdownToFirestore(dynamic walkdown) async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;

    final docId =
        walkdown.firestoreId ?? _firestore.collection('walkdowns').doc().id;

    final nowIso = DateTime.now().toIso8601String();

    final data = {
      'project_name': walkdown.projectInfo.projectName,
      'project_number': walkdown.projectInfo.projectNumber,
      'supervisor_name': walkdown.projectInfo.supervisorName,
      'road': walkdown.projectInfo.road,
      'tower_number': walkdown.projectInfo.towerNumber,
      'date': walkdown.projectInfo.date.toIso8601String(),
      'tower_type': walkdown.towerType.name,
      'created_at': walkdown.firestoreId == null
          ? nowIso
          : walkdown.projectInfo.date.toIso8601String(),
      'updated_at': nowIso,
      'ownerUid': user?.uid,
    };

    await _firestore
        .collection('walkdowns')
        .doc(docId)
        .set(data, SetOptions(merge: true));

    // Atualizar firestore_id local se for novo
    if (walkdown.id != null && walkdown.firestoreId == null) {
      await db.update(
        'walkdowns',
        {'firestore_id': docId},
        where: 'id = ?',
        whereArgs: [walkdown.id],
      );
    }

    // Sincronizar ocorrências E checklist deste walkdown
    if (walkdown.id != null) {
      await _syncOccurrencesUp(
        localWalkdownId: walkdown.id!,
        firestoreDocId: docId,
      );

      await _syncChecklistUp(
        localWalkdownId: walkdown.id!,
        firestoreDocId: docId,
      );
    }
  }

  /// Sincroniza walkdowns locais que ainda não têm firestoreId
  Future<int> syncNewWalkdownsToFirestore() async {
    print('🚀 INICIANDO SYNC...');
    final all = await getAllWalkdowns();
    final toSend = all.where((w) => w.firestoreId == null).toList();

    print('📊 Encontrados ${toSend.length} walkdowns para enviar');

    if (toSend.isEmpty) {
      print('ℹ️ Nenhum walkdown novo para sync');
      return 0;
    }

    for (final w in toSend) {
      print('📤 Tentando sync: ${w.projectInfo.projectName}');
      try {
        await saveWalkdownToFirestore(w);
        print('✅ ${w.projectInfo.projectName} enviado!');
      } catch (e) {
        print('❌ ERRO no ${w.projectInfo.projectName}: $e');
      }
    }

    print('🏁 SYNC FINALIZADO');
    return toSend.length;
  }

  // ========== SYNC OCCURRENCES ==========

  /// Envia ocorrências de um walkdown para o Firestore (PUSH) COM FOTOS
  Future<void> _syncOccurrencesUp({
    required int localWalkdownId,
    required String firestoreDocId,
  }) async {
    print(
        '🔼 SYNC OCC UP for walkdown $localWalkdownId → docId=$firestoreDocId');
    final db = await database;

    final occMaps = await db.query(
      'occurrences',
      where: 'walkdown_id = ?',
      whereArgs: [localWalkdownId],
      orderBy: 'created_at ASC',
    );
    print('   Found ${occMaps.length} occurrences in SQLite');

    final occCollRef = _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('occurrences');

    final oldSnapshot = await occCollRef.get();
    for (final doc in oldSnapshot.docs) {
      await doc.reference.delete();
    }

    for (final occ in occMaps) {
      final occId = occ['id'] as String;

      // ✅ BUSCAR FOTOS DESTA OCCURRENCE
      final photoMaps = await db.query(
        'occurrence_photos',
        where: 'occurrence_id = ?',
        whereArgs: [occId],
      );

      List<String> photoPaths =
          photoMaps.map((p) => p['photo_path'] as String).toList();

      print('   Occurrence $occId tem ${photoPaths.length} fotos');

      await occCollRef.doc(occId).set({
        'id': occId,
        'walkdown_id': localWalkdownId,
        'location': occ['location'],
        'description': occ['description'],
        'created_at': occ['created_at'],
        'photos': photoPaths, // ✅ ADICIONAR FOTOS
      });
    }
    print('   ✅ Synced ${occMaps.length} occurrences UP (com fotos)');
  }

  /// 🔥 FORÇA sync de UM walkdown específico (checklist + occurrences)
  Future<void> forceSyncWalkdown(int localWalkdownId) async {
    print('🔥 FORÇANDO SYNC do walkdown $localWalkdownId...');

    final db = await database;
    final walkdowns = await db.query(
      'walkdowns',
      where: 'id = ?',
      whereArgs: [localWalkdownId],
      limit: 1,
    );

    if (walkdowns.isEmpty) {
      print('❌ Walkdown não encontrado!');
      return;
    }

    final firestoreId = walkdowns.first['firestore_id'] as String?;

    if (firestoreId == null) {
      print('❌ Walkdown não tem firestore_id!');
      return;
    }

    print('   📤 Syncing checklist...');
    await _syncChecklistUp(
      localWalkdownId: localWalkdownId,
      firestoreDocId: firestoreId,
    );

    print('   📤 Syncing occurrences...');
    await _syncOccurrencesUp(
      localWalkdownId: localWalkdownId,
      firestoreDocId: firestoreId,
    );

    print('✅ SYNC COMPLETO!');
  }

  /// Baixa ocorrências de um walkdown do Firestore (PULL) COM FOTOS
  Future<void> _pullOccurrencesDown({
    required int localWalkdownId,
    required String firestoreDocId,
  }) async {
    print(
        '🔽 PULL OCC DOWN for localId=$localWalkdownId ← docId=$firestoreDocId');
    final db = await database;

    final occSnapshot = await _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('occurrences')
        .orderBy('created_at')
        .get();

    print('   Found ${occSnapshot.docs.length} occurrences in Firestore');

    await db.transaction((txn) async {
      final oldOccs = await txn.query(
        'occurrences',
        where: 'walkdown_id = ?',
        whereArgs: [localWalkdownId],
      );

      for (final occ in oldOccs) {
        final occId = occ['id'] as String;
        await txn.delete(
          'occurrence_photos',
          where: 'occurrence_id = ?',
          whereArgs: [occId],
        );
      }

      await txn.delete(
        'occurrences',
        where: 'walkdown_id = ?',
        whereArgs: [localWalkdownId],
      );

      for (final doc in occSnapshot.docs) {
        final data = doc.data();
        final occId = data['id'] as String? ?? doc.id;

        await txn.insert('occurrences', {
          'id': occId,
          'walkdown_id': localWalkdownId,
          'location': data['location'] as String? ?? '',
          'description': data['description'] as String? ?? '',
          'created_at':
              data['created_at'] as String? ?? DateTime.now().toIso8601String(),
        });

        // ✅ BAIXAR FOTOS
        final photos = data['photos'] as List<dynamic>? ?? [];
        for (final photoPath in photos) {
          await txn.insert('occurrence_photos', {
            'occurrence_id': occId,
            'photo_path': photoPath as String,
          });
        }

        print('   Occurrence $occId: ${photos.length} fotos baixadas');
      }
    });

    print(
        '   ✅ Inserted ${occSnapshot.docs.length} occurrences into SQLite (com fotos)');
  }

  // ========== SYNC CHECKLIST ==========

  /// Envia respostas da checklist para o Firestore (PUSH)
  Future<void> _syncChecklistUp({
    required int localWalkdownId,
    required String firestoreDocId,
  }) async {
    print(
        '🔼 SYNC CHECKLIST UP for walkdown $localWalkdownId → docId=$firestoreDocId');
    final db = await database;

    final answerMaps = await db.query(
      'checklist_answers',
      where: 'walkdown_id = ?',
      whereArgs: [localWalkdownId],
    );
    print('   Found ${answerMaps.length} checklist answers in SQLite');

    final checklistCollRef = _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('checklist_answers');

    final oldSnapshot = await checklistCollRef.get();
    for (final doc in oldSnapshot.docs) {
      await doc.reference.delete();
    }

    for (final answer in answerMaps) {
      final itemId = answer['item_id'] as String;

      await checklistCollRef.doc(itemId).set({
        'item_id': itemId,
        'answer': answer['answer'],
        'walkdown_id': localWalkdownId,
      });
    }
    print('   ✅ Synced ${answerMaps.length} checklist answers UP');
  }

  /// Baixa respostas da checklist do Firestore (PULL)
  Future<void> _pullChecklistDown({
    required int localWalkdownId,
    required String firestoreDocId,
  }) async {
    print(
        '🔽 PULL CHECKLIST DOWN for localId=$localWalkdownId ← docId=$firestoreDocId');
    final db = await database;

    final checklistSnapshot = await _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('checklist_answers')
        .get();

    print(
        '   Found ${checklistSnapshot.docs.length} checklist answers in Firestore');

    await db.delete(
      'checklist_answers',
      where: 'walkdown_id = ?',
      whereArgs: [localWalkdownId],
    );

    for (final doc in checklistSnapshot.docs) {
      final data = doc.data();
      final itemId = data['item_id'] as String? ?? doc.id;
      final answer = data['answer'] as String? ?? '';

      await db.insert('checklist_answers', {
        'walkdown_id': localWalkdownId,
        'item_id': itemId,
        'answer': answer,
      });
    }

    print(
        '   ✅ Inserted ${checklistSnapshot.docs.length} checklist answers into SQLite');
  }

  // ========== PULL WALKDOWNS ==========

  /// Baixa todos os walkdowns do Firestore DO USER ATUAL (PULL)
  Future<int> pullWalkdownsFromFirestore() async {
    print('🔽 PULLING WALKDOWNS FROM FIRESTORE...');
    final db = await database;

    // ✅ Obter user autenticado
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User não autenticado');
      return 0;
    }

    print('   User: ${user.email} (${user.uid})');

    // ✅ Filtrar por ownerUid
    final snapshot = await _firestore
        .collection('walkdowns')
        .where('ownerUid', isEqualTo: user.uid)
        .get();

    print(
        '   Found ${snapshot.docs.length} walkdowns in Firestore para este user');

    int insertedOrUpdated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final firestoreId = doc.id;
      final projectName = data['project_name'] as String? ?? '';
      final projectNumber = data['project_number'] as String? ?? '';
      final supervisorName = data['supervisor_name'] as String? ?? '';
      final road = data['road'] as String? ?? '';
      final towerNumber = data['tower_number'] as String? ?? '';
      final dateStr =
          data['date'] as String? ?? DateTime.now().toIso8601String();
      final towerTypeName = data['tower_type'] as String? ?? 'fourSections';

      final existing = await db.query(
        'walkdowns',
        where: 'firestore_id = ?',
        whereArgs: [firestoreId],
        limit: 1,
      );

      final mapToSave = {
        'project_name': projectName,
        'project_number': projectNumber,
        'supervisor_name': supervisorName,
        'road': road,
        'tower_number': towerNumber,
        'date': dateStr,
        'tower_type': TowerType.values
            .indexWhere((t) => t.name == towerTypeName)
            .clamp(0, TowerType.values.length - 1),
        'turbine_name': '',
        'is_completed': 0,
        'firestore_id': firestoreId,
      };

      int localId;

      if (existing.isEmpty) {
        localId = await db.insert('walkdowns', mapToSave);
      } else {
        localId = existing.first['id'] as int;
        await db.update(
          'walkdowns',
          mapToSave,
          where: 'id = ?',
          whereArgs: [localId],
        );
      }

      // Baixar ocorrências E checklist deste walkdown
      await _pullOccurrencesDown(
        localWalkdownId: localId,
        firestoreDocId: firestoreId,
      );

      await _pullChecklistDown(
        localWalkdownId: localId,
        firestoreDocId: firestoreId,
      );

      insertedOrUpdated++;
    }

    print('✅ PULL COMPLETE: $insertedOrUpdated walkdowns synced\n');
    return insertedOrUpdated;
  }

  // 🔥 COUNT UNSYNCED - SIMPLES E RÁPIDO
  Future<int> countUnsyncedWalkdowns() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM walkdowns WHERE firestore_id IS NULL');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
