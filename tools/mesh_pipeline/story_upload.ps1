<#
  story_upload.ps1 - uploads the 18 storybook page images as Decal assets,
  ONE at a time with a moderation check after each (the post-strike rule).
  Resumable via story_upload_result.json. ASCII only (PS 5.1 mojibake rule).
#>
param(
  [int] $GapSeconds = 150,
  [string] $SrcSubdir = 'work\story_pages',
  [string] $ResultName = 'story_upload_result.json'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$root = $PSScriptRoot
$srcDir = Join-Path $root $SrcSubdir
$resultPath = Join-Path $root $ResultName
$key = (Get-ItemProperty 'HKCU:\Environment' -Name ROBLOX_OPEN_CLOUD_KEY).ROBLOX_OPEN_CLOUD_KEY

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(180)
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

$pngs = Get-ChildItem $srcDir -Filter *.png | Sort-Object Name
foreach ($png in $pngs) {
  $id = $png.BaseName
  if ($results.ContainsKey($id) -and $results[$id].decalId) { continue }

  $requestJson = ConvertTo-Json @{
    assetType = 'Decal'
    displayName = 'Storybook ' + $id
    description = 'The Lost Sparkle storybook page (childrens watercolor art)'
    creationContext = @{ creator = @{ userId = 7230402132 } }
  } -Depth 6 -Compress

  $decalId = $null; $err = $null
  try {
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add((New-Object System.Net.Http.StringContent($requestJson)), 'request')
    $bytes = [IO.File]::ReadAllBytes($png.FullName)
    $fileContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('image/png')
    $content.Add($fileContent, 'fileContent', $png.Name)
    $resp = $client.PostAsync('https://apis.roblox.com/assets/v1/assets', $content).GetAwaiter().GetResult()
    $status = [int]$resp.StatusCode
    $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $content.Dispose()
    if ($status -ge 400) {
      Write-Output "STOPPING at $id : HTTP $status $body"
      break
    }
    $opId = ($body | ConvertFrom-Json).operationId
    if (-not $opId) { $opId = (($body | ConvertFrom-Json).path -replace '^operations/','') }
    for ($i = 0; $i -lt 40 -and -not $decalId; $i++) {
      Start-Sleep -Seconds 2
      try {
        $op = Invoke-RestMethod -Uri ("https://apis.roblox.com/assets/v1/operations/" + $opId) -Headers @{ 'x-api-key' = $key } -Method Get
        if ($op.done -and $op.response -and $op.response.assetId) {
          $decalId = $op.response.assetId
          $mod = $op.response.moderationResult.moderationState
          Write-Output ("{0} -> {1} (moderation: {2})" -f $id, $decalId, $mod)
          if ($mod -ne 'Approved') {
            $results[$id] = [pscustomobject]@{ decalId = $decalId; moderation = $mod }
            Save-Results
            Write-Output "STOPPING: non-Approved moderation on $id - review before continuing."
            exit 1
          }
        }
      } catch {}
    }
    if (-not $decalId) { Write-Output "STOPPING at $id : operation never finished"; break }
  } catch {
    Write-Output ("STOPPING at $id : " + $_.Exception.Message)
    break
  }
  $results[$id] = [pscustomobject]@{ decalId = $decalId; moderation = 'Approved' }
  Save-Results
  $done = @($results.Values | Where-Object { $_.decalId }).Count
  if ($done -ge 18) { break }
  Start-Sleep -Seconds $GapSeconds
}
Write-Output ("story pages uploaded: {0} / 18" -f @($results.Values | Where-Object { $_.decalId }).Count)
