"""Docteur de la base Neon : diagnostic des rôles et changement de mot de passe.

Lancement (depuis backend/) :
    .\\.venv\\Scripts\\python.exe -m tools.db_doctor

- L'URL du propriétaire (neondb_owner) est demandée en saisie MASQUÉE
  (getpass) : rien ne s'affiche, rien n'est écrit sur le disque, rien ne va
  dans l'historique de PowerShell (ce n'est pas un argument de commande).
- Diagnostic : connexion propriétaire, table reports, rôles sentinel_app et
  sentinel_revue et leurs droits (les mêmes que sql/roles.sql).
- Nouveau mot de passe (32 lettres et chiffres) pour un rôle : ALTER ROLE,
  construction de l'URL du rôle, test réel dans une transaction ANNULÉE,
  puis copie dans le presse-papiers Windows. L'URL n'est jamais affichée.
- Nettoyage de l'historique PowerShell (PSReadLine) des lignes contenant
  « npg_ » ou « postgresql:// », après confirmation.
"""

import contextlib
import getpass
import os
import secrets
import string
import sys
import time
import uuid
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from pathlib import Path

from sqlalchemy.engine import make_url

from app.config import TLS_MODES
from app.db import postgres_connect_args
from app.db_errors import describe

ROLES = ("sentinel_app", "sentinel_revue")
PASSWORD_LENGTH = 32
PASSWORD_ALPHABET = string.ascii_letters + string.digits
ROLES_SQL = Path(__file__).resolve().parents[1] / "sql" / "roles.sql"
SECRET_MARKERS = ("npg_", "postgresql://", "postgres://")
RENDER_STEPS = {
    "sentinel_app": (
        "Colle maintenant dans Render > sentinel-api > Environment > "
        "SENTINEL_DATABASE_URL, puis Save Changes"
    ),
    "sentinel_revue": (
        "Colle maintenant l'URL revue dans ton gestionnaire de mots de passe "
        "(entrée « URL revue »). Elle sert aux outils review et retention."
    ),
}


class DoctorError(Exception):
    """Erreur affichée telle quelle (jamais d'URL ni de mot de passe)."""


# --- Logique pure (testée sans base) ---------------------------------------


def generate_password(length: int = PASSWORD_LENGTH) -> str:
    """Mot de passe aléatoire fort : lettres et chiffres, au moins une
    minuscule, une majuscule et un chiffre (module secrets)."""
    while True:
        password = "".join(secrets.choice(PASSWORD_ALPHABET) for _ in range(length))
        if (
            any(c.islower() for c in password)
            and any(c.isupper() for c in password)
            and any(c.isdigit() for c in password)
        ):
            return password


def check_owner_url(url: str) -> None:
    """Refuse une URL inutilisable. Le message ne recopie jamais l'URL."""
    try:
        parsed = make_url(url.strip())
    except Exception as exc:
        raise DoctorError("URL illisible : recopie-la depuis Neon (bouton Connect)") from exc
    if parsed.get_backend_name() != "postgresql":
        raise DoctorError("ce n'est pas une URL PostgreSQL (elle commence par postgresql://)")
    if not parsed.host or not parsed.database or not parsed.username or not parsed.password:
        raise DoctorError(
            "URL incomplète : il manque l'utilisateur, le mot de passe, l'hôte ou la base"
        )
    if parsed.query.get("sslmode") not in TLS_MODES:
        raise DoctorError("URL sans TLS : elle doit contenir sslmode=require (ou verify-full)")
    if parsed.username in ROLES:
        raise DoctorError(
            f"c'est l'URL de {parsed.username}, pas celle du propriétaire (neondb_owner)"
        )


def build_role_url(owner_url: str, role: str, password: str) -> str:
    """URL du rôle : même schéma, hôte, port, base et paramètres (sslmode,
    channel_binding…) que l'URL propriétaire ; seuls l'utilisateur et le mot
    de passe changent."""
    if role not in ROLES:
        raise DoctorError(f"rôle inconnu : {role}")
    if not password.isalnum():
        raise DoctorError("le mot de passe doit contenir seulement des lettres et des chiffres")
    parsed = make_url(owner_url.strip())
    return parsed.set(username=role, password=password).render_as_string(hide_password=False)


def connect_kwargs(url: str) -> dict[str, object]:
    """Options psycopg (TLS, délai) identiques à celles du serveur."""
    args = postgres_connect_args(url)
    args["application_name"] = "sentinel-db-doctor"
    return args


