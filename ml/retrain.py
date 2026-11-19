"""Réentraînement sûr du détecteur d'arnaques (avec porte de qualité).

Étapes :
1. charge les messages synthétiques (seed) et réels (perso) ;
2. fige, une seule fois, un jeu de TEST RÉEL (jamais utilisé pour l'entraînement) ;
3. cherche des signes d'empoisonnement dans les messages réels ;
4. entraîne un modèle candidat et le compare au modèle livré sur les deux tests ;
5. porte de qualité : export seulement s'il ne régresse pas, puis fixtures de
   parité et flutter test ;
6. écrit un rapport lisible dans ml/reports/AAAA-MM-JJ.md.

Usage (depuis la racine du projet) :
    ml\\.venv\\Scripts\\python.exe ml\\retrain.py              # complet
    ml\\.venv\\Scripts\\python.exe ml\\retrain.py --essai      # rapport seul, aucun export
    ml\\.venv\\Scripts\\python.exe ml\\retrain.py --sans-flutter
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline

sys.path.insert(0, str(Path(__file__).resolve().parent))
import train as T  # noqa: E402

# --- Paramètres ------------------------------------------------------------------
FROZEN_FRACTION = 0.3  # part des messages réels mise de côté pour le test figé
MIN_REAL_TO_FREEZE = 20  # en dessous, on attend d'avoir plus de messages réels
MIN_PER_LABEL_TO_FREEZE = 4  # au moins 4 arnaques et 4 normaux
NEAR_DUP_SIMILARITY = 0.9  # similarité cosinus (n-grammes) = « presque identiques »
CLUSTER_ALERT = (3, 0.10)  # groupe de quasi-doublons : >= 3 messages et >= 10 %
DOMAIN_ALERT = (3, 0.15)  # même domaine : >= 3 messages et >= 15 %
SOURCE_ALERT = 0.5  # une source qui fournit plus de la moitié des messages réels
MAX_SYNTH_F1_DROP = 0.05  # le test synthétique ne doit pas s'effondrer
PARITY_TEST = "test/phishing_parity_test.dart"
COLUMNS = T.REQUIRED_COLUMNS
DOMAIN_RE = re.compile(r"((?:[a-z0-9-]+\.)+[a-z]{2,})(?=[/\s:?#]|$)")


@dataclass
class Paths:
    seed: Path
    perso: Path
    frozen: Path
    model: Path
    parity: Path
    reports: Path

    @classmethod
    def default(cls) -> "Paths":
        data = T.ROOT / "ml" / "data"
        return cls(seed=data / "messages_seed.csv", perso=data / "messages_perso.csv",
                   frozen=data / "test_reel_fige.csv", model=T.MODEL_OUT,
                   parity=T.PARITY_OUT, reports=T.ROOT / "ml" / "reports")


@dataclass
class Result:
    accepted: bool
    exported: bool
    reasons: list[str]
    report_path: Path
    poisoning: dict
    metrics: dict = field(default_factory=dict)
    flutter: str = "non lancé"


# --- Données -------------------------------------------------------------------------
def read_csv(path: Path) -> pd.DataFrame:
    """Lit un CSV au format de train.py (même nettoyage) ; fichier absent = vide."""
    if not path.exists() or path.stat().st_size == 0:
        return pd.DataFrame(columns=COLUMNS).astype({"label": int})
    df = pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")
    missing = [c for c in COLUMNS if c not in df.columns]
    if missing:
        raise SystemExit(f"ERREUR : colonnes manquantes dans {path.name} : {missing}")
    df = df[COLUMNS].copy()
    for col in COLUMNS:
        df[col] = df[col].str.strip()
    df = df[(df["text"] != "") & df["label"].isin(["0", "1"])].copy()
    df["label"] = df["label"].astype(int)
    return df.drop_duplicates(subset=["text", "label"]).reset_index(drop=True)


def write_csv(df: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        df[COLUMNS].to_csv(f, index=False, lineterminator="\r\n")


def canonical(text: str) -> str:
    """Forme de comparaison : nettoyée, minuscules, chiffres -> 0, espaces réduits."""
    return " ".join(re.sub(r"\d", "0", T.preprocess(text)).split())


def load_or_freeze_real_test(real: pd.DataFrame, path: Path) -> tuple[pd.DataFrame, str]:
    """Le jeu de test réel figé. Créé une seule fois, ensuite jamais réécrit."""
    if path.exists():
        frozen = read_csv(path)
        return frozen, f"jeu figé existant ({len(frozen)} messages), non modifié"
    counts = real["label"].value_counts()
    if (len(real) < MIN_REAL_TO_FREEZE
            or min(counts.get(0, 0), counts.get(1, 0)) < MIN_PER_LABEL_TO_FREEZE):
        return (read_csv(path),
                f"pas encore créé : il faut au moins {MIN_REAL_TO_FREEZE} messages réels "
                f"dont {MIN_PER_LABEL_TO_FREEZE} arnaques et {MIN_PER_LABEL_TO_FREEZE} "
                f"normaux (actuellement {len(real)} : {counts.get(1, 0)} arnaques, "
                f"{counts.get(0, 0)} normaux)")
    # Un seul exemplaire par forme canonique, pour ne pas figer deux quasi-copies.
    unique = real.loc[~real["text"].map(canonical).duplicated()]
    _, frozen = train_test_split(unique, test_size=FROZEN_FRACTION,
                                 stratify=unique["label"], random_state=T.RANDOM_STATE)
    frozen = frozen.sort_index().reset_index(drop=True)
    write_csv(frozen, path)
    return frozen, f"créé aujourd'hui avec {len(frozen)} messages ({FROZEN_FRACTION:.0%} des réels)"


# --- Quasi-doublons et empoisonnement ----------------------------------------------
def similar_pairs(texts_a: list[str], texts_b: list[str] | None = None,
                  threshold: float = NEAR_DUP_SIMILARITY) -> list[tuple[int, int, float]]:
    """Paires (i, j, similarité) de messages presque identiques (cosinus sur n-grammes)."""
    same = texts_b is None
    b = texts_a if same else texts_b
    if not texts_a or not b:
        return []
    vec = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), preprocessor=canonical)
    try:
        vec.fit(list(texts_a) + ([] if same else list(b)))
    except ValueError:  # aucun n-gramme (textes vides)
        return []
    xa = vec.transform(texts_a)
    xb = xa if same else vec.transform(b)
    pairs = []
    for start in range(0, xa.shape[0], 500):  # par blocs pour limiter la mémoire
        block = (xa[start:start + 500] @ xb.T).tocoo()
        for i, j, s in zip(block.row, block.col, block.data):
            i = int(i) + start
            if s >= threshold - 1e-9 and (not same or i < int(j)):
                pairs.append((i, int(j), float(s)))
    return pairs


def domains_of(text: str) -> set[str]:
    found = DOMAIN_RE.findall(T.preprocess(text))
    return {d.removeprefix("www.") for d in found if not d.replace(".", "").isdigit()}


def detect_poisoning(real: pd.DataFrame) -> dict:
    """Signale : quasi-doublons aux labels opposés, groupes de copies, domaines et
    sources sur-représentés. Les messages contradictoires sont écartés de l'entraînement."""
    texts = real["text"].tolist()
    labels = real["label"].tolist()
    n = len(texts)
    pairs = similar_pairs(texts)

    contradictions = [
        {"a": texts[i], "label_a": labels[i], "b": texts[j], "label_b": labels[j],
         "similarite": s}
        for i, j, s in pairs if labels[i] != labels[j]
    ]

    # Groupes de quasi-doublons (union-find).
    parent = list(range(n))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for i, j, _ in pairs:
        parent[find(i)] = find(j)
    groups: dict[int, list[int]] = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    min_count, share = CLUSTER_ALERT
    clusters = [
        {"taille": len(m), "part": len(m) / n, "exemple": texts[m[0]],
         "arnaques": sum(labels[k] for k in m)}
        for m in groups.values() if len(m) >= max(min_count, share * n)
    ]

    domain_counts: dict[str, int] = {}
    for t in texts:
        for d in domains_of(t):
            domain_counts[d] = domain_counts.get(d, 0) + 1
    min_count, share = DOMAIN_ALERT
    domains = [{"domaine": d, "messages": c, "part": c / n}
               for d, c in sorted(domain_counts.items(), key=lambda kv: -kv[1])
               if c >= max(min_count, share * n)]

    source_counts = real["source"].value_counts()
    sources = []
    if len(source_counts) >= 2:
        sources = [{"source": s, "messages": int(c), "part": c / n}
                   for s, c in source_counts.items() if c / n > SOURCE_ALERT]

    excluded = {c["a"] for c in contradictions} | {c["b"] for c in contradictions}
    return {"n": n, "contradictions": contradictions, "clusters": clusters,
            "domaines": domains, "sources": sources,
            "sources_vues": {str(s): int(c) for s, c in source_counts.items()},
            "exclus": excluded}


