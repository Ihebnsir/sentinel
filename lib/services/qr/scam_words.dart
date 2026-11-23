/// Mots typiques des arnaques dans un message pré-rempli (WhatsApp,
/// Telegram, e-mail…) : demande de code, de mot de passe ou d'argent.
/// Français, anglais, arabe et derja (lettres arabes ou latines).
/// Calcul pur, sans Flutter.
library;

/// Mots seuls, comparés mot à mot (déjà normalisés, voir [normalizeForScan]).
const _scamTokens = {
  // Français
  'code', 'codes', 'otp', 'pin', 'cvv', 'cvc', 'mdp', 'paiement', 'payer',
  'payez', 'paye', 'virement', 'envoie', 'envoyez', 'envoyer', 'recharge',
  'rechargez', 'iban', 'rib',
  // Anglais
  'password', 'passcode', 'pay', 'payment', 'transfer', 'send', 'wire',
  // Derja en lettres latines (« arabizi »)
  'ab3athli', 'b3athli', 'ab3ath', 'ba3thli', 'abaathli', 'ab3atli',
  'codek', 'lcode', 'el-code', 'flous', 'flouss', '7awel', '7awelli',
  'hawelli', 'chargili', 'charji',
  // Arabe standard et derja en lettres arabes
  'كود', 'كودك', 'رمز', 'ادفع', 'دفع', 'تحويل', 'حولي', 'حوللي', 'ارسل',
  'ارسلي', 'ابعث', 'ابعثلي', 'بعثلي', 'ابعتلي', 'ابعتهولي', 'فلوس', 'فلوسك',
  'شحن', 'شارجي', 'سدد', 'خلص',
};

/// Expressions de plusieurs mots, cherchées telles quelles.
const _scamPhrases = [
  'mot de passe',
  'code de verification',
  'code de confirmation',
  'code secret',
  'code recu',
  'carte bancaire',
  'numero de carte',
  'envoie moi',
  'envoyez moi',
  'western union',
  'frais de livraison',
  'frais de dossier',
  'verification code',
  'confirmation code',
  'send me',
  'gift card',
  'card number',
  'bank details',
  'كلمه السر',
  'كلمه المرور',
  'الرقم السري',
  'رقم سري',
  'رمز التحقق',
  'رمز التاكيد',
  'رقم البطاقه',
  'بطاقه بنكيه',
];

/// Expressions banales qui contiennent « code » sans danger.
const _harmless = ['qr code', 'code qr', 'code postal', 'zip code'];

const _latinAccents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ç': 'c', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  // Lettres arabes qui s'écrivent de plusieurs façons.
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ؤ': 'و',
  'ئ': 'ي',
};

// Voyelles arabes (tachkil), tatouil et caractères invisibles.
final _ignored = RegExp(
  '[\u{064B}-\u{0652}\u{0640}\u{00AD}\u{200B}-\u{200F}\u{202A}-\u{202E}\u{2060}-\u{2069}\u{FEFF}]',
);
final _separators = RegExp(r"[^\p{L}\p{N}7-]+", unicode: true);

/// Minuscules, sans accents ni voyelles arabes, une seule espace entre
/// les mots. « Envoie-moi le CODE ! » → « envoie moi le code ».
String normalizeForScan(String text) {
  final lower = text.toLowerCase().replaceAll(_ignored, '');
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    out.write(_latinAccents[c] ?? c);
  }
  return out
      .toString()
      .replaceAll('-', ' ')
      .replaceAll(_separators, ' ')
      .trim();
}

// Préfixes arabes collés au mot : « و » (et), « ف », « ال » (le)…
const _arabicPrefixes = ['وال', 'فال', 'بال', 'ال', 'و', 'ف'];

Iterable<String> _variants(String token) sync* {
  yield token;
  for (final prefix in _arabicPrefixes) {
    if (token.startsWith(prefix) && token.length > prefix.length + 1) {
      yield token.substring(prefix.length);
    }
  }
}

/// Les mots d'arnaque trouvés dans [text], dans l'ordre, sans doublon.
/// Liste vide : rien de suspect. Linéaire : un texte énorme reste rapide.
List<String> findScamWords(String text) {
  // Au-delà, un message pré-rempli n'a plus de sens : on lit le début.
  final head = text.length > 5000 ? text.substring(0, 5000) : text;
  var normalized = ' ${normalizeForScan(head)} ';
  for (final phrase in _harmless) {
    normalized = normalized.replaceAll(' $phrase ', ' ');
  }
  final found = <String>[];
  for (final phrase in _scamPhrases) {
    if (normalized.contains(' $phrase ')) found.add(phrase);
  }
  for (final token in normalized.split(' ')) {
    if (token.isEmpty) continue;
    for (final variant in _variants(token)) {
      if (_scamTokens.contains(variant)) {
        if (!found.contains(variant)) found.add(variant);
        break;
      }
    }
  }
  return found;
}
