import 'dart:io'; // needed for Platform.isWindows etc.
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // needed for kIsWeb
import 'package:path/path.dart'; // helps build file paths
import 'package:sqflite/sqflite.dart'; // the SQLite plugin
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // SQLite for Desktop

// ============================================================
// MODEL: Album
//
// A "model" is just a Dart class that represents one row
// in a database table. Think of it like a spreadsheet row.
//
// Our albuns table has these columns:
//   id, nome, descricao, icone, cor, criado_em
// ============================================================
class Album {
  final int? id; // null when not yet saved to DB
  final String nome; // album name, e.g. "Viagem para Paris"
  final String descricao; // optional description
  final String icone; // icon name, e.g. "snowflake", "flight"
  final String cor; // hex color, e.g. "#2E9E50"
  final String criadoEm; // creation date in ISO format

  // "const" constructor = can be created at compile time (slightly faster)
  const Album({
    this.id, // optional — null means "not in DB yet"
    required this.nome, // required = must be provided
    this.descricao = '', // default value = empty string
    this.icone = 'photo_album',
    this.cor = '#2E9E50',
    required this.criadoEm,
  });

  // toMap() converts this object into a Map (like a dictionary).
  // SQLite needs Maps to insert/update rows.
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, // only include id if it exists
    'nome': nome,
    'descricao': descricao,
    'icone': icone,
    'cor': cor,
    'criado_em': criadoEm,
  };

  // factory constructor = a special constructor that returns an Album.
  // fromMap() is the reverse of toMap() — turns a DB row into an Album object.
  // The "?? ''" means: if the value is null, use '' instead (safe fallback).
  factory Album.fromMap(Map<String, dynamic> m) => Album(
    id: m['id'] as int?,
    nome: (m['nome'] as String?) ?? '',
    descricao: (m['descricao'] as String?) ?? '',
    icone: (m['icone'] as String?) ?? 'photo_album',
    cor: (m['cor'] as String?) ?? '#2E9E50',
    criadoEm: (m['criado_em'] as String?) ?? DateTime.now().toIso8601String(),
  );

  // copyWith() returns a NEW Album with some fields changed.
  // Useful for editing — keeps fields you don't change the same.
  Album copyWith({
    String? nome,
    String? descricao,
    String? icone,
    String? cor,
  }) => Album(
    id: id,
    criadoEm: criadoEm,
    nome: nome ?? this.nome,
    descricao: descricao ?? this.descricao,
    icone: icone ?? this.icone,
    cor: cor ?? this.cor,
  );
}

// ============================================================
// MODEL: Registro (a "moment" saved inside an album)
//
// Our registros table columns:
//   id, album_id, titulo, descricao, local, data_hora,
//   humor, tags, album
//
// Photos are stored in a SEPARATE table (fotos) and loaded
// alongside the registro as SQLite BLOB values.
// ============================================================
class Registro {
  final int? id;
  final int? albumId; // which album this belongs to (can be null)
  final String titulo; // e.g. "Pôr do sol na praia"
  final String descricao;
  final String local; // e.g. "Florianópolis"
  final double? latitude;
  final double? longitude;
  final String dataHora; // ISO-8601 date string
  final int humor; // 0=😊 1=😄 2=😐 3=😢 4=😍
  final String tags; // not used for now, kept for future
  final String album; // album name saved here too (for quick display)
  final List<Uint8List> fotos; // image bytes stored entirely in SQLite

  const Registro({
    this.id,
    this.albumId,
    required this.titulo,
    required this.descricao,
    required this.local,
    this.latitude,
    this.longitude,
    required this.dataHora,
    required this.humor,
    required this.tags,
    required this.album,
    this.fotos = const [], // default = no photos
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'album_id': albumId,
    'titulo': titulo,
    'descricao': descricao,
    'local': local,
    'latitude': latitude,
    'longitude': longitude,
    'data_hora': dataHora,
    'humor': humor,
    'tags': tags,
    'album': album,
  };

  factory Registro.fromMap(Map<String, dynamic> m, List<Uint8List> fotos) =>
      Registro(
        id: m['id'] as int?,
        albumId: m['album_id'] as int?,
        titulo: (m['titulo'] as String?) ?? '',
        descricao: (m['descricao'] as String?) ?? '',
        local: (m['local'] as String?) ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        dataHora:
            (m['data_hora'] as String?) ?? DateTime.now().toIso8601String(),
        humor: (m['humor'] as int?) ?? 0,
        tags: (m['tags'] as String?) ?? '',
        album: (m['album'] as String?) ?? '',
        fotos: fotos,
      );
}

// ============================================================
// DATABASE HELPER
//
// This is a SINGLETON — there is only ONE instance of this
// class in the entire app. We access it via DatabaseHelper.instance
//
// Why singleton? Because you should only have one connection
// to a SQLite database at a time.
// ============================================================
class DatabaseHelper {
  // Private constructor — nobody can do "DatabaseHelper()" from outside
  DatabaseHelper._();

