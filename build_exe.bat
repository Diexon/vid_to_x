@echo off
REM build_exe.bat - convenience wrapper for build_exe.ps1
SET PowerShellExe=powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\build_exe.ps1" %*
%PowerShellExe%
