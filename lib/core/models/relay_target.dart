class RelayTarget {
  const RelayTarget({
    required this.id,
    required this.addr,
    required this.shortId,
    this.ports = const [],
    this.extraFields = const {},
  });

  final String id;
  final String addr;
  final int shortId;
  final List<int> ports;
  final Map<String, Object?> extraFields;

  RelayTarget copyWith({
    String? id,
    String? addr,
    int? shortId,
    List<int>? ports,
    Map<String, Object?>? extraFields,
  }) {
    return RelayTarget(
      id: id ?? this.id,
      addr: addr ?? this.addr,
      shortId: shortId ?? this.shortId,
      ports: ports ?? this.ports,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
