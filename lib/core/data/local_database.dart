import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

part 'local_database.g.dart';

/// The app's single on-device SQLite database — replaces Firestore for this
/// standalone build, since there's no cloud sync or per-user isolation to
/// model (exactly one local user per install). On web, `sqflite` itself has
/// no implementation, so [databaseFactoryFfiWebNoWebWorker] backs the same
/// `Database` API with an IndexedDB + sqlite3-wasm store instead. The
/// no-worker variant (main-thread wasm, no `SharedWorker`) is used
/// deliberately rather than the default [databaseFactoryFfiWeb]: this app
/// has no cross-tab sync need (exactly one local user, no multi-tab
/// scenario to keep consistent), and `SharedWorker`'s postMessage RPC proved
/// unreliable in testing — it's also unsupported on Android Chrome (one of
/// this app's two primary targets), where the package silently falls back
/// to a non-shared `Worker` anyway. Running wasm on the main thread means a
/// query briefly blocks the UI, an acceptable tradeoff at this app's scale
/// (local, single-user, dozens-to-hundreds of rows).
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;
  Database get db => _db;

  static Future<LocalDatabase> open() async {
    late final String path;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      path = 'doc_lookup.db';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      path = p.join(directory.path, 'doc_lookup.db');
    }
    final db = await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 had `bytes BLOB NOT NULL`. Web inserts now leave it null
          // (bytes live in IndexedDB instead — see WebDocumentBlobStore),
          // and SQLite has no ALTER COLUMN, so relax the constraint via the
          // standard rebuild pattern. Existing rows' bytes are carried over
          // unchanged; DocumentRepository migrates them into IndexedDB on
          // the next open.
          await db.execute('ALTER TABLE documents RENAME TO documents_old');
          await db.execute('''
            CREATE TABLE documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              format TEXT NOT NULL,
              sizeBytes INTEGER NOT NULL,
              bytes BLOB,
              folderId INTEGER,
              createdAt INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            INSERT INTO documents (id, title, format, sizeBytes, bytes, folderId, createdAt)
            SELECT id, title, format, sizeBytes, bytes, folderId, createdAt FROM documents_old
          ''');
          await db.execute('DROP TABLE documents_old');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            format TEXT NOT NULL,
            sizeBytes INTEGER NOT NULL,
            bytes BLOB, -- null on web; document bytes live in IndexedDB there instead (see WebDocumentBlobStore)
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
