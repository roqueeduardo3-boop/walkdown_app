import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

// para usar a classe Occurrence

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

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'walkdowns.db');

    return openDatabase(
      path,
      version: 6, // versão atual
      onCreate: (db, version) async {
        // Tabela walkdowns
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
      is_completed INTEGER NOT NULL DEFAULT 0
    )
  ''');

        // Tabela checklist_answers
        await db.execute('''
    CREATE TABLE checklist_answers (
      walkdown_id INTEGER NOT NULL,
      item_id TEXT NOT NULL,
      answer TEXT NOT NULL,
      PRIMARY KEY (walkdown_id, item_id)
    )
  ''');

        // Tabela occurrences
        await db.execute('''
    CREATE TABLE occurrences (
      id TEXT PRIMARY KEY,
      walkdown_id INTEGER NOT NULL,
      location TEXT NOT NULL,
      description TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');

        // Tabela occurrence_photos
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
      },
    );
  }

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

    return maps.map((m) {
      DateTime dateValue;
      if (m['date'] is int) {
        dateValue = DateTime.fromMillisecondsSinceEpoch(m['date'] as int);
      } else {
        dateValue = DateTime.parse(m['date'] as String);
      }

      int towerTypeIndex = 0;
      if (m['tower_type'] is int) {
        towerTypeIndex = m['tower_type'] as int;
      } else if (m['tower_type'] is String) {
        towerTypeIndex = int.tryParse(m['tower_type'] as String) ?? 0;
      }

      return WalkdownData(
        id: m['id'] as int?,
        projectInfo: ProjectInfo(
          projectName: m['project_name'] as String? ?? '',
          projectNumber: m['project_number'] as String? ?? '',
          supervisorName: m['supervisor_name'] as String? ?? '',
          road: m['road'] as String? ?? '',
          towerNumber: m['tower_number'] as String? ?? '',
          date: dateValue,
        ),
        occurrences: const [],
        towerType: TowerType.values[towerTypeIndex],
        turbineName: m['turbine_name'] as String? ?? '',
        isCompleted: (m['is_completed'] as int? ?? 0) == 1,
      );
    }).toList();
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

  // Guardar uma ocorrência com fotos (paths)
  Future<void> insertOccurrence(Occurrence occ, int walkdownId) async {
    final db = await database;

    await db.transaction((txn) async {
      // ocorrência
      await txn.insert('occurrences', {
        'id': occ.id,
        'walkdown_id': walkdownId,
        'location': occ.location,
        'description': occ.description,
        'created_at': occ.createdAt.toIso8601String(),
      });

      // fotos (paths)
      for (final photoPath in occ.photos) {
        await txn.insert('occurrence_photos', {
          'occurrence_id': occ.id,
          'photo_path': photoPath,
        });
      }
    });
  }

  // Atualizar ocorrência existente
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

  // Carregar ocorrências de um walkdown
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

      // lista de paths
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

  // Apagar ocorrência (CASCADE apaga fotos)
  Future<void> deleteOccurrence(String occurrenceId) async {
    final db = await database;
    await db.delete('occurrences', where: 'id = ?', whereArgs: [occurrenceId]);
  }

  Future<void> deleteWalkdown(int id) async {
    final db = await database;
    await db.delete('walkdowns', where: 'id = ?', whereArgs: [id]);
  }

  // Guardar ou atualizar resposta
  Future<void> saveChecklistAnswer(
    int walkdownId,
    String itemId,
    String answer,
  ) async {
    final db = await database;
    await db.insert(
      'checklist_answers',
      {
        'walkdown_id': walkdownId,
        'item_id': itemId,
        'answer': answer,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Carregar respostas
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
}
