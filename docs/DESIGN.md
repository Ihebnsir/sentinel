# Système de design de Sentinel

Identité « Sidi Bou » : fond chaux, bleu des portes, arche de Sidi Bou Saïd, séparateurs fins, pas de cartes ni d'ombres. Ce document dit où trouver chaque règle et quel composant utiliser.

**Règle d'or : aucune valeur magique dans les écrans.** Pas de `fontSize: 15`, pas de `SizedBox(height: 16)`, pas de `Color(0x…)`. Tout passe par les jetons de `lib/theme/` et les composants de `lib/widgets/ui.dart` (un seul import qui les donne tous).

## 1. Couleurs : `lib/theme/app_colors.dart`

Lues avec `context.colors.<nom>`, deux palettes (claire et nuit) :

| Jeton | Rôle |
|---|---|
| `chaux` | fond de toutes les pages |
| `bleu` | couleur principale : boutons, liens, onglet actif, interrupteurs |
| `encre` | texte principal |
| `secondaire` | texte atténué (sous-titres) — 70 % d'encre, AA |
| `discret` | indications, éléments inactifs — AA |
| `zitouna` | vert : rien de suspect, points gagnés |
| `ocre` | avertissement |
| `rommen` | danger |
| `ligne` | séparateurs fins |
| `surCouleur` | texte posé sur une couleur pleine ; `textOn(fond)` choisit le plus lisible |

