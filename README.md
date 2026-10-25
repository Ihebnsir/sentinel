<p align="center">
  <img src="assets/branding/icon_full.png" alt="Sentinel icon" width="112">
</p>

<h1 align="center">Sentinel</h1>

<p align="center">
  Android security app that audits the phone, scores installed apps, detects scam messages on-device and keeps secrets in an encrypted vault.
</p>

<p align="center">
  <a href="https://github.com/Ihebnsir/sentinel/actions/workflows/ci.yml"><img src="https://github.com/Ihebnsir/sentinel/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.fr.md">Français</a>
</p>

---

The app's interface is in French. Everything runs on the phone. Nothing goes over the network without your consent: the only network calls are three opt-in features, the breach check against Have I Been Pwned (5 hex characters of a SHA-1 hash, k-anonymity), the DNS firewall (forwards DNS queries to Quad9, encrypted with DNS over TLS or HTTPS) and the blocklist updates (downloads from GitHub).

## Screenshots

> **TODO:** add screenshots to `docs/screenshots/` (see [docs/screenshots/README.md](docs/screenshots/README.md)), then uncomment the table below.

<!--
| Home | Apps | Messages | Vault |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/home.png" width="200"> | <img src="docs/screenshots/apps.png" width="200"> | <img src="docs/screenshots/messages.png" width="200"> | <img src="docs/screenshots/vault.png" width="200"> |
-->

## Features

