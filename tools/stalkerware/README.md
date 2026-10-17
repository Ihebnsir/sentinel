# Indicateurs de stalkerware (update_ioc.py)

Génère `assets/data/stalkerware_ioc.json` à partir du projet public
[AssoEchap/stalkerware-indicators](https://github.com/AssoEchap/stalkerware-indicators),
maintenu par l'association [Echap](https://echap.eu.org/).

## Licence et attribution

Les données sont sous licence [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.fr) :
réutilisation permise, à condition de **citer la source** et d'**indiquer les
modifications**. C'est fait :

- dans le JSON (`source`, `commit`, `license`, `attribution`) ;
- dans les README (section « Données tierces ») ;
- dans l'app, en bas de l'écran de conseils (`iocCredit`).

## Format d'origine (ioc.yaml)

Une liste d'entrées : `name`, `type` (`stalkerware`), `names`, `packages`,
`certificates` (empreintes **SHA-1** du certificat, 40 caractères
hexadécimaux, comme `cert.sha1_fingerprint` dans leur `tools/check_apk.py`),
`websites`, `c2`. Seuls `name`, `packages` et `certificates` sont gardés.

## Mise à jour

```sh
tools/.venv/Scripts/python -m pip install -r tools/requirements.txt
tools/.venv/Scripts/python -I tools/stalkerware/update_ioc.py
```

Le commit est épinglé dans le script (`COMMIT`). Pour passer à une version
plus récente :

1. Choisir un commit sur GitHub et relire le diff de `ioc.yaml`.
2. Remplacer `COMMIT` dans `update_ioc.py` (SHA complet de 40 caractères).
3. Relancer le script, relire le diff du JSON, lancer `flutter test`.

Les packages et empreintes au format inattendu sont rejetés et comptés.

## Limites

La liste ne couvre que les stalkerwares connus : aucune correspondance ne
veut pas dire aucun logiciel espion.
