# Build release de Sentinel : signé (SEN-01) et obfusqué (SEN-04).
#
# Usage, depuis n'importe quel dossier :
#   powershell -ExecutionPolicy Bypass -File tools\release\build_release.ps1
#
# - Une seule variante depuis la 1.1.0 (applicationId com.iheb.sentinel).
#   Résultat : build\sentinel-<version>.apk. Voir docs\RELEASE.md.
#   Le build échoue si le manifeste fusionné déclare un accès bloqué par
#   Play Protect (tâche Gradle checkPlayProtectRelease).
# - Signature : android\key.properties (storeFile, keyAlias) + mot de passe
#   demandé ici, masqué, jamais écrit sur le disque. Voir docs\RELEASE.md.
# - Obfuscation : noms Dart illisibles dans l'APK ; les symboles (pour
#   décoder un plantage) sont dans build\symbols et archivés hors du dépôt.
#   --strip retire de libapp.so les informations DWARF (noms en clair, sinon
#   avertissement « unobfuscated DWARF ») : elles restent dans build\symbols.

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

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

    flutter build apk --release --obfuscate --split-debug-info=build/symbols `
        --extra-gen-snapshot-options=--strip
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
$archive = Join-Path $env:LOCALAPPDATA "Sentinel\symbols\$version-$commit"
New-Item -ItemType Directory -Force $archive | Out-Null
Copy-Item 'build\symbols\*' $archive -Recurse -Force

# Nom final, celui joint à la release GitHub (version sans le +build).
$built = 'build\app\outputs\flutter-apk\app-release.apk'
$apk = "build\sentinel-$($version.Split('+')[0]).apk"
Copy-Item $built $apk -Force
$hash = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower()
Write-Host ''
Write-Host "APK      : $apk"
Write-Host "SHA-256  : $hash"
Write-Host "Symboles : build\symbols (copie : $archive)"
Write-Host 'Vérifier la signature : voir docs\RELEASE.md (apksigner verify --print-certs).'
