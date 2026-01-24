class Groups {
  List<List<String>> groups; // List of group lists, each containing team IDs

  Groups({List<List<String>>? groups}) : groups = groups ?? [];

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
}
