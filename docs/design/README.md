# Captures avant / après la refonte du design

- `avant/` : version 1.1.0 avant la refonte (commit `1c05263`).
- `apres/` : après la refonte (système de design, `docs/DESIGN.md`).
- Audit qui a guidé les changements : [AUDIT_DESIGN.md](AUDIT_DESIGN.md).

Même nom de fichier des deux côtés : `<écran>_<variante>.png`, variantes `fr-clair`, `fr-sombre`, `ar-clair`. Format Pixel 8 à demi-résolution (540 × 1200), rendu par `test/design/screens_capture_test.dart`, données fictives.

Comparaisons les plus parlantes :

| Changement | Avant | Après |
|---|---|---|
| Accueil : score, puis « à faire », puis « Vos protections » | [avant](avant/accueil_fr-clair.png) | [après](apres/accueil_fr-clair.png) |
| Verdict d'un lien : arche + icône + mot | [avant](avant/liens-dangereux_fr-clair.png) | [après](apres/liens-dangereux_fr-clair.png) |
| Niveau de risque des apps en badge (arabe) | [avant](avant/applications_ar-clair.png) | [après](apres/applications_ar-clair.png) |
| État vide illustré : porte bleue | [avant](avant/coffre-vide_fr-clair.png) | [après](apres/coffre-vide_fr-clair.png) |
| État vide illustré : moucharabieh (sombre) | [avant](avant/applications-vide_fr-sombre.png) | [après](apres/applications-vide_fr-sombre.png) |
| Coffre verrouillé : visuel aligné sur le texte | [avant](avant/coffre-verrouille_fr-sombre.png) | [après](apres/coffre-verrouille_fr-sombre.png) |
| Interrupteurs au bleu Sentinel | [avant](avant/pare-feu_fr-clair.png) | [après](apres/pare-feu_fr-clair.png) |
