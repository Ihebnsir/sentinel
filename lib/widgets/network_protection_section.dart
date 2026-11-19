import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../screens/firewall_screen.dart';
import '../services/firewall_service.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Section « Protection réseau » de l'accueil : une ligne vers le
/// pare-feu DNS. N'affiche rien hors Android.
class NetworkProtectionSection extends StatefulWidget {
  const NetworkProtectionSection({super.key});

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
    final color = status.active
        ? context.colors.zitouna
        : context.colors.discret;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.networkProtectionTitle,
          style: TextStyle(
            fontSize: AppText.section,
            fontWeight: FontWeight.w600,
            color: context.colors.encre,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        InkWell(
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: color),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.firewallTitle,
                        style: TextStyle(
                          fontSize: AppText.intitule,
                          fontWeight: FontWeight.w500,
                          color: context.colors.encre,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        status.summary(l),
                        style: TextStyle(
                          fontSize: AppText.detail,
                          color: context.colors.secondaire,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Icon(Icons.chevron_right, color: context.colors.discret),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
