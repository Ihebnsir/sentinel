# Sentinel — détecteur d'arnaques SMS (partie Python)

Ce dossier entraîne le modèle utilisé par l'onglet **Messages** de l'application.
Le modèle tourne ensuite **100 % sur le téléphone, hors ligne** : l'app Dart ne fait
que relire `assets/models/phishing_model.json` et refaire les calculs décrits plus bas.

Modèle : TF-IDF sur n-grammes de caractères (`char_wb`, 2 à 5) + régression logistique.
Il est **explicable** : le score d'un message est une somme de poids, un par n-gramme,
donc on peut toujours montrer « quels morceaux du message ont fait monter le score ».

## Fichiers

| Fichier | Rôle |
|---|---|
| `data/messages_seed.csv` | ~400 messages **synthétiques** (`source = synthetique`) |
| `data/messages_perso.csv` | Tes vrais messages (`source = reel`), vide au départ |
| `train.py` | Entraîne, évalue, exporte le modèle et les fixtures de parité |
| `requirements.txt` | Versions exactes des bibliothèques |
| `../assets/models/phishing_model.json` | Modèle exporté (lu par Flutter) |
| `../test/fixtures/phishing_parity.json` | 38 textes + probabilités exactes (test Dart) |

Format CSV : `text,label,langue,source` avec `label` = `0` (normal) ou `1` (arnaque) et
`langue` parmi `fr`, `ar`, `derja_latin`, `derja_arabe`, `en`. Mets le texte entre
guillemets s'il contient une virgule (Excel / LibreOffice le font tout seuls).
**Masque les numéros de téléphone et les données personnelles** avant d'ajouter un vrai message.

## Réentraîner

Depuis la racine du projet, dans PowerShell :

```powershell
# Une seule fois : créer l'environnement et installer les dépendances
python -m venv ml\.venv
ml\.venv\Scripts\python.exe -m pip install -r ml\requirements.txt

# À chaque fois que les données changent
ml\.venv\Scripts\python.exe ml\train.py
```

Le script fusionne les deux CSV, retire les doublons, sépare 80 % / 20 % (stratifié,
`random_state=42`), choisit `C` par validation croisée, affiche les métriques puis
réécrit le modèle et les fixtures. **Après chaque réentraînement, il faut committer
les deux fichiers JSON ensemble** (la fixture est liée à une version du modèle).

La dernière étape (« Vérification de la spécification ») recalcule les probabilités
avec une implémentation **sans scikit-learn** qui suit exactement la spécification
ci-dessous. Si elle échoue, la spécification n'est plus valable.

## Format de `phishing_model.json`

```text
format_version   2 (2 : étape 0 de nettoyage, SEN-12)
version          "AAAAMMJJ-HHMMSS" (identifiant du modèle)
date             date d'entraînement (ISO 8601)
preprocessing    paramètres exacts (voir spécification)
threshold        seuil de décision (0.5 par défaut) : arnaque si proba >= threshold
intercept        b (nombre)
vocabulary       { "n-gramme": index }      (index de 0 à N-1)
idf              [N nombres]  idf[index]
coef             [N nombres]  coef[index]
metrics_test     métriques sur le jeu de test (indicatives)
```

Les nombres sont écrits avec assez de chiffres pour que `double.parse` en Dart
retrouve exactement le même `double` que Python.

## Spécification exacte du prétraitement (à reproduire en Dart)

