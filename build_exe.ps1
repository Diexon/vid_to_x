<#
build_exe.ps1

Builds a single-file Windows executable of mp4_to_mp3.py using PyInstaller.
Usage:
  ./build_exe.ps1                 # builds with default name 'mp4_to_mp3.exe'
  ./build_exe.ps1 -Name myexe.exe -Icon ./icon.ico -FFmpegZip ./ffmpeg.zip

If you supply -FFmpegZip, the script will extract ffmpeg.exe (from the ZIP) into the dist folder next to the built exe.
#>

param(
    [string]$Name = "mp4_to_mp3.exe",
    [string]$Icon = "",
    [string]$FFmpegZip = ""
)

set -e
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir

# Create venv
$Venv = Join-Path $ScriptDir "venv_build"
if (-not (Test-Path $Venv)) {
    python -m venv $Venv
}
$Activate = Join-Path $Venv "Scripts\Activate.ps1"
. $Activate
pip install --upgrade pip
pip install pyinstaller

# Build
$PyInstallerArgs = "--onefile --name $(Split-Path -LeafBase $Name) mp4_to_mp3.py"
if ($Icon -ne "") { $PyInstallerArgs += " --icon `"$Icon`"" }
Write-Host "Running: pyinstaller $PyInstallerArgs"
pyinstaller --onefile --name (Split-Path -LeafBase $Name) mp4_to_mp3.py --noconfirm

# Collect output
$DistDir = Join-Path $ScriptDir 'dist'
$BuiltExe = Join-Path $DistDir $Name
if (-not (Test-Path $BuiltExe)) {
    # PyInstaller names the file without .exe when using --name on Windows in some versions
    $NameNoExt = (Split-Path -LeafBase $Name)
    $Candidate = Join-Path $DistDir "$NameNoExt.exe"
    if (Test-Path $Candidate) { Move-Item -Path $Candidate -Destination $BuiltExe -Force }
}

if ($FFmpegZip -ne "") {
    if (-not (Test-Path $FFmpegZip)) {
        Write-Error "FFmpeg zip not found: $FFmpegZip"
        exit 2
    }
    # Try to extract ffmpeg.exe from the zip (search for ffmpeg.exe)
    $TempExtract = Join-Path $ScriptDir 'ffmpeg_tmp'
    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
    New-Item -ItemType Directory -Path $TempExtract | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($FFmpegZip, $TempExtract)
    $Found = Get-ChildItem -Path $TempExtract -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $Found) {
        Write-Error "ffmpeg.exe not found inside the provided zip"
        exit 3
    }
    Copy-Item $Found.FullName -Destination $DistDir -Force
    Remove-Item $TempExtract -Recurse -Force
    Write-Host "Bundled ffmpeg.exe into dist/"
}

Write-Host "Build complete. Output: $BuiltExe"
Pop-Location
