# Déployer le backend (B3b) — guide pas à pas

[← README du backend](../backend/README.md) · [Modèle de menaces](BACKEND_THREAT_MODEL.md)

Ce guide met en ligne le serveur de signalements :

- la base de données sur **Neon** (PostgreSQL gratuit) ;
- le serveur sur **Render** (conteneur Docker gratuit), à partir de GitHub.

Durée : environ 45 minutes. Aucune carte bancaire n'est nécessaire.
Vérifié avec la documentation officielle le 09/11/2026 : les écrans peuvent avoir un peu changé depuis.

> **Règle d'or.** Les URL de connexion contiennent un mot de passe. Ne les collez jamais dans un fichier du dépôt, un commit, une capture d'écran publique ou un message. Gardez-les dans un gestionnaire de mots de passe (par exemple le coffre de Sentinel).

## 0. Ce qu'il faut savoir sur les offres gratuites

| | Render (serveur) | Neon (base) |
|---|---|---|
| Région | `frankfurt` (la seule en Europe) | `aws-eu-central-1` (Francfort) |
| Veille | Après **15 min** sans requête. Le réveil prend **environ 1 min** : le premier signalement peut attendre. L'app abandonne après 10 s ; l'utilisateur réessaie. | Après **5 min** sans requête (impossible à désactiver). Le réveil prend une fraction de seconde. |
| Limites | **750 h** par mois et par compte (assez pour un service). Bande passante sortante limitée (chiffre sur la page des prix). | **1 Go** de stockage par projet (20 Go au total), **100 h de calcul** par mois et par projet, 6 h d'historique de restauration. |
| Disque | **Éphémère** : tout fichier écrit est perdu au redémarrage. D'où PostgreSQL chez Neon, pas SQLite. | Stockage géré par Neon. |
| HTTPS | Automatique. HTTP est redirigé vers HTTPS. | TLS obligatoire : Neon refuse toute connexion sans TLS. |
| Pas inclus | Pas de shell, pas de tâches ponctuelles, pas de commande avant déploiement. Les tâches planifiées coûtent au moins 1 $ par mois. | Pas de garantie de disponibilité. |

