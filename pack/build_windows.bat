@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0..\client_flutter"

rem === 设置代理, 供 flutter pub get / sqlite3 native hook 下载 GitHub Release ===
rem 需要本机代理端口为 20121 (Clash / v2rayN 之类)
set HTTP_PROXY=http://127.0.0.1:20121
set HTTPS_PROXY=http://127.0.0.1:20121
echo === Proxy set: %HTTP_PROXY% ===
echo.

echo === Killing any running app processes that may lock DLLs ===
taskkill /F /IM note123.exe 2>nul
timeout /t 1 /nobreak >nul

echo === Flutter clean ===
call flutter clean

echo === Force-removing native asset caches (avoids MSB8066 lock issues) ===
if exist ".dart_tool\hooks_runner" (
    rmdir /s /q ".dart_tool\hooks_runner" 2>nul
    echo   Removed .dart_tool\hooks_runner
)
if exist "build\windows\x64\CMakeFiles" (
    rmdir /s /q "build\windows\x64\CMakeFiles" 2>nul
    echo   Removed CMakeFiles
)
if exist "build\windows\x64\flutter" (
    rmdir /s /q "build\windows\x64\flutter" 2>nul
    echo   Removed build/windows/x64/flutter
)

echo === Flutter pub get ===
call flutter pub get

rem 定义目标目录变量
set TARGET_DIR=Z:\devs
set APP_NAME=Note123

echo Building Windows release...
echo Command: flutter build windows --release
call flutter build windows --release
set WINDOWS_ERROR=!errorlevel!
echo Windows build exit code: !WINDOWS_ERROR!

if !WINDOWS_ERROR! neq 0 (
    echo Failed to build Windows application with error code: !WINDOWS_ERROR!
    echo.
    pause
    exit /b 1
) else (
    echo Windows application built successfully!
    echo.
)

echo.
echo Creating ZIP package...

rem 检查构建输出目录
if not exist "build\windows\x64\runner\Release" (
    echo Error: Windows build output directory not found!
    echo Expected: build\windows\x64\runner\Release
    pause
    exit /b 1
)

rem 创建临时目录用于打包
set TEMP_DIR=temp_windows_package
if exist "%TEMP_DIR%" (
    echo Removing existing temporary directory...
    rmdir /s /q "%TEMP_DIR%"
)
mkdir "%TEMP_DIR%"

echo Copying Windows application files...
xcopy "build\windows\x64\runner\Release\*" "%TEMP_DIR%\" /E /I /H /Y
if !errorlevel! neq 0 (
    echo Failed to copy Windows application files!
    pause
    exit /b 1
)

REM 删掉 kernel_blob.bin (JIT fallback, Release 用 app.dll, 删了省 ~100MB)
del /s /q "%TEMP_DIR%\kernel_blob.bin" 2>nul

echo Creating ZIP file...
rem 使用PowerShell创建ZIP文件
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath 'windows_temp.zip' -Force"
if !errorlevel! neq 0 (
    echo Failed to create ZIP file!
    pause
    exit /b 1
)

echo Copying ZIP to target directory...
if not exist "%TARGET_DIR%\" (
    echo Creating target directory: %TARGET_DIR%\
    mkdir "%TARGET_DIR%\"
)

copy "windows_temp.zip" "%TARGET_DIR%\%APP_NAME%_windows.zip" /Y
if !errorlevel! neq 0 (
    echo Failed to copy ZIP to target directory!
    pause
    exit /b 1
)

echo Cleaning up temporary files...
del "windows_temp.zip"
rmdir /s /q "%TEMP_DIR%"

echo.
echo Checking final ZIP file:
if exist "%TARGET_DIR%\%APP_NAME%_windows.zip" (
    echo success "%APP_NAME%_windows.zip" found at "%TARGET_DIR%\"
    for %%A in ("%TARGET_DIR%\%APP_NAME%_windows.zip") do echo   File size: %%~zA bytes
) else (
    echo failed windows.zip not found at target location
)

echo.
echo Windows build completed!