def build_training_set(seed_train: pd.DataFrame, seed_test: pd.DataFrame,
                       perso: pd.DataFrame, frozen: pd.DataFrame,
                       excluded: set[str]) -> tuple[pd.DataFrame, dict]:
    """Entraînement = seed d'entraînement + réels hors test figé (ni copie, ni
    quasi-copie) et hors messages contradictoires."""
    frozen_texts = frozen["text"].tolist()
    frozen_canon = {canonical(t) for t in frozen_texts}
    real = perso.copy()
    in_frozen = real["text"].map(canonical).isin(frozen_canon)
    near = np.zeros(len(real), dtype=bool)
    for i, _, _ in similar_pairs(real["text"].tolist(), frozen_texts):
        near[i] = True
    contradictory = real["text"].isin(excluded).to_numpy()
    keep = ~in_frozen.to_numpy() & ~near & ~contradictory
    stats = {"reels_total": len(real), "reels_dans_test_fige": int(in_frozen.sum()),
             "reels_proches_du_test_fige": int((near & ~in_frozen.to_numpy()).sum()),
             "reels_contradictoires_ecartes": int((contradictory & ~in_frozen.to_numpy()
                                                   & ~near).sum()),
             "reels_entrainement": int(keep.sum())}
    train = pd.concat([seed_train, real[keep]], ignore_index=True)
    # Rien de ce qui sert au test synthétique ne doit entrer dans l'entraînement.
    train = train[~train["text"].isin(set(seed_test["text"]))]
    train = train.drop_duplicates(subset="text", keep="first").reset_index(drop=True)
    stats["entrainement"] = len(train)
    return train, stats


