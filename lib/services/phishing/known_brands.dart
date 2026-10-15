/// Une marque souvent imitée par les arnaqueurs, et ses vrais sites.
class KnownBrand {
  const KnownBrand({
    required this.name,
    required this.keywords,
    required this.officialDomains,
  });

  final String name; // nom affiché à l'utilisateur
  final List<String> keywords; // mots cherchés dans le nom de domaine (minuscules)
  final List<String> officialDomains; // le domaine et ses sous-domaines sont sûrs
}

// TODO(avant publication) : vérifier à la main chaque domaine officiel
// ci-dessous sur le site ou l'appli de l'organisme. Un domaine officiel
// oublié = fausse alerte ; un domaine faux = arnaque non détectée.
//
// Pour ajouter une marque : copier un bloc KnownBrand et l'adapter.
// Les mots-clés de moins de 5 lettres doivent apparaître seuls dans le
// domaine (« stb-tn.xyz ») pour éviter les fausses alertes (« bestbuy »).
const knownBrands = [
  // La Poste et ses services de paiement
  KnownBrand(
    name: 'La Poste Tunisienne',
    keywords: ['poste', 'laposte'],
    officialDomains: ['poste.tn'],
  ),
  KnownBrand(
    name: 'e-Dinar (La Poste)',
    keywords: ['edinar'],
    officialDomains: ['poste.tn'],
  ),
  KnownBrand(
    name: 'D17 (La Poste)',
    keywords: ['d17'],
    officialDomains: ['poste.tn', 'd17.tn'],
  ),

  // Banques
  KnownBrand(
    name: 'BIAT',
    keywords: ['biat'],
    officialDomains: ['biat.com.tn'],
  ),
  KnownBrand(
    name: 'STB',
    keywords: ['stb', 'stbbank'],
    officialDomains: ['stb.com.tn'],
  ),
  KnownBrand(
    name: 'BNA',
    keywords: ['bna'],
    officialDomains: ['bna.tn'],
  ),
  KnownBrand(
    name: 'Attijari Bank',
    keywords: ['attijari', 'attijaribank'],
    officialDomains: ['attijaribank.com.tn'],
  ),
  KnownBrand(
    name: 'Amen Bank',
    keywords: ['amenbank'],
    officialDomains: ['amenbank.com.tn'],
  ),
  KnownBrand(
    name: 'BH Bank',
    keywords: ['bhbank'],
    officialDomains: ['bhbank.tn'],
  ),
  KnownBrand(
    name: 'UIB',
    keywords: ['uib'],
    officialDomains: ['uib.com.tn'],
  ),
  KnownBrand(
    name: 'UBCI',
    keywords: ['ubci'],
    officialDomains: ['ubci.tn'],
  ),
  KnownBrand(
    name: 'ATB',
    keywords: ['atb'],
    officialDomains: ['atb.com.tn'],
  ),
  KnownBrand(
    name: 'Banque Zitouna',
    keywords: ['zitouna', 'banquezitouna'],
    officialDomains: ['banquezitouna.com'],
  ),

  // Opérateurs
  KnownBrand(
    name: 'Ooredoo',
    keywords: ['ooredoo'],
    officialDomains: ['ooredoo.tn', 'ooredoo.com'],
  ),
  KnownBrand(
    name: 'Orange',
    keywords: ['orange'],
    officialDomains: ['orange.tn', 'orange.com', 'orange.fr'],
  ),
  KnownBrand(
    name: 'Tunisie Telecom',
    keywords: ['tunisietelecom', 'tunisietelecome'],
    officialDomains: ['tunisietelecom.tn'],
  ),

  // Organismes sociaux
  KnownBrand(
    name: 'CNSS',
    keywords: ['cnss'],
    officialDomains: ['cnss.tn'],
  ),
  KnownBrand(
    name: 'CNAM',
    keywords: ['cnam'],
    officialDomains: ['cnam.nat.tn'],
  ),

  // Paiement en ligne
  KnownBrand(
    name: 'Flouci',
    keywords: ['flouci'],
    officialDomains: ['flouci.com'],
  ),
  KnownBrand(
    name: 'Sobflous',
    keywords: ['sobflous'],
    officialDomains: ['sobflous.tn'],
  ),
  KnownBrand(
    name: 'ClicToPay',
    keywords: ['clictopay'],
    officialDomains: ['clictopay.com.tn'],
  ),
  KnownBrand(
    name: 'Monétique Tunisie',
    keywords: ['monetique', 'monetiquetunisie'],
    officialDomains: ['monetiquetunisie.com'],
  ),
];
