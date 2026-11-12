<#
.SYNOPSIS
    Tests de fumée du backend Sentinel, par l'API publique seulement.

.DESCRIPTION
    Vérifie : santé (avec réveil de Render), redirection HTTP -> HTTPS,
    documentation fermée, en-têtes de sécurité, signalement et doublon,
    signalement invalide (422), limite par adresse (429) et usurpation
    de X-Forwarded-For. Aucun secret, aucun accès direct à la base.

    Les textes envoyés commencent tous par « [TEST SMOKE] » : à rejeter
    (touche r) dans python -m tools.review.

    Attention : le test de limite consomme le quota de VOTRE adresse IP
    pour l'heure en cours (10 signalements par heure).

.EXAMPLE
    .\tools\smoke_test.ps1 -Api https://sentinel-api-xxxx.onrender.com
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Api,
    # Réveil de Render (offre gratuite) : environ 1 minute.
    [int]$WakeTimeoutSeconds = 90,
    # Au-delà, le test de limite est déclaré en échec (pas de 429 reçu).
    [int]$MaxAttempts = 15
)

$ErrorActionPreference = 'Stop'
$Api = $Api.TrimEnd('/')
$repo = Split-Path -Parent $PSScriptRoot
$example = Join-Path $repo 'backend\exemples\signalement_valide.json'
$prefix = '[TEST SMOKE]'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$expectedLimit = 10

# Windows PowerShell 5.1 : TLS 1.2 et HttpClient à charger.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

# Client sans redirection automatique : on veut voir les 301/308.
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false
$http = New-Object System.Net.Http.HttpClient($handler)
$http.Timeout = [TimeSpan]::FromSeconds(30)
$http.DefaultRequestHeaders.UserAgent.ParseAdd('Sentinel-SmokeTest/1.0')

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$test, [bool]$ok, [string]$detail) {
    $results.Add([pscustomobject]@{
        Test     = $test
        Resultat = $(if ($ok) { 'OK' } else { 'ÉCHEC' })
        Detail   = $detail
    })
}
function Add-Skip([string]$test, [string]$detail) {
    $results.Add([pscustomobject]@{ Test = $test; Resultat = 'IGNORÉ'; Detail = $detail })
}

# Une requête : renvoie statut, en-têtes (minuscules) et corps.
function Send-Request {
    param(
        [string]$Method = 'GET',
        [string]$Url,
        [string]$Json,
        [hashtable]$Headers = @{}
    )
    $request = New-Object System.Net.Http.HttpRequestMessage(
        (New-Object System.Net.Http.HttpMethod($Method)), $Url)
    foreach ($name in $Headers.Keys) {
        [void]$request.Headers.TryAddWithoutValidation($name, $Headers[$name])
    }
    if ($Json) {
        $request.Content = New-Object System.Net.Http.StringContent(
            $Json, [Text.Encoding]::UTF8, 'application/json')
    }
    $response = $http.SendAsync($request).GetAwaiter().GetResult()
    $headersOut = @{}
    foreach ($h in $response.Headers) { $headersOut[$h.Key.ToLower()] = ($h.Value -join ', ') }
    if ($response.Content) {
        foreach ($h in $response.Content.Headers) { $headersOut[$h.Key.ToLower()] = ($h.Value -join ', ') }
    }
    $body = if ($response.Content) { $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } else { '' }
    [pscustomobject]@{ Status = [int]$response.StatusCode; Headers = $headersOut; Body = $body }
}

function New-Report([string]$text, [hashtable]$changes = @{}) {
    $report = Get-Content -Raw -Encoding UTF8 $example | ConvertFrom-Json
    $report.text = "$prefix $text"
    foreach ($key in $changes.Keys) {
        $report | Add-Member -NotePropertyName $key -NotePropertyValue $changes[$key] -Force
    }
    $report | ConvertTo-Json -Compress
}

Write-Host "Tests de fumée : $Api" -ForegroundColor Cyan

# --- 1. Santé (réveil compris) ---------------------------------------------
$start = Get-Date
$health = $null
while (((Get-Date) - $start).TotalSeconds -lt $WakeTimeoutSeconds) {
    try {
        $health = Send-Request -Url "$Api/v1/health"
        if ($health.Status -eq 200) { break }
    } catch { $health = $null }
    Write-Host '  en attente du réveil du serveur...'
    Start-Sleep -Seconds 5
}
$waited = [int]((Get-Date) - $start).TotalSeconds
if ($health -and $health.Status -eq 200 -and $health.Body -match '"status"\s*:\s*"ok"') {
    Add-Result '1. Santé /v1/health' $true "200 status ok ($waited s)"
} else {
    $got = if ($health) { "$($health.Status) $($health.Body)" } else { 'pas de réponse' }
    Add-Result '1. Santé /v1/health' $false "$got après $waited s"
    $results | Format-Table -AutoSize -Wrap
    Write-Host 'Serveur injoignable : arrêt.' -ForegroundColor Red
    exit 1
}

# --- 2. HTTP -> HTTPS -----------------------------------------------------
if ($Api.StartsWith('https://')) {
    $plain = 'http://' + $Api.Substring(8) + '/v1/health'
    try {
        $r = Send-Request -Url $plain
        $location = $r.Headers['location']
        $ok = ($r.Status -in 301, 302, 307, 308) -and $location -like 'https://*'
        Add-Result '2. HTTP redirigé vers HTTPS' $ok "$($r.Status) -> $location"
    } catch {
        Add-Result '2. HTTP redirigé vers HTTPS' $false $_.Exception.Message
    }
} else {
    Add-Skip '2. HTTP redirigé vers HTTPS' 'adresse en http (local) : rien à rediriger'
}

