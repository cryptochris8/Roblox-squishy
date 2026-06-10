<#
  trickle_upload.ps1 - the cautious successor to the batch upload.
  After the 2026-06-10 false-positive strike (see STATE.md), uploads go ONE at a
  time with long gaps and a moderation check after each; the loop STOPS at the
  first sign of trouble instead of continuing.
  (ASCII only: PS 5.1 reads BOM-less files as ANSI, and fancy dashes mojibake
  into smart quotes that break parsing.)
#>
param(
  [int] $GapSeconds = 480,
  [int] $MaxThisRun = 24
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$resultPath = Join-Path $root 'upload_result.json'
$key = (Get-ItemProperty 'HKCU:\Environment' -Name ROBLOX_OPEN_CLOUD_KEY).ROBLOX_OPEN_CLOUD_KEY

function Succeeded-Count {
  $r = Get-Content $resultPath -Raw | ConvertFrom-Json
  return @($r.PSObject.Properties | Where-Object { $_.Value.assetId }).Count
}

$before = Succeeded-Count
for ($i = 1; $i -le $MaxThisRun; $i++) {
  $prev = Succeeded-Count
  powershell -ExecutionPolicy Bypass -File (Join-Path $root 'upload_meshes.ps1') -Limit 1
  $now = Succeeded-Count
  if ($now -le $prev) {
    Write-Output "STOPPING: upload did not succeed (possible new flag) - check upload_result.json + Roblox messages."
    break
  }
  $r = Get-Content $resultPath -Raw | ConvertFrom-Json
  $newest = $r.PSObject.Properties | Where-Object { $_.Value.assetId } | Select-Object -Last 1
  try {
    $meta = Invoke-RestMethod -Uri ("https://apis.roblox.com/assets/v1/assets/" + $newest.Value.assetId) -Headers @{ 'x-api-key' = $key } -Method GET
    Write-Output ("moderation[{0}] = {1}" -f $newest.Name, $meta.moderationResult.moderationState)
    if ($meta.moderationResult.moderationState -ne 'Approved') {
      Write-Output "STOPPING: non-Approved moderation state - do not continue; review + appeal if needed."
      break
    }
  } catch {
    Write-Output ("STOPPING: metadata check failed (" + $_.Exception.Message + ") - possible new account flag.")
    break
  }
  if ((Succeeded-Count) -ge 48) { break }
  if ($i -lt $MaxThisRun) { Start-Sleep -Seconds $GapSeconds }
}
Write-Output ("trickle done: {0} -> {1} uploaded" -f $before, (Succeeded-Count))
