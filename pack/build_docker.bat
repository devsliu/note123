@echo off
set TARGET_DIR=Z:\devs

cd /d "%~dp0..\server_go\src"

set DOCKER_HOST=
set KO_DATA_PATH=
set KO_DOCKER_REPO=note123

rem 从 version.txt 读取版本号
set /p VERSION=<version.txt
set KO_DEFAULTTAG=%VERSION%

set TARBALL=note123.tar

ko publish --bare --push=false --tarball=%TARBALL% -t %VERSION% .

if not exist "%TARGET_DIR%\" mkdir "%TARGET_DIR%\"
copy "%TARBALL%" "%TARGET_DIR%\%TARBALL%" /Y
del "%TARBALL%"

echo Done!
pause
