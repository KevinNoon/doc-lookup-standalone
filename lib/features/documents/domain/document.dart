enum DocumentFormat { pdf, epub, docx, txt }

class Document {
  const Document({
    required this.id,
    required this.title,
    required this.format,
    required this.sizeBytes,
    required this.createdAt,
    this.folderId,
  });

  factory Document.fromMap(String id, Map<String, dynamic> map) {
    return Document(
      id: id,
      title: map['title'] as String? ?? 'Untitled',
      format: DocumentFormat.values.byName(map['format'] as String? ?? 'pdf'),
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      createdAt: map['createdAt'],
      folderId: map['folderId'] as String?,
    );
  }

  final String id;
  final String title;
  final DocumentFormat format;
  final int sizeBytes;
  final Object? createdAt;
  final String? folderId;

  String get fileExtension => format.name;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'format': format.name,
      'sizeBytes': sizeBytes,
      'folderId': folderId,
    };
  }
}
