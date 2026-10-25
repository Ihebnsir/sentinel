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
| DNS queries (domain names asked by apps) | Amount to the user's browsing history |
| The user's physical safety | A stalkerware finding can be dangerous if the person who installed it learns about it |

## 2. Principles

- **Local first.** No backend, no account, no analytics. Every analysis runs on the device.
- **Least data.** Message text is never logged or stored. Wi-Fi checks never read the SSID/BSSID and never ask for the location permission. The DNS firewall keeps two counters, never a domain name.
- **Explicit consent** for the network features (breach check; DNS firewall, which forwards DNS queries to Quad9) and for the notification listener.
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
| The HIBP call uses HTTPS with a 10 s timeout. Even a full MITM only sees a 5-character hash prefix | `pwned_passwords.dart` |

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

#### 3.4.1 Encrypted backup file (`.sentinel`)

The only way the vault leaves the phone is an explicit export ("Exporter une sauvegarde chiffrée" in the vault settings). *Goal of an attacker:* read a `.sentinel` file found on Drive, a USB stick or a computer, or slip a modified one to the user.

| Measure | Where |
|---|---|
| The file is protected by its own **export password**, which must pass the same rules as the master password (≥ 12 characters, strength estimate). It shares nothing with the vault: no DEK, no master password, no recovery key | `vault_crypto.dart` (`exportBackup`), `vault_settings_screen.dart` |
| Same primitives as the vault, no new cryptography: key = Argon2id (46 MiB, 2 passes, parallelism 1, fresh 16-byte salt) of the export password, items encrypted with AES-256-GCM and a fresh 12-byte nonce | `deriveKek`, `_encrypt` in `vault_crypto.dart` |
| Versioned format (`"format": "sentinel-sauvegarde"`, `"version": 1`). The header (format, version, KDF parameters) is the AES-GCM associated data: changing any byte of the header or the ciphertext makes decryption fail | `vault_backup.dart` (`VaultBackup.header`) |
| Wrong password and modified file both fail the GCM tag and get the same message ("Mot de passe incorrect, ou fichier modifié depuis l'export"); GCM cannot tell them apart. Empty, non-Sentinel, oversized (> 16 MiB) or newer-version files are rejected *before* any key derivation, with a dedicated message | `VaultBackup.decode`, `restore_backup_view.dart` |
| KDF parameters read from the file go through the same bounds as the vault, so a crafted backup cannot freeze the phone | `KdfParams.fromJson` |
| Restoring creates a **new** vault: new DEK, new master password, new recovery key. Restoring over an existing vault is refused | `VaultSession.restore` |
| Saving and opening use the Storage Access Framework (`ACTION_CREATE_DOCUMENT` / `ACTION_OPEN_DOCUMENT`): the user picks the location, the app has **no storage permission**. Only already-encrypted bytes cross the platform channel; nothing is logged | `VaultDocuments.kt` |
| Covered by tests: round trip, wrong password, tampered ciphertext and header, unknown version, empty and non-backup files, restore then reopen | `test/vault_backup_test.dart` |

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

### 3.7 Someone close to the user (stalkerware)

*Who:* a partner, ex-partner or relative who had the phone in hand for a few minutes. *Goal:* install a hidden app that reports messages, location, calls and notifications. Unlike the other attackers, this one may be physically close to the user, and may notice if the spyware stops reporting.

| Measure | Where |
|---|---|
| Known stalkerware matched by package name or SHA-1 certificate fingerprint, from the public Stalkerware Indicators list (CC BY 4.0, pinned commit). Applies **even to system apps**, since many stalkerware packages pose as system components (`com.android.core.…`) | `stalkerware_ioc.dart`, `tools/stalkerware/update_ioc.py` |
| Spy profile: launcher icon hidden (`MAIN/LAUNCHER` activity disabled after install, read with `getComponentEnabledSetting`) **and** at least two of accessibility, background location, SMS, call log, notification access, device admin | `InstalledAppsScanner.kt`, `app_risk_calculator.dart` |
| Fake and repackaged apps: popular app name with another package, official package with another signing certificate, known WhatsApp mods, test-key signatures | `known_apps.dart`, `app_risk_calculator.dart` |
| **No notification** for these findings: anyone looking at the lock screen could see it. They only appear when the user opens the Applications tab | `apps_screen.dart` |
| Safety advice **before** any action: removing the app can alert the person who installed it; contact a help organization or the police first if in danger. The detail screen offers only "Que faire ?" instead of "Désinstaller" | `spyware_advice_screen.dart`, `app_detail_screen.dart` |
| The help link can be copied and opened in a private tab or on another device, since the browser history may be checked | `spyware_advice_screen.dart` |

