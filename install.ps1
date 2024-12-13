$ErrorActionPreference = "Stop"

Write-Host "**************************************"
Write-Host "*                                    *"
Write-Host "*         Installing antup           *"
Write-Host "*                                    *"
Write-Host "**************************************"

$response = Invoke-WebRequest `
    -Uri "https://api.github.com/repos/maidsafe/antup/releases/latest" `
    -UseBasicParsing
$json = $response | ConvertFrom-Json
$version = $json.tag_name.TrimStart('v')
Write-Host "Latest version of antup is $version"
$asset = $json.assets | Where-Object { $_.name -match "antup-$version-x86_64-pc-windows-msvc.zip" }
$downloadUrl = $asset.browser_download_url

$archivePath = Join-Path $env:TEMP "antup.zip"
Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath

$antPath = Join-Path $env:USERPROFILE "ant"
New-Item -ItemType Directory -Force -Path $antPath
Expand-Archive -Path $archivePath -DestinationPath $antPath -Force
Remove-Item $archivePath
$antExePath = Join-Path $antPath "ant.exe"

$currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if ($currentPath -notlike "*$antPath*") {
    $newPath = $currentPath + ";" + $antPath
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "Added $antPath to user PATH"
} else {
    Write-Host "Path $antPath is already in user PATH"
}

Write-Host "You may need to start a new session for antup to become available."
Write-Host "When antup is available, please run 'antup --help' to see how to install network components."
