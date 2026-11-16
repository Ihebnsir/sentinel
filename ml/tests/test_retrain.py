"""Tests du pipeline de réentraînement sûr (ml/retrain.py)."""

import json

import numpy as np
import pandas as pd

import retrain
from conftest import OK, SCAM, make, write


def metrics(detectees=8, arnaques=10, fp=1, normaux=10, f1=0.9):
    return {"arnaques": arnaques, "detectees": detectees, "normaux": normaux,
            "faux_positifs": fp, "f1": f1}


# --- Jeu de test réel figé ------------------------------------------------------------
def test_jeu_fige_cree_une_seule_fois(paths):
    perso = retrain.read_csv(paths.perso)
    frozen, msg = retrain.load_or_freeze_real_test(perso, paths.frozen)
    assert paths.frozen.exists() and "créé" in msg
    assert set(frozen["label"]) == {0, 1}
    before = paths.frozen.read_bytes()
    assert b"\r\n" in before  # CRLF

    # De nouveaux messages réels n'y changent rien.
    more = pd.concat([perso, pd.DataFrame(make(SCAM, 1, 10, "reel", 900))])
    again, msg = retrain.load_or_freeze_real_test(more, paths.frozen)
    assert paths.frozen.read_bytes() == before and "non modifié" in msg
    assert again["text"].tolist() == frozen["text"].tolist()


def test_pas_de_jeu_fige_sans_assez_de_messages(paths):
    perso = retrain.read_csv(paths.perso).head(6)
    frozen, msg = retrain.load_or_freeze_real_test(perso, paths.frozen)
    assert frozen.empty and not paths.frozen.exists() and "pas encore" in msg


def test_test_fige_jamais_dans_l_entrainement(paths):
    perso = retrain.read_csv(paths.perso)
    frozen, _ = retrain.load_or_freeze_real_test(perso, paths.frozen)
    # Une quasi-copie d'un message figé doit aussi être écartée.
    copy = frozen.iloc[0]["text"] + " !!"
    perso = pd.concat([perso, pd.DataFrame([{**frozen.iloc[0].to_dict(), "text": copy}])])
    seed = retrain.read_csv(paths.seed)
    seed_train, seed_test = retrain.T.split(seed)
    train, stats = retrain.build_training_set(seed_train, seed_test, perso, frozen, set())
    canon_train = set(train["text"].map(retrain.canonical))
    assert not canon_train & set(frozen["text"].map(retrain.canonical))
    assert copy not in set(train["text"])
    assert not set(train["text"]) & set(seed_test["text"])
    assert stats["reels_entrainement"] == len(perso) - len(frozen) - 1


# --- Empoisonnement --------------------------------------------------------------------
def test_contradictions_signalees_et_ecartees():
    a = "Votre colis 4821 est bloqué, payez 2 DT ici : colis-tn.xyz"
    b = "Votre colis 9917 est bloqué, payez 2 DT ici : colis-tn.xyz"
    real = pd.DataFrame([
        {"text": a, "label": 1, "langue": "fr", "source": "reel"},
        {"text": b, "label": 0, "langue": "fr", "source": "reel"},
        {"text": "On mange ensemble ce soir ?", "label": 0, "langue": "fr", "source": "reel"},
    ])
    report = retrain.detect_poisoning(real)
    assert len(report["contradictions"]) == 1
    assert report["exclus"] == {a, b}


def test_pas_de_fausse_contradiction():
    real = pd.DataFrame(make(SCAM, 1, 6, "reel") + make(OK, 0, 6, "reel"))
    report = retrain.detect_poisoning(real)
    assert report["contradictions"] == []


def test_domaines_copies_et_sources_sur_representes():
    rows = [{"text": f"Bonjour {k}, voir promo-{k % 2}.top/x maintenant", "label": 1,
             "langue": "fr", "source": "reel"} for k in range(6)]
    rows += [{"text": f"Message normal numéro {w}", "label": 0, "langue": "fr",
              "source": "partenaire"} for w in ["un", "deux"]]
    report = retrain.detect_poisoning(pd.DataFrame(rows))
    assert {d["domaine"] for d in report["domaines"]} == {"promo-0.top", "promo-1.top"}
    assert report["clusters"] and report["clusters"][0]["taille"] >= 3
    assert [s["source"] for s in report["sources"]] == ["reel"]


