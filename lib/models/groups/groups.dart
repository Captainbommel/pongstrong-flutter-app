/// Team group assignments for the group phase.
class Groups {
  /// Nested list of team IDs, one inner list per group.
  List<List<String>> groups;

  Groups({List<List<String>>? groups}) : groups = groups ?? [];

  /// Serialises groups to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    // Convert nested array to map to avoid Firestore limitation
    final groupsMap = <String, dynamic>{};
    for (int i = 0; i < groups.length; i++) {
      groupsMap['group$i'] = groups[i];
    }
    return {
      'groups': groupsMap,
      'numberOfGroups': groups.length,
    };
  }

  /// Creates [Groups] from a Firestore JSON map.
  factory Groups.fromJson(Map<String, dynamic> json) {
    final groupsMap = json['groups'] as Map<String, dynamic>;
    final numberOfGroups = json['numberOfGroups'] as int;
    final groupsList = <List<String>>[];
    for (int i = 0; i < numberOfGroups; i++) {
      final group =
          (groupsMap['group$i'] as List).map((id) => id.toString()).toList();
      groupsList.add(group);
    }
    return Groups(groups: groupsList);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Groups) return false;
    if (groups.length != other.groups.length) return false;
    for (int i = 0; i < groups.length; i++) {
      if (groups[i].length != other.groups[i].length) return false;
      for (int j = 0; j < groups[i].length; j++) {
        if (groups[i][j] != other.groups[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        groups.map((g) => Object.hashAll(g)),
      );
}