C'est ce que fait `TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 5),
sublinear_tf=True, preprocessor=preprocess)` de scikit-learn 1.9.1
(`preprocess` = étape 0 puis minuscules), suivi de la régression
logistique. Les étapes sont à appliquer **dans cet ordre**.

### Règle n° 0 : on compte en points de code Unicode, pas en unités UTF-16

Python découpe les chaînes par **point de code**. En Dart, une `String` est en UTF-16 :
un emoji comme 😀 vaut 2 unités (`'😀'.length == 2`) mais 1 point de code.
→ En Dart, travaille sur `text.runes.toList()` et reconstruis les n-grammes avec
`String.fromCharCodes(...)`. Ne jamais utiliser `substring` sur la chaîne d'origine.

Aucune normalisation Unicode n'est faite (ni NFC, ni NFD), et les accents sont gardés :
`"café"` (é précomposé, U+00E9) et `"café"` (e + accent combinant) donnent des
n-grammes différents. En dehors de l'étape 0, ne pas « nettoyer » le texte en Dart.

### Étape 0 : texte tel qu'il s'affiche (format 2, SEN-12)

Les escrocs cachent des mots avec des caractères invisibles (`pay` + U+200B + `pal`)
ou écrivent un lien à l'envers après un U+202E (RLO), qui l'affiche à l'endroit.
On analyse donc ce que l'utilisateur **voit**. En parcourant les points de code,
avec une pile d'ouvertures (vide au départ) :

1. séparateur de paragraphe (`preprocessing.bidi.paragraph_separators` :
   U+000A, U+000D, U+001C..U+001E, U+0085, U+2029) : on vide la pile et on garde
   le caractère ;
2. ouverture (`bidi.openers` : U+202A, U+202B, U+202D, U+202E) : on l'empile ;
3. U+202C (`bidi.pdf`) : on dépile (si la pile n'est pas vide) ;
4. caractère de `preprocessing.hidden_codepoints` : on le retire ;
5. sinon : si le haut de la pile est U+202E (`bidi.rlo`), le caractère va dans
   un segment qui sera **retourné** ; sinon il est gardé tel quel.

Un segment retourné est écrit (à l'envers) dès qu'on rencontre l'un des cas 1 à 3,
ou à la fin du texte. Caractères retirés :

```text
U+00AD           trait d'union conditionnel
U+061C           marque de lettre arabe
U+180E           séparateur de voyelles mongol
U+200B..U+200F   espace, anti-liant, liant sans largeur, marques LTR/RTL
U+202A..U+202E   enchâssements et forçages de direction
U+2060..U+2064   gluon, opérateurs invisibles
U+2066..U+2069   isolats de direction
U+FEFF           espace insécable sans largeur (BOM)
```

Exemple : `"https://" + U+202E + "zyx.etsop" + U+202C` donne `"https://poste.xyz"`.
Python : `normalize_text()` de `train.py` (passée à `TfidfVectorizer(preprocessor=...)`,
suivie de `.lower()`) ; Dart : `normalizeMessage()`. La fixture de parité contient,
pour chaque cas, le texte normalisé attendu (`normalise`).

### Étape 1 : minuscules

`texte = texte.lower()` (Python, règles Unicode complètes).
En Dart : `texte.toLowerCase()`. Les deux donnent le même résultat pour le français,
l'anglais, les chiffres et l'arabe (l'arabe n'a pas de majuscules). Différences
connues mais hors de notre périmètre : `İ` turc (Python donne 2 points de code) et le
sigma grec final. Les fixtures de parité couvrent `É` et `Ç`.

### Étape 2 : découpage en mots

Un **mot** est une suite maximale de caractères qui ne sont pas des espaces.
Les caractères d'espacement sont exactement ceux pour lesquels Python
`str.isspace()` est vrai (liste aussi dans `preprocessing.whitespace_codepoints`) :

```text
U+0009..U+000D  (tabulation, \n, \v, \f, \r)
U+001C..U+001F  (séparateurs de fichier/groupe/enregistrement/unité)
U+0020          (espace)
U+0085          (next line)
U+00A0          (espace insécable)
U+1680
U+2000..U+200A  (espaces typographiques)
U+2028, U+2029  (séparateurs de ligne / paragraphe)
U+202F          (espace insécable fine)
U+205F
U+3000          (espace idéographique)
```

Attention : U+200B (« zero width space ») n'en fait **pas** partie.
Plusieurs espaces de suite, ou des espaces au début/à la fin, ne créent jamais de mot vide.
(scikit-learn remplace d'abord les suites de 2 espaces ou plus par un seul espace,
puis fait `split()` : le résultat est identique à la règle ci-dessus.)

La ponctuation **fait partie des mots** : `"ici :"` donne les mots `ici` et `:` ;
`"laposte-tn.xyz/colis"` est un seul mot.

### Étape 3 : ajout des espaces autour de chaque mot

Chaque mot `m` devient `w = " " + m + " "` (espace U+0020). Exemple : `"ok"` → `" ok "`.

### Étape 4 : génération des n-grammes (pour chaque mot, séparément)

Soit `L` = nombre de points de code de `w`. Pour `n` = 2, 3, 4, 5 dans cet ordre :

- si `L <= n` : on ajoute **un seul** n-gramme, `w` entier, puis on **arrête**
  (on ne passe pas aux `n` suivants pour ce mot) ;
- sinon : on ajoute les `L - n + 1` sous-chaînes `w[i : i+n]` pour `i` = 0 … `L - n`.

Exemple avec `"ok"` → `w = " ok "` (L = 4) :

```text
n=2 : " o", "ok", "k "
n=3 : " ok", "ok "
n=4 : L <= 4 → " ok "  puis arrêt
```

Exemple avec `"a"` → `w = " a "` (L = 3) : `" a"`, `"a "`, puis `" a "` (n=3) et arrêt.

Un n-gramme ne traverse jamais deux mots (c'est le sens de « wb » = *word boundaries*).
Les n-grammes qui ne sont pas dans `vocabulary` sont **ignorés**.

### Étape 5 : comptage

`count[g]` = nombre de fois où le n-gramme `g` apparaît dans tout le message
(toutes tailles et tous mots confondus). Un même n-gramme vu dans deux mots compte 2.

### Étape 6 : tf sublinéaire × idf

Pour chaque n-gramme `g` du vocabulaire présent (`count[g] >= 1`), avec `j = vocabulary[g]` :

```text
x[j] = (1 + ln(count[g])) * idf[j]        ln = logarithme naturel (dart:math log)
```

(`idf` est déjà calculé et stocké. Pour info, scikit-learn l'a obtenu avec
`idf = ln((1 + n_docs) / (1 + df)) + 1`.)

### Étape 7 : normalisation L2

```text
norme = sqrt( somme des x[j]² )
si norme > 0 :  x[j] = x[j] / norme
si norme == 0 (aucun n-gramme connu, ex. texte vide) : on laisse x à zéro
```

### Étape 8 : score et probabilité

```text
z     = intercept + somme sur j de x[j] * coef[j]
proba = 1 / (1 + exp(-z))          (probabilité que ce soit une arnaque)
arnaque si proba >= threshold
```

Pour éviter un dépassement avec un `z` très négatif, calculer
`exp(z) / (1 + exp(z))` quand `z < 0`.

Pour l'explication à l'utilisateur, la contribution de chaque n-gramme est
`x[j] * coef[j]` : les plus grandes valeurs positives sont les morceaux « suspects ».

### Pseudo-code complet

```text
fonction predict(texte):
    t = minuscules(texte)
    mots = découper t sur les espaces Unicode (liste ci-dessus), sans mots vides
    count = dictionnaire vide
    pour m dans mots:
        w = points_de_code(" " + m + " ")
        pour n de 2 à 5:
            si len(w) <= n: count[w] += 1 ; sortir de la boucle n
            pour i de 0 à len(w) - n: count[w[i:i+n]] += 1
    x = {}
    pour (g, c) dans count:
        si g dans vocabulary: j = vocabulary[g]; x[j] = (1 + ln(c)) * idf[j]
    norme = sqrt(somme(v² pour v dans x))
    z = intercept
    si norme > 0: pour (j, v) dans x: z += (v / norme) * coef[j]
    retourner sigmoïde(z)
