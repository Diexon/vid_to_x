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
$NameBase = [System.IO.Path]::GetFileNameWithoutExtension($Name)
$PyInstallerArgs = @("--onefile","--name",$NameBase,"mp4_to_mp3.py","--noconfirm")
if ($Icon -ne "") { $PyInstallerArgs += @("--icon", $Icon) }
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
