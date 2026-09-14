import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../shared/paginated_text_viewer_screen.dart';

class TxtViewerScreen extends StatelessWidget {
  const TxtViewerScreen({
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
    return PaginatedTextViewerScreen(
      documentId: documentId,
      title: title,
      loadText: () async => utf8.decode(bytes),
    );
  }
}
