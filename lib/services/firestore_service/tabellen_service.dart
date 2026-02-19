import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_base.dart';

/// Service for managing standings/tables data in Firestore
mixin TabellenService on FirestoreBase {
  /// Saves standings/tables to Firestore
  Future<void> saveTabellen(
    Tabellen tabellen, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Convert nested array to map to avoid Firestore nested array limitation
    final tablesMap = <String, dynamic>{};
    for (int i = 0; i < tabellen.tables.length; i++) {
      tablesMap['table$i'] =
          tabellen.tables[i].map((row) => row.toJson()).toList();
    }

    final data = {
      'tables': tablesMap,
      'numberOfTables': tabellen.tables.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'tabellen').set(data);
  }

  /// Loads standings from Firestore.
  /// Note: standings should be generated using evalGruppen,
  /// this is just for the case that no Gruppenphase data is available.
  Future<Tabellen?> loadTabellen({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'tabellen').get();
    if (!doc.exists) return null;

    final data = doc.data()! as Map<String, dynamic>;
    final tablesMap = data['tables'] as Map<String, dynamic>;
    final numberOfTables = data['numberOfTables'] as int;

    final tables = <List<TableRow>>[];
    for (int i = 0; i < numberOfTables; i++) {
      final tableRows = (tablesMap['table$i'] as List)
          .map((row) => TableRow.fromJson(row as Map<String, dynamic>))
          .toList();
      tables.add(tableRows);
    }
    return Tabellen(tables: tables);
  }

  /// Stream of standings/tables updates
  Stream<Tabellen?> tabellenStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'tabellen').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()! as Map<String, dynamic>;
      final tablesMap = data['tables'] as Map<String, dynamic>;
      final numberOfTables = data['numberOfTables'] as int;

      final tables = <List<TableRow>>[];
      for (int i = 0; i < numberOfTables; i++) {
        final tableRows = (tablesMap['table$i'] as List)
            .map((row) => TableRow.fromJson(row as Map<String, dynamic>))
            .toList();
        tables.add(tableRows);
      }
      return Tabellen(tables: tables);
    });
  }
}
