"""Entraîne le détecteur d'arnaques SMS de Sentinel et l'exporte pour Flutter.

Modèle : TF-IDF sur n-grammes de caractères (char_wb, 2 à 5) + régression logistique.
Tout est volontairement simple et explicable : le score d'un message est la somme
des poids des n-grammes qu'il contient.

Usage (depuis la racine du projet) :
    ml\\.venv\\Scripts\\python.exe ml\\train.py
"""

from __future__ import annotations

import json
import math
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd
import sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline

# --- Chemins -----------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent
DATA_FILES = [
    ROOT / "ml" / "data" / "messages_seed.csv",
    ROOT / "ml" / "data" / "messages_perso.csv",
]
MODEL_OUT = ROOT / "assets" / "models" / "phishing_model.json"
PARITY_OUT = ROOT / "test" / "fixtures" / "phishing_parity.json"

# --- Paramètres ----------------------------------------------------------------
RANDOM_STATE = 42
TEST_SIZE = 0.2
THRESHOLD = 0.5  # arnaque si probabilité >= seuil
C_GRID = [0.1, 0.3, 1.0, 3.0, 10.0, 30.0]
VECTORIZER_PARAMS = dict(
    analyzer="char_wb",
    ngram_range=(2, 5),
    lowercase=False,  # fait par preprocess() (étape 1), après l'étape 0
    sublinear_tf=True,
    min_df=2,
    max_features=8000,
)

# --- Étape 0 : nettoyage (SEN-12) ---------------------------------------------
# Identique à normalizeMessage() de lib/services/phishing/phishing_model.dart.
# Caractères retirés : contrôles de direction du texte et invisibles.
HIDDEN_CODEPOINTS = [
    0x00AD,  # trait d'union conditionnel
    0x061C,  # marque de lettre arabe
    0x180E,  # séparateur de voyelles mongol
    0x200B, 0x200C, 0x200D,  # espace, anti-liant, liant sans largeur
    0x200E, 0x200F,  # marques gauche-à-droite, droite-à-gauche
    0x202A, 0x202B, 0x202C, 0x202D, 0x202E,  # enchâssements et forçages
    0x2060, 0x2061, 0x2062, 0x2063, 0x2064,  # gluon, opérateurs invisibles
    0x2066, 0x2067, 0x2068, 0x2069,  # isolats
    0xFEFF,  # espace insécable sans largeur (BOM)
]
RLO = 0x202E  # force l'affichage à l'envers
PDF = 0x202C  # ferme la dernière ouverture
EMBEDDING_OPENERS = [0x202A, 0x202B, 0x202D, 0x202E]
PARAGRAPH_SEPARATORS = [0x0A, 0x0D, 0x1C, 0x1D, 0x1E, 0x85, 0x2029]


def normalize_text(text: str, hidden=frozenset(HIDDEN_CODEPOINTS),
                   openers=frozenset(EMBEDDING_OPENERS),
                   paragraphs=frozenset(PARAGRAPH_SEPARATORS),
                   rlo=RLO, pdf=PDF) -> str:
    """Le texte tel que l'utilisateur le voit : ce qui suit un RLO (jusqu'au PDF
    ou à la fin du paragraphe) est remis à l'endroit, puis les caractères
    cachés sont retirés."""
    out: list[str] = []
    opened: list[int] = []
    reversed_part: list[str] = []

    def flush() -> None:
        out.extend(reversed(reversed_part))
        reversed_part.clear()

    for ch in text:
        cp = ord(ch)
        if cp in paragraphs:
            flush()
            opened.clear()
            out.append(ch)
        elif cp in openers:
            flush()
            opened.append(cp)
        elif cp == pdf:
            flush()
            if opened:
                opened.pop()
        elif cp in hidden:
            pass  # retiré
        elif opened and opened[-1] == rlo:
            reversed_part.append(ch)
        else:
            out.append(ch)
    flush()
    return "".join(out)


def preprocess(text: str) -> str:
    """Étapes 0 et 1 de ml/README.md : nettoyage, puis minuscules."""
    return normalize_text(text).lower()
LANGUES = ["fr", "ar", "derja_latin", "derja_arabe", "en"]
REQUIRED_COLUMNS = ["text", "label", "langue", "source"]

