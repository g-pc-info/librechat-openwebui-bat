@echo off

rem ==================================================
rem Open WebUI 起動用バッチ
rem 起動前メニュー: 1=そのまま起動 / 2=アップデートして起動
rem ==================================================

cd /d "%~dp0"

rem 共通の環境設定を呼び出す (git / python 3.11 / VC++ランタイム)
set PRE_PYVER=3.11.9
set PRE_VCREDIST=1
call .\misc\pre_common.bat
if errorlevel 1 goto :fail

rem ---- 設定 ----
set "MAXGEN=5"
set "UPTODATE=0"
set "WDIR=%PDIR%open-webui"
set "BKDIR=%PDIR%misc\backup\open-webui\"

if not exist "%WDIR%" mkdir "%WDIR%"
if not exist "%BKDIR%" mkdir "%BKDIR%"

cd /d "%WDIR%"

rem ==================================================
rem venv セットアップ (初回のみ)
rem ==================================================
if exist ".\venv" goto :venv_ready

echo.
echo Python仮想環境を作成中...
echo ^(Creating the Python virtual environment...^)
python -m virtualenv venv --prompt open-webui
if errorlevel 1 goto :venv_fail

call .\venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install open-webui
if errorlevel 1 goto :venv_fail
call .\venv\Scripts\deactivate.bat
echo [OK] Open WebUI のインストールが完了しました。
echo ^([OK] Open WebUI installed.^)
goto :venv_ready

:venv_fail
echo [NG] セットアップに失敗しました。venvを削除します。
echo ^([NG] Setup failed. Removing the venv.^)
cd /d "%WDIR%"
if exist ".\venv" rmdir /s /q ".\venv"
goto :fail

:venv_ready

rem ==================================================
rem 起動前メニュー
rem ==================================================
:menu
echo.
echo ==================================================
echo  Open WebUI 起動メニュー
echo  ^(Open WebUI launch menu^)
echo ==================================================
echo  1. そのまま起動
echo     ^(1. Start as is^)
echo  2. アップデートしてから起動
echo     ^(2. Update, then start^)
echo.
set "CHOICE="
set /p CHOICE="番号を選択 / Select [1-2]: "
if "%CHOICE%"=="1" goto :start
if "%CHOICE%"=="2" goto :update
echo [!] 1 か 2 を入力してください。
echo ^([!] Please enter 1 or 2.^)
goto :menu

rem ==================================================
rem アップデート (バックアップ -> pip upgrade)
rem ==================================================
:update
cd /d "%WDIR%"
call .\venv\Scripts\activate.bat

