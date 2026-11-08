"""Anonymisation des signalements, AVANT tout stockage.

Module pur (aucune dépendance) : même entrée → même sortie. La version Dart
du téléphone (B2) doit donner exactement le même résultat : les cas communs
sont dans tests/fixtures/anonymize_cases.json.

Règles de portabilité (Python `re` ↔ Dart `RegExp`) :
- jamais \\d, \\w ni \\b (sens Unicode différent) : classes explicites ;
- lookbehind de longueur fixe seulement ;
- chiffres occidentaux (0-9) ET arabes-indiens (٠-٩, ۰-۹) reconnus.

Algorithme :
1. Les liens sont repérés en premier. Ils gardent leur domaine (signal utile
   au ML) mais perdent chemin, paramètres et identifiants.
2. Sur le texte HORS liens, dans cet ordre : e-mails, IBAN, RIB, cartes
   (Luhn), adresses IP, téléphones internationaux, locaux à 10 chiffres,
   tunisiens, mentions @, codes de vérification (mot-clé avant, puis après).
3. Rien d'autre n'est modifié (mots, ponctuation, espaces, domaines).
"""

import re

# À augmenter quand les règles changent (stocké avec chaque signalement).
ANONYMIZER_VERSION = 1

# Marqueurs : sans chiffre ni « @ », donc jamais repris par une règle suivante.
TEL = "[TEL]"
EMAIL = "[EMAIL]"
IBAN = "[IBAN]"
CARD = "[CARTE]"
CODE = "[CODE]"
IP = "[IP]"
USER = "[USER]"
PATH = "[CHEMIN]"

# Un chiffre : occidental ou arabe-indien.
_D = "[0-9٠-٩۰-۹]"
_ND = "[^0-9٠-٩۰-۹]"
# Séparateurs admis dans un numéro (espaces insécables compris).
_SEP = "[   .\\-]"

# --- Liens ---------------------------------------------------------------

_URL_CHARS = '[^\\s<>"«»]'
_HOST = "(?:[A-Za-z0-9](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?\\.)+[A-Za-z]{2,24}"
_URL = re.compile(
    # Avec schéma, ou commençant par www.
    "(?:[Hh][Tt][Tt][Pp][Ss]?://|[Ww][Ww][Ww]\\.)" + _URL_CHARS + "+"
    # Ou domaine nu suivi d'un chemin : « poste-tn.xyz/suivi ».
    "|(?<![A-Za-z0-9@._\\-])" + _HOST + "/" + _URL_CHARS + "*"
)
# Ponctuation de fin de phrase, laissée hors du lien.
_TRAILING = ".,;:!?)]}'\"،؛؟…"
_URL_PARTS = re.compile(
    "^(?P<scheme>[A-Za-z]+://)?"
    "(?:(?P<userinfo>[^/?#@]*)@)?"
    "(?P<host>\\[[^\\]]*\\]|[^/?#:]*)"
    "(?P<port>:[0-9]{1,5})?"
    "(?P<rest>.*)$",
    re.DOTALL,
)

# --- Le reste --------------------------------------------------------------

_EMAIL = re.compile(
    "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?"
    "(?:\\.[A-Za-z0-9](?:[A-Za-z0-9\\-]*[A-Za-z0-9])?)*\\.[A-Za-z]{2,24}"
)

# IBAN (majuscules) : pays, 2 chiffres de contrôle, 11 à 30 caractères.
_IBAN = re.compile("(?<![A-Za-z0-9])[A-Z]{2}[0-9]{2}(?:[ \\-]?[A-Z0-9]){11,30}(?![A-Za-z0-9])")
# RIB tunisien : 20 chiffres (banque 2, agence 3, compte 13, clé 2).
_RIB = re.compile("(?<!" + _D + ")" + _D + "(?:" + _SEP + "?" + _D + "){19}(?!" + _D + ")")
# Carte bancaire : 13 à 19 chiffres, vérifiés par Luhn.
_CARD = re.compile("(?<!" + _D + ")" + _D + "(?:[ \\-]?" + _D + "){12,18}(?!" + _D + ")")

