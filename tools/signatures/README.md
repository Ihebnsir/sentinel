# Empreintes de certificat (extract_cert.py)

Sert à remplir `certSha256` dans `lib/services/apps/known_apps.dart` avec des
empreintes **vérifiées**, jamais recopiées d'un site web.

## Pourquoi

Chaque APK est signé par une clé que seul l'éditeur possède. L'empreinte
SHA-256 du certificat identifie donc l'éditeur : une copie modifiée de
WhatsApp peut garder le nom et le package `com.whatsapp`, mais pas la
signature de WhatsApp.

## Méthode conseillée (app installée depuis le Play Store)

1. Sur un téléphone de test, installer l'app depuis le **Play Store**.
2. Activer le débogage USB, brancher le téléphone, installer les
   [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb`).
3. Lancer, depuis la racine du projet :

   ```sh
   python -I tools/signatures/extract_cert.py --adb com.whatsapp
   ```

4. Vérifier que la ligne `Installateur` affiche `com.android.vending`
   (Play Store), et que le sujet correspond à l'éditeur attendu.
5. Recopier la ligne `certSha256: [...]` dans l'entrée de `known_apps.dart`.
6. Idéalement, refaire la mesure sur un second téléphone : les deux
   empreintes doivent être identiques.

## Avec un fichier APK

```sh
python -I tools/signatures/extract_cert.py chemin/vers/app.apk
```

Le script **lit** le certificat mais ne vérifie pas la signature. Pour un APK
téléchargé, vérifier d'abord avec l'outil officiel du SDK Android :

```sh
apksigner verify --print-certs chemin/vers/app.apk
```

Les deux doivent donner la même empreinte SHA-256.

## Détails

- Aucune dépendance Python : le script lit le bloc de signature APK
  (schémas v2, v3, v3.1), sinon la signature v1 (`META-INF/*.RSA`).
- L'empreinte est le SHA-256 du certificat X.509 (format DER), comme
  `keytool -printcert` et `apksigner`. Vérifié sur l'APK debug de Sentinel :
  même résultat que `keytool -exportcert` sur `debug.keystore`.
- Le SHA-1 est aussi affiché : c'est le format utilisé par les indicateurs
  de stalkerware (`tools/stalkerware/`).
- Une app peut avoir changé de clé (rotation, schéma v3) : Android garde
  alors l'historique, et Sentinel accepte toute empreinte de la liste.
