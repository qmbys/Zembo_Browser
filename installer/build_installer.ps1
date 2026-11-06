# Builds the Zembo Browser installer: installer\output\ZemboBrowser-Setup-<version>.exe
# Run:  powershell -ExecutionPolicy Bypass -File .\installer\build_installer.ps1
# Needs: Flutter (Windows) and Inno Setup 6.1+  https://jrsoftware.org/isdl.php

param([string]$IsccPath = '')
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

# 1. Find the Inno Setup compiler (any version: "Inno Setup 6", "Inno Setup 7", ...).
$iscc = $null
if ($IsccPath -and (Test-Path $IsccPath)) { $iscc = $IsccPath }
if (-not $iscc) {
  $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") | Where-Object { $_ -and (Test-Path $_) }
  foreach ($r in $roots) {
    $found = Get-ChildItem -Path $r -Directory -Filter 'Inno Setup*' -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName 'ISCC.exe' } |
      Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($found) { $iscc = $found; break }
  }
}
if (-not $iscc) {
  # Registry: Inno Setup writes its install location there.
  $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
  foreach ($k in $keys) {
    if (-not (Test-Path $k)) { continue }
    $loc = Get-ChildItem $k -ErrorAction SilentlyContinue |
      Where-Object { $_.PSChildName -like 'Inno Setup*' } |
      ForEach-Object { (Get-ItemProperty $_.PSPath).InstallLocation } |
      Where-Object { $_ } | Select-Object -First 1
    if ($loc -and (Test-Path (Join-Path $loc 'ISCC.exe'))) { $iscc = Join-Path $loc 'ISCC.exe'; break }
  }
}
if (-not $iscc) {
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { $iscc = $cmd.Source }
}
if (-not $iscc) { throw 'Inno Setup not found. Pass the path: .\installer\build_installer.ps1 -IsccPath "C:\path\to\ISCC.exe"' }
Write-Host "Using $iscc"

# 2. Release build of the browser.
Push-Location $root
try {
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }
} finally { Pop-Location }

$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'zembo_browser.exe'))) { throw "Not found: $release\zembo_browser.exe" }

# 3. Stage folder: the build + Visual C++ runtime DLLs (so it starts without VC++ installed).
$stage = Join-Path $here 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
Copy-Item $release $stage -Recurse
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  $src = Join-Path $env:WINDIR "System32\$dll"
  if (Test-Path $src) { Copy-Item $src $stage -Force }
}

# 4. Installer.
& $iscc (Join-Path $here 'zembo_browser.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup returned an error' }

Write-Host ''
Write-Host "Done: $(Join-Path $here 'output')" -ForegroundColor Green
