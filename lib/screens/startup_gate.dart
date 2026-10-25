import 'package:material_ui/material_ui.dart';

import '../services/onboarding_store.dart';
import 'onboarding_screen.dart';

/// Premier écran : la présentation si elle n'a jamais été vue, sinon [home].
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.store, required this.home});

  final OnboardingStore store;
  final Widget home;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool? _done; // null : lecture en cours

  @override
  void initState() {
    super.initState();
    widget.store.isDone().then((done) {
      if (mounted) setState(() => _done = done);
    });
  }

  Future<void> _finish() async {
    setState(() => _done = true);
    try {
      await widget.store.markDone();
    } on Exception {
      // Pas grave : la présentation reviendra au prochain lancement.
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_done) {
      // Lecture très courte : fond uni, pas d'accueil qui clignote.
      null => const Scaffold(),
      false => OnboardingScreen(onDone: _finish),
      true => widget.home,
    };
  }
}
