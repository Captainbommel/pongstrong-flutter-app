class TableRow {
  String teamId;
  int punkte;
  int differenz;
  int becher;
  List<String> vergleich;

  TableRow({
    this.teamId = '',
    this.punkte = 0,
    this.differenz = 0,
    this.becher = 0,
    List<String>? vergleich,
  }) : vergleich = vergleich ?? List.filled(4, '');

  Map<String, dynamic> toJson() => {
        'teamId': teamId,
        'punkte': punkte,
        'differenz': differenz,
        'becher': becher,
        'vergleich': vergleich,
      };

  factory TableRow.fromJson(Map<String, dynamic> json) => TableRow(
        teamId: (json['teamId'] as String?) ?? '',
        punkte: (json['punkte'] as int?) ?? 0,
        differenz: (json['differenz'] as int?) ?? 0,
        becher: (json['becher'] as int?) ?? 0,
        vergleich:
            (json['vergleich'] as List?)?.map((e) => e.toString()).toList() ??
                List.filled(4, ''),
      );
}

class Tabellen {
  List<List<TableRow>> tables;

  Tabellen({List<List<TableRow>>? tables}) : tables = tables ?? [];

  // SortTable sortiert eine zu einer Gruppe zugehörige Bewertungstabelle
  static void sortTable(List<TableRow> table) {
    table.sort((a, b) {
      if (a.punkte != b.punkte) return b.punkte.compareTo(a.punkte);
      if (a.differenz != b.differenz) return b.differenz.compareTo(a.differenz);
      if (a.becher != b.becher) return b.becher.compareTo(a.becher);
      // TODO: Better tiebreaker — use the direct comparison (head-to-head)
      // between the two tied teams to determine who placed higher, instead of
      // falling back to alphabetical teamId.
      return a.teamId.compareTo(b.teamId);
    });
  }

  // SortTables sortiert alle Bewertungstabellen
  void sortTables() {
    for (final table in tables) {
      sortTable(table);
    }
  }

  List<List<Map<String, dynamic>>> toJson() =>
      tables.map((table) => table.map((row) => row.toJson()).toList()).toList();

  static Tabellen fromJson(List<dynamic> json) => Tabellen(
        tables: json
            .map((table) => (table as List)
                .map((row) => TableRow.fromJson(row as Map<String, dynamic>))
                .toList())
            .toList(),
      );

  /// Creates a deep copy of this Tabellen.
  /// Note: This uses JSON serialization and should be used sparingly for performance reasons.
  Tabellen clone() => Tabellen.fromJson(toJson());
}
