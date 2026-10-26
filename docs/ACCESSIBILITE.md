# Accessibilité de Sentinel

Audit du 26 octobre 2026 : lecteur d'écran (TalkBack), zones tactiles, contraste et grande police. Ce document dit ce qui a été vérifié, ce qui a été corrigé, et ce qui ne l'a pas été.

## Comment c'est vérifié

Test automatique : `test/accessibility_test.dart`, lancé avec les autres par `flutter test`.

Chaque écran est affiché sur un téléphone de **360 dp de large** (petit Android courant). Il est vérifié trois fois : thème clair, thème sombre, puis **police système à 200 %**. Chaque passage applique les règles de Flutter :

| Règle Flutter | Ce qu'elle exige |
|---|---|
| `androidTapTargetGuideline` | toute zone qu'on touche fait au moins 48 × 48 dp |
| `labeledTapTargetGuideline` | tout élément qu'on touche a un nom lu par TalkBack |
| `textContrastGuideline` | texte au niveau WCAG AA : 4,5:1, ou 3:1 pour le grand texte |
| à 200 % : aucune erreur de débordement | pas de texte coupé ni de bandes jaunes et noires |

Le test charge la vraie police (Readex Pro). La police de test de Flutter a des glyphes carrés presque deux fois plus larges : elle signalerait à 200 % des débordements qui n'existent pas.

**19 écrans vérifiés** :

- **Onglets et écrans de l'app** : accueil (arche du score, actions, Wi-Fi), applications, messages, résultat d'un QR code, détail d'une app à risque, conseils en cas de logiciel espion, pare-feu, choix de l'app à analyser, rapport d'analyse, Réglages, politique de confidentialité, présentation du premier lancement.
- **Coffre** : création, déverrouillage, clé de récupération, liste des éléments, mot de passe (générateur et force), santé des mots de passe, réglages du coffre.

Annonces TalkBack vérifiées une par une (même fichier, groupe « annonces TalkBack ») :

- l'arche se lit en une phrase, « Score de sécurité : 80 sur 100 ». Ni le chiffre qui défile ni « sur 100 » ne sont lus à part ;
- sur l'accueil, l'arche annonce le vrai score calculé ;
- l'arche vide annonce « Analyse en cours… » ;
- une barre de chargement a un nom et s'annonce d'elle-même ;
- un interrupteur se lit avec son texte et son état (activé ou désactivé), et l'état suit l'appui ;
- le verdict d'un message (« Arnaque probable », avec la probabilité) s'annonce dès qu'il s'affiche et compte comme un titre ;
- la case « J'ai compris » de la création du coffre se lit avec sa phrase ;
- le bouton Réglages de l'accueil a un nom et fait 48 dp.

## Ce qui a été corrigé

### Lecteur d'écran (TalkBack)

- **Arche du score** : une seule phrase, « Score de sécurité : 80 sur 100 » (traduite en anglais et en arabe). Le score final est lu tout de suite, sans attendre la fin de l'animation. Pendant l'analyse, « Analyse en cours… » est annoncé sans qu'on ait à toucher l'arche (*live region*).
- **Interrupteurs** : 8 interrupteurs étaient lus « Interrupteur, désactivé » sans dire lequel. Leur texte est maintenant lu avec eux (`MergeSemantics`) : pare-feu, protection automatique, listes de blocage, DNS non chiffré, apps système, générateur de mot de passe, empreinte, vérification des fuites.
- **Case « J'ai compris »** du coffre : elle était lue sans nom. Elle est maintenant lue avec sa phrase.
- **Chargements** : les barres et le cercle de chargement disent « Chargement en cours », ou « Analyse en cours… » pour un message ou un QR code. Ils s'annoncent dès qu'ils apparaissent. Nouveau widget `LoadingBar` (`lib/widgets/loading_bar.dart`), utilisé partout où il y avait une barre de chargement.
- **Résultats d'analyse** : le verdict d'un message ou d'un QR code (titre et probabilité ensemble) s'annonce dès qu'il apparaît et sert de titre pour la navigation de TalkBack. Le message « analyse impossible » s'annonce aussi.
- **Barre de force du mot de passe** : elle est muette pour TalkBack. La phrase juste en dessous (« Force : moyen ») dit déjà la même chose, sans pourcentage incompréhensible.
- **Icônes d'apps** (images) : ignorées par TalkBack, car le nom de l'app est toujours écrit à côté. Avant, chaque icône ajoutait une « image » sans nom.
- **Titre « Coffre »** marqué comme titre (navigation par titres).

Déjà en place et vérifié : les 5 boutons-icônes ont une info-bulle (Réglages, réglages du coffre, afficher / masquer le mot de passe, supprimer un élément du coffre, retirer un domaine de la liste blanche), lue par TalkBack. Les icônes décoratives (`Icon` sans texte) ne sont pas lues. Les onglets du bas ont leur nom.

