# fix_studio_norton_ca.ps1
# THE recurring gotcha (doc 14 / project memory): Norton's Web Shield
# intercepts Roblox Studio's TLS with its own root CA, but every Studio
# auto-update replaces Studio's bundled ssl\cacert.pem — so Studio suddenly
# "cannot connect to the server" (publish, marketplace, login all fail)
# until Norton's CA is re-appended.
#
# Run this any time Studio can't connect after an update:
#   powershell -ExecutionPolicy Bypass -File tools\fix_studio_norton_ca.ps1
# Then FULLY close Studio (check the tray) and reopen.
#
# Idempotent: skips bundles already carrying the NORTON-APPEND marker.
# Backs up each cacert.pem to cacert.pem.bak before touching it.

$ErrorActionPreference = 'Stop'

# Find Norton's interception CA in the Windows store by subject (not a
# hardcoded thumbprint — Norton can rotate the cert).
$cert = @(Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -match 'Norton Web/Mail Shield Root' } |
    Sort-Object NotAfter -Descending)[0]
if (-not $cert) {
    Write-Host "No Norton Web/Mail Shield Root CA found in the Windows store."
    Write-Host "Either Norton interception is off (Studio should work as-is) or Norton renamed its CA - check Cert:\LocalMachine\Root."
    exit 1
}
Write-Host "Norton CA: $($cert.Subject)  (expires $($cert.NotAfter.ToShortDateString()))"

$b64 = [Convert]::ToBase64String($cert.Export('Cert'))
$lines = for ($i = 0; $i -lt $b64.Length; $i += 64) { $b64.Substring($i, [Math]::Min(64, $b64.Length - $i)) }
$block = "`n# NORTON-APPEND: Norton Web/Mail Shield Root (TLS interception CA)`n" +
    "# Re-appended $(Get-Date -Format yyyy-MM-dd) after a Studio update replaced this file.`n`n" +
    "Norton Web/Mail Shield Root`n===========================`n-----BEGIN CERTIFICATE-----`n" +
    ($lines -join "`n") + "`n-----END CERTIFICATE-----`n"

$roots = @("$env:LOCALAPPDATA\Roblox\Versions", "C:\Program Files\Roblox\Versions", "C:\Program Files (x86)\Roblox\Versions") |
    Where-Object { Test-Path $_ }
$fixed = 0
foreach ($root in $roots) {
    foreach ($dir in Get-ChildItem $root -Directory) {
        $pem = Join-Path $dir.FullName "ssl\cacert.pem"
        if (-not (Test-Path $pem)) { continue }
        if (Select-String -Path $pem -Pattern 'NORTON-APPEND' -Quiet) {
            Write-Host "OK (already patched): $pem"
            continue
        }
        Copy-Item $pem "$pem.bak" -Force
        [System.IO.File]::AppendAllText($pem, $block, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "PATCHED: $pem"
        $fixed++
    }
}
Write-Host ""
Write-Host "$fixed bundle(s) patched. Fully close Roblox Studio (check the system tray), reopen, and retry File -> Publish (Alt+P)."