# 38 textes pour le test de parité Python <-> Dart : toutes les langues
# + des cas limites (vide, espaces Unicode, emojis, majuscules, accents...).
PARITY_TEXTS = [
    ("fr", "Votre code est 482913, ne le communiquez à personne."),
    ("fr", "La Poste : colis en attente, payez 1,900 DT ici : poste-colis.xyz/p"),
    ("fr", "MAMAN J'AI CHANGÉ DE NUMÉRO, ENVOIE-MOI 200 DT"),
    ("fr", "Rendez-vous   confirmé\tdemain à 9h.\nMerci !"),
    ("fr", "Ça va ? On se voit à l'École ce soir."),
    ("ar", "رمز التحقق الخاص بك هو 553201. لا تشاركه مع أحد."),
    ("ar", "تم تجميد حسابك، اضغط هنا لتفعيله: bank-ar.top"),
    ("ar", "مبروك! ربحت جائزة قيمة 🎁 اتصل بنا الآن"),
    ("derja_latin", "ya5i ab3athli el code elli jek taw 3afek"),
    ("derja_latin", "Rodbalek mel messaget hedhom, rahom arnaque"),
    ("derja_latin", "Colis mte3ek wsel, khalles 2 dt houni: colis-dl.top"),
    ("derja_latin", "Nchallah labes, nkalmek ghodwa"),
    ("derja_arabe", "ابعثلي الكود اللي جاك توا عافاك"),
    ("derja_arabe", "مبروك عليك الدار الجديدة، ربي يهنيك"),
    ("derja_arabe", "الكونت متاعك تبلوكا، إكبس هنا: kont-tn.xyz"),
    ("en", "Your OTP is 120934. Never share it."),
    ("en", "You WON a FREE iPhone!!! Click: free-phone.top 🎉"),
    ("en", "Hey mum it's me, new number, need money urgently"),
    ("en", "See you at 6, bring the charger"),
    ("special", ""),
    ("special", "   "),
    ("special", "a"),
    ("special", "ok"),
    ("special", "😀😀😀"),
    ("special", "bit.ly/xxxx"),
    ("special", "XX XXX XXX"),
    ("mixte", "Salut 3andek code? Your code is 4821 — رمز"),
    ("special", "café CAFÉ Café café"),
    ("special", "Ligne1\r\nLigne2 insécable cadratin"),
    ("special", "zero\u200Bwidth ne sépare pas les mots"),
    # SEN-12 : caractères invisibles et inversion de texte (écrits en \u).
    ("sen12", "Payez ici https://\u202Ezyx.euqanra-elpmaxe.ivius-siloc-etsopal\u202C sinon blocage"),
    ("sen12", "Payez ici https://laposte-colis-suivi.example-arnaque.xyz sinon blocage"),
    ("sen12", "pay\u00ADpal se\u200Bcu\u2060rité : vé\uFEFFrifiez votre compte"),
    ("sen12", "\u200Fمرحبا\u200E Salut \u061Cاهلا"),
    ("sen12", "Famille \U0001F468\u200D\U0001F469\u200D\U0001F467 au parc"),
    ("sen12", "\u2067arnaque\u2069 isolat \u202Bembed\u202C fin"),
    ("sen12", "\u202Edébut\nligne2 suite"),
    ("sen12", "\u202EAB\u202ACD\u202CEF\u202C GH"),
]


# --- Données -------------------------------------------------------------------
def load_data() -> pd.DataFrame:
    frames = []
    for path in DATA_FILES:
        df = pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")
        missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
        if missing:
            sys.exit(f"ERREUR : colonnes manquantes dans {path.name} : {missing}")
        print(f"  {path.name:<22} {len(df):>4} lignes")
        frames.append(df[REQUIRED_COLUMNS])
    df = pd.concat(frames, ignore_index=True)

    # Nettoyage minimal : on retire les espaces aux extrémités (sans effet sur
    # les n-grammes char_wb) et on écarte les lignes vides ou mal étiquetées.
    df["text"] = df["text"].str.strip()
    df["label"] = df["label"].str.strip()
    df["langue"] = df["langue"].str.strip()
    bad = (df["text"] == "") | (~df["label"].isin(["0", "1"]))
    if bad.any():
        print(f"  {bad.sum()} ligne(s) ignorée(s) (texte vide ou label différent de 0/1)")
    df = df[~bad].copy()
    df["label"] = df["label"].astype(int)

    before = len(df)
    df = df.drop_duplicates(subset="text", keep="first").reset_index(drop=True)
    if before != len(df):
        print(f"  {before - len(df)} doublon(s) supprimé(s)")
    return df