Sources : [Render, offre gratuite](https://render.com/docs/free), [Render, régions](https://render.com/docs/regions), [Render, Blueprint](https://render.com/docs/blueprint-spec), [Render, tâches planifiées](https://render.com/docs/cronjobs), [Neon, offres](https://neon.com/docs/introduction/plans), [Neon, régions](https://neon.com/docs/introduction/regions), [Neon, connexion sécurisée](https://neon.com/docs/connect/connect-securely).

**Conséquences pour Sentinel :**

- Les migrations s'appliquent **au démarrage du conteneur**, car Render gratuit n'a pas de commande avant déploiement.
- La rétention se lance **depuis votre PC** (étape 11), car Render gratuit n'a pas de tâche planifiée.
- La limite par adresse (10 par heure) est gardée en mémoire. Elle **repart à zéro** quand Render met le service en veille. La limite globale (500 nouveaux signalements par jour) est comptée dans la base : elle tient même après une veille.

## 1. Ce qu'il vous faut

- Le dépôt Sentinel sur GitHub, à jour (`git push` fait).
- Un compte GitHub.
- Sur votre PC : Python 3.14 et le dossier `backend/.venv` installé (voir le README du backend). Il sert à la revue et à la rétention.
- Un gestionnaire de mots de passe.

## 2. Créer la base sur Neon

1. Allez sur <https://neon.com> et cliquez sur **Sign up**. Choisissez **Continue with GitHub**.
2. Créez un projet :
   - **Project name** : `sentinel` ;
   - **Postgres version** : la version proposée par défaut (17 ou plus) ;
   - **Region** : **AWS Europe Central 1 (Frankfurt)**. La région ne peut plus être changée ensuite.
3. Cliquez sur **Create project**.

*Écran attendu* : le tableau de bord du projet, avec une base `neondb` et un rôle propriétaire `neondb_owner`.

## 3. Récupérer l'URL du propriétaire

1. Sur le tableau de bord, cliquez sur **Connect**.
2. Choisissez :
   - **Branch** : `main` ;
   - **Database** : `neondb` ;
   - **Role** : `neondb_owner` ;
   - **Connection pooling** : **désactivé**. Neon conseille une connexion directe pour les migrations. Le nom d'hôte ne doit **pas** contenir `-pooler`.
3. Copiez l'URL. Elle ressemble à :
   `postgresql://neondb_owner:MOT_DE_PASSE@ep-xxxx-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require`
4. Gardez-la dans votre gestionnaire sous le nom **URL migrations**.

Vérifiez que l'URL contient bien `sslmode=require`, sinon ajoutez `?sslmode=require` à la fin. En production, Sentinel **refuse de démarrer** sans lui. Le mieux, si votre système a les certificats racine : `sslmode=verify-full`.

## 4. Créer les tables (premier déploiement)

Les tables sont créées au premier démarrage du serveur (étape 7). Les rôles se créent **après** cela, à l'étape 7.5. Passez à l'étape 5.

## 5. Préparer les mots de passe des rôles

Générez deux mots de passe longs et aléatoires (24 caractères ou plus, lettres et chiffres). Utilisez votre gestionnaire ou PowerShell :

```powershell
-join ((48..57)+(65..90)+(97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Gardez-les sous les noms **mdp sentinel_app** et **mdp sentinel_revue**.

## 6. Déployer sur Render depuis GitHub

1. Allez sur <https://render.com> et cliquez sur **Get Started**. Choisissez **GitHub**.
2. Autorisez Render à lire **seulement** le dépôt `sentinel` (*Only select repositories*).
3. Dans le tableau de bord : **New +** puis **Blueprint**.
4. Choisissez le dépôt `sentinel`. Render lit le fichier [`render.yaml`](../render.yaml) à la racine.
5. Render demande les variables marquées `sync: false` :
   - `SENTINEL_MIGRATION_DATABASE_URL` : collez l'**URL migrations** (étape 3) ;
   - `SENTINEL_DATABASE_URL` : pour ce premier déploiement, collez **aussi l'URL migrations**. Elle sera remplacée à l'étape 7.6 par celle du rôle limité.
6. Cliquez sur **Apply** (ou **Deploy Blueprint**).

*Écran attendu* : le service `sentinel-api` (région Frankfurt, offre Free), puis les journaux de construction Docker. La construction prend quelques minutes.

`SENTINEL_FINGERPRINT_KEY` est générée par Render (256 bits aléatoires). Ne la changez pas ensuite : avec une nouvelle clé, les anciens textes ne seraient plus reconnus comme doublons.

## 7. Premier démarrage, puis rôles à moindre privilège

1. Dans **Logs**, attendez des lignes comme :
   ```
   INFO  [alembic.runtime.migration] Running upgrade  -> 0001, ...
   INFO  [alembic.runtime.migration] Running upgrade 0002 -> 0003, ...
   INFO:     Uvicorn running on http://0.0.0.0:8000
   ```
2. En haut de la page du service, notez l'adresse `https://sentinel-api-xxxx.onrender.com`.
3. Testez la santé (étape 8, premier test).
4. Sur Neon, ouvrez **SQL Editor** (base `neondb`).
5. Ouvrez [`backend/sql/roles.sql`](../backend/sql/roles.sql) **sur votre PC** et copiez tout son contenu dans l'éditeur. **Dans l'éditeur seulement** (jamais dans le fichier du dépôt), remplacez `REMPLACER_MOT_DE_PASSE_APP` et `REMPLACER_MOT_DE_PASSE_REVUE` par vos deux mots de passe. Cliquez sur **Run**.
   *Écran attendu* : « Statement executed successfully » (ou une liste de commandes réussies).
6. Construisez les deux URL limitées. Reprenez l'URL migrations et remplacez `neondb_owner:MOT_DE_PASSE` par le rôle et son mot de passe :
   - **URL app** : `postgresql://sentinel_app:MDP_APP@ep-xxxx-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require` ;
   - **URL revue** : `postgresql://sentinel_revue:MDP_REVUE@ep-xxxx-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require`.
7. Sur Render : service `sentinel-api`, puis **Environment**. Remplacez la valeur de `SENTINEL_DATABASE_URL` par l'**URL app**, puis **Save Changes**. Render redémarre le service.

Désormais, le serveur web ne peut **qu'ajouter** des signalements et augmenter un compteur. Il ne peut pas lire les textes déjà reçus. Seules les migrations, au démarrage, utilisent le propriétaire.

## 8. Tester

Remplacez l'adresse par la vôtre. Le premier appel peut prendre environ 1 min (réveil).

**Santé** (PowerShell) :

```powershell
$api = "https://sentinel-api-xxxx.onrender.com"
Invoke-RestMethod "$api/v1/health"
```

*Réponse attendue* : `status : ok`.

**Signalement** :

```powershell
Invoke-RestMethod -Method Post -Uri "$api/v1/reports" -ContentType "application/json" `
  -InFile backend/exemples/signalement_valide.json
```

*Réponse attendue* : `id : 3f2c…` (un UUID). Envoyez le même fichier une deuxième fois : vous obtenez le **même** id, car c'est un doublon et son compteur augmente.

**HTTP refusé** : `curl.exe -I http://sentinel-api-xxxx.onrender.com/v1/health` doit répondre par une redirection (`301` ou `308`) vers `https://`. C'est Render qui redirige.

**Documentation fermée** : `"$api/docs"` doit répondre `404`.

**Vérifier que la limite par adresse lit la bonne IP.** La doc de Render ne précise pas son en-tête d'IP client. Ce test le vérifie. Sentinel lit la **dernière** entrée de `X-Forwarded-For`, celle que le proxy ajoute ; le client ne peut écrire qu'au début.

1. Depuis votre PC, envoyez 11 signalements de textes différents :
   ```powershell
   1..11 | ForEach-Object {
     $body = @{ text = "test limite $_"; verdict = "rien"; probability = 0.1; language = "fr"; app_version = "1.0.0"; source = "autre" } | ConvertTo-Json
     try { Invoke-RestMethod -Method Post -Uri "$api/v1/reports" -ContentType "application/json" -Body $body | Out-Null; "$_ : 201" }
     catch { "$_ : $($_.Exception.Response.StatusCode.value__)" }
   }
   ```
   *Attendu* : 1 à 10 donnent `201`, et le 11e donne `429`.
2. **Usurpation.** Renvoyez un signalement en ajoutant `-Headers @{ "X-Forwarded-For" = "1.2.3.4" }`. *Attendu* : toujours `429`. Si vous obtenez `201`, n'importe qui peut contourner la limite : remettez `SENTINEL_TRUST_PROXY=false` sur Render et ouvrez une issue.
3. **Autre appareil.** Depuis le téléphone, en données mobiles (pas le même Wi-Fi), envoyez un signalement. *Attendu* : `201`. Si vous obtenez `429`, tout le monde partage la même adresse, celle d'un proxy interne. Essayez `SENTINEL_PROXY_HOPS=2`, ou `SENTINEL_CLIENT_IP_HEADER=true-client-ip`, puis refaites les tests 1 à 3.

Ensuite, passez ces signalements de test en « rejeté » avec l'outil de revue (étape 10).

## 9. Voir les journaux

Render, service `sentinel-api`, puis **Logs**. Vous y voyez par exemple :

```
INFO sentinel.access: POST /v1/reports 201 42ms
INFO sentinel.reports: signalement reçu
WARNING sentinel.reports: limite globale du jour atteinte
```

Les journaux de Sentinel ne contiennent **jamais** d'adresse IP ni de texte de message. Render garde ses propres journaux d'infrastructure, que Sentinel ne contrôle pas (voir le modèle de menaces).

## 10. Revoir les signalements et les exporter

Sur votre PC, dans PowerShell, depuis le dossier `backend` :

```powershell
.venv\Scripts\Activate.ps1
$env:DATABASE_URL = "postgresql://sentinel_revue:MDP_REVUE@ep-xxxx-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require"
python -m tools.review
```

*Écran attendu* :

```
─── 1/3 ── reçu le 2026-11-12 ── 4 fois
Votre colis est bloqué, payez ici : poste-tn-livraison.xyz/[CHEMIN]
verdict de l'app : arnaque (93%)
avis de l'utilisateur : arnaque ── langue : fr
[a] arnaque  [p] pas une arnaque  [r] rejeter  [s] passer  [q] quitter >
```

Touche `a` : arnaque confirmée. `p` : pas une arnaque. `r` : rejeté (spam, test, ou s'il reste un nom ou une adresse). `s` : passer. `q` : quitter. Chaque choix est enregistré tout de suite.

Export pour l'entraînement :

```powershell
python -m tools.review export
```

Les confirmés sont ajoutés à `ml/data/messages_perso.csv`, avec `source=reel`, sans doublon. Les lignes existantes ne sont pas touchées. Relancez ensuite `python ml/train.py` (voir `ml/README.md`).

À la fin, effacez la variable : `Remove-Item Env:DATABASE_URL`.

## 11. Rétention (une fois par mois)

Avec la même `DATABASE_URL` (rôle revue) :

```powershell
python -m tools.retention --dry-run   # combien seraient supprimés
python -m tools.retention             # supprime
```

Ce qui est supprimé :

- les « rejeté » et « pas_arnaque » non exportés, reçus il y a plus de 6 mois ;
- les « nouveau » jamais revus, reçus il y a plus de 12 mois.

Pour changer les durées : `--rejected-days 90 --new-days 180`.

Pour automatiser, deux options :

- **GitHub Actions** (gratuit) : une tâche planifiée qui lance `python -m tools.retention` avec l'URL revue rangée dans un *secret* du dépôt. Attention, GitHub détient alors un accès en lecture aux signalements. Le mieux serait un troisième rôle limité à la suppression.
- **Render Cron Job** : payant, au moins 1 $ par mois.

## 12. En cas de problème

| Symptôme dans les journaux Render | Cause | Solution |
|---|---|---|
| `connexion PostgreSQL sans TLS` | `sslmode=require` manque dans une URL | Ajouter `?sslmode=require` |
| `SQLite refusé en production` | `SENTINEL_DATABASE_URL` vide | Renseigner l'URL Neon |
| `SENTINEL_FINGERPRINT_KEY manquante` | Variable supprimée | La recréer : 32 caractères aléatoires ou plus |
| `permission denied for table reports` | `roles.sql` pas lancé, ou URL app utilisée pour les migrations | Refaire l'étape 7, vérifier `SENTINEL_MIGRATION_DATABASE_URL` |
| `password authentication failed` | Mot de passe mal recopié | Recopier, ou `ALTER ROLE sentinel_app WITH PASSWORD '…';` dans le SQL Editor |
| Premier appel très lent | Réveil du service | Normal sur l'offre gratuite (environ 1 min) |

## 13. Et l'app ?

Quand le serveur répond, construisez l'app avec son adresse :

```powershell
flutter build apk --release --dart-define=SENTINEL_API_URL=https://sentinel-api-xxxx.onrender.com
```

Le bouton « Signaler ce message » apparaît alors. HTTPS est obligatoire en release.
