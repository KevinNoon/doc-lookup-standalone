import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/docx_parser.dart';
import '../shared/paginated_html_viewer_screen.dart';

class DocxViewerScreen extends StatelessWidget {
  const DocxViewerScreen({
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
      errorPrefix: 'Could not open this DOCX',
      loadPages: () async {
        final bytes = await File(filePath).readAsBytes();
        return parseDocxPages(bytes);
      },
    );
  }
}
