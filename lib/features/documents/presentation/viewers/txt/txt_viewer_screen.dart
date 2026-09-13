import 'dart:io';

import 'package:flutter/material.dart';

import '../shared/paginated_text_viewer_screen.dart';

class TxtViewerScreen extends StatelessWidget {
  const TxtViewerScreen({
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
    return PaginatedTextViewerScreen(
      documentId: documentId,
      title: title,
      loadText: () => File(filePath).readAsString(),
    );
  }
}
