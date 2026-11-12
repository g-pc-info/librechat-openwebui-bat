@echo off

rem ==================================================
rem 共通 環境設定 (LibreChat / Open WebUI 共用)
rem
rem 呼び出し前に、必要なものだけフラグを設定する:
rem   set PRE_NODE=1          Node.js と npm
rem   set PRE_MONGO=1         MongoDB
rem   set PRE_PYVER=3.11.9    Python (埋め込み版) とvirtualenv
rem   set PRE_VCREDIST=1      VC++ ランタイム (未インストール時のみ)
rem Git (MinGit) は常に用意する。
rem ==================================================

rem ---- 固定バージョン (変更するときはここだけ) ----
set "GIT_VER=2.56.1"
set "GIT_TAG=v2.56.1.windows.1"
set "NODE_VER=24.22.1"
set "NPM_VER=11.13.0"
set "MONGO_VER=8.0.38"

rem ---- パス設定 ----
cd /d "%~dp0.."
set "PDIR=%CD%\"
set "DIR=%CD%\system\"
set "DLDIR=%CD%\misc\downloads\"

if not exist "%DIR%" mkdir "%DIR%"
if not exist "%DLDIR%" mkdir "%DLDIR%"

set "PATH=%DIR%minGit\cmd;%PATH%"

rem ==================================================
rem Git (MinGit) 固定バージョン
rem ==================================================
if exist "%DIR%minGit\cmd\git.exe" goto :git_ok

echo.
echo MinGit %GIT_VER% を用意します。
echo ^(Preparing MinGit %GIT_VER%.^)
call :download "https://github.com/git-for-windows/git/releases/download/%GIT_TAG%/MinGit-%GIT_VER%-64-bit.zip" "%DLDIR%MinGit-%GIT_VER%-64-bit.zip"
if errorlevel 1 goto :fail
call :extract_flat "%DLDIR%MinGit-%GIT_VER%-64-bit.zip" "%DIR%minGit"
if errorlevel 1 goto :fail
if not exist "%DIR%minGit\cmd\git.exe" goto :fail
echo [OK] MinGit のインストールが完了しました。
echo ^([OK] MinGit installed.^)
:git_ok

rem ==================================================
rem Node.js (PRE_NODE=1)
rem ==================================================
if not "%PRE_NODE%"=="1" goto :node_done
set "PATH=%DIR%node;%PATH%"

set "CUR_NODE="
if exist "%DIR%node\node.exe" for /f "delims=" %%v in ('"%DIR%node\node.exe" -v') do set "CUR_NODE=%%v"
if "%CUR_NODE%"=="v%NODE_VER%" goto :node_ok

if exist "%DIR%node" rmdir /s /q "%DIR%node"
echo.
echo Node.js %NODE_VER% を用意します。
echo ^(Preparing Node.js %NODE_VER%.^)
call :download "https://nodejs.org/dist/v%NODE_VER%/node-v%NODE_VER%-win-x64.zip" "%DLDIR%node-v%NODE_VER%-win-x64.zip"
if errorlevel 1 goto :fail
call :extract_single "%DLDIR%node-v%NODE_VER%-win-x64.zip" "%DIR%node"
if errorlevel 1 goto :fail
echo [OK] Node.js のインストールが完了しました。
echo ^([OK] Node.js installed.^)
:node_ok

set "CUR_NPM="
for /f "delims=" %%v in ('npm -v') do set "CUR_NPM=%%v"
if "%CUR_NPM%"=="%NPM_VER%" goto :node_done
echo.
echo npm を %NPM_VER% に合わせます。 ^(現在: %CUR_NPM%^)
echo ^(Setting npm to %NPM_VER%. current: %CUR_NPM%^)
call npm install -g npm@%NPM_VER%
if errorlevel 1 (
    echo [!] npm の更新に失敗しました。このまま続行します。
    echo ^([!] Failed to update npm. Continuing.^)
)
:node_done

rem ==================================================
rem MongoDB (PRE_MONGO=1) データ保護のため、無ければ入れるだけ
rem ==================================================
if not "%PRE_MONGO%"=="1" goto :mongo_done
set "PATH=%DIR%mongodb\bin;%PATH%"
if exist "%DIR%mongodb\bin\mongod.exe" goto :mongo_done

echo.
echo MongoDB %MONGO_VER% を用意します。
echo ^(Preparing MongoDB %MONGO_VER%.^)
call :download "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-%MONGO_VER%.zip" "%DLDIR%mongodb-windows-x86_64-%MONGO_VER%.zip"
if errorlevel 1 goto :fail
call :extract_single "%DLDIR%mongodb-windows-x86_64-%MONGO_VER%.zip" "%DIR%mongodb"
if errorlevel 1 goto :fail
if not exist "%DIR%mongodb\bin\mongod.exe" goto :fail
echo [OK] MongoDB のインストールが完了しました。
echo ^([OK] MongoDB installed.^)
:mongo_done

