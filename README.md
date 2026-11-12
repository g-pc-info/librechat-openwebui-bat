# LibreChat / Open WebUI 起動バッチ (Windows 11)

LibreChat と Open WebUI を、Docker や WSL2 なしで、Windows にそのまま入れて動かすバッチファイルです。
必要な道具(Git・Node.js・MongoDB・Python)は、バージョンを固定して自動でダウンロードします。これらを自分で入れておく必要はなく、すでに入っているものとも混ざりません(すべてこのフォルダの中に作られます)。

## 動作環境
- **Windows 11 のみ**(LibreChat が使う MongoDB 8.0 が Windows 11 を要求します)
- インターネット接続(初回と更新時)
- 空き容量: 数GB。LibreChat の初回ビルドはメモリを多めに使います
- **フォルダのパスに空白を含めないでください**(例: `D:\App\Libre_openweb\` はOK、`C:\Program Files\...` は不可)

## 使い方
1. [Releases](../../releases) の zip をダウンロードして、好きなフォルダに展開する(リポジトリの「Download ZIP」は文字コードが違うため、そのままでは動きません)
2. `librechat.bat` または `openwebui.bat` をダブルクリック
3. メニューで数字キーを押す
   - **1** そのまま起動
   - **2** 更新してから起動
4. ブラウザで開く
   - LibreChat: http://localhost:3080/
   - Open WebUI: http://localhost:8080/

初回は道具のダウンロードとインストールで時間がかかります。LibreChat は最初のビルドにも時間がかかります(環境によって大きく変わります)。

## 固定しているバージョン
`misc\pre_common.bat` の冒頭で固定しています。変えるときはここだけ書き換えます。

| 道具 | バージョン | 使うもの |
|---|---|---|
| MinGit | 2.56.1 | 両方 |
| Node.js | 24.22.1 | LibreChat |
| npm | 11.13.0 | LibreChat |
| MongoDB | 8.0.38 | LibreChat |
| Python(埋め込み版) | 3.11.9 | Open WebUI |

LibreChat 側が要求する Node / npm が固定版と違ってきたときは、更新を止めてお知らせします。

## 更新とバックアップ
- メニュー2を選ぶと、更新の前に自動でバックアップを取ります。
  - LibreChat: `git pull` → `npm run smart-reinstall`
  - Open WebUI: `pip install --upgrade open-webui`
- 最新ならバックアップも更新もせず、そのまま起動します。
- バックアップは `misc\backup\` に zip で保存し、**新しい5世代**だけ残します。
  - `librechat_20261111_230432_e6567c7.zip`(日時と、コミットの先頭7文字)
  - `webui_20261112_153112_v0.13.3.zip`(日時と、バージョン)
- Open WebUI で起動前などバックアップするデータがまだ無いときは、バックアップを飛ばします。
- LibreChat は MongoDB が動いている間はバックアップできないので、止めてからやり直してください。
- 戻すときは、zip を展開して中身を元の場所に戻します。

## フォルダ
- `librechat\` LibreChat 本体(`LibreChat\`)とデータ(`data\`: DB・ログ)
- `open-webui\` Open WebUI の仮想環境
- `system\` 自動で作られる Git / Node / MongoDB / Python(消すと次回起動時に再作成)
- `misc\` 共通設定(`pre_common.bat`)、ダウンロードしたファイル、バックアップ

## LibreChat の自動設定
初回起動時に、次を自動で行います。
- `.env` の暗号化キー(CREDS_KEY / CREDS_IV / JWT_SECRET / JWT_REFRESH_SECRET)が空なら、ランダムな値を入れる
- `librechat.yaml` が無ければ、最小のものを作る

`METRICS_SECRET`、RAG API、npm の `allow-remote` に関する警告は残りますが、動作に影響しません。

## 注意
- Open WebUI は既定で全ネットワークからの接続を待ち受けます(`0.0.0.0`)。初回に Windows ファイアウォールの許可を聞かれたら、自分のネットワークの種類(プライベート/パブリック)を考えて選んでください。外から見える必要がなければ許可しなくても、同じPCからは使えます。
- LibreChat 実行中に Ctrl+C → Y で止めたあと、ウィンドウが残ることがあります(MongoDB がまだ動いています)。ウィンドウを閉じれば終了します。
- MongoDB のログ(`librechat\data\mongod.log`)は自動で整理されません。
- このバッチは非公式です。LibreChat・Open WebUI・MongoDB・Node.js・Python・Git の各ソフトは、それぞれのライセンスに従います。バッチ自体は、それらを取得して起動するだけで、同梱はしていません。

## ライセンス
MIT License (バッチファイル部分)

---

# English

# LibreChat / Open WebUI launcher batch files (Windows 11)

Batch files that install and run LibreChat and Open WebUI natively on Windows, without Docker or WSL2.
The tools they need (Git, Node.js, MongoDB, Python) are downloaded automatically at pinned versions. You do not need to install any of them yourself, and they do not mix with anything already on your PC (everything is created inside this folder).

## Requirements
- **Windows 11 only** (MongoDB 8.0, used by LibreChat, requires Windows 11)
- Internet connection (for the first run and for updates)
- Free disk space: a few GB. The first LibreChat build uses a lot of memory
- **The folder path must not contain spaces** (e.g. `D:\App\Libre_openweb\` is fine, `C:\Program Files\...` is not)

## Usage
1. Download the zip from [Releases](../../releases) and extract it to any folder (the repository's "Download ZIP" will not work as is, because its character encoding is different)
2. Double-click `librechat.bat` or `openwebui.bat`
3. Press a number key in the menu
   - **1** Start as is
   - **2** Update, then start
4. Open it in your browser
   - LibreChat: http://localhost:3080/
   - Open WebUI: http://localhost:8080/

The first run takes a while to download and install the tools. The first LibreChat build also takes a while (it varies a lot by environment).

## Pinned versions
Pinned at the top of `misc\pre_common.bat`. This is the only place you need to edit to change them.

| Tool | Version | Used by |
|---|---|---|
| MinGit | 2.56.1 | both |
| Node.js | 24.22.1 | LibreChat |
| npm | 11.13.0 | LibreChat |
| MongoDB | 8.0.38 | LibreChat |
| Python (embeddable) | 3.11.9 | Open WebUI |

If a newer LibreChat requires a Node / npm version different from the pinned one, the update stops and tells you.

## Updates and backups
- Choosing 2 in the menu makes a backup automatically before updating.
  - LibreChat: `git pull` → `npm run smart-reinstall`
  - Open WebUI: `pip install --upgrade open-webui`
- If you are already on the latest version, nothing is backed up or updated and it just starts.
- Backups are saved as zip files in `misc\backup\`, and only the **newest 5 generations** are kept.
  - `librechat_20261111_230432_e6567c7.zip` (date/time and the first 7 characters of the commit)
  - `webui_20261112_153112_v0.13.3.zip` (date/time and the version)
- For Open WebUI, if there is no data to back up yet (e.g. before the first launch), the backup is skipped.
- LibreChat cannot be backed up while MongoDB is running; stop it and try again.
- To restore, extract the zip and put its contents back where they were.

## Folders
- `librechat\` LibreChat itself (`LibreChat\`) and its data (`data\`: database, logs)
- `open-webui\` The Open WebUI virtual environment
- `system\` Git / Node / MongoDB / Python, created automatically (delete it and it is recreated on the next run)
- `misc\` Shared settings (`pre_common.bat`), downloaded files, backups

## LibreChat automatic setup
On first launch the following is done automatically.
- If the encryption keys in `.env` (CREDS_KEY / CREDS_IV / JWT_SECRET / JWT_REFRESH_SECRET) are empty, random values are filled in
- If `librechat.yaml` does not exist, a minimal one is created

Warnings about `METRICS_SECRET`, the RAG API, and npm's `allow-remote` remain, but they do not affect operation.

## Notes
- Open WebUI listens on all network interfaces by default (`0.0.0.0`). If Windows Firewall asks for permission on the first run, choose according to your network type (private/public). If you do not need access from other devices, you can deny it and still use it from the same PC.
- After stopping LibreChat with Ctrl+C → Y, the window may stay open (MongoDB is still running). Close the window to finish.
- The MongoDB log (`librechat\data\mongod.log`) is not rotated automatically.
- These batch files are unofficial. LibreChat, Open WebUI, MongoDB, Node.js, Python and Git are each subject to their own licenses. The batch files only download and launch them; they do not bundle them.

## License
MIT License (batch file portion)