_OCTET = "(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])"
_IPV4 = "(?<![0-9.])" + _OCTET + "(?:\\." + _OCTET + "){3}(?![0-9]|\\.[0-9])"
_H = "[0-9A-Fa-f]{1,4}"
_IPV6 = (
    "(?<![0-9A-Fa-f:])(?:"
    "(?:"
    + _H
    + ":){7}"
    + _H  # forme complète
    + "|(?:"
    + _H
    + ":){1,6}:(?:"
    + _H
    + "(?::"
    + _H
    + "){0,5})?"  # avec « :: »
    + "|::"
    + _H
    + "(?::"
    + _H
    + "){0,6}"
    + ")(?![0-9A-Fa-f:])"
)
_IP = re.compile(_IPV4 + "|" + _IPV6)
# Aussi utilisé par le filtre des journaux (app.logging_config).
IP_PATTERN = _IP.pattern

# International : +XXX ou 00XXX, puis chiffres groupés (8 à 15 au total).
_D19 = "[1-9١-٩۱-۹]"
_PHONE_INTL = re.compile(
    "(?<!" + _D + ")\\(?(?:\\+|00)" + _D19 + "(?:[ .\\-()]{0,2}" + _D + "){7,14}(?!" + _D + ")"
)
# Tunisien : 8 chiffres commençant par 2 à 9, écrits 98123456, 98 123 456
# ou 98 12 34 56 (pas 25.12.2026 : c'est une date), avec ou sans « 216 »
# collé devant (sans « + »).
_D29 = "[2-9٢-٩۲-۹]"
_PHONE_TN = re.compile(
    "(?<!"
    + _D
    + ")(?:216"
    + _SEP
    + "?)?"
    + _D29
    + "(?:"
    + _D
    + "{7}"
    + "|"
    + _D
    + _SEP
    + _D
    + "{3}"
    + _SEP
    + _D
    + "{3}"
    + "|"
    + _D
    + _SEP
    + _D
    + "{2}"
    + _SEP
    + _D
    + "{2}"
    + _SEP
    + _D
    + "{2}"
    + ")(?!"
    + _D
    + ")"
)
# Local à 10 chiffres commençant par 0 (France, Algérie, Maroc…) :
# 0612345678, 06 12 34 56 78.
_PHONE_LOCAL10 = re.compile(
    "(?<!" + _D + ")[0٠۰]" + _D + "(?:" + _SEP + "?" + _D + "{2}){4}(?!" + _D + ")"
)

# Mention : @pseudo (les e-mails sont déjà remplacés).
_MENTION = re.compile("(?<![A-Za-z0-9_@.])@[A-Za-z0-9_.]{2,30}(?<![.])")

# Code de vérification : 4 à 8 chiffres près d'un mot-clé (30 caractères).
_KEYWORDS = (
    "code|cod|otp|pin|mdp|mot de passe|password|pass|v[ée]rification|verify"
    "|كود|الكود|رمز|الرمز|كلمة السر|كلمة المرور|تحقق|التحقق|رقم سري"
)
# L'écart peut contenir des chiffres (en derja : « mte3ek », « l7ad ») mais
# ne traverse pas un [CODE] déjà posé : un mot-clé, un code (idempotence).
_GAP = "(?:(?!\\[CODE\\])[^\\n]){0,30}?"
# Mot-clé entier côté gauche : ni dans un mot latin, ni dans un marqueur [CODE].
_KEYWORD = "(?<![\\[A-Za-z])(?:" + _KEYWORDS + ")"
_CODE_AFTER_KEYWORD = re.compile(
    "(?i)(" + _KEYWORD + _GAP + ")(?<!" + _D + ")(" + _D + "{4,8})(?!" + _D + ")"
)
_CODE_BEFORE_KEYWORD = re.compile(
    "(?i)(?<!" + _D + ")(" + _D + "{4,8})(?!" + _D + ")(?=" + _GAP + _KEYWORD + ")"
)


