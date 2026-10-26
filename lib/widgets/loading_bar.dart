import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Fine barre de chargement bleue. TalkBack l'annonce dès qu'elle
/// apparaît (« Chargement en cours », ou [label]).
class LoadingBar extends StatelessWidget {
  const LoadingBar({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: LinearProgressIndicator(
        minHeight: 2,
        color: context.colors.bleu,
        backgroundColor: context.colors.ligne,
        semanticsLabel: label ?? context.l10n.commonLoading,
      ),
    );
  }
}
