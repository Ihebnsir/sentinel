-- Rôles PostgreSQL à moindre privilège pour Sentinel.
--
-- À lancer UNE fois, APRÈS le premier démarrage du serveur (la table
-- reports doit exister), connecté avec le rôle propriétaire de la base
-- (Neon : neondb_owner), par exemple dans le « SQL Editor » de Neon.
--
-- AVANT : remplacer les deux mots de passe ci-dessous par des mots de passe
-- longs et aléatoires (au moins 24 caractères, lettres et chiffres).
-- Ne jamais commiter ce fichier avec de vrais mots de passe.
--
--   sentinel_app   : le serveur web. Peut AJOUTER un signalement et augmenter
--                    le compteur d'un doublon. Ne peut PAS lire les textes,
--                    ni modifier ou supprimer un signalement.
--   sentinel_revue : l'outil de revue et la rétention (sur votre PC). Lit,
--                    change le statut, marque l'export, supprime. Ne peut pas
--                    ajouter de signalement ni changer le schéma.
--   Le propriétaire (neondb_owner) : seulement pour les migrations.

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sentinel_app') THEN
        CREATE ROLE sentinel_app WITH LOGIN PASSWORD 'REMPLACER_MOT_DE_PASSE_APP';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sentinel_revue') THEN
        CREATE ROLE sentinel_revue WITH LOGIN PASSWORD 'REMPLACER_MOT_DE_PASSE_REVUE';
    END IF;
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO sentinel_app, sentinel_revue',
                   current_database());
END
$$;

-- Personne d'autre que le propriétaire ne crée de tables.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO sentinel_app, sentinel_revue;

-- Repartir de zéro (script relançable).
REVOKE ALL ON reports FROM sentinel_app, sentinel_revue;

-- Serveur : INSERT ... ON CONFLICT (fingerprint) DO UPDATE SET count = count + 1
-- RETURNING id, et le comptage du jour pour la limite globale.
-- Lecture limitée à 4 colonnes sans contenu : jamais text.
GRANT INSERT ON reports TO sentinel_app;
GRANT SELECT (id, fingerprint, count, received_on) ON reports TO sentinel_app;
GRANT UPDATE (count) ON reports TO sentinel_app;

-- Revue et rétention.
GRANT SELECT, DELETE ON reports TO sentinel_revue;
GRANT UPDATE (review_status, exported_on) ON reports TO sentinel_revue;

-- La table des migrations reste au propriétaire.
REVOKE ALL ON alembic_version FROM sentinel_app, sentinel_revue;
