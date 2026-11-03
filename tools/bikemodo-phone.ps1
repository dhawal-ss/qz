# Build Bikemodo from this working copy and put it on your phone or tablet, from Windows.
#   .\tools\bikemodo-phone.ps1                  build, install over the last build, open the app
#   .\tools\bikemodo-phone.ps1 -Pair 192.168.1.20:37105 -Code 123456   pair once over Wi-Fi
#   .\tools\bikemodo-phone.ps1 -Connect 192.168.1.20:41234             connect over Wi-Fi
#   .\tools\bikemodo-phone.ps1 -NoBuild         install the last build again
# Needs: the WSL toolchain from tools/bikemodo_android_setup.sh and adb in %USERPROFILE%\bikemodo.
param(
    [string]$Pair = "",
    [string]$Code = "",
    [string]$Connect = "",
    [switch]$NoBuild,
    [switch]$NoInstall
)
$ErrorActionPreference = "Stop"
$tools = Join-Path $env:USERPROFILE "bikemodo"
$adb = Join-Path $tools "platform-tools\adb.exe"
$apk = Join-Path $tools "bikemodo-debug.apk"

if ($Pair -ne "") {
    & $adb pair $Pair $Code
    exit $LASTEXITCODE
}
if ($Connect -ne "") {
    & $adb connect $Connect
    exit $LASTEXITCODE
}

if (-not $NoBuild) {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $wslRepo = (wsl -d Ubuntu-22.04 wslpath -a ($repo -replace '\\', '/')).Trim()
    $wslApk = (wsl -d Ubuntu-22.04 wslpath -a ($apk -replace '\\', '/')).Trim()
    # git may have checked the scripts out with Windows line endings
    wsl -d Ubuntu-22.04 -u root -- sed -i 's/\r$//' "$wslRepo/tools/bikemodo_android_build.sh"
    wsl -d Ubuntu-22.04 -u root -- bash "$wslRepo/tools/bikemodo_android_build.sh" "$wslApk"
    if ($LASTEXITCODE -ne 0) { throw "The build failed, see above." }
}

if (-not $NoInstall) {
    & $adb install -r $apk
    if ($LASTEXITCODE -ne 0) { throw "Install failed. Is the phone connected? Run: $adb devices" }
    & $adb shell am start -n app.bikemodo/org.cagnulen.qdomyoszwift.CustomQtActivity | Out-Null
    Write-Host "Bikemodo is installed and open on your phone."
}
