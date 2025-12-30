<#
bundle_ffmpeg.ps1

Helper to download a Windows FFmpeg build and extract ffmpeg.exe into the specified folder.
Default source uses Gyan's static build which is commonly used for CI.

Usage:
  ./bundle_ffmpeg.ps1 -DestFolder .\dist -Url https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip

Note: You may choose a different URL if you prefer.
#>

param(
    [string]$DestFolder = ".\dist",
    [string]$Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
)

$Temp = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Temp | Out-Null
$Zip = Join-Path $Temp 'ffmpeg.zip'

Write-Host "Downloading $Url..."
Invoke-WebRequest -Uri $Url -OutFile $Zip

Write-Host "Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Temp)

$Found = Get-ChildItem -Path $Temp -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $Found) {
    Write-Error "ffmpeg.exe not found in downloaded archive"
    Remove-Item $Temp -Recurse -Force
    exit 2
}

if (-not (Test-Path $DestFolder)) { New-Item -ItemType Directory -Path $DestFolder | Out-Null }
Copy-Item $Found.FullName -Destination $DestFolder -Force
Write-Host "ffmpeg.exe copied to $DestFolder"

Remove-Item $Temp -Recurse -Force