### Zones tactiles

- **Bouton Réglages de l'accueil** : 40 × 40 dp (forme « compacte ») → 48 × 48.
- **Lien stopstalkerware.org** (texte sélectionnable, appui long pour copier) : 21 dp de haut → 48.

### Contraste (WCAG AA)

Le thème sombre était déjà au niveau AA. Le thème clair avait des écarts, connus et notés lors du thème sombre :

| Couleur (thème clair) | Avant | Après |
|---|---|---|
| Ocre (« Suspect », « Modéré », force « moyen », Wi-Fi faible…) | #E0A526 : 2,0:1 | #8A6100 : **5,2:1** |
| Texte discret (notes, indications) | encre à 45 % : 2,7:1 | encre à 64 % : **4,8:1** |
| Texte secondaire | encre à 64 % : 4,8:1 | encre à 70 % : **5,8:1** (reste plus foncé que le discret) |
| Onglet inactif (barre du bas) | encre à 50 % : 3,2:1 | texte secondaire : **5,8:1** |
| Gris à 30–50 % codés en dur (ligne de version Android, sous-titres des Réglages, crédit de la liste d'espions, chevrons, QR vide) | 1,9 à 3,2:1 | couleurs du thème (`discret`, `secondaire`) |

Effet visible : l'ocre du thème clair est un ambre plus foncé, partout (textes, icônes, arche d'un score de 45 à 69). Sur cette arche, le chiffre passe de l'encre au blanc (5,5:1), choisi automatiquement par `textOn`.

### Police à 200 %

- **Rangées « Annuler … Valider »** : à 200 %, les deux boutons ne tenaient plus sur une ligne (débordement de 16 dp sur la création du coffre). Nouveau widget `ActionsRow` (`lib/widgets/actions_row.dart`) : un bouton à chaque bout, et si les textes ne tiennent pas, les boutons passent l'un sous l'autre, alignés du côté de la fin. 10 rangées concernées : création du coffre, déverrouillage par la clé, restauration, offre de clé de récupération, copier / générer, Messages (Coller / Effacer / Analyser), explications du pare-feu et de la protection, mise à jour des listes, choix de la durée d'analyse.
- **En-tête du coffre** (« Coffre », roue dentée, « Verrouiller ») : les boutons passent sous le titre s'ils ne tiennent pas.

### Ordre de lecture

TalkBack lit dans l'ordre de l'écran, de haut en bas, ce qui correspond au sens : titre, arche, actions conseillées, Wi-Fi. Les regroupements ci-dessus évitent de lire un texte puis, séparément, son interrupteur. En arabe, Flutter inverse l'ordre droite / gauche avec la mise en page (RTL), et `ActionsRow` suit ce sens.

### Clé de récupération (SEN-13)

Rien n'a changé dans la protection : la fenêtre du coffre reste marquée `setAccessibilityDataSensitive` (Android 14+, `VaultProtection.kt`). Seuls les vrais outils d'accessibilité (TalkBack, Switch Access) peuvent lire la clé. Aucun libellé ajouté ne contient la clé ni un mot de passe. Le test Kotlin `VaultPolicyTest` passe (`./gradlew testDebugUnitTest`). L'écran de la clé est dans l'audit (zones tactiles, contraste, 200 %).

## Limites

- **Pas d'essai sur un vrai téléphone** (règle du projet : pas de `flutter run`). Tout est vérifié par l'arbre d'accessibilité de Flutter, celui que TalkBack reçoit. Restent à essayer à la main avec TalkBack :
  - l'ordre réel des annonces (une *live region* peut être coupée par une autre annonce) ;
  - le rendu de la police à 200 % sur un appareil, en particulier en arabe ;
  - la clé de récupération lue par TalkBack, et masquée aux autres services sur Android 14+.
- **Écrans non couverts par le test** : feuilles du bas (détails du Wi-Fi, explications, choix de la durée d'analyse), boîtes de dialogue, liste blanche du pare-feu, restauration d'une sauvegarde, récupération par la clé, notifications, écrans d'Android (empreinte, sélecteur de fichiers, page des licences). Leurs rangées de boutons utilisent maintenant `ActionsRow`, mais ils n'ont pas été vérifiés un par un.
- **Une seule langue testée** (français). L'anglais est en général plus court. L'arabe utilise la même police et la même mise en page, mais n'a pas été vérifié à 200 %.
- **Contraste mesuré sur le texte seulement** (`textContrastGuideline`). Les icônes et les lignes fines ne sont pas mesurées : les séparateurs (`ligne`) restent volontairement pâles (décoratifs), et l'icône grise d'une app sans icône est décorative.
- **Au-delà de 200 %**, rien n'est garanti. Android permet jusqu'à 200 % pour la police (« Taille de police » maximale).
- **L'arche** elle-même garde une taille fixe (220 × 300 dp). Le chiffre grossit avec la police et tient jusqu'à 200 %.
