@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" (
  echo Godot is missing. Please read README.md for setup instructions.
  pause
  exit /b 1
)
if not exist "%~dp0artifacts" mkdir "%~dp0artifacts"
if not exist "%~dp0demo\.godot\imported" (
  echo Importing Godot resources for the first run...
  "%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --import --quit --path "%~dp0demo" --log-file "%~dp0artifacts\import.log"
  if errorlevel 1 exit /b 1
)
start "" "%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0demo" --log-file "%~dp0artifacts\runtime.log"
