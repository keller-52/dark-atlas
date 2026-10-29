@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" (
  echo Godot is missing. Please read README.md for setup instructions.
  pause
  exit /b 1
)
if not exist "%~dp0artifacts" mkdir "%~dp0artifacts"
if not exist "%~dp0demo\.godot\imported" (
  "%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --import --quit --path "%~dp0demo" --log-file "%~dp0artifacts\import.log"
  if errorlevel 1 goto failed
)
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0demo" --script res://tests/rules_test.gd --log-file "%~dp0artifacts\rules.log"
if errorlevel 1 goto failed
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0demo" --script res://tests/ui_test.gd --log-file "%~dp0artifacts\ui-tests.log"
if errorlevel 1 goto failed
echo All rule and UI integration tests passed.
pause
exit /b 0
:failed
echo Tests failed. See artifacts for details.
pause
exit /b 1
