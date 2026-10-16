# Security design and threat model

[← Back to README](../README.md) · [Architecture](ARCHITECTURE.md) · [Reporting a vulnerability](../SECURITY.md)

This document lists what Sentinel protects, who it protects against, which measures are in the code, and where those measures stop. The protections below are the ones that exist in the current code; file references point to them.

Sentinel is a personal project. It has **not** had an independent security audit.

## 1. Assets

| Asset | Why it matters |
|---|---|
| Vault contents (passwords, secure notes) | Direct access to the user's accounts |
| Vault keys: master password, DEK, recovery key | Whoever has one of them can read the vault |
| Message content read by automatic protection | Private conversations, verification codes |
| Device and app inventory | Shows what is installed and how the phone is configured |
| The user's money and accounts | The final target of scams (phishing SMS, fake bank or postal links) |

## 2. Principles

- **Local first.** No backend, no account, no analytics. Every analysis runs on the device.
- **Least data.** Message text is never logged or stored. Wi-Fi checks never read the SSID/BSSID and never ask for the location permission.
- **Explicit consent** for the only network feature (breach check) and for the notification listener.
- **Fail closed.** Wrong key, modified header or modified ciphertext all lead to an authentication error, never to partially decrypted data.
- **Explainability.** Every risk score and verdict lists its reasons, so users can judge for themselves.

## 3. Attackers and countermeasures

### 3.1 Phone thief, or someone who borrows the phone

*Goal:* read the vault or the user's data.