### 3.8 Trackers and dangerous domains (DNS firewall)

*Goal:* an app or a web page contacts an ad network, a tracker or a known malicious domain.

The DNS firewall is a local `VpnService` that **only** captures DNS. The VPN routes contain nothing but the two virtual DNS addresses (`10.111.222.2` and `fdc5:3a71:9e04::2`), so the rest of the traffic never goes through Sentinel. There is no remote server.

| Measure | Where |
|---|---|
| Blocked domain gets an immediate local `NXDOMAIN` answer. An exact entry blocks that name only; a `*.` entry also blocks its subdomains (`*.doubleclick.net` matches `ad.doubleclick.net`, not `notdoubleclick.net`) | `CategoryList.kt`, `DnsFilter.kt` |
| Three list categories (Malware et hameçonnage, Traqueurs on by default; Publicités off) built from permissively licensed lists; every block knows its category, counted in memory | `BlockPolicy.kt`, `FirewallEngine.kt` |
| Fourth category, **Imitations de marques** (on by default): a domain allowed by the lists but imitating a known brand (`assets/data/known_brands.json`, same rule and same fixtures in Dart and Kotlin) is blocked | `BrandRules.kt`, `BlockPolicy.check` |
| The user's allowlist wins over every list and over the brand rule, subdomains included | `BlockPolicy.check` |
| Malware and impersonation blocks raise a rate-limited alert (1 per domain per hour, 10 per hour), defanged and hidden on the lock screen ("Site imitant <marque> bloqué" for an imitation) | `FirewallAlertNotifier.kt`, `AlertLimiter.kt` |
| Allowed queries are forwarded to Quad9 **encrypted** (SEN-10): DNS over TLS to `9.9.9.9:853` (then `149.112.112.112`), or DNS over HTTPS/2 on port 443 if 853 is blocked (Android 10+). Connections go to the IP address (no DNS lookup), from `protect()`ed sockets, with SNI `dns.quad9.net`, strict certificate and host-name checks, 2-byte TCP framing and reused connections | `DnsTransports.kt`, `DohHttp.kt`, `UpstreamResolver.kt` |
| **Never a silent fallback to plain DNS**: if no encrypted transport answers, Sentinel replies `SERVFAIL` and the firewall screen says so. Plain UDP to Quad9 is used only after the user turns on "Autoriser le DNS non chiffré sur ce réseau" (off by default, valid for the current network only). The answer must have the same ID and question as the query | `UpstreamResolver.kt`, `UnderlyingNetworks.kt`, `DnsPacket.isResponseTo` |
| Malformed, truncated, fragmented or non-DNS packets are ignored without crashing; compression pointers may only point backwards and names are capped at 255 bytes, so a crafted packet cannot loop | `DnsPacket.kt`, `IpPacket.kt` |
| **No browsing history**: outside an app analysis the user starts (3.8.1), domain names are never logged, stored or sent to Dart. Only in-memory counters exist (queries, blocked, blocked per category), reset at each start. The alert limiter keeps alerted domains in memory for one hour at most | `SentinelVpnService.kt`, `FirewallChannel.kt`, `AlertLimiter.kt` |
| The app itself is **not** excluded with `addDisallowedApplication`: excluding it would also exempt everything else Sentinel's process does. Only the forwarding sockets bypass the VPN, one by one, with `protect()` | `SentinelVpnService.kt` |
| Visible and easy to stop: Android's key icon, a low-importance permanent notification with an "Arrêter" button, and the switch in the app | `SentinelVpnService.kt`, `firewall_screen.dart` |

**Why NXDOMAIN rather than `0.0.0.0` / `::`.** Answering `0.0.0.0` for A and `::` for AAAA makes apps connect to an unspecified address, which Linux and Android treat as *this device*: a blocked domain could then reach a local server listening on the phone. It also only covers A/AAAA, while newer record types (`HTTPS`/`SVCB`, type 65) carry addresses too. `NXDOMAIN` ("this name does not exist") works the same way for every query type and never triggers a connection. The trade-off: a few apps log an error or retry a little more, and an `NXDOMAIN` without SOA is not cached for long, so a domain removed from the list works again almost at once.

### 3.8.1 App analysis ("Analyser une application")

*Goal:* the user wants to know which domains one app contacts (trackers, ads, dangerous sites), without Sentinel keeping a history of everything.

