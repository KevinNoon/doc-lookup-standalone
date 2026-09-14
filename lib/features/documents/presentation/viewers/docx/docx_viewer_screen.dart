import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/docx_parser.dart';
import '../shared/paginated_html_viewer_screen.dart';

class DocxViewerScreen extends StatelessWidget {
  const DocxViewerScreen({
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
      errorPrefix: 'Could not open this DOCX',
      loadPages: () async => parseDocxPages(bytes),
    );
  }
}