def split(df: pd.DataFrame):
    # On stratifie sur (label, langue) pour garder l'équilibre des langues dans
    # le test ; si une combinaison est trop rare (données perso), on stratifie
    # seulement sur le label.
    strata = df["label"].astype(str) + "_" + df["langue"]
    if strata.value_counts().min() < 2:
        strata = df["label"]
    return train_test_split(
        df, test_size=TEST_SIZE, stratify=strata, random_state=RANDOM_STATE
    )


# --- Affichage -------------------------------------------------------------------
def title(text: str) -> None:
    print()
    print("=" * 70)
    print(text)
    print("=" * 70)


def show_ngram(g: str) -> str:
    # Rend les espaces visibles : " ba" -> "␣ba"
    return "'" + g.replace(" ", "␣") + "'"


# --- Implémentation de référence (sans scikit-learn) ------------------------------
# Reproduit EXACTEMENT la spécification de ml/README.md à partir du JSON exporté.
# Si ce code donne les mêmes probabilités que scikit-learn, la spécification est
# correcte et la version Dart peut s'en inspirer ligne à ligne.
def reference_predict(model: dict, text: str) -> float:
    pre = model["preprocessing"]
    whitespace = {chr(cp) for cp in pre["whitespace_codepoints"]}
    min_n, max_n = pre["ngram_range"]

    # Étape 0, uniquement à partir des valeurs du JSON exporté.
    bidi = pre["bidi"]
    text = normalize_text(
        text,
        hidden=frozenset(pre["hidden_codepoints"]),
        openers=frozenset(bidi["openers"]),
        paragraphs=frozenset(bidi["paragraph_separators"]),
        rlo=bidi["rlo"],
        pdf=bidi["pdf"],
    )
    text = text.lower()
    # Découpage en mots sur les caractères d'espacement Unicode.
    words, current = [], []
    for ch in text:
        if ch in whitespace:
            if current:
                words.append("".join(current))
                current = []
        else:
            current.append(ch)
    if current:
        words.append("".join(current))

    counts: Counter[str] = Counter()
    for word in words:
        w = " " + word + " "
        for n in range(min_n, max_n + 1):
            if len(w) <= n:  # mot court : un seul n-gramme = le mot entier
                counts[w] += 1
                break
            for i in range(len(w) - n + 1):
                counts[w[i : i + n]] += 1

    vocab, idf, coef = model["vocabulary"], model["idf"], model["coef"]
    weights = {}
    for gram, c in counts.items():
        j = vocab.get(gram)
        if j is not None:
            weights[j] = (1.0 + math.log(c)) * idf[j]
    norm = math.sqrt(sum(v * v for v in weights.values()))
    z = model["intercept"]
    if norm > 0:
        for j in sorted(weights):
            z += (weights[j] / norm) * coef[j]
    return 1.0 / (1.0 + math.exp(-z)) if z >= 0 else math.exp(z) / (1.0 + math.exp(z))


def python_whitespace() -> list[int]:
    """Caractères considérés comme espaces par str.split() (et donc par char_wb)."""
    cps = [cp for cp in range(sys.maxunicode + 1) if chr(cp).isspace()]
    # char_wb remplace d'abord les suites de \s par un espace, puis fait split().
    # On vérifie que les deux définitions coïncident, sinon la spec serait fausse.
    regex_ws = re.compile(r"\s")
    assert cps == [cp for cp in range(sys.maxunicode + 1) if regex_ws.match(chr(cp))]
    return cps


