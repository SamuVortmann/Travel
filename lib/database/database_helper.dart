import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Disponibiliza a constante kIsWeb.
import 'package:path/path.dart'; // Ajuda a montar caminhos de arquivos.
import 'package:sqflite/sqflite.dart'; // Plugin do SQLite.
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // SQLite para desktop.
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // SQLite para web.
import 'package:chronicle/utils/legacy_photo_reader.dart';

// ============================================================
// MODELO: Álbum
//
// Um modelo é uma classe Dart que representa uma linha de uma tabela
// do banco de dados, de forma semelhante a uma linha de planilha.
//
// A tabela albuns possui estas colunas:
//   id, nome, descricao, icone, cor, criado_em
// ============================================================
/// Representa um álbum armazenado na tabela `albuns`.
class Album {
  final int? id; // Nulo enquanto o álbum ainda não foi salvo.
  final String nome; // Nome do álbum, por exemplo, "Viagem para Paris".
  final String descricao; // Descrição opcional.
  final String icone; // Nome do ícone, como "snowflake" ou "flight".
  final String cor; // Cor hexadecimal, por exemplo, "#2E9E50".
  final String criadoEm; // Data de criação no formato ISO.

  // O construtor const permite criar a instância em tempo de compilação.
  const Album({
    this.id, // Opcional; nulo significa que ainda não está no banco.
    required this.nome, // Obrigatório: deve ser informado pelo chamador.
    this.descricao = '', // Usa uma string vazia como valor padrão.
    this.icone = 'photo_album',
    this.cor = '#2E9E50',
    required this.criadoEm,
  });

  // Converte o objeto em um mapa, formato usado pelo SQLite em inserções e alterações.
  Map<String, dynamic> toMap() => {
    if (id != null)
      'id': id, // Inclui o identificador somente quando ele existe.
    'nome': nome,
    'descricao': descricao,
    'icone': icone,
    'cor': cor,
    'criado_em': criadoEm,
  };

  // Reconstrói um álbum a partir de uma linha retornada pelo banco.
  // O operador "??" fornece um valor seguro quando a coluna está nula.
  factory Album.fromMap(Map<String, dynamic> m) => Album(
    id: m['id'] as int?,
    nome: (m['nome'] as String?) ?? '',
    descricao: (m['descricao'] as String?) ?? '',
    icone: (m['icone'] as String?) ?? 'photo_album',
    cor: (m['cor'] as String?) ?? '#2E9E50',
    criadoEm: (m['criado_em'] as String?) ?? DateTime.now().toIso8601String(),
  );

