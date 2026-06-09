<#
  upload_cards.ps1 — Upload Squishy Smash card PNGs to Roblox as image (Decal) assets
  via the Open Cloud Assets API, and record each returned asset id.

  WHY THIS SHAPE:
    - This environment sits behind a TLS-inspecting proxy whose CA only .NET trusts,
      so curl / Python fail the handshake. We MUST use .NET (HttpClient here, and
      Invoke-RestMethod for the polls). Run under Windows PowerShell 5.1.
    - 5.1 has no `Invoke-RestMethod -Form`, so the multipart upload is built with
      System.Net.Http.MultipartFormDataContent.
    - Harness shells don't inherit a mid-session `setx`, so the key is read straight
      from HKCU:\Environment (where setx persists it) if the env var isn't set.
    - The Assets API returns a *Decal* id. ImageLabel.Image needs the underlying
      *Image* id, so a second step (in Studio: InsertService:LoadAsset -> Decal.Texture)
      resolves each Decal id to its Image id before it goes into CardImageAssets.lua.
    - Resumable: already-succeeded cards (in OutFile) are skipped; rerun to retry only
      failures. Writes OutFile after every card. -Limit N stops after N new uploads.

  USAGE:
    powershell -ExecutionPolicy Bypass -File tools\card_art\upload_cards.ps1 -Limit 1   # test one
    powershell -ExecutionPolicy Bypass -File tools\card_art\upload_cards.ps1            # the rest

  OUTPUT:
    tools\card_art\upload_result.json  — [{ file, friendId, displayName, decalId, ok, error }]
#>
param(
  [string] $PngDir        = (Join-Path $env:TEMP 'squishy_cards_png'),
  [string] $OutFile       = (Join-Path $PSScriptRoot 'upload_result.json'),
  [long]   $CreatorUserId = 7230402132,
  [int]    $Limit         = 0   # 0 = no limit
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

$key = $env:ROBLOX_OPEN_CLOUD_KEY
if ([string]::IsNullOrWhiteSpace($key)) {
  $key = (Get-ItemProperty -Path 'HKCU:\Environment' -Name 'ROBLOX_OPEN_CLOUD_KEY' -ErrorAction SilentlyContinue).ROBLOX_OPEN_CLOUD_KEY
}
if ([string]::IsNullOrWhiteSpace($key)) {
  Write-Error "No Open Cloud key found (env ROBLOX_OPEN_CLOUD_KEY or HKCU:\Environment)."
  exit 1
}
if (-not (Test-Path $PngDir)) { Write-Error "PNG dir not found: $PngDir"; exit 1 }

# The 8 cards already uploaded + wired in CardImageAssets.lua — skip by file base name.
$skip = @(
  '001_Soft_Dumpling','002_Jelly_Bun','013_Galaxy_Dumpling','032_Singularity_Goo_Core',
  '041_Star_Eyed_Bunny','043_Glow_Ghost_Puff','046_Arcane_Wobble_Kitty','048_Mythic_Plush_Familiar'
)

$assetsUrl = 'https://apis.roblox.com/assets/v1/assets'
$opUrlBase = 'https://apis.roblox.com/assets/v1/operations/'

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(180)
$client.DefaultRequestHeaders.Add('x-api-key', $key)

function Friend-Id([string] $base)    { return (($base -replace '^\d+_', '')).ToLower() }
function Display-Name([string] $base) { return (($base -replace '^\d+_', '') -replace '_', ' ') }

# Load prior results so we can resume (keep succeeded; retry the rest).
$byFriend = @{}
if (Test-Path $OutFile) {
  try {
    $prior = Get-Content $OutFile -Raw | ConvertFrom-Json
    foreach ($p in $prior) { if ($p -and $p.friendId) { $byFriend[$p.friendId] = $p } }
  } catch { }
}

function Save-Results {
  ($byFriend.Values | Sort-Object file) | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutFile -Encoding utf8
}

$newCount = 0
$pngs = Get-ChildItem -Path $PngDir -Filter *.png | Sort-Object Name

foreach ($png in $pngs) {
  $base = $png.BaseName
  if ($skip -contains $base) { continue }
  $friendId = Friend-Id $base
  if ($byFriend.ContainsKey($friendId) -and $byFriend[$friendId].ok) { continue }   # already done
  if ($Limit -gt 0 -and $newCount -ge $Limit) { break }

  $displayName = Display-Name $base
  $requestJson = ConvertTo-Json @{
    assetType       = 'Decal'
    displayName     = $displayName
    description     = 'Squishy Smash collectible card'
    creationContext = @{ creator = @{ userId = $CreatorUserId } }
  } -Depth 6 -Compress

  $decalId = $null; $err = $null

  for ($attempt = 1; $attempt -le 4 -and -not $decalId; $attempt++) {
    try {
      $content = New-Object System.Net.Http.MultipartFormDataContent
      $content.Add((New-Object System.Net.Http.StringContent($requestJson)), 'request')
      $bytes = [System.IO.File]::ReadAllBytes($png.FullName)
      $fileContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)
      $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('image/png')
      $content.Add($fileContent, 'fileContent', $png.Name)

      $resp   = $client.PostAsync($assetsUrl, $content).GetAwaiter().GetResult()
      $status = [int]$resp.StatusCode
      $body   = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      $content.Dispose()

      if ($status -eq 429) { $err = '429 rate-limited'; Start-Sleep -Seconds (6 * $attempt); continue }
      if ($status -ge 400) { $err = "HTTP $status $body"; Start-Sleep -Seconds (2 * $attempt); continue }

      $json = $body | ConvertFrom-Json
      $opId = $json.operationId
      if (-not $opId -and $json.path) { $opId = ($json.path -replace '^operations/', '') }

      if ($json.response -and $json.response.assetId) {
        $decalId = $json.response.assetId
      } elseif ($opId) {
        for ($i = 0; $i -lt 40 -and -not $decalId; $i++) {
          Start-Sleep -Milliseconds 1500
          try {
            $op = Invoke-RestMethod -Uri ($opUrlBase + $opId) -Headers @{ 'x-api-key' = $key } -Method Get
            if ($op.done -and $op.response -and $op.response.assetId) { $decalId = $op.response.assetId }
          } catch { }
        }
        if (-not $decalId) { $err = 'operation never returned assetId' }
      } else {
        $err = "no operationId in response: $body"
      }
    } catch {
      $err = $_.Exception.Message
      Start-Sleep -Seconds (2 * $attempt)
    }
  }

  $ok = [bool]$decalId
  $byFriend[$friendId] = [pscustomobject]@{
    file = $base; friendId = $friendId; displayName = $displayName
    decalId = $decalId; ok = $ok; error = $(if ($ok) { $null } else { $err })
  }
  Save-Results
  $newCount++
  Write-Host ("{0,-34} {1}" -f $base, $(if ($ok) { $decalId } else { "FAILED: $err" }))
  Start-Sleep -Milliseconds 900   # gentle rate limit
}

$good = ($byFriend.Values | Where-Object ok).Count
Write-Host ""
Write-Host ("Done this run: $newCount processed. Total succeeded on record: $good. -> $OutFile")