# --- Modèles ------------------------------------------------------------------------
def train_candidate(train: pd.DataFrame) -> tuple[Pipeline, float]:
    """Même recette que train.py : TF-IDF + régression logistique, C par validation croisée."""
    folds = int(min(5, train["label"].value_counts().min()))
    if folds < 2:
        raise SystemExit("ERREUR : il faut au moins 2 exemples de chaque classe.")
    pipe = Pipeline([
        ("tfidf", TfidfVectorizer(**T.VECTORIZER_PARAMS, preprocessor=T.preprocess)),
        ("clf", LogisticRegression(class_weight="balanced", max_iter=5000)),
    ])
    search = GridSearchCV(pipe, {"clf__C": T.C_GRID}, scoring="f1",
                          cv=StratifiedKFold(n_splits=folds, shuffle=True,
                                             random_state=T.RANDOM_STATE))
    search.fit(train["text"], train["label"])
    return search.best_estimator_, search.best_params_["clf__C"]


def shipped_proba(model_json: dict, texts: list[str]) -> np.ndarray:
    """Probabilités du modèle livré, recalculées depuis son JSON (comme l'app)."""
    return np.array([T.reference_predict(model_json, t) for t in texts], dtype=float)


def evaluate(proba: np.ndarray, y: np.ndarray, threshold: float) -> dict:
    y = np.asarray(y, dtype=int)
    pred = (np.asarray(proba) >= threshold).astype(int)
    vp = int(((pred == 1) & (y == 1)).sum())
    fp = int(((pred == 1) & (y == 0)).sum())
    n_scam, n_ok = int((y == 1).sum()), int((y == 0).sum())
    precision = vp / (vp + fp) if vp + fp else float("nan")
    recall = vp / n_scam if n_scam else float("nan")
    if np.isnan(precision) or np.isnan(recall) or precision + recall == 0:
        f1 = float("nan") if n_scam == 0 else 0.0
    else:
        f1 = 2 * precision * recall / (precision + recall)
    return {"n": len(y), "arnaques": n_scam, "normaux": n_ok, "detectees": vp,
            "ratees": n_scam - vp, "faux_positifs": fp, "precision": precision,
            "recall": recall, "f1": f1, "taux_fp": fp / n_ok if n_ok else float("nan")}


