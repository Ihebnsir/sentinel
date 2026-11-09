# Modèle de menaces — backend Sentinel (B1)

| | |
|---|---|
| Périmètre | `backend/` : API `/v1/health` et `POST /v1/reports`, PostgreSQL (Neon) ou SQLite (dev), image Docker, outils de revue et de rétention |
| État | B3a : prêt pour la production (Render + Neon, voir [DEPLOIEMENT.md](DEPLOIEMENT.md)), pas encore déployé |
| Date | 09/11/2026 |

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
| Hébergeurs (Render, Neon) et leurs proxys | Voir passer le trafic, les adresses IP, les données | Ils exploitent l'infrastructure : on leur fait confiance, en limitant ce qu'ils voient |
| Voleur d'identifiants | Utiliser une URL de base ou la clé d'empreinte | Fuite d'un fichier, d'une capture, d'un dépôt, d'un poste |

## 4. Mesures en place

### Vie privée

| Menace | Mesure | Où |
|---|---|---|
| Données personnelles dans le texte | Anonymisation **avant tout stockage** : téléphones, e-mails, IBAN/RIB, cartes (Luhn), codes près d'un mot-clé, IP, mentions, chemins et paramètres des liens | `app/anonymize.py`, 96 cas dans `tests/fixtures/anonymize_cases.json` |
| Relier un signalement à une personne | Ni IP, ni identifiant d'appareil, ni heure : seulement le **jour** (UTC) | `app/models.py` ; test des colonnes |
| IP dans la limite de débit | Empreinte HMAC-SHA256 avec un **sel aléatoire changé à chaque fenêtre** (1 h), en mémoire uniquement | `app/rate_limit.py` |
| IP lue derrière le proxy | Seulement si `SENTINEL_TRUST_PROXY=true` ; dernière entrée de `X-Forwarded-For` (celle du proxy), jamais la première (écrite par le client). Utilisée seulement pour la limite, jamais stockée ni journalisée (tests) | `app/client_ip.py`, `tests/test_proxy.py` |
| Confirmer qu'un texte est dans une base volée | Empreinte des doublons = HMAC avec une clé secrète, pas un simple SHA-256 | `app/fingerprint.py` |
| Garder trop longtemps | Rétention : rejetés et pas_arnaque non utilisés supprimés après 6 mois, nouveaux jamais revus après 12 mois | `tools/retention.py` |
| IP ou texte dans les journaux | Journal d'accès d'uvicorn coupé ; notre journal : méthode, chemin (sans paramètres), statut, durée ; filtre qui efface les IP ; erreurs réduites à leur type ; SQL jamais journalisé | `app/logging_config.py`, `app/middleware.py`, `app/__main__.py` |
| Texte renvoyé dans les erreurs | Réponses 422 sans `input` ni `ctx` | `app/main.py` |
| Données supprimées encore lisibles dans le fichier | `PRAGMA secure_delete=ON` | `app/db.py` |
| Données collectées en trop | Champs inconnus refusés (`device_id`, `ip`… → 422) | `app/schemas.py` |

### Spam, abus et déni de service

| Menace | Mesure |
|---|---|
| Inondation de signalements | 10 par heure par adresse (IPv6 : par /64), réponse 429 + `Retry-After` |
| Inondation depuis beaucoup d'adresses | Limite globale : 500 **nouveaux** signalements par jour, comptés en base (tient aux redémarrages) |
| Même message envoyé en boucle | Une seule ligne par texte (empreinte), `count` augmente : la base ne grossit pas, et un fort compteur se voit à la revue |
| Saturation de la mémoire de la limite | Plafond de 100 000 empreintes ; au-delà, les nouvelles adresses sont refusées |
| Corps énormes | 16 Kio au plus, vérifiés aussi sans `Content-Length` (413) ; texte de 2000 caractères au plus |
| Entrées malformées | Validation stricte : types exacts, listes fermées, version au format fixe, caractères de contrôle refusés |
| Appels depuis un site web | Aucun en-tête CORS : le navigateur bloque la lecture des réponses cross-origin |

### Surface d'attaque

- `/docs`, `/redoc` et `/openapi.json` fermés en production. C'est le mode par défaut.
- **Pas de page web d'administration** : la revue se fait en ligne de commande, depuis le PC, avec un rôle à part.
- HTTPS : Render redirige HTTP vers HTTPS ; si le proxy signale encore du HTTP, réponse 400. HSTS 2 ans.
- Démarrage **refusé** en production sans TLS vers PostgreSQL (`sslmode=require` ou mieux), sans clé d'empreinte, ou avec SQLite non choisi. Les erreurs de configuration ne recopient jamais les valeurs.
- Pas d'en-tête `server`. La santé ne dit rien (`{"status": "ok"}`).
- En-têtes : CSP `default-src 'none'`, `nosniff`, `X-Frame-Options: DENY`, `no-referrer`, `no-store`, HSTS (utile derrière TLS).
- Docker : image épinglée par empreinte, utilisateur non-root (UID 10001), système de fichiers en lecture seule, `cap_drop: ALL`, `no-new-privileges`, port ouvert seulement sur 127.0.0.1.
- Chaîne d'approvisionnement : dépendances toutes épinglées, installées avec `--no-deps` ; `pip-audit`, `bandit` et `ruff` en CI ; actions GitHub épinglées par commit.

