import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../services/phishing/known_brands.dart';
import '../services/phishing/message_analyzer.dart';
import '../services/phishing/phishing_model.dart';

/// Même nom que dans BackgroundAnalyzer.kt, sinon les messages se perdent.
const backgroundAnalysisChannel = MethodChannel(
  'com.iheb.sentinel/background_analysis',
);

/// Point d'entrée du moteur Flutter « headless » (sans écran), lancé par
/// BackgroundAnalyzer.kt quand un message arrive.
/// vm:entry-point : empêche le compilateur de supprimer cette fonction,
/// que rien n'appelle côté Dart.
@pragma('vm:entry-point')
void backgroundAnalyzerMain() {
  // Nécessaire pour les canaux et la lecture des assets (le modèle).
  WidgetsFlutterBinding.ensureInitialized();
  backgroundAnalysisChannel.setMethodCallHandler(_onNativeCall);
  // Prévient Kotlin qu'on écoute : il peut envoyer les messages en attente.
  backgroundAnalysisChannel.invokeMethod<void>('ready');
}

Future<Map<String, Object>> _onNativeCall(MethodCall call) async {
  if (call.method != 'analyze') throw MissingPluginException();
  final args = call.arguments as Map<Object?, Object?>;
  final text = args['text'] as String? ?? '';
  final packageName = args['packageName'] as String? ?? '';
  final isSms = args['isSms'] as bool? ?? false;
  try {
    final model = await loadPhishingModel();
    await loadKnownBrands();
    final analysis = analyzeMessage(text, model.predict(text));
    return {
      ...backgroundResponseFor(analysis),
      'alertTitle': alertTitleFor(packageName, isSms: isSms),
    };
  } catch (_) {
    // Erreur sans détail : le texte du message ne doit jamais en sortir.
    throw PlatformException(code: 'ANALYSIS_FAILED');
  }
}

/// Phrase de secours si l'analyse n'a trouvé aucune raison précise.
const defaultAlertReason =
    'Ce message ressemble aux arnaques connues. Ne cliquez sur aucun lien.';

/// La réponse envoyée à Kotlin : verdict, pourcentage, raison principale.
/// verdict = nom technique stable ("arnaque", "suspect", "rien"),
/// pas le texte affiché, pour que Kotlin puisse le comparer sans risque.
/// La raison est affichée dans l'alerte : ses domaines sont neutralisés
/// (« site[.]xyz ») pour qu'Android n'en fasse pas un lien cliquable.
Map<String, Object> backgroundResponseFor(MessageAnalysis analysis) => {
  'verdict': analysis.verdict.name,
  'percent': analysis.percent,
  'mainReason': analysis.reasons.isEmpty
      ? defaultAlertReason
      : defangDomains(analysis.reasons.first),
};

// Un nom de domaine ou une adresse IP : des mots séparés par des points.
final _domainLike = RegExp(
  r'[a-z0-9-]+(?:\.[a-z0-9-]+)+',
  caseSensitive: false,
);
final _letter = RegExp(r'[a-z]', caseSensitive: false);
final _ip = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');

/// Rend les domaines non cliquables, comme les analystes sécurité :
/// « poste-tn-livraison.xyz » → « poste-tn-livraison[.]xyz ».
/// Les nombres comme « 3.5 » ne sont pas touchés.
String defangDomains(String text) => text.replaceAllMapped(_domainLike, (m) {
  final word = m[0]!;
  final isDomain = _letter.hasMatch(word.split('.').last) || _ip.hasMatch(word);
  return isDomain ? word.replaceAll('.', '[.]') : word;
});

/// Nom affiché des messageries « chat » surveillées.
const _chatAppNames = {
  'com.whatsapp': 'WhatsApp',
  'com.whatsapp.w4b': 'WhatsApp Business',
  'com.facebook.orca': 'Messenger',
  'org.telegram.messenger': 'Telegram',
  'com.viber.voip': 'Viber',
};

/// Titre de l'alerte selon l'app d'où vient le message.
String alertTitleFor(String packageName, {bool isSms = false}) {
  if (isSms) return 'Arnaque probable dans un SMS';
  final app = _chatAppNames[packageName];
  if (app == null) return 'Arnaque probable dans un message';
  return 'Arnaque probable sur $app';
}
