@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0..\client_flutter"

REM proxy for flutter pub get / sqlite3 native hook downloading from GitHub Release
set HTTP_PROXY=http://127.0.0.1:20121
set HTTPS_PROXY=http://127.0.0.1:20121

call flutter clean
taskkill /f /im java.exe >nul 2>&1
timeout /t 2 /nobreak >nul
set DART_VM_OPTIONS=--disable-insecure-certificates

set OUTPUT_DIR=%~dp0build
set APP_NAME=note123-android-arm64-v8a

echo Building Android APK...
echo Command: flutter build apk --release
for /f %%i in ('git rev-parse --short HEAD') do set GIT_COMMIT=%%i
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm"') do set BUILD_TIME=%%i
rem 临时把 pubspec.yaml version 改为最新 tag (去 v 前缀), 构建完还原
for /f %%i in ('powershell -NoProfile -Command "(git describe --tags --abbrev=0) -replace '^v',''"') do set APP_VERSION=%%i
echo APP_VERSION=!APP_VERSION!
powershell -NoProfile -Command "(Get-Content pubspec.yaml) -replace '^version: .*', 'version: !APP_VERSION!+1' | Set-Content pubspec.yaml"
call flutter build apk --release --target-platform android-arm64 --dart-define=GIT_COMMIT=%GIT_COMMIT% --dart-define=BUILD_TIME=%BUILD_TIME%
set BUILD_ERROR=!errorlevel!
rem 还原 pubspec.yaml (不管构建成功与否)
git checkout -- pubspec.yaml
echo Build exit code: !BUILD_ERROR!

if !BUILD_ERROR! neq 0 (
    echo Failed to build APK with error code: !BUILD_ERROR!
    exit /b 1
)

echo APK built successfully!
echo.
echo Copying APK to output directory...
if not exist "%OUTPUT_DIR%\" mkdir "%OUTPUT_DIR%\"
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\%APP_NAME%.apk" /Y
) else (
    echo Warning: APK file not found for copying
    exit /b 1
)

echo.
echo success: %OUTPUT_DIR%\%APP_NAME%.apk
exit /b 0