Android's resolver answers many queries from a cache shared by all apps, so the VPN cannot reliably tell which app asked for which name (tested: `getConnectionOwnerUid` gives the right UID for the packets that do arrive, but a name already cached never arrives again, whichever app asks). The analysis therefore rebuilds the VPN for **one app** (`addAllowedApplication`) for 2, 5 or 15 minutes: every query seen belongs to that app.

| Measure | Where |
|---|---|
| Started only by the user, from the app list, after a sheet that explains the trade-off **before** launch (other apps unprotected, automatic return, 24 h retention, never sent) | `app_analysis_screen.dart` |
| **Unprotected window, made visible**: during the analysis, the other apps' DNS goes straight to the network: no blocking, no alert. The permanent notification changes to "Analyse de X en cours" ("les autres applications ne sont pas protégées par le pare-feu jusqu'à HH:MM") with an "Arrêter l'analyse" button; the firewall screen shows the same warning and a stop button | `SentinelVpnService.showForegroundNotification`, `app_analysis_section.dart` |
| Automatic return to the normal VPN at the end (measured with `elapsedRealtime` and enforced by an `ELAPSED_REALTIME_WAKEUP` alarm that fires even in Doze, so phone sleep cannot stretch the unprotected window; exact when `SCHEDULE_EXACT_ALARM` is granted, otherwise Android may deliver it late), on manual stop, or if the firewall stops. The normal interface is established before the analysis one is closed. If it cannot be rebuilt, the firewall stops (key icon disappears) rather than staying in analysis mode | `SentinelVpnService.finishAnalysis` |
| The analyzed app is still filtered normally (lists, brand rule, allowlist) while it is analyzed | `SentinelVpnService.handlePacket` |
| Domains are recorded **only** by the analysis session, in memory, capped at 2,000 distinct names; packets still read by the previous (normal) session are never recorded | `DomainRecorder`, `TunSession` |
| **Report data**: package name and label of the app, start and end time, planned duration, stopped early or not, and for each domain its name, query count, category (malware, impersonation + imitated brand, trackers, ads, other) and whether it was blocked. Nothing about other apps | `AppReport.toJson` |
| **Retention: 24 hours at most** after the end of the analysis. Private file in `filesDir/app_reports/` (excluded from backups and device transfers by `allowBackup="false"` and `data_extraction_rules.xml`), not encrypted. Deleted on every save/listing, at app start-up, by a non-exported alarm receiver even if the app is never reopened, or at once by "Supprimer ce rapport". At most 10 reports. Never sent anywhere | `AppReportStore.kt`, `ReportCleanupReceiver.kt`, `AndroidManifest.xml` |
| Report ids are digits only and file names are parsed with a strict pattern: a crafted id cannot reach another file | `AppReportStore.ID`, `AppReportStore.NAME` |
| Sentinel itself cannot be analyzed (its own queries never use its VPN) | `FirewallChannel.startAnalysis`, `SentinelVpnService.startAnalysis` |

**Trade-off.** The analysis gives a complete and correct list for one app, at the cost of a short window where every other app loses the firewall. Making it per-app and always-on would need either an unreliable attribution (cache) or a permanent per-app browsing history, which Sentinel refuses to keep.

### 3.9 Blocklist integrity, poisoned lists and false positives

*Goal:* someone who controls an upstream list (or the download path) tries to make Sentinel block legitimate sites, or to stop it blocking dangerous ones. Blocking is a denial of service on the user's own phone: a poisoned list containing `whatsapp.com` or `*.googleapis.com` would cut services or push notifications for every user.

