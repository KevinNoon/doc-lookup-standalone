import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'local_database.g.dart';

/// The app's single on-device SQLite database — replaces Firestore for this
/// standalone build, since there's no cloud sync or per-user isolation to
/// model (exactly one local user per install).
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;
  Database get db => _db;

  static Future<LocalDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'doc_lookup.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            format TEXT NOT NULL,
            sizeBytes INTEGER NOT NULL,
            folderId INTEGER,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE folders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            colorHex TEXT NOT NULL,
            documentCount INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE groups_ (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            colorHex TEXT NOT NULL,
            lookupCount INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE lookups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            documentId INTEGER,
            documentTitle TEXT,
            page INTEGER,
            contextSnippet TEXT NOT NULL,
            quickResult TEXT,
            deepDiveResult TEXT,
            translation TEXT,
            groupIds TEXT NOT NULL,
            tags TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE highlights (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            documentId INTEGER NOT NULL,
            documentTitle TEXT NOT NULL,
            page INTEGER NOT NULL,
            text TEXT NOT NULL,
            colorHex TEXT NOT NULL,
            startOffset INTEGER,
            endOffset INTEGER,
            pdfRects TEXT,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE flashcards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lookupId TEXT NOT NULL,
            word TEXT NOT NULL,
            definition TEXT NOT NULL,
            easeFactor REAL NOT NULL,
            intervalDays INTEGER NOT NULL,
            repetitions INTEGER NOT NULL,
            dueDate INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
    return LocalDatabase._(db);
  }
}

@Riverpod(keepAlive: true)
Future<LocalDatabase> localDatabase(Ref ref) => LocalDatabase.open();
