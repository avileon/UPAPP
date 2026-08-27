@echo off
REM Windows setup for the UP project.
REM Generates the android/ and ios/ folders, fetches dependencies, and runs
REM the checks. Safe to re-run: `flutter create` only adds what is missing and
REM never touches lib/, test/ or the docs.

cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo.
  echo flutter was not found on your PATH.
  echo Install Flutter 3.22 or newer, then open a NEW terminal and try again.
  echo.
  exit /b 1
)

echo ==^> Flutter version
call flutter --version

echo.
echo ==^> Generating platform folders
call flutter create --org co.vibit.up --project-name up --platforms=android,ios .

echo.
echo ==^> Fetching dependencies
call flutter pub get

echo.
echo ==^> Analyzing
call flutter analyze

echo.
echo ==^> Testing
call flutter test

echo.
echo Done.
echo   Run on a connected phone:   flutter run
echo   Or build an installable APK: flutter build apk --debug
echo.
