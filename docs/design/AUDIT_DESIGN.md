# Audit visuel de Sentinel 1.1.0

Date : 19 novembre 2026. Objet : repérer ce qui nuit à la clarté et à la cohérence de l'interface, sans toucher aux fonctions.

## Méthode

L'émulateur Pixel 8 n'a pas pu démarrer sur ce poste (accélération matérielle absente : hyperviseur Windows arrêté, pas de droits administrateur pour l'activer ; voir `docs/NOTES_AUTONOMES.md`). Les captures ont donc été faites par le **moteur de rendu de Flutter**, avec :

- le vrai format du Pixel 8 (1080 × 2400, densité 2,625) ;
- les vraies polices (Readex Pro et icônes Material) ;
- un faux Android qui renvoie des données fictives (téléphone, Wi-Fi, pare-feu, apps, bilan) ;
- un coffre d'exemple (aucun vrai mot de passe).

Banc de capture : `test/design/screens_capture_test.dart` (ignoré par `flutter test` sauf si `SENTINEL_CAPTURE` est défini). 21 écrans × 3 variantes (français clair, français sombre, arabe clair) = 63 captures, dans `docs/design/avant/`. Les pages longues ont aussi été rendues en entier (2400 dp de haut) pour l'audit.

Limite : la barre d'état et la barre de gestes sont dessinées ; le rendu des ombres et de l'anticrénelage peut différer légèrement d'un vrai téléphone.

## Ce qui va bien (à garder)

- Identité nette : fond chaux, bleu de Sidi Bou, arche du score, séparateurs fins, pas de cartes ni d'ombres.
- Couleurs centralisées dans `AppColors` (aucune couleur codée en dur hors du visualiseur de photos, noir voulu).
- Thème sombre « nuit » cohérent, contraste AA vérifié par des tests.
- Arabe : la mise en page se retourne correctement (chevrons, icônes, « +10 » forcé de gauche à droite).
- Accessibilité solide : zones de 48 dp, libellés TalkBack, police à 200 % testée.

## Problèmes relevés

Gravité : **G** gênant pour l'utilisateur, **M** moyen (incohérence visible), **F** faible (dette de code, invisible).

### 1. Espacements

| # | Gravité | Constat | Où |
|---|---|---|---|
| E1 | M | Marge de page de 28 dp, hors de toute échelle ; espacements verticaux de 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48 dp : 14 valeurs différentes. | tous les écrans (163 `EdgeInsets`, 200+ `SizedBox`) |
| E2 | M | Lignes de liste : padding vertical tantôt 10, 12, 14 ou 16 dp. Les lignes d'Applications, du Coffre, des Réglages et de l'Accueil n'ont pas la même hauteur. | `apps_screen`, `vault_list_view`, `settings_screen`, `action_tile` |
| E3 | F | Écart entre titre et sous-titre d'une ligne : 2 dp ici, 4 dp là. | lignes à deux niveaux |

### 2. Tailles de texte

| # | Gravité | Constat | Où |
|---|---|---|---|
| T1 | M | 12 tailles différentes (12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 28, 72). 14 et 15, 17 et 18, 22 et 24 se côtoient sans raison. | 239 `fontSize:` |
| T2 | M | Titres d'écrans poussés : 24 dp (Pare-feu, Bilan, Détail d'une app) contre 28 dp pour les onglets ; intertitres de 17, 18 ou 20 dp. | `text_page`, `firewall_screen`, `weekly_report_screen` |

### 3. Couleurs

