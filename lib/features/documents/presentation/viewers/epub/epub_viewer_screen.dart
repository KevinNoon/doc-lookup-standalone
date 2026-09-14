import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/epub_parser.dart';
import '../shared/paginated_html_viewer_screen.dart';

class EpubViewerScreen extends StatelessWidget {
  const EpubViewerScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.bytes,
  });

  final String documentId;
  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return PaginatedHtmlViewerScreen(
      documentId: documentId,
      title: title,
      pageLabel: 'Chapter',
      errorPrefix: 'Could not open this EPUB',
      loadPages: () async {
        final chapters = await parseEpubChapters(bytes);
        return chapters.map((c) => c.htmlContent).toList();
      },
    );
  }
}
