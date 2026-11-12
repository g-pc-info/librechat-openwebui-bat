// LibreChat の .env に必須キーを設定する (Node.js)
// 使い方: node setup_env.js <.env のパス> <.env.temp のパス>
// 終了コード: 0 = 変更なし / 10 = キーを書き込んだ / 1 = エラー
// 文字コードの問題を避けるため、画面には何も出力しない (表示は呼び出し側のbatで行う)
const fs = require('fs');
const crypto = require('crypto');

const envPath = process.argv[2];
const tempPath = process.argv[3];

// キー名と生成する16進文字数 (CREDS_KEY=32byte, CREDS_IV=16byte, JWT=32byte)
const KEYS = [
  ['CREDS_KEY', 64],
  ['CREDS_IV', 32],
  ['JWT_SECRET', 64],
  ['JWT_REFRESH_SECRET', 64],
];

function parse(text) {
  const map = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m) map[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return map;
}

try {
  let text = fs.readFileSync(envPath, 'utf8');
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const env = parse(text);
  const temp = fs.existsSync(tempPath) ? parse(fs.readFileSync(tempPath, 'utf8')) : {};

  let changed = false;
  for (const [key, len] of KEYS) {
    if (env[key]) continue; // すでに値がある
    // 以前の起動で使われた仮の値があれば引き継ぐ (暗号化済みデータを読めなくしないため)
    const value = temp[key] || crypto.randomBytes(len / 2).toString('hex');
    const re = new RegExp('^[ \\t]*' + key + '[ \\t]*=[^\\r\\n]*$', 'm');
    if (re.test(text)) {
      text = text.replace(re, key + '=' + value);
    } else {
      if (!text.endsWith('\n')) text += eol;
      text += key + '=' + value + eol;
    }
    changed = true;
  }

  if (changed) {
    fs.writeFileSync(envPath, text, 'utf8');
    process.exit(10);
  }
  process.exit(0);
} catch (e) {
  process.exit(1);
}