# --- 3. Documentation fermée ------------------------------------------------
$docs = Send-Request -Url "$Api/docs"
$openapi = Send-Request -Url "$Api/openapi.json"
Add-Result '3. /docs et /openapi.json fermés' (($docs.Status -eq 404) -and ($openapi.Status -eq 404)) `
    "/docs $($docs.Status), /openapi.json $($openapi.Status)"

# --- 4. En-têtes de sécurité --------------------------------------------------
$wanted = [ordered]@{
    'strict-transport-security' = 'max-age='
    'x-content-type-options'    = 'nosniff'
    'x-frame-options'           = 'DENY'
    'content-security-policy'   = "default-src 'none'"
    'referrer-policy'           = 'no-referrer'
    'cache-control'             = 'no-store'
}
$missing = @()
foreach ($name in $wanted.Keys) {
    $value = $health.Headers[$name]
    if (-not $value -or -not $value.Contains($wanted[$name])) { $missing += $name }
}
$detail = if ($missing) { 'manquant : ' + ($missing -join ', ') } else { 'HSTS : ' + $health.Headers['strict-transport-security'] }
if ($health.Headers.ContainsKey('server') -and $health.Headers['server'] -match 'uvicorn') {
    $missing += 'server'; $detail += ' ; en-tête server: uvicorn présent'
}
Add-Result '4. En-têtes de sécurité' ($missing.Count -eq 0) $detail

# --- 5. Signalement et doublon ----------------------------------------------
$sent = 0  # signalements comptés par la limite (201 ou 429)
$body = New-Report "exemple $runId"
$first = Send-Request -Method POST -Url "$Api/v1/reports" -Json $body
$second = Send-Request -Method POST -Url "$Api/v1/reports" -Json $body
$sent += 2
$id1 = ($first.Body | ConvertFrom-Json -ErrorAction SilentlyContinue).id
$id2 = ($second.Body | ConvertFrom-Json -ErrorAction SilentlyContinue).id
Add-Result '5a. Signalement valide' (($first.Status -eq 201) -and $id1) "$($first.Status) id=$id1"
Add-Result '5b. Même envoi : même id' (($second.Status -eq 201) -and $id1 -and ($id1 -eq $id2)) `
    "$($second.Status) id=$id2"

# --- 6. Signalement invalide --------------------------------------------------
$invalid = New-Report "invalide $runId" @{ probability = 1.5; device_id = 'abc123' }
$bad = Send-Request -Method POST -Url "$Api/v1/reports" -Json $invalid
$leak = $bad.Body.Contains('abc123') -or $bad.Body.Contains($prefix)
Add-Result '6. Invalide (probabilité 1.5 + device_id)' (($bad.Status -eq 422) -and -not $leak) `
    "$($bad.Status)$(if ($leak) { ' ; la réponse recopie l''entrée !' } else { ', réponse sans le texte reçu' })"

# --- 7. Limite par adresse ------------------------------------------------------
$passed = 0
$limited = $null
for ($i = 1; $i -le $MaxAttempts; $i++) {
    $r = Send-Request -Method POST -Url "$Api/v1/reports" -Json (New-Report "limite $runId n°$i")
    if ($r.Status -eq 201) { $passed++ }
    elseif ($r.Status -eq 429) { $limited = $r; break }
    else { break }
}
$expectedNow = $expectedLimit - $sent
if ($limited) {
    $retry = $limited.Headers['retry-after']
    $note = "$passed passé(s) puis 429 (Retry-After $retry s). Attendu : $expectedNow (= $expectedLimit par heure - $sent envoyés au test 5)"
    if ($passed -lt $expectedNow) {
        $note += ". Moins que prévu : d'autres signalements ont été envoyés depuis cette adresse dans l'heure (tests précédents, app)."
    } elseif ($passed -gt $expectedNow) {
        $note += '. Plus que prévu : le serveur a redémarré ou s''est réveillé pendant le test (compteur en mémoire remis à zéro).'
    }
    # Jamais plus de 10 dans l'heure, sauf redémarrage du serveur.
    Add-Result '7. Limite par adresse (429)' ($passed -le $expectedLimit) $note
} else {
    Add-Result '7. Limite par adresse (429)' $false "aucun 429 après $passed envois (dernier statut $($r.Status))"
}

# --- 8. Usurpation de X-Forwarded-For ---------------------------------------------
if ($limited) {
    $spoof = Send-Request -Method POST -Url "$Api/v1/reports" `
        -Json (New-Report "usurpation $runId") -Headers @{ 'X-Forwarded-For' = '1.2.3.4' }
    $ok = $spoof.Status -eq 429
    $msg = if ($ok) { '429 : la fausse adresse est ignorée' } else { "$($spoof.Status) : la limite est contournable ! Mettre SENTINEL_TRUST_PROXY=false" }
    Add-Result '8. Usurpation X-Forwarded-For: 1.2.3.4' $ok $msg
} else {
    Add-Skip '8. Usurpation X-Forwarded-For: 1.2.3.4' 'pas de 429 au test 7'
}

$http.Dispose()
$results | Format-Table -AutoSize -Wrap
$failed = @($results | Where-Object { $_.Resultat -eq 'ÉCHEC' }).Count
if ($failed) {
    Write-Host "$failed test(s) en échec." -ForegroundColor Red
    exit 1
}
Write-Host "Tout est OK. Textes « $prefix » à rejeter dans la revue (touche r)." -ForegroundColor Green
