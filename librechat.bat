@echo off

rem ==================================================
rem LibreChat ローカル起動用バッチ
rem 起動前メニュー: 1=そのまま起動 / 2=アップデートして起動
rem ==================================================

cd /d "%~dp0"

rem 共通の環境設定を呼び出す (git / node / mongodb 固定バージョン)
set PRE_NODE=1
set PRE_MONGO=1
call .\misc\pre_common.bat
if errorlevel 1 goto :fail

rem ---- 設定 ----
set "MAXGEN=5"
set "UPTODATE=0"
set "LCDIR=%PDIR%librechat\"
set "REPO=%LCDIR%LibreChat\"
set "DBDIR=%LCDIR%data\db"
set "BKDIR=%PDIR%misc\backup\librechat\"
set "MONGO_STARTED=0"

if not exist "%LCDIR%" mkdir "%LCDIR%"
if not exist "%DBDIR%" mkdir "%DBDIR%"
if not exist "%BKDIR%" mkdir "%BKDIR%"

rem ==================================================
rem 初回セットアップ
rem ==================================================
if exist "%REPO%.git" goto :cloned
echo.
echo LibreChat を取得中...
echo ^(Cloning LibreChat...^)
rem 末尾の \ を付けると引用符が壊れるため、%LCDIR%LibreChat を直接指定する
git clone https://github.com/LibreChat-AI/LibreChat.git "%LCDIR%LibreChat"
if errorlevel 1 goto :fail
:cloned

if exist "%REPO%.env" goto :env_ok
copy "%REPO%.env.example" "%REPO%.env" >nul
if errorlevel 1 goto :fail
echo [OK] .env を作成しました。
echo ^([OK] Created .env.^)
:env_ok

rem ---- .env の必須キー(CREDS_KEY等)が空なら自動設定 ----
node "%PDIR%misc\setup_env.js" "%REPO%.env" "%REPO%.env.temp"
if errorlevel 10 echo [OK] .env に暗号化キーを設定しました。
if errorlevel 10 echo ^([OK] Set the encryption keys in .env.^)

rem ---- librechat.yaml が無ければ最小構成で作成 (バージョンは librechat.example.yaml から取得) ----
if exist "%REPO%librechat.yaml" goto :yaml_ok
set "YAMLVER="
for /f "tokens=2" %%v in ('findstr /b /c:"version:" "%REPO%librechat.example.yaml" 2^>nul') do if not defined YAMLVER set "YAMLVER=%%v"
if not defined YAMLVER goto :yaml_ok
>"%REPO%librechat.yaml" echo version: %YAMLVER%
>>"%REPO%librechat.yaml" echo cache: true
echo [OK] librechat.yaml を作成しました。
echo ^([OK] Created librechat.yaml.^)
:yaml_ok

rem ---- インストール済みNodeバージョンの確認 ----
set "INSTALLED_NODE="
if exist "%LCDIR%installed_node.txt" set /p INSTALLED_NODE=<"%LCDIR%installed_node.txt"

set "NEED_INSTALL=0"
if not exist "%REPO%node_modules" set "NEED_INSTALL=1"
if not exist "%REPO%client\dist" set "NEED_INSTALL=1"
if not "%INSTALLED_NODE%"=="%NODE_VER%" set "NEED_INSTALL=1"
if not "%NEED_INSTALL%"=="1" goto :menu

echo.
echo 依存パッケージのインストールとビルドを行います。時間がかかります。
echo ^(Installing dependencies and building. This takes a while.^)
cd /d "%REPO%"
call npm run reinstall
if errorlevel 1 goto :fail
>"%LCDIR%installed_node.txt" echo %NODE_VER%
set "INSTALLED_NODE=%NODE_VER%"

rem ==================================================
rem 起動前メニュー
rem ==================================================
:menu
echo.
echo ==================================================
echo  LibreChat 起動メニュー
echo  ^(LibreChat launch menu^)
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
rem アップデート (バックアップ -> git pull -> 再インストール)
rem ==================================================
:update
tasklist /fi "imagename eq mongod.exe" 2>nul | find /i "mongod.exe" >nul
if errorlevel 1 goto :check_version
echo [!] MongoDB が起動中です。バックアップが壊れるため、停止してからやり直してください。
echo ^([!] MongoDB is running. Stop it and try again, or the backup will be inconsistent.^)
goto :fail

