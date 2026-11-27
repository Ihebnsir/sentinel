# Screenshots

Shown in the "Screenshots" / "Captures d'écran" section of `README.md` and `README.fr.md`, and used by `tools/branding/make_social_preview.py`.

| File | Screen |
|---|---|
| `home.png` | Home: security score, actions sorted by importance, protections |
| `apps.png` | Apps: installed apps with their risk badge |
| `links.png` | Link checker: a "Dangerous" verdict, the real destination and the reasons |
| `qr-apk.png` | QR code result (1.2.1): a direct `.apk` download marked "Dangerous" |
| `vault.png` | Vault: unlocked, filled with sample entries |
| `firewall.png` | DNS firewall: status, blocked requests, block lists |
| `weekly.png` | Weekly report |
| `home-ar-dark.png` | Home in Arabic (right to left), dark theme |

**Fictitious data only**: sample apps ("Lampe Torche Pro", "Météo du Cap"…), sample vault entries with made-up passwords, `exemple.tn` addresses. No real password, message or phone number.

## How they are made

They are rendered by Flutter, not taken on a phone: `test/design/screens_capture_test.dart` draws each screen at Pixel 8 size (1080 × 2400, density 2.625) with the real fonts and a fake Android that returns sample data. The status bar (10:00, full battery) is drawn by the same test. On a real phone the vault tab could not be captured anyway (`FLAG_SECURE`).

```powershell
$env:SENTINEL_CAPTURE = "C:\path\out"
$env:SENTINEL_CAPTURE_ONLY = "accueil,applications,liens-dangereux,qr-apk,coffre,pare-feu,bilan"
$env:SENTINEL_CAPTURE_VARIANTS = "fr-clair,ar-sombre"
flutter test test/design/screens_capture_test.dart
```

Before/after captures of every screen (light, dark, Arabic) are in `docs/design/avant/` and `docs/design/apres/`.
