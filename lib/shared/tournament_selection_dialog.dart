import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

class TournamentSelectionDialog extends StatefulWidget {
  const TournamentSelectionDialog({super.key});

  @override
  State<TournamentSelectionDialog> createState() =>
      _TournamentSelectionDialogState();
}

class _TournamentSelectionDialogState extends State<TournamentSelectionDialog> {
  late Future<List<String>> _tournamentsFuture;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _firestoreService.listTournaments();
  }

  Future<void> _onTournamentSelected(String tournamentId) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final success =
        await Provider.of<TournamentDataState>(context, listen: false)
            .loadTournamentData(tournamentId);

    if (mounted) {
      if (success) {
        Provider.of<TournamentSelectionState>(context, listen: false)
            .setSelectedTournament(tournamentId);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load tournament data'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _tournamentsFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingDialog('Loading tournaments...');
        }

        // Error state
        if (snapshot.hasError) {
          return _buildErrorDialog(snapshot.error.toString());
        }

        final tournaments = snapshot.data ?? [];

        // Empty state
        if (tournaments.isEmpty) {
          return _buildEmptyDialog();
        }

        // Tournament list
        return _buildTournamentListDialog(tournaments);
      },
    );
  }

  Dialog _buildLoadingDialog(String message) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Dialog _buildErrorDialog(String error) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Error loading tournaments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(error),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Dialog _buildEmptyDialog() {
    return const Dialog(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No tournaments available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Please create a tournament first.'),
          ],
        ),
      ),
    );
  }

  Dialog _buildTournamentListDialog(List<String> tournaments) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Tournament',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              _buildLoadingDialog('Loading tournament data...').child as Widget
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final tournamentId = tournaments[index];
                    return ListTile(
                      title: Text(tournamentId),
                      onTap: () => _onTournamentSelected(tournamentId),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
