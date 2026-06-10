<#
  meshy_batch.ps1 — generate card-faithful 3D meshes for every Squishy Friend
  via Meshy image-to-3D, resumably.

  - Reads crops\<friendId>.png (the card hero art), submits up to $Concurrency
    tasks at a time, polls, downloads fbx + thumbnail into output\.
  - manifest.json records { friendId: taskId, status, fbx, thumb, credits } after
    every change, so rerunning skips finished friends and resumes in-flight tasks.
  - Key comes from HKCU:\Environment MESHY_API_KEY (never printed, never in repo).
  - Same TLS rule as the card pipeline: .NET (Invoke-RestMethod) only.
#>
param(
  [int] $Concurrency = 4,
  [int] $PollSeconds = 20,
  [string[]] $Only = @() # optional subset of friendIds (rerolls)
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$cropDir = Join-Path $root 'crops'
$outDir = Join-Path $root 'output'
$manifestPath = Join-Path $root 'manifest.json'
New-Item -ItemType Directory -Force $outDir | Out-Null

$key = (Get-ItemProperty 'HKCU:\Environment' -Name MESHY_API_KEY).MESHY_API_KEY
$headers = @{ Authorization = "Bearer $key" }
$base = 'https://api.meshy.ai/openapi/v1/image-to-3d'

# load / init manifest
$manifest = @{}
if (Test-Path $manifestPath) {
  $json = Get-Content $manifestPath -Raw | ConvertFrom-Json
  foreach ($p in $json.PSObject.Properties) { $manifest[$p.Name] = $p.Value }
}
function Save-Manifest {
  $obj = New-Object PSObject
  foreach ($k in ($manifest.Keys | Sort-Object)) { $obj | Add-Member NoteProperty $k $manifest[$k] }
  $obj | ConvertTo-Json -Depth 5 | Out-File $manifestPath -Encoding utf8
}

function Submit-Friend([string] $friendId) {
  $png = Join-Path $cropDir "$friendId.png"
  $dataUri = 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($png))
  $body = @{
    image_url = $dataUri; enable_pbr = $false; should_remesh = $true
    should_texture = $true; topology = 'triangle'; target_polycount = 12000
    symmetry_mode = 'auto'
  } | ConvertTo-Json -Compress
  $r = Invoke-RestMethod -Uri $base -Method POST -Headers $headers -ContentType 'application/json' -Body $body
  return $r.result
}

# build the work list
$all = Get-ChildItem $cropDir -Filter *.png | ForEach-Object { $_.BaseName } | Sort-Object
if ($Only.Count -gt 0) { $all = $all | Where-Object { $Only -contains $_ } }
$pending = New-Object System.Collections.ArrayList
foreach ($f in $all) {
  $m = $manifest[$f]
  if ($m -and $m.status -eq 'done') { continue }
  [void]$pending.Add($f)
}
Write-Output ("workload: {0} friends ({1} already done)" -f $pending.Count, ($all.Count - $pending.Count))

$active = @{} # friendId -> taskId
# resume any in-flight tasks from a previous run
foreach ($f in @($pending)) {
  $m = $manifest[$f]
  if ($m -and $m.status -eq 'submitted' -and $m.taskId) {
    $active[$f] = $m.taskId
    [void]$pending.Remove($f)
  }
}

while ($pending.Count -gt 0 -or $active.Count -gt 0) {
  # top up submissions
  while ($active.Count -lt $Concurrency -and $pending.Count -gt 0) {
    $f = $pending[0]; $pending.RemoveAt(0)
    try {
      $taskId = Submit-Friend $f
      $active[$f] = $taskId
      $manifest[$f] = [pscustomobject]@{ taskId = $taskId; status = 'submitted'; fbx = $null; thumb = $null; credits = $null }
      Save-Manifest
      Write-Output ("{0} submitted {1} -> {2}" -f (Get-Date -Format HH:mm:ss), $f, $taskId)
    } catch {
      Write-Output ("{0} SUBMIT FAILED {1}: {2}" -f (Get-Date -Format HH:mm:ss), $f, $_.Exception.Message)
      $manifest[$f] = [pscustomobject]@{ taskId = $null; status = 'submit_failed'; fbx = $null; thumb = $null; credits = $null }
      Save-Manifest
    }
    Start-Sleep -Seconds 2
  }

  Start-Sleep -Seconds $PollSeconds

  foreach ($f in @($active.Keys)) {
    $taskId = $active[$f]
    try {
      $t = Invoke-RestMethod -Uri "$base/$taskId" -Headers $headers -Method GET
    } catch {
      Write-Output ("{0} poll error {1}: {2}" -f (Get-Date -Format HH:mm:ss), $f, $_.Exception.Message)
      continue
    }
    if ($t.status -eq 'SUCCEEDED') {
      $fbxPath = Join-Path $outDir "$f.fbx"
      $thumbPath = Join-Path $outDir ("{0}_thumb.png" -f $f)
      try {
        Invoke-WebRequest -Uri $t.model_urls.fbx -OutFile $fbxPath -UseBasicParsing
        Invoke-WebRequest -Uri $t.thumbnail_url -OutFile $thumbPath -UseBasicParsing
        $manifest[$f] = [pscustomobject]@{ taskId = $taskId; status = 'done'; fbx = "output/$f.fbx"; thumb = "output/${f}_thumb.png"; credits = $t.consumed_credits }
        Write-Output ("{0} DONE {1} ({2} credits)" -f (Get-Date -Format HH:mm:ss), $f, $t.consumed_credits)
      } catch {
        $manifest[$f] = [pscustomobject]@{ taskId = $taskId; status = 'download_failed'; fbx = $null; thumb = $null; credits = $t.consumed_credits }
        Write-Output ("{0} DOWNLOAD FAILED {1}: {2}" -f (Get-Date -Format HH:mm:ss), $f, $_.Exception.Message)
      }
      Save-Manifest
      $active.Remove($f)
    } elseif ($t.status -eq 'FAILED' -or $t.status -eq 'CANCELED') {
      $manifest[$f] = [pscustomobject]@{ taskId = $taskId; status = 'gen_failed'; fbx = $null; thumb = $null; credits = $t.consumed_credits }
      Save-Manifest
      Write-Output ("{0} GEN FAILED {1}" -f (Get-Date -Format HH:mm:ss), $f)
      $active.Remove($f)
    }
  }
}

$done = ($manifest.Values | Where-Object { $_.status -eq 'done' }).Count
Write-Output ("batch complete: {0}/{1} done" -f $done, $all.Count)
try {
  $bal = Invoke-RestMethod -Uri 'https://api.meshy.ai/openapi/v1/balance' -Headers $headers -Method GET
  Write-Output ("credits remaining: {0}" -f $bal.balance)
} catch {}