| # | Gravité | Constat | Où |
|---|---|---|---|
| C1 | M | En clair, les interrupteurs, cases à cocher et curseurs prennent le bleu généré par `ColorScheme.fromSeed` (#3D5F90 environ), pas le bleu Sentinel : deux bleus différents sur le même écran. | pare-feu, applications, réglages |
| C2 | F | Opacités locales (`encre` à 70 % ou 80 %) au lieu des couleurs `secondaire` / `discret` du thème. | `apps_screen`, `text_page`, `score_arch` |
| C3 | F | Le visualiseur de photos du coffre utilise `Colors.black` / `Colors.white` : voulu (fond noir pour une photo), à documenter. | `vault_document_screen` |

### 4. Boutons

| # | Gravité | Constat | Où |
|---|---|---|---|
| B1 | M | 33 `FilledButton.styleFrom` et 46 `TextButton.styleFrom` recopiés écran par écran, avec des variantes (couleur de texte précisée ou non, gras ou non). | partout |
| B2 | G | Bouton « Ouvrir quand même » désactivé presque invisible (contour très pâle sur fond chaux). | Liens, résultat dangereux |
| B3 | M | Aucun retour pendant une action longue : le bouton se grise, sans indicateur (vérification d'un lien, ouverture du coffre, mise à jour des listes). | Liens, Coffre, Pare-feu |
| B4 | F | Dialogues : 10 `AlertDialog` qui redéfinissent chacun fond, teinte et styles des boutons. | Liens, Coffre, Réglages |

### 5. Alignements et hiérarchie

| # | Gravité | Constat | Où |
|---|---|---|---|
| H1 | M | Accueil : le score, les actions, le Wi-Fi et le pare-feu se suivent avec le même poids ; rien ne sépare « ce qu'il faut faire » de « ce qui vous protège ». Le Bilan de la semaine flotte sous un trait isolé. | `home_screen` |
| H2 | M | Coffre verrouillé et Création : l'icône de cadenas est centrée alors que le titre et le champ sont alignés à gauche. | `unlock_view`, `create_vault_view` |
| H3 | F | Six classes privées `_InfoRow`, cinq `_…Row`, deux `_InfoMessage`, deux `_CountRow` : même dessin, recopié. | voir liste en annexe |

### 6. Verdicts et statuts

| # | Gravité | Constat | Où |
|---|---|---|---|
| V1 | G | Verdict d'un lien : « Dangereux » en grand texte rouge, sans icône. Le texte porte le sens, mais l'œil cherche d'abord un signe ; pour un daltonien, rouge / ocre / vert se confondent à distance. | `verdict_section` (Liens, QR code) |
| V2 | M | Niveau de risque d'une app : mot coloré seul (« Élevé », « Faible »), pas d'icône, et pas de repère visuel dans la liste. | `risk_level_text` (Applications, Détail) |
| V3 | F | Wi-Fi « Correct » : même principe, mot coloré seul. | `wifi_section` |

### 7. Textes coupés et grandes polices

Aucun texte coupé observé à 100 %. À 200 %, les tests existants passent (aucun débordement). Points fragiles : la ligne d'actions du coffre (Rechercher + Ajouter) et l'en-tête du coffre (titre + Réglages + Verrouiller), déjà protégés par `Wrap`.

### 8. Icônes

| # | Gravité | Constat | Où |
|---|---|---|---|
| I1 | F | Mélange d'icônes pleines et contour dans les lignes (clé pleine, note contour, bouclier contour, USB plein). | Accueil, Coffre |
| I2 | M | L'icône adaptative Android n'a pas de version monochrome : sur Android 13+ avec les icônes à thème, Sentinel reste en couleurs au milieu des autres. | `mipmap-anydpi-v26` |

### 9. États vides

| # | Gravité | Constat | Où |
|---|---|---|---|
| X1 | G | États vides tristes : une icône Material générique (grille, cadenas) perdue au milieu d'un grand vide, sans lien avec l'identité Sidi Bou. | Applications, Coffre, rapports d'analyse |
| X2 | M | « Rien à corriger » de l'Accueil : une simple phrase grise, pas de récompense visuelle. | `home_screen` |

### 10. Mouvement

| # | Gravité | Constat | Où |
|---|---|---|---|
| M1 | M | Changement d'onglet sec (aucune transition) ; écrans poussés avec la transition Android par défaut. | `main_shell` |
| M2 | M | L'arche du score s'anime 1,4 s sans tenir compte du réglage « Supprimer les animations » d'Android. | `score_arch` |

## Priorités retenues

1. Système de design : jetons (espacements, rayons, textes, durées) et composants communs (E1-E3, T1-T2, B1, B4, H3, C2).
2. Verdicts lisibles : couleur + icône + texte (V1-V3) et bouton désactivé visible (B2).
3. Hiérarchie de l'Accueil (H1) et arche animée sobre qui respecte le réglage système (M2).
4. États vides illustrés dans l'esprit Sidi Bou (X1, X2).
5. Transitions douces et retours de chargement cohérents (M1, B3).
6. Bleu unique pour les contrôles (C1), alignements (H2), icône monochrome (I2).

## Annexe : composants dupliqués

`_InfoRow` (app_detail, qr_result, sensitive_access, wifi_section), `_CountRow` (firewall, app_report), `_InfoMessage` (home, apps), `_TwoLines` (links), `_Row` (settings), `_SettingsRow` (vault_settings), `_SwitchRow` (blocklist_sections), `_SectionTitle` (app_detail), `_PageTitle` (apps).
