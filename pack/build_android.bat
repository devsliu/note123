@echo off
setlocal enabledelayedexpansion

REM 切换到 client_flutter 目录, 确保 flutter 能找到 pubspec.yaml
cd /d "%~dp0..\client_flutter"

REM sqlite3 native hook 从 GitHub Release 下载预编译 .so, 国内不挂代理超时 (errno=121)
set HTTP_PROXY=http://127.0.0.1:20121
set HTTPS_PROXY=http://127.0.0.1:20121

call flutter clean
set DART_VM_OPTIONS=--disable-insecure-certificates

rem 定义目标目录变量
set TARGET_DIR=Z:\devs
set APP_NAME=Note123

echo Building all Android APK flavors...

echo.
echo Building Phone APK...
echo Command: flutter build apk --release --flavor phone
call flutter build apk --release --target-platform android-arm64 --flavor phone
set PHONE_ERROR=!errorlevel!
echo Phone build exit code: !PHONE_ERROR!
if !PHONE_ERROR! neq 0 (
    echo Failed to build Phone APK with error code: !PHONE_ERROR!
    echo Continuing with Pad build anyway...
    echo.
) else (
    echo Phone APK built successfully!
    echo.
    echo Copying Phone APK to target directory...
    if not exist "%TARGET_DIR%\" (
        echo Creating target directory: %TARGET_DIR%\
        mkdir "%TARGET_DIR%\"
    )
    if exist "build\app\outputs\apk\phone\release\app-phone-release.apk" (
        copy "build\app\outputs\apk\phone\release\app-phone-release.apk" "%TARGET_DIR%\%APP_NAME%_phone.apk" /Y
        echo Phone APK copied to %TARGET_DIR%\%APP_NAME%_phone.apk
    ) else if exist "build\app\outputs\flutter-apk\app-phone-release.apk" (
        copy "build\app\outputs\flutter-apk\app-phone-release.apk" "%TARGET_DIR%\%APP_NAME%_phone.apk" /Y
        echo Phone APK copied to %TARGET_DIR%\%APP_NAME%_phone.apk
    ) else (
        echo Warning: Phone APK file not found for copying
    )
    echo.
)

echo.
echo Building Pad APK...
echo Command: flutter build apk --release --flavor pad
call flutter build apk --release --target-platform android-arm64 --flavor pad
set PAD_ERROR=!errorlevel!
echo Pad build exit code: !PAD_ERROR!
if !PAD_ERROR! neq 0 (
    echo Failed to build Pad APK with error code: !PAD_ERROR!
    echo.
) else (
    echo Pad APK built successfully!
    echo.
    echo Copying Pad APK to target directory...
    if not exist "%TARGET_DIR%\" (
        echo Creating target directory: %TARGET_DIR%\
        mkdir "%TARGET_DIR%\"
    )
    if exist "build\app\outputs\apk\pad\release\app-pad-release.apk" (
        copy "build\app\outputs\apk\pad\release\app-pad-release.apk" "%TARGET_DIR%\%APP_NAME%_pad.apk" /Y
        echo Pad APK copied to %TARGET_DIR%\%APP_NAME%_pad.apk
    ) else if exist "build\app\outputs\flutter-apk\app-pad-release.apk" (
        copy "build\app\outputs\flutter-apk\app-pad-release.apk" "%TARGET_DIR%\%APP_NAME%_pad.apk" /Y
        echo Pad APK copied to %TARGET_DIR%\%APP_NAME%_pad.apk
    ) else (
        echo Warning: Pad APK file not found for copying
    )
    echo.
)

echo.
echo Build Summary:
echo Phone APK exit code: !PHONE_ERROR!
echo Pad APK exit code: !PAD_ERROR!

if !PHONE_ERROR! equ 0 if !PAD_ERROR! equ 0 (
    echo All APK builds completed successfully!
) else (
    echo Some builds failed. Check the output above for details.
)

echo.
echo Generated files:
if exist "build\app\outputs\flutter-apk\*.apk" (
    dir /b build\app\outputs\flutter-apk\*.apk
) else (
    echo No APK files found in build\app\outputs\flutter-apk\
)

echo.
echo Checking copied files in %TARGET_DIR%\:
if exist "%TARGET_DIR%\%APP_NAME%_phone.apk" (
    echo success %APP_NAME%_phone.apk found
) else (
    echo failed %APP_NAME%_phone.apk not found
)

if exist "%TARGET_DIR%\%APP_NAME%_pad.apk" (
    echo success %APP_NAME%_pad.apk found
) else (
    echo failed %APP_NAME%_pad.apk not found
)

echo.
echo APK files are available at:
echo %cd%\build\app\outputs\flutter-apk\