- **Device audit.** Security score out of 100 from 7 checks: screen lock, root indicators, security patch age (< 90 days), strong biometrics, developer options, USB debugging and storage encryption. Failed checks link to the matching Android settings screen (except root, which can't be fixed from settings).
- **App scanner.** Lists installed apps and gives each a 0–100 risk score from explainable rules: accessibility service, install source, device admin, SMS access, notification listener, overlay, microphone, background location, old `targetSdk`, and more. Pre-installed system apps are only flagged for accessibility or device admin.
- **Fake apps and stalkerware.** Reads each app's signing certificate (SHA-256/SHA-1, subject) and whether its launcher icon was hidden. Flags apps that use the name of a popular app (WhatsApp, Facebook, Instagram, TikTok…) with another package, official packages signed by someone else (once reference fingerprints are filled in), known WhatsApp mods (GB WhatsApp, FM WhatsApp…), test-key signatures, and known stalkerware from the public [Stalkerware Indicators](https://github.com/AssoEchap/stalkerware-indicators) list, even when disguised as a system app. When spyware is suspected, Sentinel shows safety advice **before** offering to uninstall, and never sends a notification about it.
- **Scam message detection.** Paste a message, share it from another app, or select text and choose "Vérifier avec Sentinel". An on-device model (TF-IDF over character n-grams + logistic regression) is combined with link rules: brand impersonation, raw IP address, punycode, `@` in the URL, URL shorteners, suspicious TLDs, too many subdomains, plain `http`. The verdict comes with the reasons.
- **Automatic protection (opt-in).** A notification listener reads incoming messages from SMS apps, WhatsApp, WhatsApp Business, Messenger, Telegram and Viber. They are analyzed by the same Dart model in a headless Flutter engine, and a "likely scam" alert is shown when the verdict is a scam.
- **Wi-Fi check.** Shows the encryption type (open, WEP, WPA2, WPA3, OWE, enterprise), captive portal and Private DNS status, without the location permission and without reading the network name.
- **Encrypted vault.** Stores passwords and secure notes, encrypted with Argon2id + AES-256-GCM. You can unlock it with the master password, a recovery key, or a fingerprint (Android Keystore). An encrypted backup file (`.sentinel`) moves it to a new phone.
- **Password tools.** Random password generator (12–64 characters), strength estimate, and a password health report: breached (Have I Been Pwned), reused and weak passwords.

## Security highlights

- **Privacy by design.** No account, no analytics, no backend. Message text is never logged or stored. Kotlin keeps only `hashCode()` values to skip duplicates.
- **Opt-in network calls only.** No network call at startup (the font is bundled). The breach check needs explicit consent. It uses the Pwned Passwords range API (k-anonymity): only the first 5 hex characters of the SHA-1 hash leave the device, and `Add-Padding: true` hides the response size. Results stay in memory and are cleared when the vault locks.
- **Vault cryptography.** A random 256-bit data key (DEK) encrypts the items with AES-256-GCM, using a fresh 12-byte nonce on every write. The DEK is wrapped by one key-encryption key (KEK) per *key slot*:
  - password: Argon2id, 46 MiB, 2 iterations, parallelism 1, 16-byte random salt, run in a separate isolate;
  - recovery key: 28 characters from a 32-symbol alphabet (140 bits), HKDF-SHA256;
  - fingerprint: AES-256-GCM key in the Android Keystore, `BIOMETRIC_STRONG` required for every operation, invalidated when a new fingerprint is enrolled.
- **Authenticated header.** The whole file header (slots, KDF parameters, last password unlock date) is the AES-GCM associated data. Changing a single byte makes decryption fail. KDF parameters read from the file have bounds, so a tampered file cannot request extreme memory or iterations.
- **Unlock hardening.** Growing delay after a wrong password (1 s, 2 s, 4 s… capped at 30 s). The master password is required again after 7 days of fingerprint-only unlocks.
- **On-screen protection.** `FLAG_SECURE` on the vault tab (no screenshots, hidden in recent apps). The vault locks when the screen turns off and after 30 s in the background. Copied secrets are marked sensitive (Android 13+) and cleared from the clipboard after 30 s.
- **Safe alerts.** Scam alerts show a neutral text on the lock screen. Domains in the alert are defanged (`site[.]xyz`), and Android's automatic "open link" actions are disabled.
- **Atomic writes.** The vault is written to a temporary file and then renamed, so a crash cannot corrupt it.
- **No Android backup.** `allowBackup="false"`, plus `dataExtractionRules` on Android 12+, keep app data out of cloud backups and device-to-device transfers. To change phones, the user exports the vault instead (next point).
- **Encrypted export / import.** "Exporter une sauvegarde chiffrée" (vault settings) writes a versioned `.sentinel` file: Argon2id of a separate export password (same strength rules as the master password) + AES-256-GCM, with the header as associated data. It is saved and opened through the Android file picker (Storage Access Framework), so the app needs no storage permission. "Restaurer une sauvegarde" (vault creation screen) asks for the file, its password, then a new master password, and creates a new vault with a new recovery key. A wrong password or a modified file gets a clear message, never a crash.

Full threat model and known limitations: [docs/SECURITY_DESIGN.md](docs/SECURITY_DESIGN.md).

## Architecture

Flutter (Dart) handles the UI and all the logic: scoring, ML inference, cryptography. Kotlin talks to Android APIs through `MethodChannel`s: device state, package manager, Wi-Fi, Keystore and biometrics, the notification listener. For background analysis, Kotlin starts a headless Flutter engine that runs the same Dart model as the UI.

Diagrams and details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Tech stack

| Area | Technology |
|---|---|
| App | Flutter 3.47.7, Dart 3.13.5 |
| Android | Kotlin, Java 17, Android Gradle Plugin 9.1.0, Gradle 9.3.1 |
| Cryptography | [`cryptography`](https://pub.dev/packages/cryptography) (Argon2id, AES-GCM, HKDF), [`crypto`](https://pub.dev/packages/crypto) (SHA-1), Android Keystore |
| Network | [`http`](https://pub.dev/packages/http) (Pwned Passwords API only) |
| Machine learning | Python 3.14, scikit-learn 1.9.1, pandas, numpy (training only; inference is in Dart) |
| CI | GitHub Actions, Gitleaks, Dependabot |

## Tests

**447 tests** in 29 test files (`flutter test`). They cover:

- the vault: the Argon2id RFC 9106 test vector, encryption, key slots, v1 → v2 migration, tamper detection (ciphertext, wrapped key, header), session and lock behavior;
- the encrypted backup: export/import round trip, wrong password, tampered file, unknown version, empty file, restore into a new vault;
- **bit-for-bit parity** between the Dart and scikit-learn models on 30 fixtures (5 languages plus Unicode edge cases, tolerance 1e-9);
- the k-anonymity client, using a fake HTTP client;
- the app, device and Wi-Fi risk rules;
- password health and the password generator.

Network and biometrics are replaced by test doubles, so the tests run offline.

## Getting started

Prerequisites: Flutter 3.47.7 (stable), Java 17, Android SDK. Android is the only target platform.

```bash
git clone https://github.com/Ihebnsir/sentinel.git
cd sentinel
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Release builds still use the debug signing config. A release signing setup is a TODO (see Roadmap).

## Machine learning

The scam classifier is trained in Python (`ml/train.py`) and exported to `assets/models/phishing_model.json`. The app re-implements the preprocessing and the prediction in pure Dart (`lib/services/phishing/phishing_model.dart`). The exact specification is in [ml/README.md](ml/README.md).

Pipeline:

1. Merge `ml/data/messages_seed.csv` (400 synthetic messages: 200 scam, 200 normal) with `ml/data/messages_perso.csv` (real messages; currently empty), then remove duplicates.
2. Stratified 80/20 split (`random_state=42`).
3. `TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 5), sublinear_tf=True, min_df=2, max_features=8000)`.
4. `LogisticRegression(class_weight="balanced")`, with `C` chosen by 5-fold cross-validation on F1 (selected: `C = 30`).
5. Export the model and the parity fixtures. A sklearn-free reference implementation re-checks the specification.

Languages: French, Arabic, Tunisian Derja (Latin and Arabic script), English.

Test-set metrics, as written by `train.py` to `metrics_test` in the shipped model (80 messages):

| Precision | Recall | F1 | Accuracy | Confusion matrix `[[TN, FP], [FN, TP]]` |
|---:|---:|---:|---:|---|
| 0.952 | 1.000 | 0.976 | 0.975 | `[[38, 2], [0, 40]]` |

> **Honest warning.** The dataset is synthetic and hand-written, and these numbers are **optimistic**. They do not show real-world performance. In the synthetic data, every scam link uses `.xyz`/`.top` or `bit.ly`, so the model leans heavily on those n-grams. In the app, the link rules and a conservative threshold (≥ 0.8 for "likely scam" from the model alone) partly make up for this. Credible metrics need real, varied messages.

## Roadmap

These items come from the known limitations in the code and docs. **TODO:** review and reorder them.

- [ ] Collect real (anonymized) messages and retrain to get credible metrics.
- [ ] Manually verify the official domains in `lib/services/phishing/known_brands.dart` (TODO in the code).
- [ ] Release signing configuration (currently debug keys).
- [ ] Persist the failed-unlock counter across app restarts.
- [x] Encrypted vault export/import, to move the vault to a new phone (Android backup is disabled on purpose).
- [ ] Add screenshots.
- [ ] Fill in the reference certificate fingerprints in `lib/services/apps/known_apps.dart` with `tools/signatures/extract_cert.py`, and the packages of Tunisian banking and postal apps (TODO in the code).
- [ ] Add verified Tunisian help contacts to the stalkerware advice screen (TODO in `spyware_advice_screen.dart`).

## Security

Please report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

The app was audited against OWASP MASVS v2 (static and dynamic analysis, 17 findings and their fixes): see the [audit report](docs/audit/RAPPORT_AUDIT.md) (in French). Release builds are documented in [docs/RELEASE.md](docs/RELEASE.md).

## Third-party data

`assets/data/stalkerware_ioc.json` is derived from [Stalkerware Indicators of Compromise](https://github.com/AssoEchap/stalkerware-indicators) by [Echap](https://echap.eu.org/) (Julien Voisin, Tek and contributors), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Changes: only app names, package names and SHA-1 certificate fingerprints are kept, converted to JSON by `tools/stalkerware/update_ioc.py` at a pinned commit. The list is not exhaustive: no match does not mean no stalkerware.

The DNS firewall lists (`assets/blocklists/`) are generated by `tools/blocklists/update_lists.py` at pinned commits, converted to domain lists, merged and deduplicated (protected domains are removed):

- [Phishing.Database](https://github.com/Phishing-Database/Phishing.Database), licensed under [MIT](https://github.com/Phishing-Database/Phishing.Database/blob/master/LICENSE). Copyright (c) 2018-2025 Mitchell Krog, Copyright (c) 2018-2025 Nissar Chababy, Copyright (c) 2018-2025 Phishing.Database Contributors.
- [BlockLists](https://github.com/ShadowWhisperer/BlockLists) by ShadowWhisperer, public domain ([The Unlicense](https://github.com/ShadowWhisperer/BlockLists/blob/master/LICENSE)).
- [AdGuard CNAME disguised trackers list](https://github.com/AdguardTeam/cname-trackers), licensed under [MIT](https://github.com/AdguardTeam/cname-trackers/blob/master/LICENSE). Copyright 2021 Adguard Software Ltd.
- [AdAway default blocklist](https://github.com/AdAway/adaway.github.io) by Kicelo, Dominik Schuermann and contributors, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

Details, MIT license texts and rejected sources: [tools/blocklists/README.md](tools/blocklists/README.md).

## License

[MIT](LICENSE) © 2026 Iheb