```

L'implémentation Python de référence est `reference_predict()` dans `train.py`.

### Parité exacte

`test/fixtures/phishing_parity.json` contient 38 textes (5 langues + cas limites + caractères cachés :
texte vide, espaces seuls, emojis, tabulations, espace insécable, U+200B,
accent combinant…) avec, pour chacun, `proba` et `decision` (= `z`) calculés par
scikit-learn, et `n_ngrammes_connus` (nombre de n-grammes distincts du vocabulaire
trouvés, pratique pour déboguer l'étape 4).

« Exactement » en calcul flottant veut dire : identique **à l'arrondi près**. L'ordre
des additions peut changer le dernier chiffre (~1e-16). Le test Dart doit vérifier
`(probaDart - proba).abs() < tolerance` avec `tolerance = 1e-9` : c'est des millions
de fois plus strict que nécessaire, et toute vraie erreur de prétraitement donne un
écart bien plus grand (en général > 1e-3).

## Limites à garder en tête

- Les données de départ sont **synthétiques** et écrites à la main : les scores
  affichés par `train.py` sont **trop optimistes**. Ajoute de vrais messages dans
  `messages_perso.csv` (en particulier des messages normaux variés) pour obtenir des
  chiffres crédibles.
- Dans les données synthétiques, tous les liens d'arnaque finissent en `.xyz`/`.top`
  ou `bit.ly`. Le modèle s'appuie donc beaucoup sur ces n-grammes. Les vraies
  arnaques utilisent aussi d'autres domaines (`.com`, `.tn` imités…) : il faudra des
  exemples réels pour qu'il apprenne autre chose que l'extension du domaine.
- Le modèle exporté est celui entraîné sur les 80 % d'entraînement, pour que les
  métriques stockées correspondent exactement au fichier livré.