  // The single instance, created once and reused everywhere
  static final DatabaseHelper instance = DatabaseHelper._();

  // The actual database object — null until first use
  static Future<Database>? _databaseFuture;

  // ── Platform setup ──────────────────────────────────────────
  // On Android/iOS: sqflite works out of the box, no setup needed.
  // On Windows/Linux/macOS: we need to use the FFI (desktop) version.
  static void initFfiIfNeeded() {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit(); // initialize the desktop SQLite
      databaseFactory = databaseFactoryFfi; // tell sqflite to use it
    }
    // On mobile (Android, iOS) — do nothing. sqflite handles it automatically.
  }

  // ── Database getter ─────────────────────────────────────────
  // "get database" is a getter — accessed like a property: DatabaseHelper.instance.database
  // "_db ??= ..." means: if _db is null, initialize it. Otherwise, return it.
  Future<Database> get database => _databaseFuture ??= _initDb();

  Future<Database> reopenDatabase() async {
    final current = _databaseFuture;
    _databaseFuture = null;
    if (current != null) {
      try {
        final db = await current.timeout(const Duration(seconds: 2));
        await db.close();
      } catch (_) {
        // A failed or blocked opening has no usable connection to close.
      }
    }
    return database;
  }

  Future<void> validateDatabase() async {
    final db = await database.timeout(const Duration(seconds: 15));
    await db.rawQuery('SELECT COUNT(*) FROM albuns');
    await db.rawQuery('SELECT COUNT(*) FROM registros');
  }

  // Opens the database file (creates it if it doesn't exist yet)
  Future<Database> _initDb() async {
    final dir = await getDatabasesPath(); // gets the app's data folder
    final path = join(dir, 'chronicle.db'); // builds the full file path

    return openDatabase(
      path,
      version: 6, // bump this number when you change the schema
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate, // called when DB is created for the first time
      onUpgrade: _onUpgrade, // called when version number increases
      onOpen: _repairSchema,
    );
  }

  Future<void> _repairSchema(Database db) async {
    await _createTableAlbuns(db);
    await _createTableRegistros(db);
    await _createTableFotos(db);
    await _addColumnIfMissing(db, 'registros', 'latitude', 'REAL');
    await _addColumnIfMissing(db, 'registros', 'longitude', 'REAL');
    await _ensureCompatiblePhotoTable(db);
  }

  // Called once when the database is brand new
  Future<void> _onCreate(Database db, int version) async {
    await _createTableAlbuns(db);
    await _createTableRegistros(db);
    await _createTableFotos(db);
    await _seedDefaultAlbums(db); // add 4 starter albums
  }