def test_une_seule_source_n_est_pas_signalee():
    real = pd.DataFrame(make(OK, 0, 4, "reel"))
    assert retrain.detect_poisoning(real)["sources"] == []


# --- Mesures et porte de qualité ---------------------------------------------------------
def test_evaluate():
    m = retrain.evaluate(np.array([0.9, 0.2, 0.7, 0.6]), np.array([1, 1, 0, 0]), 0.5)
    assert (m["detectees"], m["ratees"], m["faux_positifs"]) == (1, 1, 2)
    assert m["precision"] == 1 / 3 and m["recall"] == 0.5 and m["taux_fp"] == 1.0


def test_porte_accepte_sans_regression():
    ok, checks = retrain.quality_gate(
        {"reel": metrics(), "synthetique": metrics()},
        {"reel": metrics(), "synthetique": metrics()})
    assert ok and all(c["ok"] for c in checks)


def test_porte_refuse_baisse_du_rappel_reel():
    ok, checks = retrain.quality_gate(
        {"reel": metrics(detectees=7), "synthetique": metrics(detectees=10)},
        {"reel": metrics(detectees=8), "synthetique": metrics(detectees=8)})
    assert not ok and "1 arnaque(s) de plus" in checks[0]["texte"]


def test_porte_refuse_plus_de_faux_positifs_reels():
    ok, checks = retrain.quality_gate(
        {"reel": metrics(fp=3), "synthetique": metrics(fp=0)},
        {"reel": metrics(fp=1), "synthetique": metrics(fp=1)})
    assert not ok and not checks[1]["ok"]


def test_porte_utilise_le_synthetique_sans_test_reel():
    ok, checks = retrain.quality_gate({"synthetique": metrics(detectees=5)},
                                      {"synthetique": metrics(detectees=6)})
    assert not ok and "synthétique" in checks[0]["texte"]


def test_porte_sans_modele_livre():
    ok, _ = retrain.quality_gate({"synthetique": metrics()}, None)
    assert ok


# --- Pipeline complet (sans flutter) ------------------------------------------------------
def test_premier_modele_exporte_puis_regression_refusee(paths):
    first = retrain.run(paths, with_flutter=False)
    assert first.accepted and first.exported
    model = json.loads(paths.model.read_text(encoding="utf-8"))
    parity = json.loads(paths.parity.read_text(encoding="utf-8"))
    assert parity["model_version"] == model["version"]
    assert model["metrics_test"]["test_reel_fige"]["n"] == len(retrain.read_csv(paths.frozen))
    report = first.report_path.read_text(encoding="utf-8")
    assert "ACCEPTÉ" in report and "non lancé (option --sans-flutter)" in report

    # Données empoisonnées : labels inversés partout sauf le test figé.
    for p in (paths.seed, paths.perso):
        df = retrain.read_csv(p)
        df["label"] = 1 - df["label"]
        write(df, p)
    model_before, parity_before = paths.model.read_bytes(), paths.parity.read_bytes()
    frozen_before = paths.frozen.read_bytes()
    second = retrain.run(paths, with_flutter=False)
    assert not second.accepted and not second.exported and second.reasons
    assert paths.model.read_bytes() == model_before
    assert paths.parity.read_bytes() == parity_before
    assert paths.frozen.read_bytes() == frozen_before
    assert second.report_path != first.report_path  # nouveau rapport, même jour
    text = second.report_path.read_text(encoding="utf-8")
    assert "REFUSÉ" in text and "rien n'a été modifié" in text


def test_mode_essai_ne_touche_a_rien(paths):
    result = retrain.run(paths, dry_run=True, with_flutter=False)
    assert result.accepted and not result.exported
    assert not paths.model.exists() and not paths.parity.exists()
    assert "--essai" in result.report_path.read_text(encoding="utf-8")


def test_echec_flutter_remet_les_anciens_fichiers(paths, monkeypatch):
    retrain.run(paths, with_flutter=False)
    before = paths.model.read_bytes()
    monkeypatch.setattr(retrain, "run_flutter_parity", lambda: (False, "1 test failed"))
    result = retrain.run(paths, with_flutter=True)
    assert result.accepted and not result.exported
    assert paths.model.read_bytes() == before
    assert "ÉCHEC" in result.report_path.read_text(encoding="utf-8")
