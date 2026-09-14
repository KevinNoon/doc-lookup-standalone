import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/documents/domain/document.dart';
import '../../features/documents/presentation/folders_screen.dart';
import '../../features/documents/presentation/library_screen.dart';
import '../../features/documents/presentation/viewers/docx/docx_viewer_screen.dart';
import '../../features/documents/presentation/viewers/epub/epub_viewer_screen.dart';
import '../../features/documents/presentation/viewers/pdf/pdf_viewer_screen.dart';
import '../../features/documents/presentation/viewers/txt/txt_viewer_screen.dart';
import '../../features/flashcards/presentation/quiz_screen.dart';
import '../../features/groups_tags/presentation/groups_screen.dart';
import '../../features/highlights/presentation/highlights_screen.dart';
import '../../features/search/presentation/saved_lookups_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/document',
        builder: (context, state) {
          final args = state.extra! as (String documentId, String title, Uint8List bytes, DocumentFormat format);
          final (documentId, title, bytes, format) = args;
          return switch (format) {
            DocumentFormat.epub =>
              EpubViewerScreen(documentId: documentId, title: title, bytes: bytes),
            DocumentFormat.txt =>
              TxtViewerScreen(documentId: documentId, title: title, bytes: bytes),
            DocumentFormat.docx =>
              DocxViewerScreen(documentId: documentId, title: title, bytes: bytes),
            DocumentFormat.pdf =>
              PdfViewerScreen(documentId: documentId, title: title, bytes: bytes),
          };
        },
      ),
      GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen()),
      GoRoute(path: '/saved-lookups', builder: (context, state) => const SavedLookupsScreen()),
      GoRoute(path: '/study', builder: (context, state) => const QuizScreen()),
      GoRoute(path: '/highlights', builder: (context, state) => const HighlightsScreen()),
      GoRoute(path: '/folders', builder: (context, state) => const FoldersScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
}