def split_history_entries(lines: list[str]) -> list[list[str]]:
    """Regroupe les lignes d'historique en commandes : PSReadLine écrit une
    commande sur plusieurs lignes terminées par un accent grave (`)."""
    entries: list[list[str]] = []
    current: list[str] = []
    for line in lines:
        current.append(line)
        if not line.rstrip("\r\n").endswith("`"):
            entries.append(current)
            current = []
    if current:
        entries.append(current)
    return entries


def clean_history(lines: list[str]) -> tuple[list[str], int]:
    """Lignes gardées, et nombre de lignes retirées (commandes entières qui
    contiennent un marqueur de secret)."""
    kept: list[str] = []
    removed = 0
    for entry in split_history_entries(lines):
        if any(marker in line.lower() for line in entry for marker in SECRET_MARKERS):
            removed += len(entry)
        else:
            kept.extend(entry)
    return kept, removed


@dataclass(frozen=True)
class Check:
    label: str
    # Fonction PostgreSQL has_*_privilege et ses arguments (passés en paramètres).
    function: str
    args: tuple[str, ...]
    expected: bool

    @property
    def sql(self) -> str:
        placeholders = ", ".join(["%s"] * len(self.args))
        if self.function == "has_database_privilege":
            # (rôle, base courante, droit)
            return "SELECT has_database_privilege(%s, current_database(), %s)"
        return f"SELECT {self.function}({placeholders})"


def _table(label: str, role: str, privilege: str, expected: bool, table: str = "reports") -> Check:
    return Check(label, "has_table_privilege", (role, table, privilege), expected)


def _column(label: str, role: str, column: str, privilege: str, expected: bool) -> Check:
    return Check(label, "has_column_privilege", (role, "reports", column, privilege), expected)


def expected_checks(role: str) -> list[Check]:
    """Droits attendus, d'après sql/roles.sql (True : doit avoir le droit)."""
    common = [
        Check("se connecter à la base", "has_database_privilege", (role, "CONNECT"), True),
        Check("utiliser le schéma public", "has_schema_privilege", (role, "public", "USAGE"), True),
        Check(
            "créer des tables (interdit)",
            "has_schema_privilege",
            (role, "public", "CREATE"),
            False,
        ),
        _table("lire alembic_version (interdit)", role, "SELECT", False, "alembic_version"),
    ]
    if role == "sentinel_app":
        return [
            *common,
            _table("ajouter un signalement (INSERT)", role, "INSERT", True),
            *(
                _column(f"lire la colonne {c}", role, c, "SELECT", True)
                for c in ("id", "fingerprint", "count", "received_on")
            ),
            _column("augmenter count (UPDATE count)", role, "count", "UPDATE", True),
            _column("lire les textes (interdit)", role, "text", "SELECT", False),
            _table("tout lire (interdit)", role, "SELECT", False),
            _column("changer un statut (interdit)", role, "review_status", "UPDATE", False),
            _table("supprimer (interdit)", role, "DELETE", False),
        ]
    return [
        *common,
        _table("lire les signalements (SELECT)", role, "SELECT", True),
        _table("supprimer (DELETE)", role, "DELETE", True),
        _column("changer le statut", role, "review_status", "UPDATE", True),
        _column("marquer l'export", role, "exported_on", "UPDATE", True),
        _table("ajouter un signalement (interdit)", role, "INSERT", False),
        _column("modifier un texte (interdit)", role, "text", "UPDATE", False),
    ]


def safe_error(exc: BaseException, secrets_: Iterable[str | None]) -> str:
    """Erreur lisible, sans URL ni mot de passe."""
    return describe(exc, forbidden=secrets_)


# --- Presse-papiers Windows ------------------------------------------------


