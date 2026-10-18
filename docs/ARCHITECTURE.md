# Architecture

[← Back to README](../README.md) · [Security design](SECURITY_DESIGN.md)

Sentinel is a Flutter app with Android as its only target. Dart contains the UI and all the decision logic (risk rules, ML inference, cryptography). Kotlin reads Android state and talks to the system services that Flutter cannot reach directly. The two sides communicate through named `MethodChannel`s.

Most of the logic is written as **pure functions** (`calculateSecurityScore`, `calculateAppRisk`, `assessWifi`, `analyzeMessage`, `analyzePasswordHealth`…). They take plain data and return a report without calling Android, which makes them easy to unit-test.

## Code layout

```mermaid
flowchart LR
  subgraph Dart["lib/ (Dart)"]
    main["main.dart"]
    screens["screens/<br/>main_shell, home, apps,<br/>app_detail, messages, vault/…"]
    widgets["widgets/<br/>score_arch, wifi_section,<br/>auto_protection_section…"]
    models["models/<br/>device_security_status,<br/>installed_app, wifi_status"]
    subgraph services["services/"]
      calc["security_score_calculator<br/>app_risk_calculator<br/>wifi_risk"]
      phishing["phishing/<br/>phishing_model, message_analyzer,<br/>url_analyzer, known_brands"]
      vault["vault/<br/>vault_crypto, vault_file,<br/>vault_session, vault_storage,<br/>vault_biometrics, vault_platform…"]
      breach["breach/<br/>pwned_passwords,<br/>breach_checker, breach_consent"]
      appsdb["apps/<br/>known_apps, stalkerware_ioc"]
      bridges["device_security_service<br/>apps_scanner_service<br/>wifi_service, share_service<br/>protection_service, firewall_service"]
    end
    background["background/<br/>background_analyzer.dart"]
  end

  subgraph Kotlin["android/…/com/iheb/sentinel (Kotlin)"]
    activity["MainActivity"]
    dev["DeviceSecurityChecker"]
    apps["InstalledAppsScanner"]
    wifi["WifiSecurityChecker"]
    vp["VaultProtection"]
    bio["VaultBiometric"]
    listener["SentinelNotificationListener"]
    bg["BackgroundAnalyzer"]
    notif["ScamAlertNotifier"]
    prefs["ProtectionSettings"]
    fw["firewall/<br/>FirewallChannel, SentinelVpnService,<br/>DnsFilter, DnsPacket, IpPacket"]
  end

  main --> screens --> widgets
  screens --> services
  bridges <-->|MethodChannel| activity
  vault <-->|MethodChannel| vp
  activity --> dev & apps & wifi & vp & prefs & fw
  vp --> bio
  listener --> bg --> notif
  bg <-->|MethodChannel| background
  background --> phishing
```

The app has four tabs (`main_shell.dart`): **Accueil** (device audit, Wi-Fi and the DNS firewall), **Applications**, **Messages** (message check and the automatic protection switch) and **Coffre** (vault).

## Method channels

| Channel | Kotlin side | Dart → Kotlin | Kotlin → Dart |
|---|---|---|---|
| `com.iheb.sentinel/device_security` | `MainActivity` → `DeviceSecurityChecker` | `getSecurityStatus`, `openSettings` | — |
| `com.iheb.sentinel/apps` | `MainActivity` → `InstalledAppsScanner` (background executor) | `scanApps`, `openAppSettings`, `uninstallApp`, `openWebPage` | — |
| `com.iheb.sentinel/share` | `MainActivity` | `getInitialSharedText` | `onSharedText` |
| `com.iheb.sentinel/protection` | `MainActivity` → `ProtectionSettings` | `getStatus`, `setEnabled`, `openListenerSettings`, `openNotificationSettings`, `requestNotificationPermission` | — |
| `com.iheb.sentinel/wifi` | `WifiSecurityChecker` | `getWifiStatus`, `startListening`, `stopListening`, `openPrivateDnsSettings` | `onWifiChanged` (debounced 400 ms) |
| `com.iheb.sentinel/vault` | `VaultProtection` → `VaultBiometric` | `setSecure`, `copySensitive`, `clearClipboard`, `biometricAvailable`, `biometricEncrypt`, `biometricDecrypt`, `biometricDeleteKey` | `onScreenOff` |
| `com.iheb.sentinel/firewall` | `FirewallChannel` → `SentinelVpnService` | `prepare`, `start`, `stop`, `status` | — |
| `com.iheb.sentinel/background_analysis` | `BackgroundAnalyzer` (headless engine) | `ready` | `analyze` |

```mermaid
sequenceDiagram
  participant UI as Dart UI
  participant MA as MainActivity / helpers
  participant OS as Android
  UI->>MA: scanApps (apps channel)
  MA->>OS: PackageManager on a background thread
  OS-->>MA: packages, permissions, installer, signing certificates, launcher state
  MA-->>UI: list of maps (posted back on the main thread)
  UI->>UI: StalkerwareIoc.load() once, then calculateAppRisk() for each app
  OS-->>MA: ACTION_SCREEN_OFF broadcast
  MA-->>UI: onScreenOff (vault channel)
  UI->>UI: VaultSession.lock()
```