Teintes : une surface teintée (badge, arche, indicateur d'onglet) utilise la couleur à 10-12 % d'opacité. Contraste AA vérifié par `test/theme_test.dart`, `test/dark_screens_test.dart` et `test/accessibility_test.dart`.

Seule exception : le visualiseur de photos du coffre (`vault_document_screen.dart`) reste sur fond noir, comme toute visionneuse d'images.

## 2. Jetons : `lib/theme/tokens.dart`

### Espacements (`AppSpace`), échelle de 4

| Jeton | dp | Usage |
|---|---|---|
| `xs` | 4 | titre ↔ sous-titre, icône ↔ texte d'un badge |
| `sm` | 8 | petits écarts, entre deux boutons |
| `md` | 12 | entre un titre de section et son contenu |
| `lg` | 16 | padding vertical d'une ligne (`row`), icône ↔ texte (`rowGap`) |
| `xl` | 24 | marge de page (`page`, `pageTop`) |
| `xxl` | 32 | entre deux sections (`section`) |
| `xxxl` | 48 | grands vides (messages centrés) |

### Rayons (`AppRadius`)

`sm` 8 (champs de saisie, `AppRadius.field`), `md` 12 (messages, dialogues), `pill` (boutons et badges, `AppRadius.badge`).

### Textes (`AppText`), police Readex Pro

| Jeton | dp | Usage |
|---|---|---|
| `legende` | 12 | barre de navigation, crédits |
| `detail` | 13 | sous-titres, notes |
| `corps` | 15 | texte courant, boutons |
| `intitule` | 16 | titre d'une ligne |
| `section` | 18 | en-tête de section |
| `accroche` | 20 | titre d'un état vide, d'un dialogue |
| `titreSecondaire` | 24 | titre d'un écran poussé |
| `titre` | 28 | titre d'un onglet, verdict |
| `score` | 72 | chiffre de l'arche |

Graisses : `w600` titres, `w500` intitulés, normal ailleurs. Interligne du texte long : `AppText.interligne` (1,45).

### Tailles (`AppSize`)

Icônes 18 / 24 / 28, icône d'en-tête 48 (`iconHero`), icônes d'app 32 / 40 / 64, cible tactile 48 (`tap`), séparateur 1, barre de chargement 2, dessin d'état vide 120.

### Mouvement (`AppMotion`)

| Jeton | Durée | Usage |
|---|---|---|
| `rapide` | 150 ms | retour d'appui, badge qui change |
| `moyen` | 250 ms | changement d'onglet, apparition d'un bloc |
| `lent` | 350 ms | transition entre écrans |
| `score` | 1 200 ms | remplissage de l'arche du score |

Courbes : `entree` (easeOutCubic), `sortie` (easeInCubic). **Toujours** `AppMotion.of(context, durée)` : la durée tombe à zéro quand « Supprimer les animations » est actif dans Android (`AppMotion.reduced`).

## 3. Thème : `lib/theme/app_theme.dart`

Les styles par défaut sont définis une fois : boutons (pilule, 48 dp, texte `corps` `w600`), interrupteurs et cases (bleu Sentinel, plus le bleu généré par Material), dialogues, feuilles du bas, messages (`SnackBar` flottant encre sur chaux), barre d'application sans ombre, barre de navigation. Les écrans n'écrivent plus de `styleFrom` pour ces cas.

Transitions : `SoftPageTransitionsBuilder` (fondu + glissement de 3 % vers le haut, 350 ms), coupé si les animations sont supprimées. Onglets : fondu de 250 ms dans `MainShell`.

## 4. Composants : `lib/widgets/ui.dart`

| Composant | Quand l'utiliser |
|---|---|
| `PrimaryButton` | l'action clé de l'écran (un seul) ; `busy: true` pendant l'action (petit cercle, bouton inactif), `danger: true` pour supprimer, `expand: true` pleine largeur |
| `SecondaryButton` | l'action alternative ; contour bleu, bien visible même inactif |
| `TextButton` + `mutedButtonStyle` / `dangerButtonStyle` / `inlineButtonStyle` | « Annuler », action rouge, lien aligné sur le texte |
| `PageHeader` | titre d'onglet (28) ou d'écran poussé (`secondary`, 24), sous-titre facultatif ; annoncé comme titre par TalkBack |
| `SectionHeader` | intertitre d'une section (18, `w600`), élément à droite facultatif |
| `ListRow` | toute ligne de liste : icône (ou `leading`), titre, sous-titre, élément à droite, `chevron` ; hauteur minimale 48 dp |
| `AppDivider` | séparateur fin entre deux lignes (rouge pour un bloc d'alerte) |
| `StatusBadge` | statut court en pilule teintée : **icône + mot + couleur**, jamais la couleur seule |
| `VerdictHeader` | grand verdict (liens, QR, détail d'une app) : petite arche teintée avec icône, mot en grand, phrase |
| `EmptyState` | écran vide : dessin Sidi Bou, titre, explication, bouton principal |
| `SidiBouIllustration` | dessins originaux : `porte` (coffre), `fenetre` (applications), `jasmin` (tout va bien) |
| `InfoMessage` | phrase centrée à la place d'un contenu (analyse impossible) |
| `LoadingBar` (`widgets/loading_bar.dart`) | chargement : barre fine bleue, annoncée par TalkBack |

### Statuts

`StatusLevel` donne couleur et icône :

| Niveau | Couleur | Icône | Exemples |
|---|---|---|---|
| `danger` | rommen | bouclier barré | Dangereux, risque élevé, Wi-Fi ouvert |
| `warning` | ocre | point d'exclamation | Suspect, modéré, à corriger |
| `ok` | zitouna | bouclier coché | Rien de connu, faible, correct |
| `neutral` | secondaire | cercle barré | Système, inconnu |

## 5. Mise en page

- Page : marge de 24 dp à gauche et à droite, 24 dp en haut.
- Une page = un `PageHeader`, puis des sections séparées de 32 dp, chacune ouverte par un `SectionHeader`.
- Listes : `ListRow` séparées par `AppDivider`, jamais de cartes.
- Arabe : utiliser `EdgeInsetsDirectional`, `AlignmentDirectional` et les icônes qui se retournent ; forcer `TextDirection.ltr` pour les liens, numéros et « +10 ».
- Police à 200 % : préférer `Wrap` / `OverflowBar` (`ActionsRow`) aux `Row` de boutons ; tester avec `test/accessibility_test.dart`.

## 6. Captures

Banc : `test/design/screens_capture_test.dart` (rendu Flutter au format Pixel 8, données fictives). Captures avant / après : `docs/design/avant/`, `docs/design/apres/`. Captures du README : `docs/screenshots/`. Tests golden : `test/goldens/`.