| Measure | Where |
|---|---|
| Lists bundled in the APK are generated from **pinned commits** and reviewed in the Git diff before release; the manifest stores the SHA-256 of every file, checked at each load (corrupted or modified file → fallback to the asset) | `update_lists.py`, `CategoryList.read`, `FirewallEngine.kt` |
| Updates are **off by default** and need an explicit consent sheet. Download URLs come from the manifest **inside the signed APK**, never from a downloaded file; HTTPS only (Java never follows an HTTPS → HTTP redirect); no cookie, no parameter, generic User-Agent | `BlocklistUpdater.kt`, `HttpsFetcher` |
| Size cap (32 MiB per source, 2 million entries per category); format check (at most 10 % invalid lines, so an HTML error page is rejected); consistency with the bundled version (at least half, at most 5× the reference count, so an emptied, truncated or inflated list is rejected) | `BlocklistUpdater.isConsistent`, `LimitedInputStream` |
| **Protected domains**: entries that would block one of the 103 names in `protected.txt` (connectivity checks, Firebase Cloud Messaging, Google, Apple, Microsoft, Meta, GitHub, Quad9, shared-hosting apexes such as `github.io`, shared infrastructure such as the AMP cache) are removed at generation and at every update. Found on the first run: `docs.google.com` and `sites.google.com` in Phishing.Database, `fcm.googleapis.com` in ShadowWhisperer Ads. Second run, after a real analysis of Chrome: `cdn.ampproject.org`, `firebasestorage.googleapis.com`, `storage.cloud.google.com`, `l.instagram.com`, `bit.ly` and `*.amplifyapp.com` in Phishing.Database. A line protects one name, not its subdomains: the 348 specific phishing sites on `amplifyapp.com` stay blocked. Trade-off: a phishing page behind a path on a protected name (`bit.ly/xyz`, a file on Firebase Storage) is no longer blocked by DNS, which cannot see paths anyway; the SMS analyzer still flags shortened links | `protected.txt`, `CategoryBuilder` |
| Strict validation of every entry (labels, length, punycode); manifest file names limited to `[a-z0-9-]+.txt`, so a manifest cannot point outside the lists folder | `DomainNames.kt`, `BlocklistManifest.kt` |
| Atomic writes (temporary file, `fsync`, rename; manifest last). Any failure keeps the previous version, category by category | `BlocklistUpdater.writeAtomically` |
| Exact vs subdomain semantics follow each upstream list, so an exact hosts entry such as `faux-site.github.io` never blocks all of `github.io` | `ListParser.kt` |

**False positives.** Lists are made by people and scripts and do contain mistakes. The brand rule is lexical and its edge cases are written down in `test/fixtures/brand_parity.json`. A domain whose registrable name is exactly a brand keyword (`laposte.fr`, `orange.be`) is treated as the same brand in another country and not reported, except under a cheap scam extension (`biat.xyz`) or a Tunisian one (`cnam.tn`, `laposte.com.tn`), which stay reported. The flip side: a scammer who registers the bare keyword under another ordinary extension (`flouci.app`, `biat.fr`) is not caught by this rule. A long keyword only counts at the start or end of a part (`monlaposte`, `laposte2`), so `imposter.com` is no longer reported; a scam glued in the middle of a word (`xlaposteyz.com`) is missed in return. In the DNS firewall such a site is blocked until the user adds it to the allowlist; the category switch shows a warning saying so. The user can add any domain to the allowlist (it wins over everything, subdomains included), turn a whole category off, and the ad category, the most likely to break apps, is off by default. Malware lists target names that host phishing pages, often on shared platforms; an exact entry blocks only that subdomain.