rem ==================================================
rem Python 埋め込み版 (PRE_PYVER=x.y.z)
rem ==================================================
if not defined PRE_PYVER goto :py_done

for /f "tokens=1,2 delims=." %%a in ("%PRE_PYVER%") do set "PYMAJ=%%a" & set "PYMIN=%%b"
set "CMDPY=python%PYMAJ%.%PYMIN%"
set "PYNODOT=%PYMAJ%%PYMIN%"
set "PYDIR=%DIR%%CMDPY%"
set "PYZIP=python-%PRE_PYVER%-embed-amd64.zip"
set "PYINC=%PDIR%misc\python_%PRE_PYVER%_include_libs.zip"

set "PATH=%PYDIR%;%PYDIR%\Scripts;%PATH%"

if exist "%PYDIR%\python.exe" if exist "%PYDIR%\Scripts\virtualenv.exe" goto :py_done

echo.
echo Python %PRE_PYVER% を用意します。
echo ^(Preparing Python %PRE_PYVER%.^)

call :download "https://www.python.org/ftp/python/%PRE_PYVER%/%PYZIP%" "%DLDIR%%PYZIP%"
if errorlevel 1 goto :fail
if not exist "%PYDIR%\python.exe" call :extract_flat "%DLDIR%%PYZIP%" "%PYDIR%"
if errorlevel 1 goto :fail

rem include/libs (任意。zipがあり、未展開のときだけ)
if exist "%PYINC%" if not exist "%PYDIR%\include" tar -xf "%PYINC%" -C "%PYDIR%"

rem site-packages を有効にする
if exist "%PYDIR%\python%PYNODOT%._pth" "%DIR%minGit\usr\bin\sed.exe" -i "s/^#import site/import site/" "%PYDIR%\python%PYNODOT%._pth"

rem pip
if exist "%PYDIR%\Scripts\pip.exe" goto :py_pip_ok
call :download "https://bootstrap.pypa.io/get-pip.py" "%DLDIR%get-pip.py"
if errorlevel 1 goto :fail
pushd "%PYDIR%"
.\python.exe "%DLDIR%get-pip.py"
set "PYRC=%errorlevel%"
popd
if not "%PYRC%"=="0" goto :fail
:py_pip_ok

"%PYDIR%\python.exe" -m pip install --upgrade pip >nul 2>&1

rem virtualenv
"%PYDIR%\python.exe" -m pip install virtualenv >nul 2>&1
if errorlevel 1 goto :fail
echo [OK] Python %PRE_PYVER% の準備が完了しました。
echo ^([OK] Python %PRE_PYVER% is ready.^)
:py_done

rem ==================================================
rem VC++ ランタイム (PRE_VCREDIST=1) 未インストール時のみ
rem ==================================================
if not "%PRE_VCREDIST%"=="1" goto :vc_done
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Installed >nul 2>&1
if not errorlevel 1 goto :vc_done

call :download "https://aka.ms/vs/17/release/vc_redist.x64.exe" "%DLDIR%vc_redist.x64.exe"
if errorlevel 1 goto :fail
echo.
echo タスクバーを確認して、管理者権限での実行を許可してください。
echo ^(Check the taskbar and allow it to run with administrative privileges.^)
start /wait "" "%DLDIR%vc_redist.x64.exe" /install /quiet /norestart
:vc_done

cd /d "%PDIR%"
exit /b 0

:fail
echo.
echo [NG] 環境の準備に失敗しました。
echo ^([NG] Failed to prepare the environment.^)
cd /d "%PDIR%"
exit /b 1

rem ==================================================
rem サブルーチン
rem ==================================================

:download
rem %1=URL  %2=保存先 (既にあれば何もしない)
if exist "%~2" exit /b 0
echo ダウンロード中: %~1
echo ^(Downloading: %~1^)
curl -L --fail -o "%~2.part" "%~1"
if errorlevel 1 (
    echo [NG] ダウンロードに失敗しました。
    echo ^([NG] Download failed.^)
    del /f /q "%~2.part" 2>nul
    exit /b 1
)
move /y "%~2.part" "%~2" >nul
exit /b 0

:extract_flat
rem %1=zip  %2=展開先フォルダ (zipの中身をそのまま展開。末尾に \ を付けないこと)
if not exist "%~2" mkdir "%~2"
echo 展開中: %~nx1
echo ^(Extracting: %~nx1^)
tar -xf "%~1" -C "%~2"
exit /b %errorlevel%

:extract_single
rem %1=zip  %2=展開先フォルダ (zip内の最上位フォルダ1つを %2 にリネーム)
if exist "%~2_tmp" rmdir /s /q "%~2_tmp"
mkdir "%~2_tmp"
echo 展開中: %~nx1
echo ^(Extracting: %~nx1^)
tar -xf "%~1" -C "%~2_tmp"
if errorlevel 1 exit /b 1
for /d %%d in ("%~2_tmp\*") do move "%%d" "%~2" >nul
rmdir /s /q "%~2_tmp"
if not exist "%~2" exit /b 1
exit /b 0
