import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../screens/firewall_screen.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Section « Protection réseau » de l'accueil : une ligne vers le
/// pare-feu DNS. N'affiche rien hors Android.
class NetworkProtectionSection extends StatefulWidget {
  const NetworkProtectionSection({super.key, this.showTitle = true});

  /// false : l'accueil la range sous « Vos protections ».
  final bool showTitle;

  @override
  State<NetworkProtectionSection> createState() =>
      _NetworkProtectionSectionState();
}

class _NetworkProtectionSectionState extends State<NetworkProtectionSection> {
  final _service = FirewallService();
  late final AppLifecycleListener _lifecycle;

  FirewallStatus? _status;

  @override
  void initState() {
    super.initState();
    // Au retour dans l'app (ex : arrêt depuis la notification).
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _open() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FirewallScreen()));
    await _refresh(); // l'état a pu changer sur l'écran du pare-feu
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final level = status.active ? StatusLevel.ok : StatusLevel.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) SectionHeader(title: l.networkProtectionTitle),
        ListRow(
          icon: Icons.shield_outlined,
          iconColor: level.color(context.colors),
          title: l.firewallTitle,
          subtitle: status.summary(l),
          onTap: _open,
          chevron: true,
        ),
      ],
    );
  }
}
