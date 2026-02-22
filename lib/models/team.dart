import 'package:pongstrong/models/groups.dart';

/// A tournament team consisting of two members.
class Team {
  String id;
  String name;
  String member1;
  String member2;

  Team({
    this.id = '',
    this.name = '',
    this.member1 = '',
    this.member2 = '',
  });

  /// Returns the group index this team belongs to, or -1 if not found.
  int origin(Groups groups) {
    for (int g = 0; g < groups.groups.length; g++) {
      if (groups.groups[g].contains(id)) {
        return g;
      }
    }
    return -1;
  }

  /// Serialises this team to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'member1': member1,
        'member2': member2,
      };

  /// Creates a [Team] from a Firestore JSON map.
  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        member1: (json['member1'] as String?) ?? '',
        member2: (json['member2'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          id == other.id &&
          name == other.name &&
          member1 == other.member1 &&
          member2 == other.member2;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ member1.hashCode ^ member2.hashCode;
}
