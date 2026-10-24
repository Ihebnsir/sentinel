# Publier une version de Sentinel

Une version publiée est **signée avec la clé de publication** (SEN-01) et **obfusquée** (SEN-04). Le build release refuse de démarrer sans la clé : il n'y a plus aucun repli sur la clé de debug.

## 1. Créer la clé (une seule fois)

À faire **soi-même**, dans PowerShell. La clé est rangée **hors du dépôt** : le build refuse un keystore placé dans le dossier du projet.

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\cles-sentinel"
keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\cles-sentinel\sentinel-release.p12" `
  -storetype PKCS12 `
  -alias sentinel `
  -keyalg RSA -keysize 4096 `
  -validity 10000
```

- `keytool` demande le **mot de passe** (deux fois), puis le nom, l'organisation et le pays. Ne jamais passer le mot de passe dans la commande (`-storepass`) : il resterait dans l'historique de PowerShell.
- Choisir une longue phrase de passe, unique.
- `-validity 10000` : environ 27 ans. Google Play exige une validité au-delà de 2033.

**Sauvegarde obligatoire.** Copier `sentinel-release.p12` sur un support hors ligne (clé USB rangée à part) et noter la phrase de passe dans un gestionnaire de mots de passe. **Perdre la clé = ne plus jamais pouvoir mettre à jour l'app** sur les téléphones où elle est installée. Avec Google Play, activer Play App Signing : cette clé devient alors la clé d'envoi (*upload key*), remplaçable en cas de perte.

## 2. Indiquer la clé au build

Créer `android/key.properties` (déjà ignoré par Git) **sans mot de passe** :

```properties
storeFile=C:/Users/VOTRE_NOM/cles-sentinel/sentinel-release.p12
keyAlias=sentinel
```

- Chemin absolu, avec des `/`.
- Les mots de passe sont demandés par le script (étape 3) et passés au build par les variables d'environnement `SENTINEL_STORE_PASSWORD` et `SENTINEL_KEY_PASSWORD`, effacées à la fin. On *peut* les écrire dans `key.properties` (`storePassword=…`, `keyPassword=…`), mais c'est déconseillé : ils seraient lisibles par tout programme qui lit vos fichiers.

Le build release s'arrête avec un message clair si : `key.properties` manque, `storeFile` ou `keyAlias` manque, le keystore est introuvable ou **dans le dépôt**, ou un mot de passe manque.

## 3. Construire

```powershell
powershell -ExecutionPolicy Bypass -File tools\release\build_release.ps1
```

Le script :
1. vérifie que `android\key.properties` existe ;
2. demande le mot de passe (saisie masquée, jamais écrite sur le disque) ;
3. lance `flutter build apk --release --obfuscate --split-debug-info=build/symbols` ;
4. copie les symboles dans `%LOCALAPPDATA%\Sentinel\symbols\<version>-<commit>` (hors du dépôt : `flutter clean` efface `build\`) ;
5. affiche le SHA-256 de l'APK.

## 4. Vérifier la signature

```powershell
$bt = Get-ChildItem "$env:LOCALAPPDATA\Android\sdk\build-tools" | Sort-Object Name | Select-Object -Last 1
& "$($bt.FullName)\apksigner.bat" verify --verbose --print-certs build\app\outputs\flutter-apk\app-release.apk
keytool -list -v -keystore "$env:USERPROFILE\cles-sentinel\sentinel-release.p12" -alias sentinel
```

À vérifier :
- `Verifies` et `Verified using v2 scheme (APK Signature Scheme v2): true` ;
- `Signer #1 certificate DN` **n'est pas** `CN=Android Debug` ;
- l'empreinte `SHA-256` du certificat affichée par `apksigner` est la même que celle de `keytool -list`.

Noter cette empreinte (par exemple dans la page de la version sur GitHub) : elle permet à chacun de vérifier qu'un APK vient bien de vous.

## 5. Décoder un plantage (symboles)

Une trace de pile d'une version obfusquée contient des noms illisibles. Pour la relire :

```powershell
flutter symbolize -i trace.txt -d "$env:LOCALAPPDATA\Sentinel\symbols\<version>-<commit>\app.android-arm64.symbols"
```

Prendre le fichier de l'architecture du téléphone (`arm64` pour la plupart). Les symboles ne sont **jamais** commités (`build/` est ignoré par Git) : il faut garder la copie de chaque version publiée.

## Ce qu'il ne faut jamais faire

- Committer `android/key.properties`, un `.jks`, un `.p12` ou un `.keystore` (ignorés par Git, à vérifier avec `git status` avant chaque commit).
- Ranger le keystore dans le dossier du projet (le build le refuse).
- Envoyer la clé ou la phrase de passe à qui que ce soit, y compris un assistant ou un outil en ligne.
- Distribuer un APK `profile` ou `debug` : ils sont signés avec la clé de debug.
