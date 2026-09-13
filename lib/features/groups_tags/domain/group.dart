class Group {
  const Group({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.lookupCount,
  });

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: map['name'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#009688',
      lookupCount: map['lookupCount'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String colorHex;
  final int lookupCount;

  Map<String, dynamic> toMap() {
    return {'name': name, 'colorHex': colorHex, 'lookupCount': lookupCount};
  }
}