## Headless engine for background analysis

When automatic protection is on, `SentinelNotificationListener` gets message notifications. Kotlin does not re-implement the model. Instead, `BackgroundAnalyzer` starts a **headless `FlutterEngine`** (no UI) on the first message and runs the Dart entry point `backgroundAnalyzerMain` (marked `@pragma('vm:entry-point')` and re-exported from `main.dart` so release builds keep it). The engine stays in `FlutterEngineCache` for later messages and is destroyed when protection is turned off or the listener disconnects.

```mermaid
sequenceDiagram
  participant N as Messaging app notification
  participant L as SentinelNotificationListener
  participant B as BackgroundAnalyzer (Kotlin)
  participant E as Headless FlutterEngine
  participant D as backgroundAnalyzerMain (Dart)
  participant A as ScamAlertNotifier

  N->>L: onNotificationPosted
  L->>L: enabled? SMS / chat app? not ongoing / group summary?<br/>extract last message, skip own replies,<br/>dedupe by hashCode (last 50)
  L->>B: analyze(text, packageName, isSms)
  alt engine not started
    B->>B: queue request in RAM (max 10)
    B->>E: new FlutterEngine + executeDartEntrypoint
    E->>D: backgroundAnalyzerMain()
    D-->>B: "ready"
  end
  B->>D: "analyze"
  D->>D: loadPhishingModel() → predict() → analyzeMessage()
  D-->>B: verdict, percent, mainReason (domains defanged), alertTitle
  alt verdict == "arnaque"
    B->>A: show(title, reason, text)
    A->>A: private notification + neutral public version,<br/>no system "open link" actions
  end
```

Only scams trigger an alert. "Suspect" never does, to avoid alert fatigue. Tapping the alert opens the Messages tab with the text, through the same `EXTRA_TEXT` path as the Android share sheet.

## DNS firewall

The DNS firewall (`android/…/firewall/`) is a local `VpnService`. The TUN interface gets private addresses (`10.111.222.1/32`, `fdc5:3a71:9e04::1/128`), a virtual DNS server (`10.111.222.2`, `fdc5:3a71:9e04::2`) and **routes to those two DNS addresses only**. Android then sends every app's system DNS queries into the TUN, while the rest of the traffic keeps using the real network directly.

```mermaid
flowchart TD
  app["App asks for ads.example.net"] --> resolver["Android resolver<br/>(VPN DNS = 10.111.222.2)"]
  resolver -->|"IPv4/IPv6 + UDP → port 53<br/>only route into the TUN"| tun["TUN interface"]
  tun --> loop["Reader thread<br/>Os.poll(TUN, stop pipe)"]
  loop --> parse["IpPacket.parseUdp()<br/>DnsPacket.parseQuery()"]
  parse -->|"malformed, fragment, TCP, not port 53"| drop["Ignored"]
  parse --> check{"DomainBlocklist.isBlocked()<br/>name or a parent domain"}
  check -->|blocked| nx["DnsPacket.buildEmptyResponse(NXDOMAIN)<br/>blocked + 1"]
  check -->|allowed| pool["Forwarding pool (4 threads, queue 64)"]
  pool --> sock["DatagramSocket + protect()<br/>connect 9.9.9.9:53, 2 s timeout<br/>(then 149.112.112.112)"]
  sock -->|"same ID + same question"| answer["Upstream answer<br/>(SERVFAIL if &gt; MTU)"]
  nx --> build["IpPacket.buildUdp()<br/>addresses and ports swapped,<br/>IPv4 header + UDP checksums"]
  answer --> build
  build -->|"write (synchronized)"| tun
  tun --> resolver --> app
```