  // Cria um novo álbum alterando apenas os campos informados.
  // É útil na edição porque preserva os demais valores.
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
// MODELO: Registro (um momento salvo dentro de um álbum)
//
// A tabela registros possui estas colunas:
//   id, album_id, titulo, descricao, local, data_hora,
//   humor, tags, album
//
// As fotos ficam em uma tabela SEPARADA e são carregadas junto
// do registro como valores BLOB do SQLite.
// ============================================================
/// Representa um momento e suas fotos armazenados no banco.
class Registro {
  final int? id;
  final int? albumId; // Identifica o álbum relacionado; pode ser nulo.
  final String titulo; // Por exemplo, "Pôr do sol na praia".
  final String descricao;
  final String local; // Por exemplo, "Florianópolis".
  final double? latitude;
  final double? longitude;
  final String dataHora; // Data e hora no formato ISO-8601.
  final int humor; // 0=😊 1=😄 2=😐 3=😢 4=😍
  final String tags; // Reservado para uso futuro.
  final String album; // Nome duplicado para agilizar a exibição.
  final List<Uint8List> fotos; // Bytes das imagens armazenados no SQLite.

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
    this.fotos = const [], // Por padrão, o registro não possui fotos.
  });

  Map<String, dynamic> toMap() => {
    // Serializa apenas os campos mantidos na tabela principal de registros.
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
      // Reconstrói o registro combinando a linha principal com suas fotos.
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
// AUXILIAR DO BANCO DE DADOS
//
// Esta classe usa o padrão SINGLETON: existe apenas uma instância
// em todo o aplicativo, acessada por DatabaseHelper.instance.
//
// Isso mantém uma única conexão ativa com o banco SQLite.
// ============================================================
/// Centraliza a conexão, o esquema e todas as operações do SQLite.
class DatabaseHelper {
  // O construtor privado impede a criação de instâncias externas.
  DatabaseHelper._();

  // Instância única, criada uma vez e reutilizada em todo o aplicativo.
  static final DatabaseHelper instance = DatabaseHelper._();

  // Conexão real com o banco; permanece nula até o primeiro uso.
  static Future<Database>? _databaseFuture;

  // ── Configuração por plataforma ─────────────────────────────
  // No Android e iOS, o sqflite não exige configuração adicional.
  // No Windows, Linux e macOS, é usada a implementação FFI.
  static void initFfiIfNeeded() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit(); // Inicializa o SQLite para desktop.
      databaseFactory =
          databaseFactoryFfi; // Define a fábrica usada pelo sqflite.
    }
    // Em dispositivos móveis, o sqflite cuida da inicialização automaticamente.
  }

  // ── Acesso ao banco ─────────────────────────────────────────
  // O getter permite acessar a conexão como DatabaseHelper.instance.database.
  // Se _db estiver nulo, a conexão é inicializada; caso contrário, é reutilizada.
  Future<Database> get database => _databaseFuture ??= _initDb();

  Future<Database> reopenDatabase() async {
    // Descarta a conexão armazenada e tenta abrir uma nova instância.
    final current = _databaseFuture;
    _databaseFuture = null;
    if (current != null) {
      try {
        final db = await current.timeout(const Duration(seconds: 2));
        await db.close();
      } catch (_) {
        // Uma abertura bloqueada ou com falha não produz conexão para fechar.
      }
    }
    return database;
  }

  Future<void> validateDatabase() async {
    // Confirma que o banco abre e que o esquema mínimo está disponível.
    final db = await database.timeout(const Duration(seconds: 15));
    await db.rawQuery('SELECT COUNT(*) FROM albuns');
    await db.rawQuery('SELECT COUNT(*) FROM registros');
  }

  // Abre o arquivo do banco e o cria caso ainda não exista.
  Future<Database> _initDb() async {
    final dir =
        await getDatabasesPath(); // Obtém a pasta de dados do aplicativo.
    final path = join(
      dir,
      'chronicle.db',
    ); // Monta o caminho completo do arquivo.

    return openDatabase(
      path,
      version: 6, // Deve aumentar sempre que o esquema for alterado.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate, // Chamado na primeira criação do banco.
      onUpgrade: _onUpgrade, // Chamado quando a versão aumenta.
      onOpen: _repairSchema,
    );
  }

  Future<void> _repairSchema(Database db) async {
    // Recria estruturas ausentes sem apagar os dados existentes.
    await _createTableAlbuns(db);
    await _createTableRegistros(db);
    await _createTableFotos(db);
    await _addColumnIfMissing(db, 'registros', 'latitude', 'REAL');
    await _addColumnIfMissing(db, 'registros', 'longitude', 'REAL');
    await _ensureCompatiblePhotoTable(db);
  }

  // Executado uma única vez quando o banco é criado.
  Future<void> _onCreate(Database db, int version) async {
    await _createTableAlbuns(db);
    await _createTableRegistros(db);
    await _createTableFotos(db);
    await _seedDefaultAlbums(db); // Adiciona quatro álbuns iniciais.
  }

  // Executa as migrações quando a versão do esquema aumenta.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // A versão 1 ainda não possuía a tabela albuns.
      await _createTableAlbuns(db);
      await _seedDefaultAlbums(db);
      try {
        // Adiciona album_id à tabela de registros existente.
        await db.execute('ALTER TABLE registros ADD COLUMN album_id INTEGER');
      } catch (_) {
        // Ignora a falha caso a coluna já exista.
      }
    }
    if (oldVersion < 3) {
      // Associa momentos antigos pelo nome de álbum armazenado.
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
    // Consulta a estrutura da tabela antes de executar uma alteração segura.
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<void> _ensureCompatiblePhotoTable(Database db) async {
    // Garante que a tabela de fotos use a estrutura esperada pela versão atual.
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

  // ── SQL de criação das tabelas ──────────────────────────────
  // Cada método cria uma tabela; IF NOT EXISTS evita erros de duplicidade.

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

  // As fotos ficam separadas para que um registro possa possuir várias imagens.
  Future<void> _createTableFotos(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS fotos (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      registro_id  INTEGER NOT NULL,
      dados        BLOB,
      caminho      TEXT,
      FOREIGN KEY (registro_id) REFERENCES registros(id) ON DELETE CASCADE
    )
  ''');

  // Insere quatro álbuns iniciais para apresentar conteúdo aos novos usuários.
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

  // ── CRUD DE ÁLBUNS ──────────────────────────────────────────
  // CRUD reúne as quatro operações básicas: criar, ler, atualizar e excluir.

  Future<int> inserirAlbum(Album a) async =>
      // Insere um álbum e devolve o identificador criado pelo SQLite.
      (await database).insert('albuns', a.toMap());

  Future<List<Album>> listarAlbuns() async {
    final rows = await (await database).query(
      'albuns',
      orderBy: 'criado_em ASC',
    );
    // Transforma cada linha retornada em um objeto Album.
    return rows.map(Album.fromMap).toList();
  }

  Future<void> atualizarAlbum(Album a) async {
    // Atualiza o álbum e mantém o nome duplicado nos registros sincronizado.
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
      // Remove o álbum identificado; as relações dependem das regras do esquema.
      (await database).delete('albuns', where: 'id = ?', whereArgs: [id]);

  Future<int> totalRegistrosPorAlbum(int albumId) async {
    // Conta quantos momentos pertencem ao álbum informado.
    final res = await (await database).rawQuery(
      'SELECT COUNT(*) as c FROM registros WHERE album_id = ?',
      [albumId],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<Map<int, int>> contagemRegistrosPorAlbum() async {
    // Retorna um mapa que associa cada álbum à sua quantidade de registros.
    final rows = await (await database).rawQuery(
      'SELECT album_id, COUNT(*) as c FROM registros '
      'WHERE album_id IS NOT NULL GROUP BY album_id',
    );
    return {
      for (final row in rows) row['album_id'] as int: (row['c'] as int?) ?? 0,
    };
  }

  Future<List<Registro>> listarRegistrosPorAlbum(int albumId) async {
    // Busca os registros do álbum em ordem cronológica decrescente.
    final db = await database;
    final rows = await db.query(
      'registros',
      where: 'album_id = ?',
      whereArgs: [albumId],
      orderBy: 'data_hora DESC',
    );
    return _addPhotos(db, rows, photoLimit: 1);
  }

  // ── CRUD DE REGISTROS ───────────────────────────────────────

  Future<int> inserirRegistro(Registro r) async {
    final db = await database;
    int newId = 0;
    // A transação garante que todas as etapas sejam salvas ou nenhuma delas.
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
    // Lista todos os registros, incluindo suas fotos.
    final db = await database;
    final rows = await db.query('registros', orderBy: 'data_hora DESC');
    return rows.map((row) => Registro.fromMap(row, const [])).toList();
  }

  Future<List<Registro>> listarRegistrosRecentes({int limite = 5}) async {
    // Obtém somente os registros mais recentes até o limite solicitado.
    final db = await database;
    final rows = await db.query(
      'registros',
      orderBy: 'data_hora DESC',
      limit: limite,
    );
    return _addPhotos(db, rows, photoLimit: 1);
  }

  Future<Registro?> buscarRegistro(int id) async {
    // Procura um único registro e retorna nulo quando ele não existe.
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
      // Remove as fotos antigas antes de inserir a nova lista.
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
      // Exclui o registro; as fotos relacionadas são removidas pelo esquema.
      (await database).delete('registros', where: 'id = ?', whereArgs: [id]);

  Future<int> totalRegistros() async {
    // Calcula o número total de momentos salvos.
    final res = await (await database).rawQuery(
      'SELECT COUNT(*) as c FROM registros',
    );
    return (res.first['c'] as int?) ?? 0;
  }

  Future<int> totalRegistrosComFotos() async {
    // Conta registros distintos que possuem pelo menos uma foto.
    final res = await (await database).rawQuery(
      'SELECT COUNT(DISTINCT registro_id) AS c FROM fotos',
    );
    return (res.first['c'] as int?) ?? 0;
  }

  // ── Métodos auxiliares privados ─────────────────────────────

  // Carrega as fotos correspondentes para cada linha de registro.
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

  // Obtém todas as fotos pertencentes a um registro.
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
          final bytes = await readLegacyPhoto(
            path,
          ).timeout(const Duration(seconds: 3));
          if (bytes == null || bytes.isEmpty) continue;
          photos.add(bytes);
          await db.update(
            'fotos',
            {'dados': bytes},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        } catch (_) {
          // Arquivos antigos ausentes não impedem a listagem dos momentos.
        }
      }
    }
    return photos;
  }
}
