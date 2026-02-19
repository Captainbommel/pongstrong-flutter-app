import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

//TODO: This is currently only a placeholder, the actual content still needs to be improved.

/// Dialog displaying Impressum & Datenschutz (Imprint & Privacy) information
class ImpressumDialog extends StatelessWidget {
  const ImpressumDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ImpressumDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: GroupPhaseColors.cupred,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Impressum & Datenschutz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'Impressum',
                      'Pongstrong Tournament Manager\n\n'
                          'Dies ist eine nicht-kommerzielle Anwendung zur '
                          'Verwaltung von Bierpong-Turnieren.',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      'Kontakt',
                      'Bei Fragen oder Anliegen wenden Sie sich bitte '
                          'an email@address.com.',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      'Datenschutz',
                      'Diese App speichert Turnierdaten (Teamnamen, Spielergebnisse) '
                          'in Firebase Cloud Firestore. Da nur Turnier-Ersteller '
                          'einen Account benötigen, ist eine Zuordnung der '
                          'Turnierdaten zu einzelnen Teilnehmern nicht möglich.\n\n'
                          'Anonyme Authentifizierung wird für Turnier-Teilnehmer '
                          'verwendet. Dabei werden keine persönlichen Daten gespeichert.',
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      'Haftungsausschluss',
                      'Die Nutzung dieser App erfolgt auf eigene Verantwortung. '
                          'Für die Richtigkeit der angezeigten Turnierdaten wird '
                          'keine Gewähr übernommen.',
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