### Base managée, secrets et rôles

| Menace | Mesure |
|---|---|
| Faille dans le serveur (injection, bug) qui lit ou efface la base | Le serveur tourne avec `sentinel_app` : INSERT, et lecture de 4 colonnes sans contenu (`id`, `fingerprint`, `count`, `received_on`) ; mise à jour de `count` seulement. Pas de lecture des textes, pas de DELETE, pas de DDL (`sql/roles.sql`, vérifié par `tests/test_postgres_roles.py`) |
| Outil de revue compromis | `sentinel_revue` : lecture, statut, export, suppression ; pas d'INSERT, pas de DDL |
| Migrations | Rôle propriétaire, utilisé seulement au démarrage du conteneur (`SENTINEL_MIGRATION_DATABASE_URL`) |
| Trafic vers la base intercepté | TLS exigé par Neon et par le serveur (`sslmode=require` ; `verify-full` conseillé) |
| Secrets dans le dépôt | Aucun : `render.yaml` ne contient que des noms (`sync: false`) ; clé d'empreinte générée par Render ; mots de passe des rôles remplacés seulement dans l'éditeur SQL de Neon |

### Empoisonnement des données (data poisoning)

Le serveur ne peut pas savoir si un signalement bien formé dit vrai. Aucune donnée n'entre donc dans l'entraînement sans **revue humaine** : le statut `nouveau` est fixé par le serveur, le client ne peut pas le choisir, et il faut une revue pour le passer à `arnaque_confirmee` ou `pas_arnaque`. La limite de débit rend une attaque massive plus lente et plus visible. L'avis facultatif `user_feedback` (B2 : `arnaque`, `pas_arnaque`, `ne_sait_pas`) n'est qu'une indication pour la revue : il ne change jamais le statut tout seul.

## 5. Limites connues (et pistes)

| Limite | Conséquence | Piste |
|---|---|---|
| L'anonymisation repose sur des règles | Un nom propre (« Ahmed Ben Salah »), une adresse postale ou un numéro de CIN (8 chiffres commençant par 0 ou 1) **ne sont pas retirés** | Ajouter une règle CIN avec mot-clé ; revue humaine avant tout usage ; demander à l'utilisateur de relire avant l'envoi (B2) |
| Codes sans mot-clé | « 4821 » seul n'est pas reconnu comme code : il peut aussi être un montant ou une année | Choix assumé : garder les montants utiles au modèle |
| Les hébergeurs voient les IP | Le proxy de Render et Cloudflare voient l'IP de chaque requête et gardent leurs propres journaux d'infrastructure ; Neon voit l'IP de Render. Sentinel n'y a pas la main | Politique de confidentialité de l'app à jour ; pas d'IP dans nos journaux ni en base |
| En-tête d'IP de Render non documenté | La doc officielle ne dit pas quel en-tête porte l'IP du client. Si la dernière entrée de `X-Forwarded-For` était un proxy interne, tous les clients partageraient une limite | Test au déploiement (DEPLOIEMENT.md, étape 8) ; réglages `SENTINEL_PROXY_HOPS` / `SENTINEL_CLIENT_IP_HEADER` ; la limite globale reste un filet |
| Secrets chez l'hébergeur | Un accès au compte Render donne les URL des bases (dont le propriétaire, pour les migrations) | Comptes protégés par double authentification ; rotation des mots de passe (`ALTER ROLE`) en cas de doute |
| Doublons regroupés | L'avis et le verdict d'un doublon ne sont pas gardés (seul le compteur augmente) | Suffisant pour la revue ; détail par avis si besoin plus tard |
| Clé d'empreinte changée | Les anciens textes ne sont plus reconnus comme doublons | Ne pas régénérer la clé ; sinon, accepter quelques doublons |
| Limite par IP | Un réseau de machines (botnet) ou un opérateur mobile qui partage une IP (CGNAT) faussent la limite : l'un contourne, l'autre bloque des innocents | Jeton anonyme par installation (Privacy Pass), preuve de travail, ou App Attest / Play Integrity (au prix d'un identifiant) |
| Limite en mémoire | Effacée au redémarrage et à chaque mise en veille de Render (15 min sans requête) ; non partagée entre plusieurs instances | La limite globale (en base) tient ; plus tard, un compteur partagé avec la même empreinte salée |
| Empoisonnement lent | Quelques signalements par jour et par IP passent la limite | Revue humaine, détection des doublons et quasi-doublons, pondération par accord entre signalements |
| IP réelle derrière un proxy | Sans proxy de confiance bien réglé, toutes les requêtes semblent venir du proxy | `SENTINEL_FORWARDED_ALLOW_IPS` à régler au déploiement |
| Pas de TLS entre l'app et le serveur en local | Le trafic local (émulateur → PC) est en clair | En production : HTTPS de Render, HTTP refusé ; en local, debug seulement |
| Rétention manuelle | Render gratuit n'a pas de tâche planifiée : il faut lancer `tools.retention` | Rappel mensuel ; GitHub Actions ou Render Cron (payant) |
| Dépendances épinglées sans empreintes | Un paquet remplacé sur PyPI avec le même numéro ne serait pas détecté | `pip-compile --generate-hashes`, puis `--require-hashes` |