rem ---- 更新が無い場合 (インストール済みとPyPIの最新が同じバージョン) は何もせず起動へ ----
echo.
echo 更新内容を確認中...
echo ^(Checking for updates...^)
set "CURVER="
for /f "tokens=2" %%v in ('python -m pip show open-webui 2^>nul ^| findstr /b /c:"Version:"') do set "CURVER=%%v"
set "NEWVER="
for /f "delims=" %%v in ('powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'https://pypi.org/pypi/open-webui/json').info.version" 2^>nul') do set "NEWVER=%%v"
if not defined NEWVER goto :ver_unknown
echo 現在: %CURVER% / 最新: %NEWVER%
echo ^(Installed: %CURVER% / Latest: %NEWVER%^)
if "%CURVER%"=="%NEWVER%" goto :already_latest
goto :check_data

:ver_unknown
echo [NG] 最新バージョンを確認できませんでした。ネットワークを確認してください。
echo ^([NG] Could not check the latest version. Check your network.^)
goto :fail

:already_latest
echo [OK] すでに最新版です。
echo ^([OK] Already up to date.^)
set "UPTODATE=1"
dir /b "%BKDIR%webui_*.zip" >nul 2>&1
if errorlevel 1 goto :first_backup
echo バックアップと更新は行いません。
echo ^(Skipping backup and update.^)
call .\venv\Scripts\deactivate.bat
goto :start

:first_backup
echo バックアップが1世代も無いため、バックアップだけ作成します。
echo ^(No backup exists yet. Creating a backup only.^)
goto :check_data

:check_data
rem データフォルダの場所を求める (環境変数 DATA_DIR、無ければ open_webui\data)
rem open_webui.env は読み込まない (WEBUI_SECRET_KEY 未設定だと終了し、フォルダも作ってしまうため)
set "WEBUI_DATA="
for /f "delims=" %%d in ('python -c "import os,importlib.util as u;s=u.find_spec('open_webui');print(os.path.abspath(os.environ.get('DATA_DIR') or os.path.join(os.path.dirname(s.origin),'data')))" 2^>nul') do set "WEBUI_DATA=%%d"
if not defined WEBUI_DATA goto :nodata
if not exist "%WEBUI_DATA%" goto :nobackup
rem readme.md (パッケージ同梱) 以外に何も無ければ、まだ起動していないのでバックアップ不要
dir /b "%WEBUI_DATA%" 2>nul | findstr /v /i /x /c:"readme.md" >nul
if errorlevel 1 goto :nobackup
goto :backup

:nobackup
rem データフォルダは初回起動時に作られるため、インストール直後はまだ無い (バックアップ対象なし)
echo バックアップ対象のデータがまだ無いため、バックアップは行いません。
echo ^(No data to back up yet. Skipping backup.^)
goto :after_backup

:nodata
echo [NG] データフォルダの場所を取得できませんでした。アップデートを中止します。
echo ^([NG] Could not find the data folder. Update aborted.^)
goto :fail

:backup
for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%t"
set "VERTAG="
if defined CURVER set "VERTAG=_v%CURVER%"
set "BKFILE=%BKDIR%webui_%STAMP%%VERTAG%.zip"

echo.
echo バックアップ中: %BKFILE%
echo ^(Backing up: %BKFILE%^)
echo 対象: %WEBUI_DATA%
echo ^(Target: %WEBUI_DATA%^)

for %%I in ("%WEBUI_DATA%") do set "WD_PARENT=%%~dpI."
for %%I in ("%WEBUI_DATA%") do set "WD_NAME=%%~nxI"

set "BKEXTRA="
if exist "%WDIR%\.webui_secret_key" set BKEXTRA=-C "%WDIR%" .webui_secret_key

tar -a -c -f "%BKFILE%" -C "%WD_PARENT%" "%WD_NAME%" %BKEXTRA%
if errorlevel 1 (
    echo [NG] バックアップに失敗しました。アップデートを中止します。
    echo ^([NG] Backup failed. Update aborted.^)
    del /f /q "%BKFILE%" 2>nul
    goto :fail
)
echo [OK] バックアップが完了しました。
echo ^([OK] Backup completed.^)

rem 古い世代を削除 (新しい %MAXGEN% 世代だけ残す)
powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%BKDIR%' -Filter 'webui_*.zip' | Sort-Object Name -Descending | Select-Object -Skip %MAXGEN% | Remove-Item -Force"

:after_backup
rem 更新が無くてバックアップだけ作った場合は、更新せず起動へ
if "%UPTODATE%"=="1" goto :start

echo.
echo Open WebUI をアップデート中...
echo ^(Updating Open WebUI...^)
python -m pip install --upgrade open-webui
if errorlevel 1 goto :fail
echo [OK] アップデートが完了しました。
echo ^([OK] Update completed.^)
call .\venv\Scripts\deactivate.bat

rem ==================================================
rem 起動
rem ==================================================
:start
cd /d "%WDIR%"
call .\venv\Scripts\activate.bat

set GIT_PYTHON_REFRESH=quiet
echo.
echo Open WebUI を起動します。
echo ^(Starting Open WebUI.^)
open-webui serve

call .\venv\Scripts\deactivate.bat
cd /d "%PDIR%"
pause
exit /b 0

:fail
echo.
echo [NG] 処理に失敗しました。上のメッセージを確認してください。
echo ^([NG] Failed. Check the messages above.^)
pause
exit /b 1
