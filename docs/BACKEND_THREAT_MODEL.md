# Modèle de menaces — backend Sentinel (B1)

| | |
|---|---|
| Périmètre | `backend/` : API `/v1/health` et `POST /v1/reports`, base SQLite, image Docker |
| État | B1 : local uniquement, pas de déploiement, pas encore de lien avec l'app |
| Date | 08/11/2026 |

## 1. Ce que fait le service

L'utilisateur choisit de signaler un message d'arnaque. L'app envoie le texte, son verdict, sa probabilité, la langue, la source (SMS, WhatsApp…) et sa version. Le serveur **anonymise** le texte, puis l'enregistre avec la date du jour. Ces signalements serviront plus tard à réentraîner le modèle tunisien, après une revue humaine (statut `nouveau` → `arnaque_confirmee` / `pas_arnaque` / `rejete`).

## 2. Actifs

| Actif | Pourquoi il compte |
|---|---|
| Vie privée des personnes citées dans les messages (victime, proches, numéros, codes) | Un message reçu contient souvent des données d'autres personnes, qui n'ont rien accepté |
| Anonymat de la personne qui signale | Savoir **qui** signale **quoi**, **quand**, permettrait de la relier à ses messages |
| Qualité des données d'entraînement | Des données fausses dégradent le modèle, qui protège tous les utilisateurs |
| Disponibilité du service | Un signalement perdu, c'est une arnaque qui reste inconnue |
| Confiance des utilisateurs | Une seule fuite suffit à décourager tout signalement |

## 3. Attaquants

| Attaquant | Objectif | Moyens |
|---|---|---|
| Spammeur | Remplir la base de déchets, publicités, insultes | Scripts, nombreuses adresses IP |
| Empoisonneur de données ML | Faire apprendre au modèle que ses arnaques sont « sans danger », ou que des messages légitimes (banque, La Poste) sont des arnaques | Signalements en masse, bien formés, avec des verdicts trompeurs |
| Curieux ou voleur de données | Lire les signalements, retrouver des personnes | Accès au serveur, à une sauvegarde, aux journaux ; erreurs bavardes |
| Attaquant de disponibilité (déni de service) | Rendre le service inutilisable | Gros volumes de requêtes, corps énormes, connexions lentes |
| Site web malveillant | Faire envoyer des signalements par le navigateur d'un visiteur | Requêtes JavaScript cross-origin |

## 4. Mesures en place

### Vie privée

| Menace | Mesure | Où |
|---|---|---|
| Données personnelles dans le texte | Anonymisation **avant tout stockage** : téléphones, e-mails, IBAN/RIB, cartes (Luhn), codes près d'un mot-clé, IP, mentions, chemins et paramètres des liens | `app/anonymize.py`, 96 cas dans `tests/fixtures/anonymize_cases.json` |
| Relier un signalement à une personne | Ni IP, ni identifiant d'appareil, ni heure : seulement le **jour** (UTC) | `app/models.py` ; test des colonnes |
| IP dans la limite de débit | Empreinte HMAC-SHA256 avec un **sel aléatoire changé à chaque fenêtre** (1 h), en mémoire uniquement | `app/rate_limit.py` |
| IP ou texte dans les journaux | Journal d'accès d'uvicorn coupé ; notre journal : méthode, chemin (sans paramètres), statut, durée ; filtre qui efface les IP ; erreurs réduites à leur type ; SQL jamais journalisé | `app/logging_config.py`, `app/middleware.py`, `app/__main__.py` |
| Texte renvoyé dans les erreurs | Réponses 422 sans `input` ni `ctx` | `app/main.py` |
| Données supprimées encore lisibles dans le fichier | `PRAGMA secure_delete=ON` | `app/db.py` |
| Données collectées en trop | Champs inconnus refusés (`device_id`, `ip`… → 422) | `app/schemas.py` |

### Spam, abus et déni de service

