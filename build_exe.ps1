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

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir
Write-Host "Starting build in $ScriptDir"

# Create or reuse venv
$Venv = Join-Path $ScriptDir "venv_build"
if (-not (Test-Path $Venv)) {
    Write-Host "Creating virtual environment at $Venv..."
    python -m venv $Venv
}
$Activate = Join-Path $Venv "Scripts\Activate.ps1"
if (-not (Test-Path $Activate)) {
    Write-Error "Activation script not found: $Activate. Ensure Python is installed and 'python -m venv $Venv' succeeded."
    Pop-Location
    exit 1
}
. $Activate

Write-Host "Upgrading pip and ensuring PyInstaller is installed..."
& python -m pip install --upgrade pip
& python -m pip install pyinstaller

# Build
# Find ffmpeg to bundle (check PATH, provided ZIP, or download a default ZIP)
$ffmpegPath = $null
$cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($cmd) {
    $ffmpegPath = $cmd.Path
    Write-Host "Found ffmpeg on PATH: $ffmpegPath"
} elseif ($FFmpegZip -ne "") {
    if (-not (Test-Path $FFmpegZip)) {
        Write-Error "FFmpeg zip not found: $FFmpegZip"
        Pop-Location
        exit 2
    }
    $TempExtract = Join-Path $ScriptDir 'ffmpeg_tmp'
    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
    New-Item -ItemType Directory -Path $TempExtract | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($FFmpegZip, $TempExtract)
    $Found = Get-ChildItem -Path $TempExtract -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $Found) {
        Write-Error "ffmpeg.exe not found inside the provided zip"
        Remove-Item $TempExtract -Recurse -Force
        Pop-Location
        exit 3
    }
    $embedDir = Join-Path $ScriptDir 'build_embedded'
    if (-not (Test-Path $embedDir)) { New-Item -ItemType Directory -Path $embedDir | Out-Null }
    $dest = Join-Path $embedDir 'ffmpeg.exe'
    Copy-Item $Found.FullName -Destination $dest -Force
    $ffmpegPath = $dest
    Remove-Item $TempExtract -Recurse -Force
    Write-Host "Copied ffmpeg to $ffmpegPath for bundling"
} else {
    $DefaultUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    Write-Host "No ffmpeg on PATH and no zip provided; downloading default ffmpeg from $DefaultUrl (may be large)..."
    $Temp = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $Temp | Out-Null
    $Zip = Join-Path $Temp 'ffmpeg.zip'
    Invoke-WebRequest -Uri $DefaultUrl -OutFile $Zip
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Temp)
    $Found = Get-ChildItem -Path $Temp -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $Found) {
        $embedDir = Join-Path $ScriptDir 'build_embedded'
        if (-not (Test-Path $embedDir)) { New-Item -ItemType Directory -Path $embedDir | Out-Null }
        $dest = Join-Path $embedDir 'ffmpeg.exe'
        Copy-Item $Found.FullName -Destination $dest -Force
        $ffmpegPath = $dest
        Write-Host "Copied ffmpeg to $ffmpegPath for bundling"
    } else {
        Write-Warning "Could not find ffmpeg in downloaded archive; continuing without bundling."
    }
    Remove-Item $Temp -Recurse -Force
}

$NameBase = [System.IO.Path]::GetFileNameWithoutExtension($Name)
$PyInstallerArgs = @("--onefile","--name",$NameBase,"mp4_to_mp3.py","--noconfirm")
if ($Icon -ne "") { $PyInstallerArgs += @("--icon", $Icon) }
if ($ffmpegPath) { $PyInstallerArgs += @("--add-binary", "$ffmpegPath;."); Write-Host "Will bundle ffmpeg: $ffmpegPath" } else { Write-Host "Building without embedding ffmpeg (exe will require external ffmpeg)." }

Write-Host "Running: python -m PyInstaller $($PyInstallerArgs -join ' ')"
$ArgsList = @("-m","PyInstaller") + $PyInstallerArgs
$proc = Start-Process -FilePath "python" -ArgumentList $ArgsList -NoNewWindow -Wait -PassThru
if ($null -eq $proc) {
    Write-Error "Failed to start python process. Ensure 'python' is on PATH or use the py launcher."
    Pop-Location
    exit 1
}
if ($proc.ExitCode -ne 0) {
    Write-Error "PyInstaller failed with exit code $($proc.ExitCode)."
    Pop-Location
    exit $proc.ExitCode
}

# Collect output
$DistDir = Join-Path $ScriptDir 'dist'
$NameExe = $NameBase + '.exe'
$BuiltExe = Join-Path $DistDir $NameExe
if (-not (Test-Path $BuiltExe)) {
    Write-Host "Build did not produce expected $BuiltExe. Contents of dist/:"
    Get-ChildItem -Path $DistDir -Force -ErrorAction SilentlyContinue
    Pop-Location
    exit 2
}

Write-Host "Build complete. Output: $BuiltExe"

# Quick self-check: run the built exe with --version to ensure it runs and (if bundled) reports ffmpeg path
try {
    Write-Host "Running self-check: $BuiltExe --version"
    $checkOut = & $BuiltExe --version 2>&1
    Write-Host $checkOut
    if ($LASTEXITCODE -ne 0) { Write-Warning "Self-check returned exit code $LASTEXITCODE" }
} catch {
    Write-Warning "Self-check failed to run: $_"
}

Pop-Location
