"""Anonymisation : beaucoup de cas tunisiens, et ce qu'il faut garder."""

import re

import pytest

from app.anonymize import CARD, CODE, EMAIL, IBAN, NUMBER, PHONE, anonymize

# Numéros tunisiens : mobiles (2x, 4x, 5x, 9x) et fixes (3x, 7x),
# avec ou sans indicatif, et tous les séparateurs courants.
TUNISIAN_PHONES = [
    "+216 22 123 456",
    "+21622123456",
    "+216 22123456",
    "+216-22-123-456",
    "+216.22.123.456",
    "00216 98 123 456",
    "0021698123456",
    "00 216 55 123 456",
    "216 50 123 456",
    "21650123456",
    "(+216) 71 234 567",
    "(00216) 73 123 456",
    "22 123 456",
    "22123456",
    "29.123.456",
    "41-123-456",
    "52 12 34 56",
    "98.12.34.56",
    "71 234 567",
    "36 123 456",
    "+216 22 123 456",  # espaces insécables (copier-coller)
]


@pytest.mark.parametrize("phone", TUNISIAN_PHONES)
def test_numero_tunisien_remplace(phone: str) -> None:
    result = anonymize(f"Appelez le {phone} vite")
    assert result == f"Appelez le {PHONE} vite"


@pytest.mark.parametrize(
    "text",
    [
        "tel:+21622123456",
        "wa.me/21650123456",
        "https://wa.me/21698123456?text=salut",
        "viber://chat?number=%2B21622123456",
    ],
)
def test_numero_dans_un_lien(text: str) -> None:
    assert not re.search(r"\d{8}", anonymize(text))


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("+33 6 12 34 56 78", PHONE),
        ("06 12 34 56 78", PHONE),
        ("0612345678", PHONE),
        ("+1 (555) 123-4567", PHONE),
        ("+213 555 12 34 56", PHONE),  # Algérie
        ("+212 6 12 34 56 78", PHONE),  # Maroc
    ],
)
def test_numeros_etrangers(text: str, expected: str) -> None:
    assert anonymize(text) == expected


def test_plusieurs_numeros_dans_un_message() -> None:
    text = "Contactez 22 123 456 ou +216 98 765 432, sinon le 71 000 111."
    assert anonymize(text) == f"Contactez {PHONE} ou {PHONE}, sinon le {PHONE}."


@pytest.mark.parametrize(
    "email",
    [
        "ali.bensalah@gmail.com",
        "contact@poste.tn",
        "a+test@sous.domaine.com.tn",
        "service-client@tunisietelecom.tn",
        "user_99@yahoo.fr",
    ],
)
def test_email_remplace(email: str) -> None:
    assert anonymize(f"Écrivez à {email} !") == f"Écrivez à {EMAIL} !"


@pytest.mark.parametrize(
    "account",
    [
        "TN59 1000 6035 1835 9847 8831",
        "TN5910006035183598478831",
        "tn59 1000 6035 1835 9847 8831",
        "FR76 3000 6000 0112 3456 7890 189",
        "08 006 0123456789012 34",  # RIB tunisien : banque, agence, compte, clé
        "08006012345678901234",
        "10-006-0351835984788-31",
    ],
)
def test_iban_et_rib_remplaces(account: str) -> None:
    assert anonymize(f"Virez sur {account} aujourd'hui") == f"Virez sur {IBAN} aujourd'hui"


@pytest.mark.parametrize(
    "card",
    ["4111 1111 1111 1111", "4111-1111-1111-1111", "5555555555554444", "3782 822463 10005"],
)
def test_carte_bancaire(card: str) -> None:
    assert anonymize(f"Carte {card} bloquée") == f"Carte {CARD} bloquée"


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("Votre code est 4821", f"Votre code est {CODE}"),
        ("OTP: 123456, ne le partagez pas", f"OTP: {CODE}, ne le partagez pas"),
        ("code:9876543", f"code:{CODE}"),
        ("PIN 0000", f"PIN {CODE}"),
        ("référence ABC12345", f"référence ABC{CODE}"),
        ("Colis n°123456789012", f"Colis n°{NUMBER}"),
        ("suivi 12345678901234567890123456", f"suivi {NUMBER}"),
    ],
)
def test_codes_et_nombres_longs(text: str, expected: str) -> None:
    assert anonymize(text) == expected


def test_chiffres_arabes() -> None:
    assert anonymize("رمز التحقق ٤٥٦٧٨٩") == f"رمز التحقق {CODE}"
    assert anonymize("اتصل بالرقم ٩٨١٢٣٤٥٦") == f"اتصل بالرقم {PHONE}"


def test_message_arabe_tunisien_complet() -> None:
    text = "مبروك! ربحت 1000 دينار. اتصل على 22123456 و ابعث الكود 5531"
    result = anonymize(text)
    assert "22123456" not in result
    assert "5531" not in result
    assert "1000" not in result  # 4 chiffres : traité comme un code
    assert PHONE in result


@pytest.mark.parametrize(
    "text",
    [
        "Payez 2 DT de frais",
        "Version 1.2.3 de l'app",
        "Rendez-vous à 14h30 le 12/05",
        "Gagnez 500 dinars",
        "Livraison sous 48 h",
        "Promo -50 % sur poste-tn.xyz/paiement",
        "https://bit.ly/3abc",
        "",
    ],
)
def test_ce_qui_est_garde(text: str) -> None:
    # Montants courts, dates, heures, liens : utiles au modèle, inoffensifs.
    assert anonymize(text) == text


def test_lien_garde_mais_identifiants_retires() -> None:
    text = "http://poste-tn.xyz/suivi?colis=99887766&mail=moi@test.tn"
    result = anonymize(text)
    assert result.startswith("http://poste-tn.xyz/suivi?colis=")
    assert "99887766" not in result
    assert "moi@test.tn" not in result


def test_resultat_jamais_plus_de_3_chiffres_de_suite() -> None:
    # Garde-fou général : après anonymisation, aucun groupe de 4 chiffres.
    text = (
        "Tel +216 22 123 456, RIB 08 006 0123456789012 34, code 123456, "
        "carte 4111 1111 1111 1111, mail x@y.tn, colis 55512345678, "
        "fixe 71.234.567, ٩٨١٢٣٤٥٦"
    )
    assert not re.search(r"\d{4}", anonymize(text))


def test_marqueurs_stables() -> None:
    # Anonymiser deux fois ne change plus rien.
    once = anonymize("Appelez le 22 123 456, code 4821, mail a@b.tn")
    assert anonymize(once) == once