| Menace | Mesure |
|---|---|
| Inondation de signalements | 10 par heure par adresse (IPv6 : par /64), réponse 429 + `Retry-After` |
| Saturation de la mémoire de la limite | Plafond de 100 000 empreintes ; au-delà, les nouvelles adresses sont refusées |
| Corps énormes | 16 Kio au plus, vérifiés aussi sans `Content-Length` (413) ; texte de 2000 caractères au plus |
| Entrées malformées | Validation stricte : types exacts, listes fermées, version au format fixe, caractères de contrôle refusés |
| Appels depuis un site web | Aucun en-tête CORS : le navigateur bloque la lecture des réponses cross-origin |

### Surface d'attaque

- `/docs`, `/redoc` et `/openapi.json` fermés en production. C'est le mode par défaut.
- Pas d'en-tête `server`. La santé ne dit rien (`{"status": "ok"}`).
- En-têtes : CSP `default-src 'none'`, `nosniff`, `X-Frame-Options: DENY`, `no-referrer`, `no-store`, HSTS (utile derrière TLS).
- Docker : image épinglée par empreinte, utilisateur non-root (UID 10001), système de fichiers en lecture seule, `cap_drop: ALL`, `no-new-privileges`, port ouvert seulement sur 127.0.0.1.
- Chaîne d'approvisionnement : dépendances toutes épinglées, installées avec `--no-deps` ; `pip-audit`, `bandit` et `ruff` en CI ; actions GitHub épinglées par commit.

### Empoisonnement des données (data poisoning)

Le serveur ne peut pas savoir si un signalement bien formé dit vrai. Aucune donnée n'entre donc dans l'entraînement sans **revue humaine** : le statut `nouveau` est fixé par le serveur, le client ne peut pas le choisir, et il faut une revue pour le passer à `arnaque_confirmee` ou `pas_arnaque`. La limite de débit rend une attaque massive plus lente et plus visible.

## 5. Limites connues (et pistes)

| Limite | Conséquence | Piste |
|---|---|---|
| L'anonymisation repose sur des règles | Un nom propre (« Ahmed Ben Salah »), une adresse postale ou un numéro de CIN (8 chiffres commençant par 0 ou 1) **ne sont pas retirés** | Ajouter une règle CIN avec mot-clé ; revue humaine avant tout usage ; demander à l'utilisateur de relire avant l'envoi (B2) |
| Codes sans mot-clé | « 4821 » seul n'est pas reconnu comme code : il peut aussi être un montant ou une année | Choix assumé : garder les montants utiles au modèle |
| Limite par IP | Un réseau de machines (botnet) ou un opérateur mobile qui partage une IP (CGNAT) faussent la limite : l'un contourne, l'autre bloque des innocents | Jeton anonyme par installation (Privacy Pass), preuve de travail, ou App Attest / Play Integrity (au prix d'un identifiant) |
| Limite en mémoire | Effacée au redémarrage ; non partagée entre plusieurs instances | Suffisant pour une instance ; plus tard, un compteur partagé (Redis) avec la même empreinte salée |
| Empoisonnement lent | Quelques signalements par jour et par IP passent la limite | Revue humaine, détection des doublons et quasi-doublons, pondération par accord entre signalements |
| IP réelle derrière un proxy | Sans proxy de confiance bien réglé, toutes les requêtes semblent venir du proxy | `SENTINEL_FORWARDED_ALLOW_IPS` à régler au déploiement |
| Pas de TLS en local | Le trafic local est en clair | Au déploiement : TLS obligatoire (reverse proxy), HSTS déjà envoyé |
| Base SQLite non chiffrée | Quelqu'un qui a accès au disque lit les textes anonymisés | Chiffrement du disque ou du volume au déploiement ; accès restreint |
| Pas d'interface de revue ni de suppression | La revue et l'effacement se font à la main | B3 : outil de revue authentifié, durée de conservation, suppression automatique |
| Dépendances épinglées sans empreintes | Un paquet remplacé sur PyPI avec le même numéro ne serait pas détecté | `pip-compile --generate-hashes`, puis `--require-hashes` |
