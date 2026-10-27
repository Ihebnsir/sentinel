"""Anonymisation du texte d'un signalement, avant tout stockage.

Remplace par des marqueurs ce qui peut identifier une personne : e-mails,
IBAN / RIB, cartes bancaires, numéros de téléphone (tunisiens surtout),
codes de 4 à 8 chiffres, et tout autre nombre long. Les liens sont gardés
(utiles au modèle), mais les e-mails et nombres qu'ils contiennent sont
remplacés aussi.

\\d de Python reconnaît aussi les chiffres arabes (٠١٢…) : ils sont traités
comme les autres.
"""

import re

# Change si les règles changent : stocké avec chaque signalement.
ANONYMIZER_VERSION = 1

EMAIL = "[EMAIL]"
IBAN = "[IBAN]"
CARD = "[CARTE]"
PHONE = "[TEL]"
CODE = "[CODE]"
NUMBER = "[NUMERO]"

# Pas de chiffre collé avant / après : « 12345678901 » n'est pas un
# numéro de 8 chiffres suivi de 3 autres.
_NO_DIGIT_BEFORE = r"(?<!\d)"
_NO_DIGIT_AFTER = r"(?!\d)"
# Séparateurs courants : espace (aussi insécable), point, tiret.
_SEP = r"[  .\-]?"
# Dans un IBAN ou une carte : espace ou tiret seulement.
_GROUP_SEP = r"[  \-]?"

_EMAIL_RE = re.compile(r"[\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+")

# IBAN : 2 lettres, 2 chiffres, un premier groupe (lettres possibles,
# ex : NWBK), puis des chiffres (TN59 1000 6035 1835 9847 8831).
_IBAN_RE = re.compile(
    r"\b[A-Za-z]{2}\d{2}" + _GROUP_SEP + r"[A-Za-z\d]{4}"
    r"(?:" + _GROUP_SEP + r"\d{4}){1,6}(?:" + _GROUP_SEP + r"\d{1,3})?"
    + _NO_DIGIT_AFTER
)

# RIB tunisien : 20 chiffres (banque 2, agence 3, compte 13, clé 2),
# collés ou séparés.
_RIB_RE = re.compile(
    _NO_DIGIT_BEFORE
    + r"\d{2}" + _SEP + r"\d{3}" + _SEP + r"\d{13}" + _SEP + r"\d{2}"
    + _NO_DIGIT_AFTER
)

# Numéros avec indicatif (jamais 0 en tête) : +33 6 12 34 56 78,
# 0021698123456, (+216) 71…
_INTL_PHONE_RE = re.compile(
    r"\(?(?:\+|" + _NO_DIGIT_BEFORE + r"00)\s?[1-9]\d{0,2}\)?"
    r"(?:" + _SEP + r"\(?\d{1,4}\)?){2,6}"
    + _NO_DIGIT_AFTER
)

# Carte bancaire : 13 à 19 chiffres, souvent par groupes de 4
# (nombre de chiffres vérifié par _card_or_keep).
_CARD_RE = re.compile(
    _NO_DIGIT_BEFORE
    + r"\d{4}(?:" + _GROUP_SEP + r"\d{3,6}){2,3}(?:" + _GROUP_SEP + r"\d{1,5})?"
    + _NO_DIGIT_AFTER
)

# Numéro à 10 chiffres commençant par 0 : 06 12 34 56 78, 0612345678.
_LOCAL10_RE = re.compile(
    _NO_DIGIT_BEFORE + r"0\d(?:" + _SEP + r"\d{2}){4}" + _NO_DIGIT_AFTER
)

# Tunisie : 8 chiffres (22 123 456, 22.12.34.56, 22123456), avec ou sans
# « 216 » collé devant (wa.me/21650123456).
_TN_8 = (
    r"\d{2}" + _SEP + r"\d{3}" + _SEP + r"\d{3}"
    + r"|\d{2}" + _SEP + r"\d{2}" + _SEP + r"\d{2}" + _SEP + r"\d{2}"
)
_TN_PHONE_RE = re.compile(
    r"(?:" + _NO_DIGIT_BEFORE + r"216" + _SEP + r"|" + _NO_DIGIT_BEFORE + r")"
    + r"(?:" + _TN_8 + r")"
    + _NO_DIGIT_AFTER
)

# Ce qui reste : nombres longs, puis codes (4 à 8 chiffres).
_LONG_NUMBER_RE = re.compile(r"\d{9,}")
_CODE_RE = re.compile(_NO_DIGIT_BEFORE + r"\d{4,8}" + _NO_DIGIT_AFTER)


def anonymize(text: str) -> str:
    """Texte sans données personnelles. L'ordre compte : du plus précis
    (e-mail, IBAN) au plus large (codes)."""
    text = _EMAIL_RE.sub(EMAIL, text)
    text = _IBAN_RE.sub(IBAN, text)
    text = _RIB_RE.sub(IBAN, text)
    # Indicatif avant la carte : 0021698123456 a 13 chiffres aussi.
    text = _INTL_PHONE_RE.sub(PHONE, text)
    text = _CARD_RE.sub(_card_or_keep, text)
    # 10 chiffres avant 8 : sinon « 06 12 34 56 78 » laisserait « 78 ».
    text = _LOCAL10_RE.sub(PHONE, text)
    text = _TN_PHONE_RE.sub(PHONE, text)
    text = _LONG_NUMBER_RE.sub(NUMBER, text)
    text = _CODE_RE.sub(CODE, text)
    return text


def _card_or_keep(match: re.Match[str]) -> str:
    # Une carte a 13 à 19 chiffres ; plus court, c'est peut-être un
    # téléphone (traité ensuite).
    digits = sum(c.isdigit() for c in match.group(0))
    return CARD if 13 <= digits <= 19 else match.group(0)
