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
        teamId: json['teamId'] ?? '',
        punkte: json['punkte'] ?? 0,
        differenz: json['differenz'] ?? 0,
        becher: json['becher'] ?? 0,
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
      return 0;
    });
  }

  // SortTables sortiert alle Bewertungstabellen
  void sortTables() {
    for (var table in tables) {
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
}
