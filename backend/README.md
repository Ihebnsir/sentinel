# Backend Sentinel (prêt pour la production : B3a)

Reçoit des **signalements volontaires** de messages d'arnaque, pour améliorer plus tard le modèle anti-arnaque tunisien. La vie privée passe en premier : le texte est **anonymisé avant tout stockage**, et le serveur ne garde **ni adresse IP, ni identifiant d'appareil, ni heure exacte**.

L'app l'appelle depuis B2 (bouton « Signaler ce message »). Le déploiement (Render + Neon) se fait à la main en suivant [docs/DEPLOIEMENT.md](../docs/DEPLOIEMENT.md) ; la configuration est décrite dans [`render.yaml`](../render.yaml).

## Choix techniques

| Élément | Version | Pourquoi |
|---|---|---|
| Python | **3.14.8** | Sortie en octobre 2025, avec un an de correctifs (8ᵉ version de maintenance). Toutes les bibliothèques ont des paquets prêts pour elle. 3.15 est trop récente : certaines dépendances compilées (pydantic-core) arrivent plus tard. Même version que `ml/`. |
| FastAPI | 0.162.0 | API web, validation automatique, documentation générée |
| Pydantic | 2.14.1 | Validation stricte des données reçues |
| SQLAlchemy | 2.1.6 | Accès à la base |
| Alembic | 1.20.1 | Migrations (évolutions du schéma de la base) |
| PostgreSQL | 17 (Neon, docker compose) | Base de production : managée, sauvegardée, TLS obligatoire |
| psycopg | 3.3.6 (`psycopg-binary`) | Pilote PostgreSQL (libpq incluse, rien à compiler) |
| SQLite | celle de Python | Base dans un fichier, pour le dev et les tests |

Toutes les dépendances sont épinglées, transitives comprises : `requirements.txt` pour le serveur, `requirements-dev.txt` pour les tests et outils. Chaque version a été publiée il y a au moins 2 semaines (vérifié sur PyPI le 08/11/2026).

## Lancer en local (Windows, PowerShell)

```powershell
cd backend
py -3.14 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --no-deps -r requirements-dev.txt
Copy-Item .env.example .env        # mode dev : /docs ouvert
.\.venv\Scripts\python.exe -m app  # migrations, puis serveur sur 127.0.0.1:8000
```

`python -m app` applique d'abord les migrations (`alembic upgrade head`), puis démarre uvicorn. La base est créée dans `backend/data/sentinel.db` (ignorée par Git).

Avec Docker, **comme en production** (API + PostgreSQL 17 avec TLS) :

```powershell
cd backend
docker compose up -d --build   # http://127.0.0.1:8000, mode prod (/docs fermé)
docker compose logs -f api     # journaux
docker compose down            # arrêt (données gardées dans les volumes)
```