**What this does not protect against.** Updates are not signed by Sentinel: a compromise of an upstream repository, of GitHub, or of the TLS chain can still push a list that passes the checks (e.g. a few hundred well-chosen extra entries, or the removal of a few). The consistency checks and the protected list limit the damage, they do not prove authenticity. Possible next step: publish reviewed lists from Sentinel's own repository with a detached signature verified against a key embedded in the APK.

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
10. **Moving the vault to a new phone is manual.** Android backup is still disabled on purpose (see 3.4). **Solution:** the user exports an encrypted `.sentinel` file and restores it on the new phone (see 3.4.1). Remaining limits: the export is a snapshot (later changes are not in it), the breach-check consent and the protection switch are not part of it, and the file is only as strong as its export password against an offline attack (Argon2id slows guessing, it cannot save a weak password). A restored vault gets a new recovery key; the old phone's key does not open it. During a restore, the decrypted items stay in memory between the backup password step and the new master password step.
11. **Recovery key = full access.** Anyone who has it can reset the master password. It is shown once. Keeping it safe is up to the user.
12. **Simple strength estimator.** `password_strength.dart` is an entropy heuristic with a small list of common words. It is not a dictionary- or pattern-based estimator such as zxcvbn.
13. **Lexical link analysis only.** Links are not resolved or checked against an online reputation list (by design, to stay offline). Shortened links are flagged but not expanded.
14. **Brand list not yet verified.** The official domains in `assets/data/known_brands.json` still have to be checked by hand (`todo` field in the file). A missing official domain causes false alarms and, since the DNS firewall now blocks imitations, an actual block of that site; a wrong one hides real scams.
15. **No certificate pinning.** The HIBP call trusts the system CA store.
16. **Release signing needs the owner's key.** The release build reads `android/key.properties` (ignored by git, keystore outside the repository) and fails without it: no fallback to the debug key (SEN-01, see `docs/RELEASE.md`).
17. **`QUERY_ALL_PACKAGES`.** The app scanner needs this permission. Google Play only allows it for some app categories after a declaration.
18. **Stalkerware detection is a list, not a guarantee.** The indicators only cover known stalkerware (131 apps at the pinned commit), and a new build with a new package and key escapes them. The spy profile is a heuristic: an app can spy without hiding its icon. No match does not mean no stalkerware.
19. **Reference fingerprints are not filled in yet.** Every `certSha256` list in `known_apps.dart` is empty until verified with `tools/signatures/extract_cert.py`, so the "repackaged copy" rule is inactive. Packages of Tunisian banking and postal apps are also missing (TODO), so their impersonation is not detected yet.
20. **Visible scan.** A stalker with access to the phone could open Sentinel and see the warning. Sentinel does not hide itself; it only avoids pushing the finding to the lock screen.
21. **Generic IOC packages.** A few indicator packages are short (`com.fone`, `com.smart`). A legitimate app with exactly that name would be flagged with score 100.
22. **One VPN at a time.** Android allows a single active VPN. Turning on another VPN (or an always-on VPN set by a work profile) revokes Sentinel's: the firewall stops (`onRevoke`). While the firewall is on, the user can't use another VPN.
23. **Apps with their own DNS escape the filter.** Only queries sent to the system resolver reach the virtual DNS server. Browsers with "Secure DNS" (DNS over HTTPS) turned on, and apps that hard-code a resolver (`8.8.8.8:53`, DoH, DoT), are not filtered, because only the virtual DNS addresses are routed into the VPN.
24. **Android Private DNS in strict mode.** With a Private DNS hostname set, Android requires DNS over TLS on the VPN network too, cannot validate it, and stops resolving any name. Sentinel detects strict mode (SEN-11), refuses to turn on, warns while running, and links to the setting so the user can choose "Automatic" (Sentinel already encrypts DNS). In automatic mode, Android falls back to the virtual server, which is filtered.
25. **Encrypted upstream, one resolver.** Since SEN-10, the network operator no longer sees the names (DoT/DoH), unless the user explicitly allows plain DNS on a network that blocks encrypted DNS. Quad9 still sees every query under its own privacy policy, and no DNSSEC validation is done on the device. DNS over HTTPS needs ALPN, so before Android 10 only DNS over TLS is available.
26. **Browsing history in memory.** Domain names pass through the process memory while they are filtered. They are never logged, kept in a list or sent to Dart, but root access or a debugger could read them, like any VPN app.
27. **UDP only, small packets.** DNS over TCP to the virtual server is not answered. Answers larger than the 1500-byte MTU are replaced by `SERVFAIL`. IPv4 fragments and IPv6 extension headers are ignored.
28. **Lists are not perfect.** Bundled lists date from the last generation (19 Oct 2026): without updates, new phishing domains are missed, and Phishing.Database's GitHub copy lags behind its own site by up to a few weeks. Every list has false positives and false negatives (see 3.9). Debug builds also block `example.com`, filed under "Malware et hameçonnage", to test blocking and the alert.
29. **Unsigned updates.** Downloaded lists are checked (HTTPS, size, format, consistency, protected domains) but not signed (see 3.9). The download itself reveals to GitHub that the phone uses these lists, from its IP address.
30. **No "site blocked" page.** A DNS firewall can only say "this name does not exist": browsers show their own connection error, and Sentinel cannot replace it with an explanation page without intercepting HTTPS, which it will not do. The malware alert is the only explanation the user gets.
31. **Unfiltered at start-up.** Queries pass unfiltered for the second or so it takes to load the lists after the VPN starts.
32. **Alert shows the domain on the unlocked screen.** The alert text includes the defanged blocked domain, so someone looking at the unlocked phone can see a dangerous site was requested.
33. **No firewall for other apps during an app analysis.** For 2 to 15 minutes, only the analyzed app is filtered (see 3.8.1). A malicious link opened in another app during that window is not blocked.
34. **App analysis reports are plain files.** They are private to the app and kept 24 h at most, but not encrypted: root access, or someone who opens Sentinel on the unlocked phone, can read which domains the analyzed app contacted. If Android kills the service during an analysis, that analysis and its report are lost. Query counts are approximate (cached answers are not seen again).
35. **Brand rule false positives in the firewall.** See 3.9: a real site that contains a brand keyword but is not in the official list is blocked until allowlisted.