def quality_gate(cand: dict, ship: dict | None) -> tuple[bool, list[dict]]:
    """Règles : rappel des arnaques et faux positifs sur les messages normaux, sur le
    test réel figé (ou le synthétique tant qu'il n'existe pas) ; pas d'effondrement
    du F1 synthétique. Renvoie (accepté, critères)."""
    if ship is None:
        return True, [{"ok": True, "texte": "Aucun modèle livré : rien à comparer, "
                                             "le candidat devient le premier modèle."}]
    checks = []
    real_c, real_s = cand.get("reel"), ship.get("reel")
    synth_c, synth_s = cand["synthetique"], ship["synthetique"]

    # 1. Rappel : le candidat doit détecter au moins autant d'arnaques.
    if real_c and real_c["arnaques"] > 0:
        c, s, base = real_c, real_s, "test réel figé"
    else:
        c, s, base = synth_c, synth_s, "test synthétique, faute d'arnaques réelles figées"
    ok = c["detectees"] >= s["detectees"]
    checks.append({"ok": ok, "texte":
                   f"Arnaques détectées ({base}) : {s['detectees']}/{s['arnaques']} pour le "
                   f"modèle livré, {c['detectees']}/{c['arnaques']} pour le candidat."
                   + ("" if ok else f" Le candidat laisserait passer "
                      f"{s['detectees'] - c['detectees']} arnaque(s) de plus.")})

    # 2. Faux positifs : pas plus de fausses alertes sur des messages normaux.
    if real_c and real_c["normaux"] > 0:
        c, s, base = real_c, real_s, "test réel figé"
    else:
        c, s, base = synth_c, synth_s, "test synthétique, faute de messages normaux réels figés"
    ok = c["faux_positifs"] <= s["faux_positifs"]
    checks.append({"ok": ok, "texte":
                   f"Fausses alertes sur messages normaux ({base}) : {s['faux_positifs']}/"
                   f"{s['normaux']} pour le modèle livré, {c['faux_positifs']}/{c['normaux']} "
                   f"pour le candidat."
                   + ("" if ok else f" Le candidat déclencherait "
                      f"{c['faux_positifs'] - s['faux_positifs']} fausse(s) alerte(s) de plus.")})

    # 3. Garde-fou : le test synthétique ne doit pas s'effondrer.
    f_c = 0.0 if np.isnan(synth_c["f1"]) else synth_c["f1"]
    f_s = 0.0 if np.isnan(synth_s["f1"]) else synth_s["f1"]
    ok = f_c >= f_s - MAX_SYNTH_F1_DROP
    checks.append({"ok": ok, "texte":
                   f"F1 sur le test synthétique : {f_s:.3f} → {f_c:.3f} "
                   f"(baisse tolérée : {MAX_SYNTH_F1_DROP})."})
    return all(c["ok"] for c in checks), checks


