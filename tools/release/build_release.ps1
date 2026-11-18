# Build release de Sentinel : signé (SEN-01) et obfusqué (SEN-04).
#
# Usage, depuis n'importe quel dossier :
#   powershell -ExecutionPolicy Bypass -File tools\release\build_release.ps1
#   (variante Google Play : ajouter -Flavor complete)
#   (autre serveur : ajouter -ApiUrl https://mon-serveur.example)
#
# - Variante (-Flavor) : standard (défaut : APK GitHub, sans protection
#   automatique, accepté par Play Protect) ou complete (Google Play).
#   Résultat : build\sentinel-<version>-<variante>.apk. Voir docs\RELEASE.md.
# - Signature : android\key.properties (storeFile, keyAlias) + mot de passe
#   demandé ici, masqué, jamais écrit sur le disque. Voir docs\RELEASE.md.
# - Obfuscation : noms Dart illisibles dans l'APK ; les symboles (pour
#   décoder un plantage) sont dans build\symbols et archivés hors du dépôt.
#   --strip retire de libapp.so les informations DWARF (noms en clair, sinon
#   avertissement « unobfuscated DWARF ») : elles restent dans build\symbols.
# - Signalement : -ApiUrl est passé en --dart-define=SENTINEL_API_URL, sinon
#   le bouton « Signaler ce message » n'existe pas dans l'APK. HTTPS seulement.

param(
    [ValidateSet('standard', 'complete')]
    [string]$Flavor = 'standard',
    [string]$ApiUrl = 'https://sentinel-api-b2gs.onrender.com'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

# Mêmes règles que parseServerUrl (report_client.dart) en release : HTTPS,
# un nom d'hôte, ni identifiants, ni paramètres, ni fragment. Sinon l'app
# ignorerait l'adresse et masquerait le bouton sans rien dire.
$ApiUrl = $ApiUrl.Trim().TrimEnd('/')
$uri = $null
if (-not [Uri]::TryCreate($ApiUrl, [UriKind]::Absolute, [ref]$uri)) {
    throw "-ApiUrl invalide : '$ApiUrl'."
}
if ($uri.Scheme -ne 'https') {
    throw "-ApiUrl doit commencer par https:// (reçu : $($uri.Scheme)://). HTTP en clair refusé."
}
if (-not $uri.Host -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw "-ApiUrl : nom d'hôte obligatoire, sans identifiants, paramètres (?) ni fragment (#)."
}

if (-not (Test-Path 'android\key.properties')) {
    throw 'android\key.properties est absent : voir docs\RELEASE.md (aucun repli sur la clé debug).'
}

# Lit un secret sans l'afficher ni l'écrire sur le disque.
function Read-Secret([string]$prompt) {
    $secure = Read-Host -AsSecureString $prompt
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$hadStore = [bool]$env:SENTINEL_STORE_PASSWORD
$hadKey = [bool]$env:SENTINEL_KEY_PASSWORD
try {
    if (-not $hadStore) { $env:SENTINEL_STORE_PASSWORD = Read-Secret 'Mot de passe du keystore' }
    # Keystore PKCS12 (défaut de keytool) : même mot de passe pour la clé.
    if (-not $hadKey) { $env:SENTINEL_KEY_PASSWORD = $env:SENTINEL_STORE_PASSWORD }

    flutter build apk --release --flavor $Flavor --obfuscate --split-debug-info=build/symbols `
        --extra-gen-snapshot-options=--strip "--dart-define=SENTINEL_API_URL=$ApiUrl"
    if ($LASTEXITCODE -ne 0) { throw "Échec du build release (code $LASTEXITCODE)." }
}
finally {
    # Les mots de passe ne restent pas dans la session PowerShell.
    if (-not $hadStore) { Remove-Item Env:SENTINEL_STORE_PASSWORD -ErrorAction SilentlyContinue }
    if (-not $hadKey) { Remove-Item Env:SENTINEL_KEY_PASSWORD -ErrorAction SilentlyContinue }
}

# Symboles archivés hors du dépôt : « flutter clean » efface build\.
$version = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$commit = (git rev-parse --short HEAD).Trim()
$archive = Join-Path $env:LOCALAPPDATA "Sentinel\symbols\$version-$Flavor-$commit"
New-Item -ItemType Directory -Force $archive | Out-Null
Copy-Item 'build\symbols\*' $archive -Recurse -Force

# Nom final, celui joint à la release GitHub (version sans le +build).
$built = "build\app\outputs\flutter-apk\app-$Flavor-release.apk"
$apk = "build\sentinel-$($version.Split('+')[0])-$Flavor.apk"
Copy-Item $built $apk -Force
$hash = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower()
Write-Host ''
Write-Host "Variante : $Flavor"
Write-Host "APK      : $apk"
Write-Host "SHA-256  : $hash"
Write-Host "Serveur  : $ApiUrl (bouton « Signaler ce message »)"
Write-Host "Symboles : build\symbols (copie : $archive)"
Write-Host 'Vérifier la signature : voir docs\RELEASE.md (apksigner verify --print-certs).'
