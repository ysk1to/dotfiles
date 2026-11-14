# kindle-capture

Kindle for Mac の表示画面を1ページずつ撮影し、1つのPDFにまとめるスクリプト。
DRMの解除は行わない。Amazonの利用規約に反する可能性があるため、個人利用の範囲にとどめること。

## 事前準備

1. 「システム設定 → プライバシーとセキュリティ」で、実行するターミナルアプリに次の2つを許可する
   - **画面収録**（スクリーンショットのため）
   - **アクセシビリティ**（ページ送りのキー操作のため）
2. Kindle で本を開き、撮影を始めたいページ（表紙など）を表示する
3. 表示を整える（全画面表示・1ページ表示にすると、余白が少なくきれいに撮れる）

## 使い方

```sh
~/.claude/skills/kindle-capture/kindle-capture.sh                 # 縦書きの日本語本（←でページ送り）
~/.claude/skills/kindle-capture/kindle-capture.sh -d right        # 横書きの本（→でページ送り）
~/.claude/skills/kindle-capture/kindle-capture.sh -w 2 -o ~/Documents/book.pdf
```

| オプション | 内容 | デフォルト |
|---|---|---|
| `-n ページ数` | 撮影する最大ページ数 | 1000 |
| `-d left\|right` | ページ送りの方向 | left |
| `-w 秒` | ページ送り後の待ち時間 | 1.2 |
| `-r x,y,w,h` | 撮影範囲 | Kindleのウィンドウ全体 |
| `-o パス` | 出力PDFのファイルかディレクトリ | `~/Desktop/kindle_日時.pdf` |

出力先 `-o` は、実行したディレクトリからの相対パスでも絶対パスでもよい。

```sh
~/.claude/skills/kindle-capture/kindle-capture.sh -o .              # 今いるディレクトリに kindle_日時.pdf で保存
~/.claude/skills/kindle-capture/kindle-capture.sh -o ~/Documents/   # ディレクトリを指定
~/.claude/skills/kindle-capture/kindle-capture.sh -o books/本の名前  # 拡張子を省くと .pdf を付ける
```

- 出力先のディレクトリがないときは、撮影を始める前にエラーで止まる
- 同名のファイルがあるときは、上書きせずに末尾に日時を付ける

撮影中の動作:

- 同じ画面が3回続くと最終ページとみなして自動で止まる
- 途中で止めるときは Ctrl+C（撮影済みの画像は削除され、PDFは作られない）
- 撮影した画像は一時ディレクトリに保存し、終了時にディレクトリごと削除する
- 撮影中はマウスやキーボードを操作しないこと。ページ送りのキー入力と撮影は、前面にあるアプリに対して行われる
- ほかのアプリが前面に出たときは、キーを送らずに Kindle を前面に戻して続ける。戻せなければ撮影を止め、撮れたところまでを `〜_途中まで.pdf` に保存して終了コード 2 で終わる

## Claude Code から使う

どのディレクトリで Claude Code を開いていても、`/kindle-capture` と入力する（または「Kindleの本を撮って」と頼む）。
「出力は〇〇に置いて」のように保存場所も指定できる。
Claude が次の手順を進める。

1. 権限と Kindle の状態をチェックし、ウィンドウのプレビューを撮る
2. プレビューを見て、書名（ファイル名）、ページ送りの方向、撮影範囲（本文だけ）を決める
3. 確認のあと撮影する
4. できたPDFを何ページか見て、仕上がりを報告する。最後に Kindle の読了画面（レビューやシリーズの次巻の案内）が入っていれば、自動で削除する

権限は、Claude Code を動かしているターミナルアプリ（tmux の中なら、tmux を起動したターミナルアプリ）に与える。

## 構成

dotfiles の `claude/skills/kindle-capture/` にあり、`make deploy-claude` で `~/.claude/skills/kindle-capture` にリンクされる。

- `kindle-capture.sh`: 撮影とページ送りのループ、PDF作成の呼び出し
- `make_pdf.swift`: 画像をファイル名順に並べてPDFにする（PDFKitを使用。追加のインストール不要）
- `SKILL.md`: Claude Code のスキルの手順
- `preflight.sh`: 撮影前のチェックとプレビューの撮影（Kindle の操作はしない）
- `window_info.swift`: Kindle のウィンドウの位置と画面収録の許可を調べる
- `render_pages.swift`: 仕上がり確認のため、PDFの指定ページをPNGに書き出す
- `remove_pages.swift`: PDFから指定したページを削除する（読了画面の削除に使う）