rem ---- 更新前チェック: 新しい版が要求するNode/npmが固定値と同じか確認 ----
rem (バックアップより先に行う。不一致で止まってもバックアップの世代を消費しない)
:check_version
echo.
echo 更新内容を確認中...
echo ^(Checking the incoming version...^)
cd /d "%REPO%"
git fetch
if errorlevel 1 goto :fail

rem 更新が無い場合 (ローカルと取得先のコミットが同じ) は何もせず起動へ
set "HEADREV="
set "UPREV="
for /f "delims=" %%h in ('git rev-parse HEAD 2^>nul') do set "HEADREV=%%h"
for /f "delims=" %%h in ('git rev-parse @{u} 2^>nul') do set "UPREV=%%h"
if not defined HEADREV goto :check_nvmrc
if not defined UPREV goto :check_nvmrc
if "%HEADREV%"=="%UPREV%" goto :already_latest

:check_nvmrc
set "NVMRC="
for /f "delims=" %%v in ('git --no-pager show @{u}:.nvmrc 2^>nul') do if not defined NVMRC set "NVMRC=%%v"
if not defined NVMRC goto :check_npm
set "NVMRC=%NVMRC:v=%"
if not "%NVMRC%"=="%NODE_VER%" goto :mismatch_node

:check_npm
set "NPMREQ="
for /f "delims=" %%v in ('powershell -NoProfile -Command "(git --no-pager show '@{u}:package.json' | Out-String | ConvertFrom-Json).packageManager" 2^>nul') do set "NPMREQ=%%v"
if not defined NPMREQ goto :backup
set "NPMREQ=%NPMREQ:npm@=%"
if not "%NPMREQ%"=="%NPM_VER%" goto :mismatch_npm
goto :backup

:mismatch_node
echo [NG] 新しい LibreChat は Node.js %NVMRC% を要求しています。
echo ^([NG] The new LibreChat requires Node.js %NVMRC%.^)
goto :mismatch_common

:mismatch_npm
echo [NG] 新しい LibreChat は npm %NPMREQ% を要求しています。
echo ^([NG] The new LibreChat requires npm %NPMREQ%.^)

:mismatch_common
echo     このバッチは Node.js %NODE_VER% / npm %NPM_VER% に固定されています。
echo     ^(This batch is pinned to Node.js %NODE_VER% / npm %NPM_VER%.^)
echo     misc\pre_common.bat の NODE_VER と NPM_VER を更新してから、やり直してください。
echo     ^(Update NODE_VER and NPM_VER in misc\pre_common.bat, then try again.^)
echo     コードもバックアップも、まだ変更していません。
echo     ^(Neither the code nor the backups have been changed.^)
goto :fail

:already_latest
echo [OK] すでに最新版です。
echo ^([OK] Already up to date.^)
set "UPTODATE=1"
dir /b "%BKDIR%librechat_*.zip" >nul 2>&1
if errorlevel 1 goto :first_backup
echo バックアップと更新は行いません。
echo ^(Skipping backup and update.^)
goto :start

:first_backup
echo バックアップが1世代も無いため、バックアップだけ作成します。
echo ^(No backup exists yet. Creating a backup only.^)
goto :backup

:backup
for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%t"
set "REVTAG="
if defined HEADREV set "REVTAG=_%HEADREV:~0,7%"
set "BKFILE=%BKDIR%librechat_%STAMP%%REVTAG%.zip"

echo.
echo バックアップ中: %BKFILE%
echo ^(Backing up: %BKFILE%^)

cd /d "%LCDIR%"
set "BKLIST="
if exist "data" set "BKLIST=%BKLIST% data"
if exist "LibreChat\.env" set "BKLIST=%BKLIST% LibreChat\.env"
if exist "LibreChat\.env.temp" set "BKLIST=%BKLIST% LibreChat\.env.temp"
if exist "LibreChat\librechat.yaml" set "BKLIST=%BKLIST% LibreChat\librechat.yaml"
if exist "LibreChat\uploads" set "BKLIST=%BKLIST% LibreChat\uploads"
if exist "LibreChat\client\public\images" set "BKLIST=%BKLIST% LibreChat\client\public\images"