def _clipboard_api():  # pragma: no cover - Windows uniquement
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.WinDLL("user32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
    kernel32.GlobalAlloc.restype = wintypes.HGLOBAL
    kernel32.GlobalLock.argtypes = [wintypes.HGLOBAL]
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
    kernel32.GlobalUnlock.restype = wintypes.BOOL
    kernel32.GlobalFree.argtypes = [wintypes.HGLOBAL]
    kernel32.GlobalFree.restype = wintypes.HGLOBAL
    user32.OpenClipboard.argtypes = [wintypes.HWND]
    user32.OpenClipboard.restype = wintypes.BOOL
    user32.EmptyClipboard.restype = wintypes.BOOL
    user32.CloseClipboard.restype = wintypes.BOOL
    user32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
    user32.SetClipboardData.restype = wintypes.HANDLE
    user32.RegisterClipboardFormatW.argtypes = [wintypes.LPCWSTR]
    user32.RegisterClipboardFormatW.restype = wintypes.UINT
    return ctypes, user32, kernel32


@contextlib.contextmanager
def _open_clipboard(user32):  # pragma: no cover - Windows uniquement
    for _ in range(20):  # une autre application peut le tenir un instant
        if user32.OpenClipboard(None):
            break
        time.sleep(0.05)
    else:
        raise DoctorError("presse-papiers occupé : réessaie")
    try:
        user32.EmptyClipboard()
        yield
    finally:
        user32.CloseClipboard()


def copy_to_clipboard(text: str) -> None:  # pragma: no cover - Windows uniquement
    """Copie le texte, exclu de l'historique (Win+V) et de la synchro cloud."""
    if sys.platform != "win32":
        raise DoctorError("le presse-papiers n'est géré que sous Windows")
    ctypes, user32, kernel32 = _clipboard_api()
    cf_unicodetext, gmem_moveable = 13, 0x0002

    def put(fmt: int, data: bytes) -> None:
        handle = kernel32.GlobalAlloc(gmem_moveable, len(data))
        pointer = kernel32.GlobalLock(handle) if handle else None
        if not pointer:
            raise DoctorError("mémoire du presse-papiers indisponible")
        ctypes.memmove(pointer, data, len(data))
        kernel32.GlobalUnlock(handle)
        if not user32.SetClipboardData(fmt, handle):
            kernel32.GlobalFree(handle)
            raise DoctorError("copie dans le presse-papiers impossible")

    with _open_clipboard(user32):
        put(cf_unicodetext, (text + "\0").encode("utf-16-le"))
        zero = (0).to_bytes(4, "little")
        for name in (
            "ExcludeClipboardContentFromMonitorProcessing",
            "CanIncludeInClipboardHistory",
            "CanUploadToCloudClipboard",
        ):
            put(user32.RegisterClipboardFormatW(name), zero)


def clear_clipboard() -> None:  # pragma: no cover - Windows uniquement
    if sys.platform == "win32":
        _ctypes, user32, _kernel32 = _clipboard_api()
        with _open_clipboard(user32):
            pass


# --- Base de données -------------------------------------------------------


def _connect(url: str, *, autocommit: bool = False):
    import psycopg

    return psycopg.connect(url.strip(), autocommit=autocommit, **connect_kwargs(url))


def _scalar(conn, sql: str, params: tuple = ()) -> object:
    row = conn.execute(sql, params).fetchone()
    return row[0] if row else None


def diagnose(conn) -> dict[str, bool]:
    """Affiche le diagnostic ; renvoie {rôle: tout est conforme}."""
    user = _scalar(conn, "SELECT current_user")
    database = _scalar(conn, "SELECT current_database()")
    version = _scalar(conn, "SHOW server_version")
    print(f"[OK] Connexion propriétaire : rôle {user}, base {database}, PostgreSQL {version}")
    if not _scalar(conn, "SELECT to_regclass('public.reports') IS NOT NULL"):
        print("[!!] Table reports absente : les migrations n'ont pas tourné.")
        print("     Vérifie SENTINEL_MIGRATION_DATABASE_URL sur Render et les logs du démarrage.")
        return dict.fromkeys(ROLES, False)
    revision = None
    if _scalar(conn, "SELECT to_regclass('public.alembic_version') IS NOT NULL"):
        revision = _scalar(conn, "SELECT version_num FROM alembic_version")
    print(f"[OK] Table reports présente (migration {revision or 'inconnue'})")
    if revision != "0003":
        print("[!!] Migration attendue : 0003. Redéploie le service pour l'appliquer.")

    status: dict[str, bool] = {}
    for role in ROLES:
        print()
        row = conn.execute(
            "SELECT rolcanlogin, rolsuper FROM pg_roles WHERE rolname = %s", (role,)
        ).fetchone()
        if row is None:
            print(f"[!!] Rôle {role} : n'existe pas. Choisis « Réappliquer roles.sql ».")
            status[role] = False
            continue
        can_login, superuser = row
        ok = bool(can_login) and not superuser
        print(
            f"[{'OK' if can_login else '!!'}] Rôle {role} : existe, connexion "
            f"{'autorisée' if can_login else 'INTERDITE (LOGIN manquant)'}"
        )
        if superuser:
            print(f"[!!] {role} est superutilisateur : bien trop de droits")
        for check in expected_checks(role):
            actual = bool(_scalar(conn, check.sql, check.args))
            good = actual == check.expected
            ok = ok and good
            print(f"   [{'OK' if good else '!!'}] {check.label}")
        if not ok:
            print(f"   → Droits incorrects pour {role} : choisis « Réappliquer roles.sql ».")
        status[role] = ok
    return status


def _must_be_denied(conn, statement: str, params: tuple, message: str) -> None:
    """Le rôle NE DOIT PAS pouvoir faire ceci (dans un point de sauvegarde)."""
    import psycopg

    try:
        with conn.transaction():
            conn.execute(statement, params)
    except psycopg.errors.InsufficientPrivilege:
        return  # attendu : moindre privilège
    except psycopg.Error:
        pass  # le droit existe (l'erreur vient d'ailleurs, ex. NOT NULL)
    raise DoctorError(message)


def _try_as_app(conn) -> None:
    """Ce que fait le serveur, dans une transaction ANNULÉE (rien n'est gardé)."""
    with conn.transaction(force_rollback=True):
        conn.execute("SELECT count(*) FROM reports WHERE received_on = current_date")
        conn.execute(
            "INSERT INTO reports (id, text, verdict, probability, language, source,"
            " app_version, received_on, review_status, anonymizer_version, fingerprint, count)"
            " VALUES (%s, 'test db_doctor', 'rien', 0, 'autre', 'autre', '0.0.0', current_date,"
            " 'nouveau', 1, %s, 1)"
            " ON CONFLICT (fingerprint) DO UPDATE SET count = reports.count + 1 RETURNING id",
            (uuid.uuid4(), "db-doctor-" + uuid.uuid4().hex),
        ).fetchone()
        _must_be_denied(
            conn,
            "SELECT text FROM reports LIMIT 1",
            (),
            "sentinel_app peut lire les textes : réapplique roles.sql (option 5)",
        )


def _try_as_revue(conn) -> None:
    with conn.transaction(force_rollback=True):
        conn.execute("SELECT count(*) FROM reports")
        conn.execute("UPDATE reports SET review_status = review_status WHERE false")
        _must_be_denied(
            conn,
            "INSERT INTO reports (id) VALUES (%s)",
            (uuid.uuid4(),),
            "sentinel_revue peut ajouter des signalements : réapplique roles.sql (option 5)",
        )


def verify_role_url(url: str, role: str, secrets_: Iterable[str]) -> None:
    """Connexion avec le rôle et test réel, quelques essais (le nouveau mot
    de passe peut mettre un instant à être pris en compte)."""
    import psycopg

    last: Exception | None = None
    for attempt in range(3):
        try:
            with _connect(url) as conn:
                (_try_as_app if role == "sentinel_app" else _try_as_revue)(conn)
            return
        except psycopg.OperationalError as exc:
            last = exc
            time.sleep(2 + attempt * 2)
        except psycopg.Error as exc:
            raise DoctorError(f"test en {role} refusé : {safe_error(exc, secrets_)}") from None
    raise DoctorError(f"connexion en {role} impossible : {safe_error(last, secrets_)}")


def rotate(owner_conn, owner_url: str, role: str) -> None:
    from psycopg import sql

    password = generate_password()
    role_url = build_role_url(owner_url, role, password)
    secrets_ = (owner_url, password, role_url)
    try:
        owner_conn.execute(
            sql.SQL("ALTER ROLE {} WITH LOGIN PASSWORD {}").format(
                sql.Identifier(role), sql.Literal(password)
            )
        )
    except Exception as exc:
        raise DoctorError(f"ALTER ROLE impossible : {safe_error(exc, secrets_)}") from None
    print(f"[OK] Nouveau mot de passe appliqué à {role} (l'ancien ne marche plus).")
    print(f"     Test de connexion en {role} (transaction annulée, rien n'est gardé)…")
    verify_role_url(role_url, role, secrets_)
    print(f"[OK] Connexion et droits de {role} vérifiés.")
    copy_to_clipboard(role_url)
    print()
    print(f">>> URL {role} COPIÉE dans le presse-papiers (elle n'est pas affichée).")
    print(f">>> {RENDER_STEPS[role]}")
    input("    Appuie sur Entrée quand c'est collé (le presse-papiers sera vidé)… ")
    clear_clipboard()
    print("[OK] Presse-papiers vidé.")


def reapply_roles(owner_conn, owner_url: str) -> None:
    """sql/roles.sql tel quel ; les rôles absents sont créés avec un mot de
    passe aléatoire jetable (à remplacer ensuite par les options 2 et 3)."""
    script = (
        ROLES_SQL.read_text(encoding="utf-8")
        .replace("REMPLACER_MOT_DE_PASSE_APP", generate_password())
        .replace("REMPLACER_MOT_DE_PASSE_REVUE", generate_password())
    )
    try:
        owner_conn.execute(script)
    except Exception as exc:
        raise DoctorError(f"roles.sql a échoué : {safe_error(exc, (owner_url,))}") from None
    print("[OK] roles.sql appliqué. Change maintenant les mots de passe (options 2 et 3).")


# --- Historique PowerShell -------------------------------------------------


def history_files() -> list[Path]:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return []
    folder = Path(appdata) / "Microsoft" / "Windows" / "PowerShell" / "PSReadLine"
    return sorted(folder.glob("*_history.txt"))


def clean_history_files(ask: Callable[[str], str] = input) -> None:
    files = history_files()
    plans = []
    for path in files:
        lines = path.read_text(encoding="utf-8", errors="surrogateescape", newline="").splitlines(
            keepends=True
        )
        kept, removed = clean_history(lines)
        if removed:
            plans.append((path, kept, removed))
    if not plans:
        print("[OK] Aucun secret trouvé dans l'historique PowerShell.")
        return
    for path, _kept, removed in plans:
        print(f"   {path.name} : {removed} ligne(s) à retirer")
    if ask("Retirer ces lignes ? (o/n) ").strip().lower() not in {"o", "oui"}:
        print("Rien n'a été modifié.")
        return
    for path, kept, _removed in plans:
        temporary = path.with_suffix(".tmp")
        temporary.write_text("".join(kept), encoding="utf-8", errors="surrogateescape", newline="")
        os.replace(temporary, path)
    print("[OK] Historique nettoyé. Ferme puis rouvre tes terminaux PowerShell")
    print("     (ceux qui sont ouverts gardent les anciennes lignes en mémoire).")


# --- Menu ------------------------------------------------------------------

MENU = """
Que veux-tu faire ?
  1. Diagnostic (connexion, table, rôles et droits)
  2. Nouveau mot de passe pour sentinel_app (copie l'URL app pour Render)
  3. Nouveau mot de passe pour sentinel_revue (copie l'URL revue)
  4. Nettoyer l'historique PowerShell (lignes avec npg_ ou postgresql://)
  5. Réappliquer roles.sql (crée les rôles manquants, remet les droits)
  q. Quitter
"""


def ask_owner_url() -> str:
    print("Colle l'URL du PROPRIÉTAIRE Neon (neondb_owner), puis Entrée.")
    print("Neon > ton projet > Connect > rôle neondb_owner, pooling désactivé.")
    print("Rien ne s'affiche pendant la saisie : c'est normal.")
    url = getpass.getpass("URL propriétaire : ").strip()
    check_owner_url(url)
    return url


def main() -> None:
    print("=== Docteur de la base Sentinel ===")
    owner_url: str | None = None
    owner_conn = None
    try:
        while True:
            choice = input(MENU + "Ton choix : ").strip().lstrip("﻿").lower()
            if choice in {"q", ""}:
                break
            if choice == "4":
                clean_history_files()
                continue
            if choice not in {"1", "2", "3", "5"}:
                print("Choix inconnu.")
                continue
            try:
                if owner_conn is None:
                    owner_url = ask_owner_url()
                    try:
                        owner_conn = _connect(owner_url, autocommit=True)
                    except Exception as exc:
                        url, owner_url = owner_url, None
                        raise DoctorError(
                            f"connexion propriétaire impossible : {safe_error(exc, (url,))}"
                        ) from None
                if choice == "1":
                    diagnose(owner_conn)
                elif choice == "2":
                    rotate(owner_conn, owner_url, "sentinel_app")
                elif choice == "3":
                    rotate(owner_conn, owner_url, "sentinel_revue")
                else:
                    reapply_roles(owner_conn, owner_url)
            except DoctorError as exc:
                print(f"[!!] {exc}")
    except KeyboardInterrupt, EOFError:
        print()
    finally:
        if owner_conn is not None:
            owner_conn.close()
    print("Au revoir.")


if __name__ == "__main__":
    main()
