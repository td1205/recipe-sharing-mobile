class RecipeTag {
  const RecipeTag({required this.name, this.type = 'user', this.voteCount = 0});

  final String name;
  final String type;
  final int voteCount;

  bool get isCommunity => type == 'community';

  /// Null-safe parse; returns null when the payload lacks a usable name.
  static RecipeTag? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final votes = raw['voteCount'];
    final normalizedName = name.trim();
    final type = raw['type'];
    return RecipeTag(
      name: normalizedName,
      type: type is String ? type : 'user',
      voteCount: votes is num ? votes.toInt() : 0,
    );
  }
}