tar -a -c -f "%BKFILE%" %BKLIST%
if errorlevel 1 (
    echo [NG] バックアップに失敗しました。アップデートを中止します。
    echo ^([NG] Backup failed. Update aborted.^)
    del /f /q "%BKFILE%" 2>nul
    goto :fail
)
echo [OK] バックアップが完了しました。
echo ^([OK] Backup completed.^)

rem 古い世代を削除 (新しい %MAXGEN% 世代だけ残す)
powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%BKDIR%' -Filter 'librechat_*.zip' | Sort-Object Name -Descending | Select-Object -Skip %MAXGEN% | Remove-Item -Force"

rem 更新が無くてバックアップだけ作った場合は、更新せず起動へ
if "%UPTODATE%"=="1" goto :start

:do_pull
echo.
echo 最新版を取得中...
echo ^(Pulling the latest version...^)
cd /d "%REPO%"
git pull
if errorlevel 1 goto :fail

rem Nodeのバージョンが変わっていれば完全再インストール、同じなら差分のみ
set "NPMCMD=smart-reinstall"
if not "%INSTALLED_NODE%"=="%NODE_VER%" set "NPMCMD=reinstall"
echo.
echo npm run %NPMCMD% を実行します。
echo ^(Running npm run %NPMCMD%.^)
call npm run %NPMCMD%
if errorlevel 1 goto :fail
>"%LCDIR%installed_node.txt" echo %NODE_VER%
echo [OK] アップデートが完了しました。
echo ^([OK] Update completed.^)

rem ==================================================
rem 起動
rem ==================================================
:start
tasklist /fi "imagename eq mongod.exe" 2>nul | find /i "mongod.exe" >nul
if not errorlevel 1 goto :mongo_ready

echo.
echo MongoDB を起動中...
echo ^(Starting MongoDB...^)
rem 同じコンソールで start /b 起動する: 新しい窓は出ず、ログはファイルへ出す。
rem この窓をxで閉じるとMongoDBにも終了の合図が届き、一緒に終わる。
rem start /b のプロセスはCtrl+Cを無視するので、Ctrl+CではLibreChatだけが止まる。
start "" /b "%DIR%mongodb\bin\mongod.exe" --dbpath "%DBDIR%" --bind_ip 127.0.0.1 --port 27017 --logpath "%LCDIR%data\mongod.log" --logappend
set "MONGO_STARTED=1"
timeout /t 5 /nobreak >nul

:mongo_ready
echo.
echo LibreChat を起動します。 http://localhost:3080/
echo ^(Starting LibreChat. Open http://localhost:3080/^)
echo 停止するには Ctrl+C を押してください。
echo ^(Press Ctrl+C to stop.^)
rem 1プロセス構成のため、スケジュール機能の警告を抑える (LibreChatのログの指示どおり)
set SCHEDULES_SINGLE_PROCESS=true
cd /d "%REPO%"
call npm run backend

rem ==================================================
rem 終了処理 (このバッチが起動したMongoDBだけ停止する)
rem ==================================================
if not "%MONGO_STARTED%"=="1" goto :end
echo.
echo MongoDB を停止中...
echo ^(Stopping MongoDB...^)
rem MongoDB自身にshutdownコマンドを送って正常終了させる (LibreChatのmongodbドライバを使用)
cd /d "%REPO%"
node -e "const {MongoClient}=require('mongodb');(async()=>{const c=new MongoClient('mongodb://127.0.0.1:27017');await c.connect();try{await c.db('admin').command({shutdown:1})}catch(e){}await c.close().catch(()=>{})})().catch(()=>{})" >nul 2>&1
timeout /t 5 /nobreak >nul
tasklist /fi "imagename eq mongod.exe" 2>nul | find /i "mongod.exe" >nul
if errorlevel 1 goto :end
taskkill /f /im mongod.exe >nul 2>&1

:end
cd /d "%PDIR%"
pause
exit /b 0

:fail
echo.
echo [NG] 処理に失敗しました。上のメッセージを確認してください。
echo ^([NG] Failed. Check the messages above.^)
pause
exit /b 1
