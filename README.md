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
