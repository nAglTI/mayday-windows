class ServerTarget {
  const ServerTarget({
    required this.id,
    required this.key,
    required this.priority,
    this.extraFields = const {},
  });

  final String id;
  final String key;
  final int priority;
  final Map<String, Object?> extraFields;

  ServerTarget copyWith({
    String? id,
    String? key,
    int? priority,
    Map<String, Object?>? extraFields,
  }) {
    return ServerTarget(
      id: id ?? this.id,
      key: key ?? this.key,
      priority: priority ?? this.priority,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
