class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.documentCount,
  });

  factory Folder.fromMap(String id, Map<String, dynamic> map) {
    return Folder(
      id: id,
      name: map['name'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#009688',
      documentCount: map['documentCount'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String colorHex;
  final int documentCount;

  Map<String, dynamic> toMap() {
    return {'name': name, 'colorHex': colorHex, 'documentCount': documentCount};
  }
}