| Measure | Where |
|---|---|
| Device audit pushes for a screen lock, strong biometrics, recent security patch and storage encryption | `security_score_calculator.dart`, `DeviceSecurityChecker.kt` |
| Vault locks as soon as the screen turns off, and after 30 s in the background (wall-clock check on resume, in case the timer was frozen) | `vault_screen.dart`, `VaultProtection.kt` |
| Master password: at least 12 characters and not rated "weak" | `password_strength.dart` |
| Growing delay after wrong passwords: 1, 2, 4, 8, 16, then 30 s | `VaultSession.delayAfterFailures` |
| Fingerprint unlock needs `BIOMETRIC_STRONG` on every use, and the key is invalidated when a new fingerprint is enrolled (so a thief can't add their own) | `VaultBiometric.kt` |
| Master password required again after 7 days, or if the stored date is more than a day in the future (clock tampering) | `VaultFile.needsPassword` |
| `FLAG_SECURE` on the vault tab: the vault is hidden in the recent-apps preview | `VaultProtection.setSecure` |
| Scam alerts show a neutral public version on the lock screen | `ScamAlertNotifier.kt` |

### 3.2 Malicious app on the same phone

*Goal:* steal secrets through screenshots, the clipboard or the screen, or abuse powerful permissions.

| Measure | Where |
|---|---|
| App scanner flags the patterns used by banking trojans: an enabled accessibility service (with an extra penalty when combined with an unknown install source), device admin, SMS access, notification listener, overlay | `app_risk_calculator.dart`, `InstalledAppsScanner.kt` |
| `FLAG_SECURE` blocks screenshots and screen recording of the vault | `VaultProtection.kt` |
| Copied secrets are marked `EXTRA_IS_SENSITIVE` (Android 13+) and cleared after 30 s, but only if the clipboard still holds the same value (retried on resume, because Android blocks background clipboard reads) | `vault_platform.dart` (`ClipboardGuard`) |
| Vault file stored in the app's private directory | `vault_storage.dart` |
| Screen-off receiver registered with `RECEIVER_NOT_EXPORTED` (Android 13+) | `VaultProtection.kt` |
| Notification listener bound with `BIND_NOTIFICATION_LISTENER_SERVICE`, so only the system can connect to it | `AndroidManifest.xml` |
| Alert `PendingIntent` is `FLAG_IMMUTABLE`, so another app can't change it | `ScamAlertNotifier.kt` |

### 3.3 Hostile Wi-Fi network

*Goal:* read or modify traffic, phish credentials on a captive portal.

| Measure | Where |
|---|---|
| Reports open, WEP and WPA networks as dangerous or weak, with advice (avoid banking, use mobile data) | `wifi_risk.dart` |
| Detects captive portals, caps them at "weak" and warns against reusing passwords on the login page | `wifi_risk.dart` |
| Detects when Private DNS is off and links to the setting | `WifiSecurityChecker.kt` |
| The only network call (HIBP) uses HTTPS with a 10 s timeout. Even a full MITM only sees a 5-character hash prefix | `pwned_passwords.dart` |

### 3.4 Someone who gets the vault file

*Goal:* an offline attack on a copy of `vault.json` (from a backup, a forensic dump or a rooted device).

| Measure | Where |
|---|---|
| Items are encrypted with AES-256-GCM under a random 256-bit DEK, with a fresh 12-byte nonce on every write | `vault_crypto.dart` |
| The password KEK uses Argon2id (46 MiB, 2 passes, parallelism 1, random 16-byte salt), above the OWASP minimum of 19 MiB / 2 passes. A unit test checks the RFC 9106 vector | `vault_crypto.dart`, `test/vault_crypto_test.dart` |
| The recovery key carries 140 bits of entropy, so a fast KDF (HKDF-SHA256) is enough | `recovery_key.dart` |
| The biometric slot is useless without the Keystore key, which never leaves the device's Keystore | `VaultBiometric.kt` |
| The whole header is AAD: changing slots, KDF parameters or the 7-day date breaks decryption | `VaultFile.header`, `KeySlot.aad` |
| KDF parameters read from the file are bounded (memory ≤ 1 GiB, iterations ≤ 20, parallelism ≤ 16, salt = 16 bytes), so a crafted file cannot freeze the device | `KdfParams.fromJson` |
| No secret in plain text in the file (tested) | `test/vault_crypto_test.dart` |
| Atomic write (temp file, then rename), so an interrupted write cannot corrupt the vault | `vault_storage.dart` |
| Android backup disabled: `android:allowBackup="false"`, and on Android 12+ `dataExtractionRules` exclude every storage domain from both cloud backup and device-to-device transfer, so the file never leaves the phone through a backup | `AndroidManifest.xml`, `res/xml/data_extraction_rules.xml` |

### 3.5 Scammer (SMS, WhatsApp, Telegram…)

*Goal:* make the user click a fake link, pay, or give out a code.

| Measure | Where |
|---|---|
| On-device classifier trained on French, Arabic, Tunisian Derja and English messages | `phishing_model.dart`, `ml/` |
| Link rules: impersonation of 22 Tunisian brands (banks, La Poste, operators, CNSS/CNAM, payment services), raw IP, punycode, `@` trick, shorteners, cheap TLDs, deep subdomains, plain `http` | `url_analyzer.dart`, `known_brands.dart` |
| Brand impersonation or an IP link means "Arnaque probable" (likely scam) whatever the model says | `message_analyzer.dart` |
| Optional background protection: the user doesn't need to think of checking | `SentinelNotificationListener.kt` |
| Domains in alerts are defanged (`site[.]xyz`), and system "smart actions" are disabled so the alert never offers to open the scam link | `background_analyzer.dart`, `ScamAlertNotifier.kt` |
| Clear advice for each verdict (don't click, never share codes, call the official number) | `message_analyzer.dart` |

### 3.6 Privacy toward third parties (HIBP, network observers)

| Measure | Where |
|---|---|
| k-anonymity: only the first 5 hex characters of the SHA-1 hash are sent | `pwned_passwords.dart` |
| `Add-Padding: true`, so the response size doesn't reveal the prefix | `pwned_passwords.dart` |
| Explicit, revocable consent. Revoking it also erases the results | `breach_checker.dart`, `breach_consent_sheet.dart` |
| Results are kept in memory, keyed by hash, and cleared on lock. The response cache only lasts for one check run | `breach_checker.dart` |

## 4. Known limitations

These are real gaps. Some can't be fixed in this setup; others are on the roadmap.

1. **Dart memory can't be reliably wiped.** `wipe()` zeroes the `Uint8List` keys, but the master password, item passwords and decrypted JSON go through immutable Dart `String`s. Copies can also stay behind from the garbage collector or from isolate messages (the Argon2id isolate gets the password). Wiping shortens how long a key lives in memory; it does not guarantee erasure.
2. **The failure counter only lives in memory.** The 1 s → 30 s backoff resets when the app is killed and restarted. It slows down guessing on the device only. An attacker with a copy of the file is limited by the cost of Argon2id alone.
3. **The ML model is trained on synthetic data.** 400 hand-written messages, with optimistic metrics (F1 0.976 on 80 test messages). Every synthetic scam link uses `.xyz`/`.top`/`bit.ly`, so real scams on other domains may be missed by the model and caught only by the link rules, or not at all.
4. **Limited Wi-Fi analysis.** The encryption type can only be read on **Android 12+** without the location permission; older versions show "unknown". Sentinel does not detect evil-twin access points, ARP/DNS spoofing or TLS interception. It only reports what Android exposes (encryption type, captive portal, Private DNS).
5. **No protection on a rooted or compromised phone.** Root detection is a simple heuristic (`su` binary paths, `test-keys`), easy to hide (e.g. Magisk), and it only lowers the score. With root or a compromised OS, an attacker can read process memory, hook the app, log keystrokes or bypass `FLAG_SECURE`.
6. **Accessibility malware can still read the screen.** `FLAG_SECURE` stops screenshots, not accessibility services. Sentinel can only flag those apps.
7. **Clipboard.** The "sensitive" flag is only honored by the system on Android 13+. Before that, keyboards and clipboard managers may keep a copy. Clearing after 30 s is best-effort: if the process is killed, the timer is gone.
8. **Message text in the alert.** For tap-to-check, the message text is kept in the alert's `PendingIntent` extras until the user taps or dismisses it. It is never logged or written by Sentinel.
9. **Keystore strength depends on the device.** The biometric key doesn't require StrongBox. On some devices the Keystore is TEE-backed or weaker. The 7-day rule is an app policy based on the device clock, not a cryptographic barrier.
10. **No way to move the vault to a new phone (yet).** Android backup is disabled on purpose (see 3.4), so the vault, the breach-check consent and the protection switch are not restored on a new phone or after a reinstall. Users who change phones lose their vault unless they copy their entries by hand. The recovery key doesn't help here, because it unlocks a file that is no longer there. Planned fix: an explicit, user-triggered export of the vault as an encrypted file (protected by its own password with Argon2id + AES-256-GCM), imported on the new phone.
11. **Recovery key = full access.** Anyone who has it can reset the master password. It is shown once. Keeping it safe is up to the user.
12. **Simple strength estimator.** `password_strength.dart` is an entropy heuristic with a small list of common words. It is not a dictionary- or pattern-based estimator such as zxcvbn.
13. **Lexical link analysis only.** Links are not resolved or checked against an online reputation list (by design, to stay offline). Shortened links are flagged but not expanded.
14. **Brand list not yet verified.** The official domains in `known_brands.dart` still have to be checked by hand (TODO in the code). A missing official domain causes false alarms; a wrong one hides real scams.
15. **No certificate pinning.** The HIBP call trusts the system CA store.
16. **Release builds are signed with the debug key** (`android/app/build.gradle.kts` TODO). Do not distribute them.
17. **`QUERY_ALL_PACKAGES`.** The app scanner needs this permission. Google Play only allows it for some app categories after a declaration.
