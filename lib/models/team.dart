import 'package:pongstrong/models/groups.dart';

class Team {
  String id;
  String name;
  String mem1;
  String mem2;

  Team({
    this.id = '',
    this.name = '',
    this.mem1 = '',
    this.mem2 = '',
  });

  // origin returns the group the team is in
  int origin(Groups groups) {
    for (int g = 0; g < groups.groups.length; g++) {
      if (groups.groups[g].contains(id)) {
        return g;
      }
    }
    return -1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mem1': mem1,
        'mem2': mem2,
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        mem1: (json['mem1'] as String?) ?? '',
        mem2: (json['mem2'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          id == other.id &&
          name == other.name &&
          mem1 == other.mem1 &&
          mem2 == other.mem2;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ mem1.hashCode ^ mem2.hashCode;
}