SQLite reste possible (voir l'en-tête de `docker-compose.yml`).

### Variables principales

| Variable | Rôle |
|---|---|
| `SENTINEL_ENV` | `prod` (défaut) ou `dev` |
| `SENTINEL_DATABASE_URL` | Base du serveur. PostgreSQL : `postgresql://…?sslmode=require` (rôle `sentinel_app`) |
| `SENTINEL_MIGRATION_DATABASE_URL` | Base pour les migrations au démarrage (rôle propriétaire) ; vide = la même |
| `SENTINEL_ALLOW_SQLITE` | SQLite autorisé en prod (défaut : non) |
| `SENTINEL_FINGERPRINT_KEY` | Clé secrète des empreintes de doublons (32 caractères min. en prod) |
| `SENTINEL_TRUST_PROXY`, `SENTINEL_CLIENT_IP_HEADER`, `SENTINEL_PROXY_HOPS` | IP du client derrière le proxy de l'hébergeur (voir plus bas) |
| `SENTINEL_RATE_LIMIT_PER_WINDOW`, `SENTINEL_GLOBAL_DAILY_LIMIT` | 10 par heure et par adresse ; 500 nouveaux signalements par jour au total |

Liste complète : `.env.example`. **En production, le serveur refuse de démarrer** si PostgreSQL n'exige pas TLS, si la clé d'empreinte manque, ou si la base est SQLite sans choix explicite. Le message d'erreur ne recopie jamais l'URL (elle contient le mot de passe).

## Tester avec curl

Sous PowerShell, utilisez `curl.exe` (et non l'alias `curl`).

```powershell
# 1. Santé
curl.exe -i http://127.0.0.1:8000/v1/health

# 2. Signalement valide → 201 et un identifiant aléatoire
curl.exe -i -X POST http://127.0.0.1:8000/v1/reports -H "Content-Type: application/json" `
  --data-binary "@exemples/signalement_valide.json"

# 3. Signalement invalide (champ inconnu, probabilité hors limites) → 422
curl.exe -i -X POST http://127.0.0.1:8000/v1/reports -H "Content-Type: application/json" `
  --data-binary "@exemples/signalement_invalide.json"
```

Les fichiers d'exemple évitent les problèmes de guillemets de PowerShell.

## API (version 1)

| Méthode | Chemin | Réponse |
|---|---|---|
| GET | `/v1/health` | `200 {"status": "ok"}`, sans aucune information interne |
| POST | `/v1/reports` | `201 {"id": "<UUID v4>"}` (même id pour un doublon) ; `422` invalide ; `413` trop grand ; `429` trop de signalements (par adresse ou au total) ; `400` HTTP en clair derrière le proxy |

Corps de `POST /v1/reports` (tout champ inconnu est refusé) :

| Champ | Valeurs |
|---|---|
| `text` | 1 à 2000 caractères, sans caractère de contrôle |
| `verdict` | `arnaque`, `suspect`, `rien` (verdict de l'app) |
| `probability` | nombre de 0 à 1 |
| `language` | `fr`, `ar`, `derja_latin`, `derja_arabe`, `en`, `autre` |
| `app_version` | ex : `1.4.0` ou `1.4.0+12` |
| `source` | `sms`, `whatsapp`, `messenger`, `telegram`, `autre`, `inconnue` |
| `user_feedback` | facultatif : `arnaque`, `pas_arnaque`, `ne_sait_pas` (avis de l'utilisateur, B2) ; absent ou `null` pour les anciens clients |

## Anonymisation (`app/anonymize.py`)

Avant tout stockage, ces éléments sont remplacés par des marqueurs :

| Élément | Marqueur |
|---|---|
| Téléphones (+216, 00216, 8 chiffres, espaces / points / tirets, internationaux, locaux à 10 chiffres) | `[TEL]` |
| E-mails | `[EMAIL]` |
| IBAN, RIB tunisien (20 chiffres) | `[IBAN]` |
| Cartes bancaires (vérifiées par Luhn) | `[CARTE]` |
| Codes de 4 à 8 chiffres **près d'un mot-clé** (code, OTP, PIN, رمز, الكود…) | `[CODE]` |
| Adresses IPv4 et IPv6 | `[IP]` |
| Mentions `@pseudo` | `[USER]` |
| Liens : chemin et paramètres (le **domaine reste**) | `domaine/[CHEMIN]` |

Le reste n'est **pas modifié** (mots d'arnaque, domaines, montants, dates) : c'est ce qui sert au modèle. Les chiffres arabes (٠١٢…) sont reconnus. Ré-anonymiser un texte déjà anonymisé ne change rien.

`tests/fixtures/anonymize_cases.json` contient 96 cas (entrée → sortie attendue), dont beaucoup en derja et en arabe. La version Dart du téléphone (`lib/services/report/anonymizer.dart`) donne exactement les mêmes sorties (test de parité).

## Doublons et limites

- **Doublons** : le texte anonymisé est normalisé (majuscules, espaces, formes Unicode), puis haché avec HMAC-SHA256 et la clé `SENTINEL_FINGERPRINT_KEY`. Un texte déjà reçu n'ajoute pas de ligne : son champ `count` augmente (`INSERT … ON CONFLICT DO UPDATE`). Sans la clé, une fuite de la base ne permet pas de tester « tel message est-il dedans ? ».
- **Limite par adresse** : 10 par heure, en mémoire (remise à zéro au redémarrage ou à la mise en veille de l'hébergeur).
- **Limite globale** : 500 **nouveaux** signalements par jour (UTC), comptés dans la base. Au-delà : `429` jusqu'à minuit UTC.

## Derrière le proxy de l'hébergeur

Chez Render, le serveur voit l'adresse du proxy, pas celle du téléphone. Avec `SENTINEL_TRUST_PROXY=true`, l'IP du client est lue dans `X-Forwarded-For`, **à la fin** (`SENTINEL_PROXY_HOPS`-ième entrée en partant de la droite). Le client peut écrire n'importe quoi au début de cet en-tête ; le proxy ajoute la vraie adresse à la fin. Sans cette variable (défaut), l'en-tête est ignoré. uvicorn ne réécrit plus l'adresse (`proxy_headers=False`). Cette IP sert **seulement** à la limite de débit, en mémoire, sous forme d'empreinte salée.

HTTPS : Render redirige HTTP vers HTTPS. Si le proxy signale malgré tout une requête en HTTP (`X-Forwarded-Proto: http`), le serveur répond `400` (pas de redirection : un POST redirigé renverrait le texte en clair). HSTS : 2 ans.

## Base de données et rôles

- Migrations Alembic compatibles PostgreSQL et SQLite (`migrations/versions/0001` à `0003`), appliquées **au démarrage du conteneur** (`python -m app`) avec `SENTINEL_MIGRATION_DATABASE_URL`.
- [`sql/roles.sql`](sql/roles.sql) crée deux rôles à moindre privilège :
  - `sentinel_app` (le serveur) : ajouter un signalement, augmenter le compteur d'un doublon, compter ceux du jour. Il ne peut **pas** lire les textes, ni modifier un statut, ni supprimer ;
  - `sentinel_revue` (vos outils) : lire, changer le statut, marquer l'export, supprimer. Il ne peut pas ajouter de signalement ni changer le schéma.
- Les tests `tests/test_postgres_roles.py` vérifient ces droits sur un vrai PostgreSQL.

## Outils (sur votre PC)

Depuis `backend/`, avec l'URL du rôle revue dans `DATABASE_URL` (TLS obligatoire) :

```powershell
python -m tools.review            # revue un par un : a / p / r / s / q
python -m tools.review export     # confirmés → ../ml/data/messages_perso.csv (source=reel)
python -m tools.retention --dry-run
python -m tools.retention         # rejetés / pas_arnaque non utilisés > 6 mois, nouveaux > 12 mois
```

Pas de page web d'administration : une page de plus, en ligne, serait une cible de plus.

## Sécurité et journaux

- **Aucune IP stockée** : ni en base, ni dans les journaux. La limite de débit (10 signalements par heure et par adresse) garde en mémoire une **empreinte HMAC-SHA256** de l'IP, avec un sel aléatoire changé à chaque heure. En IPv6, c'est le /64 qui compte.
- **Journaux sans IP ni texte** : le journal d'accès d'uvicorn est désactivé (`access_log=False`) et remplacé par une ligne « méthode chemin statut durée ». Un filtre efface aussi toute IP qui apparaîtrait dans un message. En cas d'erreur, seul le *type* d'erreur est journalisé, car le message pourrait contenir le texte.
- **Erreurs de validation** : la réponse 422 ne renvoie jamais le texte reçu.
- Requêtes limitées à 16 Kio (413). En-têtes de sécurité (CSP, nosniff, no-referrer…), pas d'en-tête `server`.
- **CORS fermé** : aucun site web ne peut appeler l'API depuis un navigateur. L'app mobile n'est pas concernée.
- `/docs` et `/openapi.json` existent **seulement** si `SENTINEL_ENV=dev`. Le mode par défaut est `prod`.
- Configuration par variables d'environnement (`.env.example`). Secrets de production (URL des bases, clé d'empreinte) : seulement dans les variables de l'hébergeur, jamais dans le dépôt.
- Docker : image épinglée par empreinte, utilisateur non-root, système de fichiers en lecture seule, aucun privilège.

Menaces et limites : [docs/BACKEND_THREAT_MODEL.md](../docs/BACKEND_THREAT_MODEL.md).

## Vérifications

```powershell
.\.venv\Scripts\python.exe -m pytest -q          # SQLite
# Même suite en PostgreSQL (docker compose up -d db) :
$env:SENTINEL_TEST_DATABASE_URL = "postgresql://sentinel:sentinel-local@127.0.0.1:5432/sentinel?sslmode=require"
.\.venv\Scripts\python.exe -m pytest -q ; Remove-Item Env:SENTINEL_TEST_DATABASE_URL
.\.venv\Scripts\ruff.exe check . ; .\.venv\Scripts\ruff.exe format --check .
.\.venv\Scripts\bandit.exe -q -c pyproject.toml -r app tools
.\.venv\Scripts\pip-audit.exe --no-deps --disable-pip -r requirements-dev.txt
```

La CI (`.github/workflows/backend.yml`) lance les mêmes commandes, la suite en SQLite **et** en PostgreSQL, plus le build Docker, à chaque modification de `backend/`.