# --- Programme principal -------------------------------------------------------------
def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    print(f"Python {sys.version.split()[0]} | scikit-learn {sklearn.__version__} "
          f"| pandas {pd.__version__} | numpy {np.__version__}")

    title("1. Données")
    df = load_data()
    print(f"  Total après nettoyage : {len(df)} messages "
          f"({(df.label == 1).sum()} arnaques, {(df.label == 0).sum()} normaux)")
    print("\n  Répartition (langue x label) :")
    print(pd.crosstab(df["langue"], df["label"], margins=True).to_string().replace("\n", "\n  "))

    train_df, test_df = split(df)
    print(f"\n  Entraînement : {len(train_df)} | Test : {len(test_df)}")

    title("2. Choix de C par validation croisée (5 plis, score = F1)")
    pipe = Pipeline([
        ("tfidf", TfidfVectorizer(**VECTORIZER_PARAMS, preprocessor=preprocess)),
        ("clf", LogisticRegression(class_weight="balanced", max_iter=5000)),
    ])
    search = GridSearchCV(
        pipe,
        {"clf__C": C_GRID},
        scoring="f1",
        cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE),
    )
    search.fit(train_df["text"], train_df["label"])
    for c, m, s in zip(C_GRID, search.cv_results_["mean_test_score"],
                       search.cv_results_["std_test_score"]):
        mark = "  <- retenu" if c == search.best_params_["clf__C"] else ""
        print(f"  C = {c:<5}  F1 = {m:.3f} (± {s:.3f}){mark}")
    best_c = search.best_params_["clf__C"]
    model: Pipeline = search.best_estimator_  # réentraîné sur tout le jeu d'entraînement
    vec: TfidfVectorizer = model.named_steps["tfidf"]
    clf: LogisticRegression = model.named_steps["clf"]
    print(f"  Vocabulaire : {len(vec.vocabulary_)} n-grammes")

    title(f"3. Résultats sur le jeu de test (seuil = {THRESHOLD})")
    y_true = test_df["label"].to_numpy()
    proba = model.predict_proba(test_df["text"])[:, 1]
    y_pred = (proba >= THRESHOLD).astype(int)
    precision = precision_score(y_true, y_pred, zero_division=0)
    recall = recall_score(y_true, y_pred, zero_division=0)
    f1 = f1_score(y_true, y_pred, zero_division=0)
    accuracy = accuracy_score(y_true, y_pred)
    cm = confusion_matrix(y_true, y_pred, labels=[0, 1])
    print(f"  Précision : {precision:.3f}  (quand on crie « arnaque », on a raison {precision:.0%} du temps)")
    print(f"  Rappel    : {recall:.3f}  (part des arnaques détectées)")
    print(f"  F1        : {f1:.3f}")
    print(f"  Exactitude: {accuracy:.3f}")
    print("\n  Matrice de confusion :")
    print("                     prédit normal   prédit arnaque")
    print(f"    vrai normal      {cm[0, 0]:>13}   {cm[0, 1]:>14}")
    print(f"    vraie arnaque    {cm[1, 0]:>13}   {cm[1, 1]:>14}")

    print("\n  Par langue :")
    print(f"    {'langue':<13} {'rappel arnaques':>16} {'faux positifs':>15}")
    per_lang = {}
    for langue in sorted(test_df["langue"].unique()):
        m = (test_df["langue"] == langue).to_numpy()
        scam, ok = m & (y_true == 1), m & (y_true == 0)
        r = float(y_pred[scam].mean()) if scam.any() else float("nan")
        fp = int(y_pred[ok].sum())
        per_lang[langue] = {"rappel": r, "arnaques": int(scam.sum()),
                            "faux_positifs": fp, "normaux": int(ok.sum())}
        print(f"    {langue:<13} {r:>9.3f} ({int(y_pred[scam].sum())}/{int(scam.sum())})"
              f" {fp:>9}/{int(ok.sum())}")

    title("4. Explicabilité : n-grammes les plus influents")
    names = vec.get_feature_names_out()
    coefs = clf.coef_[0]
    order = np.argsort(coefs)
    print("  20 n-grammes les plus « arnaque » :")
    for j in order[::-1][:20]:
        print(f"    {coefs[j]:+.3f}  {show_ngram(names[j])}")
    print("\n  20 n-grammes les plus « normal » :")
    for j in order[:20]:
        print(f"    {coefs[j]:+.3f}  {show_ngram(names[j])}")

    title("5. Messages du test mal classés")
    wrong = np.flatnonzero(y_pred != y_true)
    if len(wrong) == 0:
        print("  Aucun (voir l'avertissement sur les données synthétiques dans le README).")
    for i in wrong:
        row = test_df.iloc[i]
        kind = "ARNAQUE RATÉE " if row.label == 1 else "FAUSSE ALERTE "
        print(f"  [{kind}] p={proba[i]:.3f} ({row.langue}) {row.text}")

    title("6. Export")
    whitespace = python_whitespace()
    now = datetime.now()
    vocab = {g: int(j) for g, j in sorted(vec.vocabulary_.items(), key=lambda kv: kv[1])}
    export = {
        "format_version": 2,  # 2 : étape 0 (SEN-12)
        "version": now.strftime("%Y%m%d-%H%M%S"),
        "date": now.isoformat(timespec="seconds"),
        "sklearn_version": sklearn.__version__,
        "labels": {"0": "normal", "1": "arnaque"},
        "preprocessing": {
            "hidden_codepoints": HIDDEN_CODEPOINTS,
            "bidi": {
                "rlo": RLO,
                "pdf": PDF,
                "openers": EMBEDDING_OPENERS,
                "paragraph_separators": PARAGRAPH_SEPARATORS,
            },
            "lowercase": True,
            "analyzer": "char_wb",
            "ngram_range": list(VECTORIZER_PARAMS["ngram_range"]),
            "strip_accents": None,
            "unicode_normalization": None,
            "whitespace_codepoints": whitespace,
            "sublinear_tf": True,
            "use_idf": True,
            "smooth_idf": True,
            "norm": "l2",
            "min_df": VECTORIZER_PARAMS["min_df"],
            "max_features": VECTORIZER_PARAMS["max_features"],
        },
        "classifier": {"type": "logistic_regression", "C": best_c, "class_weight": "balanced"},
        "threshold": THRESHOLD,
        "intercept": float(clf.intercept_[0]),
        "vocabulary": vocab,
        "idf": [float(x) for x in vec.idf_],
        "coef": [float(x) for x in coefs],
        "metrics_test": {
            "n_train": len(train_df),
            "n_test": len(test_df),
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "accuracy": accuracy,
            "confusion_matrix": cm.tolist(),
            "par_langue": per_lang,
            "attention": "donnees majoritairement synthetiques : metriques optimistes",
        },
    }
    MODEL_OUT.parent.mkdir(parents=True, exist_ok=True)
    # JSON compact sur une ligne ; les flottants sont écrits avec assez de
    # chiffres pour être relus à l'identique (aller-retour exact en Dart).
    with open(MODEL_OUT, "w", encoding="utf-8", newline="") as f:
        f.write(json.dumps(export, ensure_ascii=False, separators=(",", ":")))
        f.write("\r\n")
    print(f"  Modèle  : {MODEL_OUT.relative_to(ROOT)} ({MODEL_OUT.stat().st_size / 1024:.0f} Ko)")

    # Fixtures de parité.
    texts = [t for _, t in PARITY_TEXTS]
    p_parity = model.predict_proba(texts)[:, 1]
    z_parity = model.decision_function(texts)
    nnz = vec.transform(texts).getnnz(axis=1)
    max_gap = 0.0
    cases = []
    for (langue, text), p, z, k in zip(PARITY_TEXTS, p_parity, z_parity, nnz):
        max_gap = max(max_gap, abs(reference_predict(export, text) - float(p)))
        cases.append({"langue": langue, "text": text, "normalise": normalize_text(text),
                      "n_ngrammes_connus": int(k), "decision": float(z), "proba": float(p)})
    parity = {
        "model_version": export["version"],
        "tolerance": 1e-9,
        "description": "Probabilités exactes de scikit-learn ; la version Dart doit "
                       "donner les mêmes à la tolérance près.",
        "cases": cases,
    }
    PARITY_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(PARITY_OUT, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(json.dumps(parity, ensure_ascii=False, indent=2))
        f.write("\n")
    print(f"  Parité  : {PARITY_OUT.relative_to(ROOT)} ({len(cases)} cas)")

    title("7. Vérification de la spécification du README")
    print(f"  Écart max. implémentation de référence (sans sklearn) vs sklearn : {max_gap:.2e}")
    if max_gap > 1e-12:
        sys.exit("  ERREUR : la spécification ne reproduit pas scikit-learn !")
    print("  OK : la spécification reproduit scikit-learn.")


if __name__ == "__main__":
    main()
