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
    _db = null; // ← Força recriar na próxima chamada
  }

// ========== CRIAÇÃO E UPGRADE DA BASE DE DADOS ==========
  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'walkdowns.db');

    return openDatabase(
      path,
      version: 10, // ✅ Versão 10
      onCreate: (db, version) async {
        // Criação INICIAL (instalação limpa)
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
            firestore_id TEXT,
            needs_sync INTEGER NOT NULL DEFAULT 1
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
            created_at TEXT NOT NULL,
            check_item_id TEXT
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

        await _createChecklistTemplateTables(db);
        await _seedChecklistTemplateIfNeeded(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Upgrading DB from v$oldVersion to v$newVersion');

        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE walkdowns ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0',
          );
          print('✅ v5: is_completed adicionado');
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
          print('✅ v6: occurrence_photos criada');
        }

        if (oldVersion < 7) {
          await db
              .execute('ALTER TABLE walkdowns ADD COLUMN firestore_id TEXT');
          print('✅ v7: firestore_id adicionado');
        }

        if (oldVersion < 8) {
          print('🔄 Migration v7→v8: Adicionando firestore_id...');

          // OCCURRENCES
          try {
            await db.execute(
                'ALTER TABLE occurrences ADD COLUMN firestore_id TEXT');
            print('✅ occurrences.firestore_id adicionado');
          } catch (e) {
            print('⚠️ occurrences já tem firestore_id: $e');
          }

          // CHECKLIST_ANSWERS
          try {
            await db.execute(
                'ALTER TABLE checklist_answers ADD COLUMN firestore_id TEXT');
            print('✅ checklist_answers.firestore_id adicionado');
          } catch (e) {
            print('⚠️ checklist_answers já tem firestore_id: $e');
          }

          // NEEDS_SYNC (walkdowns)
          try {
            await db.execute(
                'ALTER TABLE walkdowns ADD COLUMN needs_sync INTEGER NOT NULL DEFAULT 1');
            print('✅ walkdowns.needs_sync adicionado');
          } catch (e) {
            print('⚠️ walkdowns já tem needs_sync: $e');
          }
        }

        if (oldVersion < 9) {
          print('🔄 Migration v8→v9: Adicionando check_item_id...');

          try {
            await db.execute(
                'ALTER TABLE occurrences ADD COLUMN check_item_id TEXT');
            print('✅ occurrences.check_item_id adicionado');
          } catch (e) {
            print('⚠️ occurrences já tem check_item_id: $e');
          }
        }

        if (oldVersion < 10) {
          print(
              '🔄 Migration v9→v10: Criando template editável da checklist...');
          await _createChecklistTemplateTables(db);
          await _seedChecklistTemplateIfNeeded(db);
        }
      },
    );
  }

  Future<void> _createChecklistTemplateTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_sections (
        id TEXT PRIMARY KEY,
        title_pt TEXT NOT NULL,
        title_en TEXT,
        tower_requirement TEXT NOT NULL DEFAULT 'all',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_items (
        id TEXT PRIMARY KEY,
        section_id TEXT NOT NULL,
        text_pt TEXT NOT NULL,
        text_en TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (section_id) REFERENCES checklist_sections(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _seedChecklistTemplateIfNeeded(DatabaseExecutor db) async {
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM checklist_sections',
    );
    final existingCount = Sqflite.firstIntValue(countResult) ?? 0;
    if (existingCount > 0) {
      return;
    }

    final defaultSections = _defaultChecklistTemplateSections();

    for (final section in defaultSections) {
      await db.insert('checklist_sections', {
        'id': section.id,
        'title_pt': section.titlePt,
        'title_en': section.titleEn,
        'tower_requirement': section.towerRequirement.storageValue,
        'sort_order': section.sortOrder,
      });

      for (final item in section.items) {
        await db.insert('checklist_items', {
          'id': item.id,
          'section_id': section.id,
          'text_pt': item.textPt,
          'text_en': item.textEn,
          'sort_order': item.sortOrder,
        });
      }
    }
  }

  List<ChecklistSection> _defaultChecklistTemplateSections() {
    final fourSectionDefaults = buildChecklistForWalkdown(
      _templateWalkdown(TowerType.fourSections),
    );
    final fiveSectionDefaults = buildChecklistForWalkdown(
      _templateWalkdown(TowerType.fiveSections),
    );

    final merged = <ChecklistSection>[];
    final sectionIndexById = <String, int>{};

    for (final section in fourSectionDefaults) {
      final items = <ChecklistItem>[];
      for (var itemIndex = 0; itemIndex < section.items.length; itemIndex++) {
        final item = section.items[itemIndex];
        items.add(item.copyWith(sortOrder: itemIndex));
      }

      final normalized = section.copyWith(
        sortOrder: merged.length,
        towerRequirement: ChecklistTowerRequirement.all,
        items: items,
      );

      sectionIndexById[normalized.id] = merged.length;
      merged.add(normalized);
    }

    for (final section in fiveSectionDefaults) {
      final existingIndex = sectionIndexById[section.id];

      if (existingIndex == null) {
        final items = <ChecklistItem>[];
        for (var itemIndex = 0; itemIndex < section.items.length; itemIndex++) {
          final item = section.items[itemIndex];
          items.add(item.copyWith(sortOrder: itemIndex));
        }

        final normalized = section.copyWith(
          sortOrder: merged.length,
          towerRequirement: ChecklistTowerRequirement.fiveSections,
          items: items,
        );

        sectionIndexById[normalized.id] = merged.length;
        merged.add(normalized);
        continue;
      }

      final existingSection = merged[existingIndex];
      final existingItems = existingSection.items.toList();
      final existingItemIds = existingItems.map((item) => item.id).toSet();

      for (final item in section.items) {
        if (existingItemIds.add(item.id)) {
          existingItems.add(item.copyWith(sortOrder: existingItems.length));
        }
      }

      merged[existingIndex] = existingSection.copyWith(items: existingItems);
    }

    return merged;
  }

  WalkdownData _templateWalkdown(TowerType towerType) {
    return WalkdownData(
      projectInfo: ProjectInfo(
        projectName: '',
        projectNumber: '',
        supervisorName: '',
        road: '',
        towerNumber: '',
        date: DateTime(2000),
      ),
      occurrences: const [],
      towerType: towerType,
      turbineName: '',
    );
  }
// ========== OPERAÇÕES COM WALKDOWNS ==========

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
        'firestore_id': data.firestoreId,
        'needs_sync': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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

  Future<void> deleteWalkdown(int id) async {
    final db = await database;
    String? firestoreId;

    await db.transaction((txn) async {
      final walkdownRows = await txn.query(
        'walkdowns',
        columns: ['firestore_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (walkdownRows.isEmpty) {
        throw StateError('Walkdown $id não encontrado para apagar.');
      }

      firestoreId = walkdownRows.first['firestore_id'] as String?;

      await txn.delete(
        'occurrence_photos',
        where:
            'occurrence_id IN (SELECT id FROM occurrences WHERE walkdown_id = ?)',
        whereArgs: [id],
      );

      await txn.delete(
        'occurrences',
        where: 'walkdown_id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'checklist_answers',
        where: 'walkdown_id = ?',
        whereArgs: [id],
      );

      final deletedRows = await txn.delete(
        'walkdowns',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (deletedRows == 0) {
        throw StateError('Walkdown $id não foi apagado da base de dados.');
      }
    });

    if (firestoreId != null && firestoreId!.isNotEmpty) {
      try {
        await _firestore.collection('walkdowns').doc(firestoreId).delete();
      } catch (e) {
        print('⚠️ Falha ao apagar walkdown $id do Firestore: $e');
      }
    }
  }

  Future<void> clearAllData() async {
    final db = await database;

    await db.delete('occurrence_photos');
    await db.delete('occurrences');
    await db.delete('checklist_answers');
    await db.delete('walkdowns');
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
        'check_item_id': occ.checkItemId,
      });

      for (final photoPath in occ.photos) {
        await txn.insert('occurrence_photos', {
          'occurrence_id': occ.id,
          'photo_path': photoPath,
        });
      }
    });

    await db.update(
      'walkdowns',
      {'needs_sync': 1},
      where: 'id = ?',
      whereArgs: [walkdownId],
    );
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
          'check_item_id': occ.checkItemId,
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

    await db.update(
      'walkdowns',
      {'needs_sync': 1},
      where: 'id = ?',
      whereArgs: [walkdownId],
    );
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
          checkItemId: map['check_item_id'] as String?,
        ),
      );
    }

    return occurrences;
  }

  /// 🔥 CONTA ocorrências por walkdown (RÁPIDO!)
  Future<int> countOccurrencesForWalkdown(int walkdownId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM occurrences WHERE walkdown_id = ?',
      [walkdownId],
    );

    final count = result.isNotEmpty ? result.first['count'] as int : 0;
    print('🗄️ DB REAL: walkdown $walkdownId tem $count occurrences');

    return count;
  }

  // ========== OPERAÇÕES COM CHECKLIST ==========
  Future<void> saveChecklistAnswer(
    int walkdownId,
    String itemId,
    String answer,
  ) async {
    final db = await database;

    print('🔵 SAVING: walkdownId=$walkdownId, itemId=$itemId, answer=$answer');

    await db.insert(
      'checklist_answers',
      {
        'walkdown_id': walkdownId,
        'item_id': itemId,
        'answer': answer,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ SAVED!');
    // ✅ MARCA walkdown como pendente
    await db.update(
      'walkdowns',
      {'needs_sync': 1},
      where: 'id = ?',
      whereArgs: [walkdownId],
    );
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

  Future<List<ChecklistSection>> getChecklistSections({
    TowerType? towerType,
    bool includeEmptySections = false,
  }) async {
    final db = await database;
    await _seedChecklistTemplateIfNeeded(db);

    final sectionMaps = await db.query(
      'checklist_sections',
      orderBy: 'sort_order ASC, title_pt COLLATE NOCASE ASC',
    );

    final itemMaps = await db.query(
      'checklist_items',
      orderBy: 'sort_order ASC, text_pt COLLATE NOCASE ASC',
    );

    final itemsBySection = <String, List<ChecklistItem>>{};
    for (final itemMap in itemMaps) {
      final sectionId = itemMap['section_id'] as String;
      itemsBySection.putIfAbsent(sectionId, () => []).add(
            ChecklistItem(
              id: itemMap['id'] as String,
              textPt: itemMap['text_pt'] as String? ?? '',
              textEn: itemMap['text_en'] as String?,
              sortOrder: itemMap['sort_order'] as int? ?? 0,
            ),
          );
    }

    final sections = <ChecklistSection>[];
    for (final sectionMap in sectionMaps) {
      final requirement = ChecklistTowerRequirementX.fromStorageValue(
        sectionMap['tower_requirement'] as String?,
      );

      if (towerType != null && !requirement.appliesTo(towerType)) {
        continue;
      }

      final sectionId = sectionMap['id'] as String;
      final items = itemsBySection[sectionId] ?? const <ChecklistItem>[];

      if (!includeEmptySections && items.isEmpty) {
        continue;
      }

      sections.add(
        ChecklistSection(
          id: sectionId,
          titlePt: sectionMap['title_pt'] as String? ?? sectionId,
          titleEn: sectionMap['title_en'] as String?,
          towerRequirement: requirement,
          sortOrder: sectionMap['sort_order'] as int? ?? 0,
          items: items,
        ),
      );
    }

    return sections;
  }

  Future<List<ChecklistSection>> getChecklistSectionsForWalkdown(
    WalkdownData walkdown,
  ) {
    return getChecklistSections(towerType: walkdown.towerType);
  }

  Future<void> upsertChecklistSection(ChecklistSection section) async {
    final db = await database;
    await _seedChecklistTemplateIfNeeded(db);

    await db.insert(
      'checklist_sections',
      {
        'id': section.id,
        'title_pt': section.titlePt,
        'title_en': section.titleEn,
        'tower_requirement': section.towerRequirement.storageValue,
        'sort_order': section.sortOrder,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertChecklistItem({
    required String id,
    required String sectionId,
    required String textPt,
    String? textEn,
    required int sortOrder,
  }) async {
    final db = await database;
    await _seedChecklistTemplateIfNeeded(db);

    await db.insert(
      'checklist_items',
      {
        'id': id,
        'section_id': sectionId,
        'text_pt': textPt,
        'text_en': textEn,
        'sort_order': sortOrder,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteChecklistItem(String itemId) async {
    final db = await database;
    await db.delete(
      'checklist_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteChecklistSection(String sectionId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'checklist_items',
        where: 'section_id = ?',
        whereArgs: [sectionId],
      );
      await txn.delete(
        'checklist_sections',
        where: 'id = ?',
        whereArgs: [sectionId],
      );
    });
  }

  // ========== SINCRONIZAÇÃO COM FIRESTORE ========
  static final _firestore = FirebaseFirestore.instance;

  /// Guarda um walkdown no Firestore (PUSH)
  Future<void> saveWalkdownToFirestore(dynamic walkdown) async {
    final db = await database;
    final user = FirebaseAuth.instance.currentUser;

    // ✅ ADICIONA ESTES LOGS
    print('🔐 User atual: ${user?.email}');
    print('🔐 User UID: ${user?.uid}');
    print('🔐 User autenticado: ${user != null}');

    if (user == null) {
      print('❌ ERRO: Usuário não autenticado!');
      return;
    }

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
      'tower_type': walkdown.towerType.index,
      'created_at': walkdown.firestoreId == null
          ? nowIso
          : walkdown.projectInfo.date.toIso8601String(),
      'updated_at': nowIso,
      'ownerUid': user.uid,
    };

    await _firestore
        .collection('walkdowns')
        .doc(docId)
        .set(data, SetOptions(merge: true));

    // Atualizar firestore_id local se for novo E marcar como sincronizado
    if (walkdown.id != null) {
      await db.update(
        'walkdowns',
        {
          'firestore_id': docId,
          'needs_sync': 0, // ✅ Marca como sincronizado
        },
        where: 'id = ?',
        whereArgs: [walkdown.id],
      );
      print('✅ Walkdown ${walkdown.id} → firestore_id=$docId, needs_sync=0');
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

  /// Sincroniza walkdowns com needs_sync = 1
  Future<int> syncNewWalkdownsToFirestore() async {
    print('🚀 INICIANDO SYNC...');

    final db = await database;

    final maps = await db.query(
      'walkdowns',
      where: 'needs_sync = ?',
      whereArgs: [1],
    );

    print('📊 Encontrados ${maps.length} walkdowns com needs_sync=1');

    if (maps.isEmpty) {
      print('ℹ️ Nenhum walkdown pendente para sync');
      return 0;
    }

    int syncedCount = 0;
    const int maxConcurrent = 3;

    // Particiona a lista em grupos de até 3
    for (var i = 0; i < maps.length; i += maxConcurrent) {
      final batch = maps.skip(i).take(maxConcurrent).toList();

      await Future.wait(
        batch.map((map) async {
          final walkdown = WalkdownData.fromMap(map);

          print(
              '📤 Sync (batch): ${walkdown.projectInfo.projectName} (ID=${walkdown.id})');

          try {
            await saveWalkdownToFirestore(walkdown);
            syncedCount++;
            print('   ✅ ${walkdown.projectInfo.projectName} sincronizado!');
          } catch (e) {
            print('   ❌ ERRO no ${walkdown.projectInfo.projectName}: $e');
          }
        }),
      );
    }

    print('🏁 SYNC FINALIZADO: $syncedCount/${maps.length} sincronizados');
    return syncedCount;
  }

  /// Envia ocorrências de um walkdown para o Firestore com WRITEBATCH (1 chamada única)
  Future<void> _syncOccurrencesUp({
    required int localWalkdownId,
    required String firestoreDocId,
  }) async {
    print(
        '🔼 SYNC OCC UP (BATCH) for walkdown $localWalkdownId → docId=$firestoreDocId');
    final db = await database;

    final occMaps = await db.query(
      'occurrences',
      where: 'walkdown_id = ?',
      whereArgs: [localWalkdownId],
      orderBy: 'created_at ASC',
    );
    print('   📊 Found ${occMaps.length} occurrences in SQLite');

    if (occMaps.isEmpty) {
      print('   ✅ No occurrences to sync');
      return;
    }

    final occCollRef = _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('occurrences');

    // 🔥 WRITEBATCH - 1 única chamada para TODAS as occurrences!
    final batch = _firestore.batch();

    // Apagar existentes (batch delete)
    final oldSnapshot = await occCollRef.get();
    for (final doc in oldSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Adicionar novas (batch set)
    for (final occ in occMaps) {
      final occId = occ['id'] as String;

      // Buscar fotos desta occurrence
      final photoMaps = await db.query(
        'occurrence_photos',
        where: 'occurrence_id = ?',
        whereArgs: [occId],
      );

      List<String> photoPaths =
          photoMaps.map((p) => p['photo_path'] as String).toList();

      print('   📤 Occurrence $occId: ${photoPaths.length} fotos');

      batch.set(occCollRef.doc(occId), {
        'id': occId,
        'walkdown_id': localWalkdownId,
        'location': occ['location'],
        'description': occ['description'],
        'created_at': occ['created_at'],
        'photos': photoPaths,
        'check_item_id': occ['check_item_id'], // ✅ NOVO
      });
    }

    // 🔥 EXECUTAR BATCH
    await batch.commit();

    print(
        '   ✅ BATCH COMMIT: ${occMaps.length} occurrences + ${oldSnapshot.docs.length} deletes (1 chamada única)');
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
    final db = await database;

    print('📥 PULL OCC DOWN localId=$localWalkdownId - docId=$firestoreDocId');

    final occSnapshot = await _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('occurrences')
        .orderBy('created_at')
        .get();

    print('   Found ${occSnapshot.docs.length} occurrences in Firestore');

    await db.transaction((txn) async {
      // 🔥 LIMPA TUDO ANTES (ORDEM CERTA!)
      await txn.delete('occurrence_photos',
          where:
              'occurrence_id IN (SELECT id FROM occurrences WHERE walkdown_id = ?)',
          whereArgs: [localWalkdownId]);
      await txn.delete('occurrences',
          where: 'walkdown_id = ?', whereArgs: [localWalkdownId]);

      // Insere FRESH do Firestore
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
          'check_item_id': data['check_item_id'] as String?, // ✅ NOVO
        });

        // ✅ INSERE FOTOS
        final photos = data['photos'] as List<dynamic>? ?? [];
        for (final photoPath in photos) {
          await txn.insert('occurrence_photos', {
            'occurrence_id': occId,
            'photo_path': photoPath as String,
          });
        }

        print('   📥 Occurrence $occId: ${photos.length} fotos');
      }
    });

    print(
        '✅ PULL COMPLETE: ${occSnapshot.docs.length} occurrences synced SQLite');
  }

  // ========== SYNC CHECKLIST ==========

  /// Envia respostas da checklist para o Firestore com WRITEBATCH (1 chamada única)
  Future<void> _syncChecklistUp({
    required int localWalkdownId,
    required String firestoreDocId,
  }) async {
    print(
        '🔼 SYNC CHECKLIST UP (BATCH) for walkdown $localWalkdownId → docId=$firestoreDocId');
    final db = await database;

    final answerMaps = await db.query(
      'checklist_answers',
      where: 'walkdown_id = ?',
      whereArgs: [localWalkdownId],
    );
    print('   📊 Found ${answerMaps.length} checklist answers in SQLite');

    if (answerMaps.isEmpty) {
      print('   ✅ No checklist answers to sync');
      return;
    }

    final checklistCollRef = _firestore
        .collection('walkdowns')
        .doc(firestoreDocId)
        .collection('checklist_answers');

    // 🔥 WRITEBATCH para checklist
    final batch = _firestore.batch();

    // Apagar existentes
    final oldSnapshot = await checklistCollRef.get();
    for (final doc in oldSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Adicionar novas
    for (final answer in answerMaps) {
      final itemId = answer['item_id'] as String;

      batch.set(checklistCollRef.doc(itemId), {
        'item_id': itemId,
        'answer': answer['answer'],
        'walkdown_id': localWalkdownId,
      });
    }

    // 🔥 EXECUTAR BATCH
    await batch.commit();

    print(
        '   ✅ BATCH CHECKLIST COMMIT: ${answerMaps.length} answers + ${oldSnapshot.docs.length} deletes (1 chamada única)');
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

  /// Baixa todos os walkdowns do Firestore DO USER ATUAL (PULL) - ✅ CORRIGIDO!
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
      final projectNumber = data['project_number']?.toString() ?? '';
      final supervisorName = data['supervisor_name']?.toString() ?? '';
      final road = data['road']?.toString() ?? '';
      final towerNumber = data['tower_number']?.toString() ?? '';
      final dateStr =
          data['date'] as String? ?? DateTime.now().toIso8601String();

      // 🔥 FIX CRÍTICO: tower_type int do Firestore → int para SQLite
      final towerTypeIndex = (data['tower_type'] as num?)?.toInt() ?? 0;

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
        'tower_type': towerTypeIndex, // ✅ int → int (correto!)
        'turbine_name': '',
        'is_completed': 0,
        'firestore_id': firestoreId,
      };

      int? localId;

      if (existing.isEmpty) {
        localId = await db.insert('walkdowns', mapToSave);
        print('✅ INSERT novo: $localId');

        // 🔥 PULL occurrences e checklist deste walkdown
        await _pullOccurrencesDown(
            localWalkdownId: localId, firestoreDocId: firestoreId);
        await _pullChecklistDown(
            localWalkdownId: localId, firestoreDocId: firestoreId);
      } else {
        localId = existing.first['id'] as int?;
        await db.update(
          'walkdowns',
          mapToSave,
          where: 'id = ?',
          whereArgs: [localId!],
        );
        print('✅ UPDATE existente: $localId');

        // 🔥 PULL occurrences e checklist deste walkdown
        await _pullOccurrencesDown(
            localWalkdownId: localId, firestoreDocId: firestoreId);
        await _pullChecklistDown(
            localWalkdownId: localId, firestoreDocId: firestoreId);
      }

      insertedOrUpdated++;
    }

    print('✅ PULL COMPLETE: $insertedOrUpdated walkdowns synced');
    return insertedOrUpdated;
  }

  Future<int> countUnsyncedWalkdowns() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM walkdowns WHERE needs_sync = 1',
    );

    final count = Sqflite.firstIntValue(result) ?? 0;
    print('📊 Walkdowns pendentes: $count');
    return count;
  }

  Future<void> markWalkdownCompleted(int walkdownId) async {
    final db = await database;
    await db.update(
      'walkdowns',
      {'is_completed': 1, 'needs_sync': 1},
      where: 'id = ?',
      whereArgs: [walkdownId],
    );
  }
}
