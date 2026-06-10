<#
  upload_meshes.ps1 — upload the Meshy-generated FBX bodies to Roblox as Model
  assets via the Open Cloud Assets API (same .NET/multipart shape as the card
  uploader; see ../card_art/upload_cards.ps1 for why).

  FBXs embed their textures, so the imported Model arrives with a MeshPart +
  SurfaceAppearance (ColorMap/NormalMap) ready to use — no separate texture step.

  Resumable: upload_result.json records friendId -> assetId; succeeded friends
  are skipped on rerun.
#>
param(
  [long] $CreatorUserId = 7230402132,
  [int]  $Limit = 0
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$outDir = Join-Path $root 'output'
$resultPath = Join-Path $root 'upload_result.json'

$key = $env:ROBLOX_OPEN_CLOUD_KEY
if ([string]::IsNullOrWhiteSpace($key)) {
  $key = (Get-ItemProperty 'HKCU:\Environment' -Name ROBLOX_OPEN_CLOUD_KEY).ROBLOX_OPEN_CLOUD_KEY
}

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(300)
$client.DefaultRequestHeaders.Add('x-api-key', $key)

$results = @{}
if (Test-Path $resultPath) {
  $json = Get-Content $resultPath -Raw | ConvertFrom-Json
  foreach ($p in $json.PSObject.Properties) { $results[$p.Name] = $p.Value }
}
function Save-Results {
  $obj = New-Object PSObject
  foreach ($k in ($results.Keys | Sort-Object)) { $obj | Add-Member NoteProperty $k $results[$k] }
  $obj | ConvertTo-Json -Depth 4 | Out-File $resultPath -Encoding utf8
}

function Display-Name([string] $friendId) {
  return ((($friendId -split '_') | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ' ')
}

$newCount = 0
$fbxes = Get-ChildItem $outDir -Filter *.fbx | Sort-Object Name
foreach ($fbx in $fbxes) {
  $friendId = $fbx.BaseName
  if ($results.ContainsKey($friendId) -and $results[$friendId].assetId) { continue }
  if ($Limit -gt 0 -and $newCount -ge $Limit) { break }

  $requestJson = ConvertTo-Json @{
    assetType = 'Model'
    displayName = (Display-Name $friendId) + ' Body'
    description = 'Squishy Smash friend 3D body (card-faithful)'
    creationContext = @{ creator = @{ userId = $CreatorUserId } }
  } -Depth 6 -Compress

  $assetId = $null; $err = $null
  for ($attempt = 1; $attempt -le 4 -and -not $assetId; $attempt++) {
    try {
      $content = New-Object System.Net.Http.MultipartFormDataContent
      $content.Add((New-Object System.Net.Http.StringContent($requestJson)), 'request')
      $bytes = [IO.File]::ReadAllBytes($fbx.FullName)
      $fileContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)
      $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('model/fbx')
      $content.Add($fileContent, 'fileContent', $fbx.Name)

      $resp = $client.PostAsync('https://apis.roblox.com/assets/v1/assets', $content).GetAwaiter().GetResult()
      $status = [int]$resp.StatusCode
      $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      $content.Dispose()

      if ($status -eq 429) { $err = '429 rate-limited'; Start-Sleep -Seconds (8 * $attempt); continue }
      if ($status -ge 400) { $err = "HTTP $status $body"; Start-Sleep -Seconds (3 * $attempt); continue }

      $opId = ($body | ConvertFrom-Json).operationId
      if (-not $opId) { $opId = (($body | ConvertFrom-Json).path -replace '^operations/','') }
      for ($i = 0; $i -lt 60 -and -not $assetId; $i++) {
        Start-Sleep -Seconds 2
        try {
          $op = Invoke-RestMethod -Uri ("https://apis.roblox.com/assets/v1/operations/" + $opId) -Headers @{ 'x-api-key' = $key } -Method Get
          if ($op.done -and $op.response -and $op.response.assetId) { $assetId = $op.response.assetId }
        } catch {}
      }
      if (-not $assetId) { $err = 'operation never returned assetId' }
    } catch {
      $err = $_.Exception.Message
      Start-Sleep -Seconds (3 * $attempt)
    }
  }

  $results[$friendId] = [pscustomobject]@{ assetId = $assetId; error = $(if ($assetId) { $null } else { $err }) }
  Save-Results
  $newCount++
  Write-Output ("{0,-28} {1}" -f $friendId, $(if ($assetId) { $assetId } else { "FAILED: $err" }))
  Start-Sleep -Seconds 1
}

$good = ($results.Values | Where-Object { $_.assetId }).Count
Write-Output ("uploads on record: {0}" -f $good)