Every query adds 1 to the "total" counter. The domain name is never logged or stored (see [Security design](SECURITY_DESIGN.md#38-trackers-and-dangerous-domains-dns-firewall)).

Packet layout handled by `IpPacket` and `DnsPacket`:

```text
IPv4 header (20 bytes)          IPv6 header (40 bytes)
  version/IHL, total length       version, payload length
  flags/fragment (DF only)        next header = 17 (UDP), hop limit
  TTL, protocol = 17, checksum    source (16), destination (16)
  source (4), destination (4)
UDP header (8 bytes)
  source port, destination port = 53, length, checksum (pseudo-header + data)
DNS message
  header (12): ID, flags (QR, opcode, RD, RA, RCODE), 4 counts
  question: name as labels (3www7example3com0, or a 0xC0 pointer), type, class
```

Life cycle:

- **prepare.** `VpnService.prepare()` returns an `Intent` the first time: `FirewallChannel` opens Android's consent screen and answers Dart from `MainActivity.onActivityResult`.
- **start.** `startForegroundService` → `startForeground` (type `systemExempted` on Android 14+, the type Android documents for VPN apps) → `establish()` → reader thread.
- **stop.** "Arrêter" in the notification, the switch, `onRevoke` (another VPN) or `onDestroy`. Closing the write end of a pipe wakes `Os.poll`, the reader thread ends, the pool is shut down (each socket times out after 2 s at most), then the TUN is closed.
- **Unit tests.** `DnsPacket`, `IpPacket`, `DomainBlocklist` and `DnsFilter` do not use Android APIs. JUnit tests in `android/app/src/test` run with `./gradlew testDebugUnitTest` (also in CI).

## Scam detection flow

```mermaid
flowchart TD
  input["Message text<br/>(typed, shared, PROCESS_TEXT, alert tap,<br/>or notification in background)"]
  input --> model["PhishingModel.predict()<br/>lowercase → split on Python isspace() set →<br/>char_wb n-grams 2..5 (code points) →<br/>sublinear TF × IDF → L2 norm → logistic"]
  input --> links["analyzeLinks()<br/>brand impersonation · IP · punycode · '@' ·<br/>shortener · suspicious TLD · &gt;3 subdomains · http"]
  model --> p["probability p<br/>+ top suspicious n-grams / words"]
  links --> f["link findings"]
  p --> decide{"analyzeMessage()"}
  f --> decide
  decide -->|"p ≥ 0.8 or brand impersonation or IP link"| scam["Arnaque probable"]
  decide -->|"p ≥ 0.5 or any other link finding"| suspect["Suspect"]
  decide -->|otherwise| ok["Rien de suspect"]
```

The model is trained offline in Python (`ml/train.py`) and shipped as `assets/models/phishing_model.json` (8,000-entry vocabulary, IDF, coefficients, intercept, metrics). The Dart implementation follows the specification in [`ml/README.md`](../ml/README.md). `test/phishing_parity_test.dart` checks it against scikit-learn's output on 30 fixtures with a tolerance of 1e-9.

## Vault key hierarchy

```mermaid
flowchart TD
  pw["Master password"] -->|"Argon2id<br/>46 MiB · 2 passes · p=1 · 16-byte salt"| kek1["KEK (password)"]
  rk["Recovery key<br/>28 chars · 140 bits"] -->|"HKDF-SHA256<br/>16-byte salt"| kek2["KEK (recovery)"]
  ks["Android Keystore key<br/>AES-256-GCM · BIOMETRIC_STRONG per use ·<br/>invalidated on new enrollment"] --> kek3["KEK (fingerprint)"]

  kek1 -->|"AES-256-GCM wrap<br/>AAD = version + slot params"| slot1["Password slot"]
  kek2 -->|"AES-256-GCM wrap"| slot2["Recovery slot"]
  kek3 -->|"AES-GCM wrap (in Keystore)"| slot3["Biometric slot (optional)"]

  slot1 & slot2 & slot3 --> dek["DEK — random 256-bit data key"]
  dek -->|"AES-256-GCM, fresh 12-byte nonce<br/>AAD = full header"| data["Encrypted items<br/>(passwords, secure notes)"]
```

`vault.json` (version 2) lives in the app's private support directory:

```text
{
  "version": 2,
  "derniereOuvertureMdp": "<UTC, to the second>",   ┐
  "keySlots": [                                      │ header = AAD of "data"
    { "type": "password", "kdf": {…}, "wrappedKey": {nonce, chiffre} },
    { "type": "recovery", "sel": "…", "wrappedKey": {…} },
    { "type": "biometric", "wrappedKey": {…} }       ┘
  ],
  "data": { "nonce": "…", "chiffre": "…" }
}
```

Key points:

- **One DEK, several ways to unwrap it.** Changing the master password only rewrites the password slot. The items are not re-encrypted with a new key.
- **Recovery.** "Forgot password" opens the vault with the recovery key, then sets a new password *and* a new recovery key. The old recovery key stops working.
- **Fingerprint.** `biometricEncrypt` generates a fresh Keystore key and encrypts the DEK after a `BiometricPrompt` with a `CryptoObject`. If fingerprints change, the key becomes invalid. The biometric slot is then dropped at the next password unlock.
- **7-day rule.** `derniereOuvertureMdp` is inside the authenticated header. Once it is more than 7 days old (or more than one day in the future), the fingerprint is refused and the password is required.
- **Migration.** Version 1 files (a single password, no slots) are still read. They are upgraded to version 2 on the first successful password unlock, reusing the same KEK.
- **Session.** `VaultSession` holds the DEK in memory only while the vault is open. `lock()` overwrites it with zeros. Every change copies the DEK first, so a lock during a write cannot encrypt with a zeroed key.

## Other data stored on the device

| Data | Where | Content |
|---|---|---|
| Vault | `vault.json` in the application support directory | Encrypted (see above) |
| Breach-check consent | `breach_consent.json` in the same directory | `{"accepted": true/false}` |
| Automatic protection switch | `SharedPreferences` `sentinel_protection` | One boolean |
| DNS firewall counters | Memory of `SentinelVpnService` only | Two numbers, reset at each start |
| Fingerprint key | Android Keystore, alias `sentinel_vault_bio` | Non-exportable AES key |

Message text, breach results and scan results are never written to disk. None of the data above is included in Android backups or device-to-device transfers (`allowBackup="false"` and `res/xml/data_extraction_rules.xml`).