# --- Export -----------------------------------------------------------------------------
def run_flutter_parity() -> tuple[bool, str]:
    # Depuis la 1.1.0, l'app n'utilise plus le modèle : plus de test Dart.
    if not (T.ROOT / PARITY_TEST).exists():
        return True, "sans objet (l'app n'utilise plus le modèle depuis la 1.1.0)"
    exe = shutil.which("flutter")
    if exe is None:
        return False, "flutter introuvable dans le PATH"
    proc = subprocess.run([exe, "test", PARITY_TEST], cwd=T.ROOT, capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    last = (proc.stdout.strip().splitlines() or [""])[-1]
    return proc.returncode == 0, last.strip()


def export_candidate(model: Pipeline, best_c: float, metrics: dict, paths: Paths,
                     with_flutter: bool) -> tuple[bool, str, str]:
    """Écrit modèle + fixtures. En cas d'échec (parité ou flutter test), remet les
    anciens fichiers. Renvoie (exporté, message parité, message flutter)."""
    backups = {p: p.read_bytes() for p in (paths.model, paths.parity) if p.exists()}

    def restore() -> None:
        for p in (paths.model, paths.parity):
            if p in backups:
                p.write_bytes(backups[p])
            elif p.exists():
                p.unlink()

    export = T.build_export(model, best_c, metrics)
    T.write_model(export, paths.model)
    max_gap, n_cases = T.write_parity(model, export, paths.parity)
    parity_msg = (f"{n_cases} cas régénérés ; écart implémentation de référence / "
                  f"scikit-learn : {max_gap:.1e}")
    if max_gap > 1e-12:
        restore()
        return False, parity_msg + " → trop grand, anciens fichiers remis", "non lancé"
    if not with_flutter:
        return True, parity_msg, "non lancé (option --sans-flutter)"
    ok, last = run_flutter_parity()
    if not ok:
        restore()
        return False, parity_msg, f"ÉCHEC ({last}) → anciens fichiers remis"
    return True, parity_msg, f"réussi ({last})"


# --- Rapport ----------------------------------------------------------------------------
def pct(x: float) -> str:
    return "–" if x is None or np.isnan(x) else f"{x * 100:.1f} %".replace(".", ",")


def short(text: str, n: int = 90) -> str:
    text = " ".join(T.normalize_text(text).split()).replace("|", "/")
    return text if len(text) <= n else text[: n - 1] + "…"


def metrics_table(name: str, ship: dict | None, cand: dict) -> list[str]:
    rows = [f"### {name} ({cand['n']} messages : {cand['arnaques']} arnaques, "
            f"{cand['normaux']} normaux)", "",
            "| Mesure | Modèle livré | Candidat |", "|---|---|---|"]

    def cell(m: dict | None, key: str) -> str:
        if m is None:
            return "–"
        if key == "faux_positifs":
            return f"{m['faux_positifs']} sur {m['normaux']} ({pct(m['taux_fp'])})"
        if key == "ratees":
            return f"{m['ratees']} sur {m['arnaques']}"
        return pct(m[key])

    for label, key in [("Précision", "precision"), ("Rappel", "recall"), ("F1", "f1"),
                       ("Fausses alertes (messages normaux)", "faux_positifs"),
                       ("Arnaques ratées", "ratees")]:
        rows.append(f"| {label} | {cell(ship, key)} | {cell(cand, key)} |")
    return rows + [""]


def write_report(paths: Paths, today: date, *, accepted: bool, exported: bool,
                 dry_run: bool, checks: list[dict], frozen_msg: str, data: dict,
                 metrics: dict, poison: dict, parity_msg: str, flutter_msg: str,
                 shipped_version: str | None, best_c: float) -> Path:
    paths.reports.mkdir(parents=True, exist_ok=True)
    path = paths.reports / f"{today.isoformat()}.md"
    k = 2
    while path.exists():  # plusieurs réentraînements le même jour
        path = paths.reports / f"{today.isoformat()}-{k}.md"
        k += 1

    if exported:
        verdict = "✅ Nouveau modèle ACCEPTÉ et exporté"
        summary = ("Le modèle candidat fait au moins aussi bien que le modèle livré sur "
                   "les points qui comptent. Il remplace l'ancien dans l'application.")
    elif accepted and dry_run:
        verdict = "🟡 Candidat acceptable, mais rien n'a été exporté (mode --essai)"
        summary = "Le candidat passerait la porte de qualité. Relance sans --essai pour l'exporter."
    elif accepted:
        verdict = "❌ Candidat accepté mais export ANNULÉ"
        summary = ("Le candidat passait la porte de qualité, mais la vérification après "
                   "export a échoué. Les anciens fichiers ont été remis : rien n'a changé.")
    else:
        verdict = "❌ Nouveau modèle REFUSÉ : rien n'a été modifié"
        summary = ("Le candidat ferait moins bien que le modèle livré sur au moins un "
                   "point important (détails ci-dessous). Le modèle de l'application "
                   "n'a pas été touché.")

    L = [f"# Réentraînement du {today.isoformat()}", "", f"**{verdict}**", "", summary, "",
         "## Les données", "",
         "| | Nombre |", "|---|---|",
         f"| Messages synthétiques (écrits à la main) | {data['seed']} |",
         f"| Messages réels (signalements revus) | {data['reels_total']} |",
         f"| Jeu de test réel figé | {data['fige']} |",
         f"| Réels utilisés pour l'entraînement | {data['reels_entrainement']} |",
         f"| Réels écartés : copies ou quasi-copies du test figé | "
         f"{data['reels_dans_test_fige'] + data['reels_proches_du_test_fige']} |",
         f"| Réels écartés : labels contradictoires | {data['reels_contradictoires_ecartes']} |",
         f"| Total entraînement du candidat | {data['entrainement']} |",
         f"| Test synthétique | {data['test_synth']} |", "",
         f"Jeu de test réel : {frozen_msg}.", "",
         "## Résultats", "",
         f"Modèle livré : `{shipped_version or 'aucun'}`. Candidat : C = {best_c}.", ""]
    L += metrics_table("Test réel figé", metrics["livre"].get("reel") if metrics["livre"]
                       else None, metrics["candidat"]["reel"]) if metrics["candidat"].get(
        "reel") else ["### Test réel figé", "", "Pas encore disponible (voir ci-dessus).", ""]
    L += metrics_table("Test synthétique", metrics["livre"]["synthetique"]
                       if metrics["livre"] else None, metrics["candidat"]["synthetique"])
    L += ["Le test synthétique est trop facile (messages écrits à la main) : ses chiffres "
          "sont optimistes. Le test réel figé est celui qui compte.", "",
          "## Porte de qualité", ""]
    L += [f"- {'✅' if c['ok'] else '❌'} {c['texte']}" for c in checks]
    L += ["", "## Export et test de parité Dart / Python", ""]
    if exported or (accepted and not dry_run):
        L += [f"- Fixtures de parité : {parity_msg}", f"- `flutter test {PARITY_TEST}` : {flutter_msg}"]
    else:
        L += ["- Rien n'a été exporté : modèle, fixtures et tests inchangés."]

    L += ["", "## Surveillance de l'empoisonnement", "",
          f"Analyse de {poison['n']} messages réels (test figé compris). « Empoisonner » un "
          "modèle, c'est lui glisser des exemples faux pour le tromper.", ""]
    if poison["contradictions"]:
        L += [f"⚠️ **{len(poison['contradictions'])} paire(s) de messages presque identiques "
              "avec des labels opposés** (écartées de l'entraînement, à revérifier dans la "
              "revue) :", "", "| Message A (label) | Message B (label) | Similarité |",
              "|---|---|---|"]
        L += [f"| {short(c['a'])} ({c['label_a']}) | {short(c['b'])} ({c['label_b']}) | "
              f"{c['similarite']:.2f} |" for c in poison["contradictions"][:30]]
        L.append("")
    else:
        L += ["- ✅ Aucun quasi-doublon avec des labels contradictoires."]
    if poison["clusters"]:
        L += [f"- ⚠️ Groupe de {c['taille']} quasi-copies ({pct(c['part'])} des réels, "
              f"{c['arnaques']} étiquetées arnaque), ex. : « {short(c['exemple'], 70)} »"
              for c in poison["clusters"]]
    else:
        L += ["- ✅ Aucun message recopié en masse."]
    if poison["domaines"]:
        L += [f"- ⚠️ Domaine `{d['domaine']}` dans {d['messages']} messages ({pct(d['part'])})"
              for d in poison["domaines"]]
    else:
        L += ["- ✅ Aucun domaine sur-représenté."]
    if poison["sources"]:
        L += [f"- ⚠️ Source « {s['source']} » : {s['messages']} messages ({pct(s['part'])})"
              for s in poison["sources"]]
    else:
        seen = ", ".join(f"« {s} » : {c}" for s, c in poison["sources_vues"].items()) or "aucune"
        L += [f"- ✅ Aucune source sur-représentée (sources vues : {seen})."]

    L += ["", "## Petit lexique", "",
          "- **Précision** : quand le modèle crie « arnaque », combien de fois il a raison.",
          "- **Rappel** : parmi toutes les vraies arnaques, combien il en attrape.",
          "- **F1** : une note unique qui combine précision et rappel (1 = parfait).",
          "- **Fausse alerte (faux positif)** : un message normal pris pour une arnaque.",
          "- **Test réel figé** : des vrais messages mis de côté une fois pour toutes. Le "
          "modèle ne les voit jamais pendant l'entraînement, ce qui permet de comparer "
          "honnêtement les modèles d'une fois sur l'autre.",
          "- **Porte de qualité** : le nouveau modèle n'est gardé que s'il ne rate pas plus "
          "d'arnaques réelles et ne crée pas plus de fausses alertes que l'ancien.", ""]
    with open(path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(L))
    return path


# --- Programme principal ------------------------------------------------------------------
def run(paths: Paths, *, dry_run: bool = False, with_flutter: bool = True,
        today: date | None = None) -> Result:
    today = today or date.today()
    seed = read_csv(paths.seed)
    perso = read_csv(paths.perso)

    frozen, frozen_msg = load_or_freeze_real_test(perso, paths.frozen)
    all_real = pd.concat([frozen, perso], ignore_index=True).drop_duplicates(
        subset=["text", "label"]).reset_index(drop=True)
    poison = detect_poisoning(all_real)

    seed_dedup = seed.drop_duplicates(subset="text").reset_index(drop=True)
    seed_train, seed_test = T.split(seed_dedup)
    train, stats = build_training_set(seed_train, seed_test, perso, frozen, poison["exclus"])
    model, best_c = train_candidate(train)

    # Évaluation des deux modèles sur les deux jeux de test.
    tests = {"synthetique": seed_test}
    if len(frozen):
        tests["reel"] = frozen
    cand = {k: evaluate(model.predict_proba(df["text"])[:, 1], df["label"], T.THRESHOLD)
            for k, df in tests.items()}
    shipped_json = json.loads(paths.model.read_text(encoding="utf-8")) if paths.model.exists() else None
    ship = None
    if shipped_json:
        ship = {k: evaluate(shipped_proba(shipped_json, df["text"].tolist()), df["label"],
                            shipped_json["threshold"]) for k, df in tests.items()}

    accepted, checks = quality_gate(cand, ship)
    exported, parity_msg, flutter_msg = False, "", "non lancé"
    if accepted and not dry_run:
        metrics_export = {"n_train": len(train), "n_test": len(seed_test),
                          **cand["synthetique"], "test_reel_fige": cand.get("reel"),
                          "attention": "test synthetique optimiste ; voir test_reel_fige"}
        exported, parity_msg, flutter_msg = export_candidate(
            model, best_c, metrics_export, paths, with_flutter)

    data = {"seed": len(seed), "fige": len(frozen), "test_synth": len(seed_test), **stats}
    metrics = {"livre": ship, "candidat": cand}
    report = write_report(paths, today, accepted=accepted, exported=exported, dry_run=dry_run,
                          checks=checks, frozen_msg=frozen_msg, data=data, metrics=metrics,
                          poison=poison, parity_msg=parity_msg, flutter_msg=flutter_msg,
                          shipped_version=shipped_json["version"] if shipped_json else None,
                          best_c=best_c)
    reasons = [c["texte"] for c in checks if not c["ok"]]
    return Result(accepted, exported, reasons, report, poison, metrics, flutter_msg)


def main(argv: list[str] | None = None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Réentraînement sûr du détecteur d'arnaques")
    parser.add_argument("--essai", action="store_true", help="rapport seul, aucun export")
    parser.add_argument("--sans-flutter", action="store_true", help="ne lance pas flutter test")
    args = parser.parse_args(argv)
    result = run(Paths.default(), dry_run=args.essai, with_flutter=not args.sans_flutter)
    if result.exported:
        print("Nouveau modèle accepté et exporté.")
    elif result.accepted:
        print("Candidat acceptable, mais pas exporté (voir le rapport).")
    else:
        print("Nouveau modèle refusé, rien n'a été modifié :")
        for r in result.reasons:
            print(f"  - {r}")
    print(f"Rapport : {result.report_path}")
    return 0 if result.exported or result.accepted else 1


if __name__ == "__main__":
    sys.exit(main())
