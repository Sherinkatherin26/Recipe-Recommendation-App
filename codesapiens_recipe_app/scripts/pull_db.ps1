# Pull the app DB from connected Android device to current folder
$adbCmd = (Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source) 2>$null
if (-not $adbCmd) {
  $candidates = @(
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\\Android\\Sdk\\platform-tools\\adb.exe",
    "C:\\Users\\$env:USERNAME\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe"
  )
  foreach ($p in $candidates) { if (Test-Path $p) { $adbCmd = $p; break } }
}
if (-not $adbCmd) {
  Write-Error 'adb not found in PATH or common SDK locations. Please ensure Android platform-tools are installed and adb is available.'
  exit 2
}
Write-Host "Using adb: $adbCmd"
& $adbCmd devices -l
Write-Host 'Copying DB from app storage to /sdcard and pulling to workspace...'
try {
  $out = & $adbCmd shell "run-as com.example.codesapiens_recipe_app cp /data/data/com.example.codesapiens_recipe_app/databases/codesapiens_app.db /sdcard/codesapiens_app.db" 2>&1
  Write-Host $out
  $out2 = & $adbCmd pull /sdcard/codesapiens_app.db . 2>&1
  Write-Host $out2
  & $adbCmd shell rm /sdcard/codesapiens_app.db 2>&1 | Write-Host
  Write-Host 'Pull complete. Local file: codesapiens_app.db'
} catch {
  Write-Error "Failed to pull DB: $_"
  exit 3
}
