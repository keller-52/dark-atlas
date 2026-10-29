@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" (
  echo Godot is missing. Please read README.md for setup instructions.
  pause
  exit /b 1
)
start "" "%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0demo"
