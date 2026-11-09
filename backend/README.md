# Backend Sentinel (B1 : local uniquement)

Reçoit des **signalements volontaires** de messages d'arnaque, pour améliorer plus tard le modèle anti-arnaque tunisien. La vie privée passe en premier : le texte est **anonymisé avant tout stockage**, et le serveur ne garde **ni adresse IP, ni identifiant d'appareil, ni heure exacte**.

Pas encore de déploiement, et pas encore de lien avec l'app (B2).

## Choix techniques

| Élément | Version | Pourquoi |
|---|---|---|
| Python | **3.14.8** | Sortie en octobre 2025, avec un an de correctifs (8ᵉ version de maintenance). Toutes les bibliothèques ont des paquets prêts pour elle. 3.15 est trop récente : certaines dépendances compilées (pydantic-core) arrivent plus tard. Même version que `ml/`. |
| FastAPI | 0.162.0 | API web, validation automatique, documentation générée |
| Pydantic | 2.14.1 | Validation stricte des données reçues |
| SQLAlchemy | 2.1.6 | Accès à la base |
| Alembic | 1.20.1 | Migrations (évolutions du schéma de la base) |
| SQLite | celle de Python | Base dans un fichier, suffisante en local |

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

Avec Docker :

```powershell
cd backend
docker compose up --build    # http://127.0.0.1:8000, mode prod (/docs fermé)
```

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
| POST | `/v1/reports` | `201 {"id": "<UUID v4>"}` ; `422` invalide ; `413` trop grand ; `429` trop de signalements |

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

`tests/fixtures/anonymize_cases.json` contient 96 cas (entrée → sortie attendue), dont beaucoup en derja et en arabe. La version Dart du téléphone (B2) devra donner exactement les mêmes sorties.

## Sécurité et journaux

- **Aucune IP stockée** : ni en base, ni dans les journaux. La limite de débit (10 signalements par heure et par adresse) garde en mémoire une **empreinte HMAC-SHA256** de l'IP, avec un sel aléatoire changé à chaque heure. En IPv6, c'est le /64 qui compte.
- **Journaux sans IP ni texte** : le journal d'accès d'uvicorn est désactivé (`access_log=False`) et remplacé par une ligne « méthode chemin statut durée ». Un filtre efface aussi toute IP qui apparaîtrait dans un message. En cas d'erreur, seul le *type* d'erreur est journalisé, car le message pourrait contenir le texte.
- **Erreurs de validation** : la réponse 422 ne renvoie jamais le texte reçu.
- Requêtes limitées à 16 Kio (413). En-têtes de sécurité (CSP, nosniff, no-referrer…), pas d'en-tête `server`.
- **CORS fermé** : aucun site web ne peut appeler l'API depuis un navigateur. L'app mobile n'est pas concernée.
- `/docs` et `/openapi.json` existent **seulement** si `SENTINEL_ENV=dev`. Le mode par défaut est `prod`.
- Configuration par variables d'environnement (`.env.example`). Aucun secret n'est nécessaire.
- Docker : image épinglée par empreinte, utilisateur non-root, système de fichiers en lecture seule, aucun privilège.

Menaces et limites : [docs/BACKEND_THREAT_MODEL.md](../docs/BACKEND_THREAT_MODEL.md).

## Vérifications

```powershell
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\ruff.exe check . ; .\.venv\Scripts\ruff.exe format --check .
.\.venv\Scripts\bandit.exe -q -c pyproject.toml -r app
.\.venv\Scripts\pip-audit.exe --no-deps --disable-pip -r requirements-dev.txt
```

La CI (`.github/workflows/backend.yml`) lance les mêmes commandes, plus le build Docker, à chaque modification de `backend/`.