def _digit_values(text: str) -> list[int]:
    """Valeurs des chiffres (occidentaux ou arabes-indiens) de [text]."""
    return [ord(c) & 0xF for c in text if re.fullmatch(_D, c)]


def luhn_valid(digits: list[int]) -> bool:
    total = 0
    for i, d in enumerate(reversed(digits)):
        if i % 2 == 1:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return total % 10 == 0


def _iban_valid(candidate: str) -> bool:
    """IBAN tunisien (TN + 22 chiffres) accepté tel quel ; autres : modulo 97."""
    compact = re.sub("[ \\-]", "", candidate).upper()
    if compact.startswith("TN"):
        return len(compact) == 24 and compact[2:].isascii() and compact[2:].isdigit()
    rearranged = compact[4:] + compact[:4]
    number = "".join(str(int(c, 36)) for c in rearranged)
    return int(number) % 97 == 1


def _anonymize_url(url: str) -> str:
    parts = _URL_PARTS.match(url)
    if parts is None:  # pragma: no cover - le motif accepte tout
        return url
    scheme = parts["scheme"] or ""
    host = parts["host"]
    out = scheme
    if parts["userinfo"] is not None:
        out += USER + "@"
    out += IP if _IP.fullmatch(host.strip("[]")) else host
    out += parts["port"] or ""
    rest = parts["rest"]
    if rest not in ("", "/"):
        out += "/" + PATH
    else:
        out += rest
    return out


def _anonymize_plain(text: str) -> str:
    """Texte sans lien : données personnelles remplacées par des marqueurs."""
    text = _EMAIL.sub(EMAIL, text)
    text = _IBAN.sub(lambda m: IBAN if _iban_valid(m[0]) else m[0], text)
    text = _RIB.sub(IBAN, text)
    text = _CARD.sub(lambda m: CARD if luhn_valid(_digit_values(m[0])) else m[0], text)
    text = _IP.sub(IP, text)
    text = _PHONE_INTL.sub(_intl_phone, text)
    # Téléphones avant les codes : « appelez le 98123456 pour le code ».
    text = _PHONE_LOCAL10.sub(TEL, text)
    text = _PHONE_TN.sub(TEL, text)
    text = _MENTION.sub(USER, text)
    text = _CODE_AFTER_KEYWORD.sub(lambda m: m[1] + CODE, text)
    return _CODE_BEFORE_KEYWORD.sub(CODE, text)


def _intl_phone(match: re.Match[str]) -> str:
    # « (+216) » : la parenthèse ouvrante ne reste que si elle n'est pas fermée.
    value = match[0]
    prefix = "(" if value.startswith("(") and ")" not in value else ""
    return prefix + TEL


_CLOSERS = {")": "(", "]": "[", "}": "{"}


def _trim_url(url: str) -> str:
    """Retire la ponctuation de fin ; une fermante n'est retirée que si elle
    n'est pas ouverte dans le lien (« /[CHEMIN] » reste entier)."""
    while url and url[-1] in _TRAILING:
        last = url[-1]
        opener = _CLOSERS.get(last)
        if opener is not None and url.count(opener) >= url.count(last):
            break
        url = url[:-1]
    return url


def anonymize(text: str) -> str:
    """Remplace les données personnelles de [text] ; garde tout le reste."""
    out: list[str] = []
    last = 0
    for match in _URL.finditer(text):
        url = _trim_url(match[0])
        out.append(_anonymize_plain(text[last : match.start()]))
        out.append(_anonymize_url(url))
        last = match.start() + len(url)
    out.append(_anonymize_plain(text[last:]))
    return "".join(out)
