import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/epub_parser.dart';
import '../shared/paginated_html_viewer_screen.dart';

class EpubViewerScreen extends StatelessWidget {
  const EpubViewerScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.filePath,
  });

  final String documentId;
  final String title;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return PaginatedHtmlViewerScreen(
      documentId: documentId,
      title: title,
      pageLabel: 'Chapter',
      errorPrefix: 'Could not open this EPUB',
      loadPages: () async {
        final bytes = await File(filePath).readAsBytes();
        final chapters = await parseEpubChapters(bytes);
        return chapters.map((c) => c.htmlContent).toList();
      },
    );
  }
}
