class BadAppFinding {
  const BadAppFinding({
    required this.category,
    required this.name,
    required this.path,
    required this.publisher,
    required this.version,
    required this.status,
    required this.state,
    required this.matchedKeywords,
  });

  final String category;
  final String name;
  final String path;
  final String publisher;
  final String version;
  final String status;
  final String state;
  final List<String> matchedKeywords;

  factory BadAppFinding.fromJson(Map<String, Object?> json) {
    return BadAppFinding(
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      publisher: json['publisher']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      matchedKeywords: _readStringList(json['matchedKeywords']),
    );
  }

  String get title {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }

    final trimmedPath = path.trim();
    if (trimmedPath.isNotEmpty) {
      return trimmedPath;
    }

    return category;
  }

  String get dedupeKey {
    return [
      category,
      name,
      path,
      publisher,
      version,
      status,
      state,
    ].map((value) => value.trim().toLowerCase()).join('\u0001');
  }

  static List<String> _readStringList(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (value is! Iterable) {
      return const [];
    }

    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }
}