  // Called when we increase the version number (schema migration)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version 1 didn't have the albuns table
      await _createTableAlbuns(db);
      await _seedDefaultAlbums(db);
      try {
        // Add the album_id column to existing registros table
        await db.execute('ALTER TABLE registros ADD COLUMN album_id INTEGER');
      } catch (_) {
        // Ignore error if column already exists
      }
    }
    if (oldVersion < 3) {
      // Link legacy moments to albums by matching the stored album name
      await db.execute('''
        UPDATE registros
        SET album_id = (
          SELECT id FROM albuns WHERE albuns.nome = registros.album LIMIT 1
        )
        WHERE album_id IS NULL AND album != ''
      ''');
    }
    if (oldVersion < 4) {
      await _addColumnIfMissing(db, 'registros', 'latitude', 'REAL');
      await _addColumnIfMissing(db, 'registros', 'longitude', 'REAL');
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'registros', 'latitude', 'REAL');
      await _addColumnIfMissing(db, 'registros', 'longitude', 'REAL');
    }
    if (oldVersion < 6) {
      await _ensureCompatiblePhotoTable(db);
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<void> _ensureCompatiblePhotoTable(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(fotos)');
    if (columns.isEmpty) {
      await _createTableFotos(db);
      return;
    }
    if (!columns.any((row) => row['name'] == 'dados')) {
      await db.execute('ALTER TABLE fotos ADD COLUMN dados BLOB');
    }
    if (!columns.any((row) => row['name'] == 'caminho')) {
      await db.execute('ALTER TABLE fotos ADD COLUMN caminho TEXT');
    }
  }

  // ── Table creation SQL ──────────────────────────────────────
  // Each of these creates one table in the database.
  // "IF NOT EXISTS" prevents errors if the table already exists.

  Future<void> _createTableAlbuns(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS albuns (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      nome       TEXT    NOT NULL,
      descricao  TEXT    NOT NULL DEFAULT '',
      icone      TEXT    NOT NULL DEFAULT 'photo_album',
      cor        TEXT    NOT NULL DEFAULT '#2E9E50',
      criado_em  TEXT    NOT NULL
    )
  ''');

  Future<void> _createTableRegistros(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS registros (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      album_id  INTEGER,
      titulo    TEXT    NOT NULL,
      descricao TEXT    NOT NULL DEFAULT '',
      local     TEXT    NOT NULL DEFAULT '',
      latitude  REAL,
      longitude REAL,
      data_hora TEXT    NOT NULL,
      humor     INTEGER NOT NULL DEFAULT 0,
      tags      TEXT    NOT NULL DEFAULT '',
      album     TEXT    NOT NULL DEFAULT '',
      FOREIGN KEY (album_id) REFERENCES albuns(id) ON DELETE SET NULL
    )
  ''');

  // Fotos are stored separately so one registro can have many photos
  Future<void> _createTableFotos(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS fotos (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      registro_id  INTEGER NOT NULL,
      dados        BLOB,
      caminho      TEXT,
      FOREIGN KEY (registro_id) REFERENCES registros(id) ON DELETE CASCADE
    )
  ''');

  // Insert 4 starter albums so new users have something to see
  Future<void> _seedDefaultAlbums(Database db) async {
    final now = DateTime.now().toIso8601String();
    for (final a in [
      {'nome': 'Inverno', 'icone': 'snowflake', 'cor': '#5B8DEF'},
      {'nome': 'Verão', 'icone': 'wb_sunny', 'cor': '#F5A623'},
      {'nome': 'Outono', 'icone': 'eco', 'cor': '#E07B39'},
      {'nome': 'Primavera', 'icone': 'local_florist', 'cor': '#2E9E50'},
    ]) {
      await db.insert('albuns', {...a, 'descricao': '', 'criado_em': now});
    }
  }

  // ── ALBUM CRUD ──────────────────────────────────────────────
  // CRUD = Create, Read, Update, Delete — the 4 basic DB operations

  Future<int> inserirAlbum(Album a) async =>
      (await database).insert('albuns', a.toMap());

  Future<List<Album>> listarAlbuns() async {
    final rows = await (await database).query(
      'albuns',
      orderBy: 'criado_em ASC',
    );
    // .map() transforms each row (Map) into an Album object
    return rows.map(Album.fromMap).toList();
  }

  Future<void> atualizarAlbum(Album a) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('albuns', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
      await txn.update(
        'registros',
        {'album': a.nome},
        where: 'album_id = ?',
        whereArgs: [a.id],
      );
    });
  }

  Future<void> deletarAlbum(int id) async =>
      (await database).delete('albuns', where: 'id = ?', whereArgs: [id]);

  Future<int> totalRegistrosPorAlbum(int albumId) async {
    final res = await (await database).rawQuery(
      'SELECT COUNT(*) as c FROM registros WHERE album_id = ?',
      [albumId],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<Map<int, int>> contagemRegistrosPorAlbum() async {
    final rows = await (await database).rawQuery(
      'SELECT album_id, COUNT(*) as c FROM registros '
      'WHERE album_id IS NOT NULL GROUP BY album_id',
    );
    return {
      for (final row in rows) row['album_id'] as int: (row['c'] as int?) ?? 0,
    };
  }

  Future<List<Registro>> listarRegistrosPorAlbum(int albumId) async {
    final db = await database;
    final rows = await db.query(
      'registros',
      where: 'album_id = ?',
      whereArgs: [albumId],
      orderBy: 'data_hora DESC',
    );
    return _addPhotos(db, rows, photoLimit: 1);
  }

  // ── REGISTRO CRUD ───────────────────────────────────────────

  Future<int> inserirRegistro(Registro r) async {
    final db = await database;
    int newId = 0;
    // transaction = all-or-nothing: if anything fails, nothing is saved
    await db.transaction((txn) async {
      newId = await txn.insert('registros', r.toMap());
      for (final bytes in r.fotos) {
        await txn.insert('fotos', {
          'registro_id': newId,
          'dados': bytes,
          'caminho': '',
        });
      }
    });
    return newId;
  }

  Future<List<Registro>> listarRegistros() async {
    final db = await database;
    final rows = await db.query('registros', orderBy: 'data_hora DESC');
    return rows.map((row) => Registro.fromMap(row, const [])).toList();
  }

  Future<List<Registro>> listarRegistrosRecentes({int limite = 5}) async {
    final db = await database;
    final rows = await db.query(
      'registros',
      orderBy: 'data_hora DESC',
      limit: limite,
    );
    return _addPhotos(db, rows, photoLimit: 1);
  }

  Future<Registro?> buscarRegistro(int id) async {
    final db = await database;
    final rows = await db.query('registros', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final fotos = await _fotosDoRegistro(db, id);
    return Registro.fromMap(rows.first, fotos);
  }

  Future<void> atualizarRegistro(Registro r) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'registros',
        r.toMap(),
        where: 'id = ?',
        whereArgs: [r.id],
      );
      // Delete old photos then re-insert the new list
      await txn.delete('fotos', where: 'registro_id = ?', whereArgs: [r.id]);
      for (final bytes in r.fotos) {
        await txn.insert('fotos', {
          'registro_id': r.id,
          'dados': bytes,
          'caminho': '',
        });
      }
    });
  }

  Future<void> deletarRegistro(int id) async =>
      (await database).delete('registros', where: 'id = ?', whereArgs: [id]);

  Future<int> totalRegistros() async {
    final res = await (await database).rawQuery(
      'SELECT COUNT(*) as c FROM registros',
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<int> totalRegistrosComFotos() async {
    final res = await (await database).rawQuery(
      'SELECT COUNT(DISTINCT registro_id) AS c FROM fotos',
    );
    return (res.first['c'] as int?) ?? 0;
  }

  // ── Private helpers ─────────────────────────────────────────

  // Takes a list of DB rows and loads photos for each registro
  Future<List<Registro>> _addPhotos(
    Database db,
    List<Map<String, dynamic>> rows, {
    int? photoLimit,
  }) async {
    final result = <Registro>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final fotos = await _fotosDoRegistro(db, id, limit: photoLimit);
      result.add(Registro.fromMap(row, fotos));
    }
    return result;
  }

  // Gets all photo paths for one registro
  Future<List<Uint8List>> _fotosDoRegistro(
    Database db,
    int registroId, {
    int? limit,
  }) async {
    final rows = await db.query(
      'fotos',
      where: 'registro_id = ?',
      whereArgs: [registroId],
      limit: limit,
    );
    final photos = <Uint8List>[];
    for (final row in rows) {
      final data = row['dados'];
      if (data is Uint8List) {
        photos.add(data);
      } else if (data is List<int>) {
        photos.add(Uint8List.fromList(data));
      } else {
        final path = row['caminho'] as String?;
        if (path == null || path.isEmpty) continue;
        try {
          final bytes = await File(
            path,
          ).readAsBytes().timeout(const Duration(seconds: 3));
          if (bytes.isEmpty) continue;
          photos.add(bytes);
          await db.update(
            'fotos',
            {'dados': bytes},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        } catch (_) {
          // Missing legacy image files do not block the moment list.
        }
      }
    }
    return photos;
  }
}
