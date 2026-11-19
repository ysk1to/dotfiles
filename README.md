# dotfiles

macOS用の設定ファイル管理リポジトリ

## 📁 構成

### Shell設定
- `.zshrc` - zshの基本設定
- `.zprofile` - 環境変数とPATH設定
- `.zpreztorc` - Preztoフレームワーク設定
- `.p10k.zsh` - Powerlevel10kテーマ設定

### エディタ設定
- `.vimrc` - Vim設定
- `.tmux.conf` - tmux設定
- `vscode/` - Visual Studio Code設定（`~/Library/Application Support/Code/User/`にシンボリックリンク）
  - `settings.json` - エディタ設定
  - `keybindings.json` - キーバインド設定
- `claude/` - Claude Code設定（`~/.claude/`にシンボリックリンク）
  - `settings.json` - 権限・フック・statusLine・自動圧縮（30万トークンで開始）などの設定
  - `CLAUDE.md` - 全プロジェクト共通の指示
  - `keybindings.json` - キーバインド設定（Alt+Enterで改行）
  - `skills/` - 全プロジェクト共通のスキル（スキルごとに`~/.claude/skills/`へシンボリックリンク。`~/.claude/skills/synced`はClaudeが管理するので触らない）
    - `kindle-capture/` - Kindleの本を1ページずつ撮影してPDFにする（撮影スクリプト本体も含む）
    - `book-summary/` - 書籍PDFを章ごとに要約する
  - ほかの人が公開しているスキルは中身をリポジトリに入れず、`Makefile`の`EXTERNAL_SKILLS`にコミットを書いて`make deploy-claude`で取得する
    - [yomiyasu](https://github.com/nanaism/yomiyasu) - AIが書いた日本語を推敲する
    - 更新するときは、新しい版の中身を確かめてから`EXTERNAL_SKILLS`のコミットを書き換え、`make deploy-claude`を実行する
  - PCごとの設定は Git 管理外の `~/.claude/settings.local.json` に書く
  - 個人の情報は Git 管理外のファイルに書き、`CLAUDE.md` から `@` で読み込む
    - `~/.claude/notion-hub.local.md` - Notion のハブと DB の URL
    - `~/.claude/todoist.local.md` - 自動実行中の判断待ちを登録する Todoist のプロジェクト
- シェルのPCごとの設定は Git 管理外の `~/.zprofile.local` に書く（`.zprofile`が読み込む。例: tmux-weather の地点 `TMUX_WEATHER_LOCATION`）

### アプリケーション
- `Brewfile` - Homebrewパッケージ管理
- `iterm2/profile.json` - iTerm2のdynamic profile（Shift+EnterでESC+CRを送りClaude Codeで改行）

### スクリプト
- `bin/claude-team` - 共通のtmuxセッション `claude` に、指定ディレクトリでClaude Codeを3ペイン起動するウィンドウを作る（リポジトリごとに1ウィンドウ）
- `bin/claude-statusline` - Claude CodeのstatusLine（モデル・effort・トークン数・コンテキスト使用率など）
- `bin/claude-context-guard` - Claude Codeのフック。コンテキストが自動圧縮に近づいたら（既定25万トークン）、圧縮前にNotionへ途中経過を記録するよう促す
- `bin/claude-auto-dev` - launchdなどから定期的に呼ばれ、リポジトリの`auto-ready`のIssueを1件、Claude Code（`claude -p`）にPRにさせる。手順の本体はリポジトリの`.claude/auto-dev.md`。Issueがない回はClaudeを起動しない。`.claude/auto-plan.md`があるリポジトリでは、決まった間隔で次の作業を企画してIssueにし、`.claude/auto-plan-review.md`があれば、企画したIssueとマージされたPRを別の回で精査する
- `bin/claude-auto-dev-status` - `claude-auto-dev`の状況をまとめて出す（本人待ちの判断・PR、実行中の回、作業中と次に着手するIssue、今日の回と費用、次の起動と起動の見落とし、直近にClaudeが作った・決めたもの、消えた通知）。Claudeは起動せず、GitHubと`claude-auto-dev`が残したファイルだけを読む。`--json`で集計をJSONで出す
- `bin/claude-skill-install` - ほかの人が公開しているClaude Codeのスキルを、コミットを決めて`~/.claude/skills/`に置く。同じコミットが置いてあれば取得しない。自分が置いたのではないフォルダは置き換えない
- `bin/claude-usage-refresh` - usage APIからプラン使用率を取得してキャッシュ（Claude Codeを起動していない間の利用もtmuxに反映する）
- `bin/tmux-claude-auto-dev` - `claude-auto-dev-status`の結果を、tmuxのステータスバーの2行目にリポジトリごとの絵文字と件数で表示（例: `🔧 kbi  🏃 #14 12m  🙋 1  🔀 2  │  foo  ✓  │  ⏩ 20:00  🔁 4  💰 2.50`）。結果は5分キャッシュし、古くなったら裏で取り直す。実行中の回は毎回ロックから読む。`--popup`で凡例と状況の全文を出す（`C-q + A`）
- `bin/claude-auto-dev-watch` - 自動開発の監視用のペイン。リポジトリごとの状況（実行中の回、判断待ちとPRの番号、次の起動、今日の回と費用、見落とし・失敗）、実行中の回の手順（最後の5回のツールの呼び出し）と、全リポジトリのできごとを新しい順に流し続ける。判断待ちや失敗があればペインの枠を赤くする。`C-q + M`で右下のペインを左右に割って開け閉めする
- `bin/tmux-claude-notify` - Claude Codeのフック。ペインの状態（許可待ち・完了・作業中）をtmuxに記録し、効果音を鳴らす
- `bin/tmux-claude-panes` - 現在のセッションのClaude Codeペイン数と、許可待ち・完了の数をtmuxに表示
- `bin/tmux-claude-usage` - Claudeプラン使用率をtmuxに表示
- `bin/tmux-weather` - wttr.inの天気をキャッシュしてtmuxに表示（既定30分。地点は環境変数`TMUX_WEATHER_LOCATION`で指定し、`~/.zprofile.local`などに書く）

## 🚀 セットアップ

### 1. リポジトリをクローン
```bash
git clone https://github.com/ysk1to/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. 設定の展開とHomebrewパッケージのインストール
```bash
make install
```
dotfiles・Claude Code・VSCode・iTerm2の設定をシンボリックリンクで展開し、`brew bundle`でパッケージを入れる。個別に展開したいときは`make deploy-*`を使う

### 3. iTerm2のプロファイルがデフォルトになっているかを確かめる
`make install`は、iTerm2が動いていなければ「ysk1to (dotfiles)」をデフォルトのプロファイルにする。iTerm2の中から実行したときは変えないので、次のどちらかでデフォルトにする
- iTerm2の Settings → Profiles で「ysk1to (dotfiles)」を選び、Other Actions → Set as Default を選ぶ
- iTerm2を終了し、ほかのターミナルから`make deploy-iterm`を実行する

デフォルトが外れると、新しいウィンドウでShift+Enterの改行や配色が効かなくなる。外れていないかは`make check`でわかる

### 4. 状態を確認
```bash
make check
```

## 📋 利用可能なコマンド

### Makeターゲット
- `make` / `make help` - ターゲット一覧を表示
- `make install` - すべての設定を展開し、Homebrewパッケージをインストール
- `make check` - シンボリックリンク、外部のスキル、iTerm2の既定のプロファイル、Homebrewパッケージが揃っているか確認（古いだけのパッケージは問題なしとみなす）
- `make lint` - `bin/`のスクリプトをshellcheck、JSONファイルを構文チェック
- `make list` - リポジトリ内のdotfilesを一覧表示
- `make deploy` - dotfilesをホームディレクトリにシンボリックリンク作成
- `make deploy-vscode` - VSCode設定をアプリケーションディレクトリにシンボリックリンク作成
- `make deploy-claude` - Claude Code設定を`~/.claude/`にシンボリックリンク作成し、外部のスキルを取得
- `make deploy-iterm` - iTerm2のdynamic profileをシンボリックリンク作成し、既定のプロファイルにする（iTerm2を終了してから実行する。動いているあいだは設定ファイルが上書きされるため、変えずに画面での直し方を出す）

### カスタムスクリプト
- `claude-auto-dev <リポジトリのパス>` - 自動開発ワークフローを1回動かす。リモートの最新から専用のworktreeを作って作業させ、終わったら片付ける
  - `auto-ready`のIssueを、`p1`→`p2`→ラベルなしの順に、同じ段階の中では番号の小さい順に選ぶ（あとから出た大事なIssueを先にできる）。判断待ち（`needs-decision`）と作業中（`auto-in-progress`、対話のセッションが作業中の`in-progress`）のIssueは選ばない
  - ClaudeにはGitHubを触らせない。Issueの選択・取得、着手のラベルとコメント、push、PRの作成はスクリプトが行う。Issueの本文とコメントはファイルで渡し、コメントは「本人の判断」「ワークフローが書いたもの」「ほかの人のもの」に仕分ける
  - ClaudeがコミットしてPRのファイル（1行目がタイトル、2行目以降が本文）を書いたら、スクリプトが`auto-`のブランチをpushし、`auto-dev`と`no-auto-merge`のラベル付きでPRを作る（慣らしが済んだら`CLAUDE_AUTO_DEV_AUTO_MERGE=1`で`no-auto-merge`を外す）。判断待ちのファイルを書いたら、その中身をIssueにコメントして`needs-decision`にする
  - 企画の回: リポジトリに`.claude/auto-plan.md`があれば、前の企画から6時間たった回に、実装の代わりに企画の回を起動する（1回に1つ）。Issueが少なくなるのを待たないのは、設計の残りを足すだけでなく、改善や新機能を定期的に考えさせるため。ClaudeはIssueの案を1件1ファイルで書き（1行目がタイトル、2行目が`labels: ラベル, …`、3行目以降が本文）、スクリプトが`auto-planned`ラベル付きのIssueにする。コードは変えられない
    - 付けられるラベルは`auto-ready`・`needs-decision`・`protected`・`auto-decided`だけ。`needs-decision`か`protected`（`.github/`の変更など、自動開発に任せないもの）のIssueには`auto-ready`を付けない
    - 優先の`p2`は、企画の案には1回に1件まで付けられ、精査がPRから見つけた問題（`auto-finding`）には必ず付く。`p1`は本人だけが付ける（Claudeが`p1`と書いても`p2`にする）
    - 1回に作るのは、着手できる`auto-ready`のIssueが8件になるまで。すでに8件あれば企画しない。件数は上限で、出す価値のある案がなければ1件も作らない
    - 前の企画から、mainもIssueの開閉も変わっていなければくり返さない（出せる案がないのに毎回起動しないため）。失敗したら通知する
    - 今あるIssue（開いているものは本文つき、閉じたものはタイトルだけ）は、スクリプトがファイルで渡す
  - 精査の回: リポジトリに`.claude/auto-plan-review.md`があれば、前の精査から1日たった回に、企画でも実装でもなく精査の回を起動する。企画と同じ回にしないのは、案を書いた流れに引きずられないようにするため。コードは変えられない
    - 見るのは、企画が作ったIssue（`auto-planned`）のうちまだ精査していないものと、マージされたPR（自動開発のものも、手元の作業のものも。1回10件まで）。どちらもなければ起動しない
    - Issueに問題があれば、Claudeが`<番号>.md`を書く（1行目が`action: hold`か`action: close`、2行目以降が理由）。スクリプトが理由をコメントし、`hold`は`auto-ready`を外して`needs-decision`に、`close`は閉じる。対象でないIssueのファイルは無視する
    - PRに直すべき問題があれば、ClaudeがIssueの案を`new-NN.md`に書き（形とラベルの決まりは企画の案と同じ）、スクリプトが`auto-finding`ラベル付きのIssueにする。1回5件まで
    - 精査したIssueとPRには`auto-reviewed`を付け、次からは見ない。失敗した回は何も反映せず、通知する
  - 企画の回と精査の回が付けるラベル（`auto-planned`・`auto-finding`・`auto-reviewed`・`auto-decided`・`protected`・`p2`など）がリポジトリになければ、スクリプトが作る。すでにあるラベルには触らない。`p1`は本人が使うラベルなので、必要なら手で作る
  - `CLAUDE_AUTO_DEV_DAILY_MAX`を指定すると、実装の回を1日にその回数までにする（企画の回は数えない）。起動の回数を増やしても、使用量とレビュー待ちが増えすぎないようにするため
  - 失敗したとき・何も残さずに終わったとき・時間の上限を超えたとき・前の回が途中で止まって`auto-in-progress`が残っていたときは、Issueを`needs-decision`にしてmacOSの通知で知らせる
  - `--restricted`と`--permission-mode dontAsk`で起動する。ユーザーの設定（グローバルの`CLAUDE.md`・許可・フック）は読まず、ファイルの読み書きは作業ディレクトリと受け渡し用のファイルに限り、WebFetchは使えない。決まりは各リポジトリの`.claude/auto-dev.md`に書く
  - Bashのコマンドはサンドボックスで囲み、worktreeの外に書けないようにする（コミット用に元のリポジトリの`.git`だけ許す）。リポジトリごとの追加は`<リポジトリ名>.sandbox.json`（`sandbox`設定の中身。例: `{"filesystem":{"allowWrite":["~/.npm"]},"network":{"allowedDomains":["registry.npmjs.org"]}}`）。サンドボックス自体は切れない
  - NotionとTodoistは足す操作だけを許す（Notionの既存ページの書き換えは許さない）
  - 設定（Git管理外）: `~/.config/claude-auto-dev/<リポジトリ名>.md`（プロンプトに足す内容。NotionのURL、Todoistの登録先など）、`<リポジトリ名>.tools`（追加で許すツール。1行1つ。例: `Bash(go test:*)`）、`labels`（tmuxなどで並べる略称。「リポジトリ名 略称」を1行1つ。なければ名前の先頭3文字）
  - 環境変数: `CLAUDE_AUTO_DEV_MODEL`（既定 `opus`）、`CLAUDE_AUTO_DEV_MAX_TURNS`（既定 150）、`CLAUDE_AUTO_DEV_TIMEOUT`（秒。既定 10800）、`CLAUDE_AUTO_DEV_DAILY_MAX`（実装の回の1日の上限。既定はなし）、精査の回の`CLAUDE_AUTO_DEV_REVIEW_MODEL`（既定 `fable`）・`CLAUDE_AUTO_DEV_REVIEW_INTERVAL`（精査の間隔の秒数。既定 86400）・`CLAUDE_AUTO_DEV_REVIEW_PRS`（1回に巡回するPRの件数。既定 10）・`CLAUDE_AUTO_DEV_REVIEW_MAX`（1回に作るIssueの上限。既定 5）、企画の回の`CLAUDE_AUTO_DEV_PLAN_MODEL`（既定 `fable`）・`CLAUDE_AUTO_DEV_PLAN_INTERVAL`（企画の間隔の秒数。既定 21600）・`CLAUDE_AUTO_DEV_PLAN_TARGET`（着手できるIssueの目標の件数。既定 8）・`CLAUDE_AUTO_DEV_PLAN_MAX`（1回に作る件数の上限。既定 8）
  - ログは`~/.local/state/claude-auto-dev/logs/`（最後の応答、ターン数・費用・拒否されたツール。`.json`に結果の全体、`.stream.jsonl`に claude の出力の全体（stream-json））
  - できごと（着手・終了・PR・Issue・判断待ち・失敗）は全リポジトリ分を`~/.local/state/claude-auto-dev/events.tsv`に1行1件で残す。実行中の回の種類とIssueは`locks/<リポジトリ名>/run`にある

## 🔧 カスタマイズ

### 新しいdotfileを追加
1. ファイルをリポジトリルートに配置（`.`で始まるファイル名）
2. `make deploy`で自動的にシンボリックリンクが作成されます

### VSCode設定の更新
シンボリックリンクなので、VSCode上で設定を変えるとそのまま`vscode/`に反映される。差分をコミットするだけでよい

### Homebrewパッケージの追加
```bash
# 新しいパッケージをインストール
brew install [package-name]

# Brewfileの該当カテゴリに手で追記する（dumpすると依存ライブラリまで混ざるため）
# Brewfileとの差分確認
brew bundle check --verbose
```

## 💻 主要な設定内容

### Shell環境
- **zsh** + **Prezto** + **Powerlevel10k** による高機能なシェル環境
- **anyenv**による言語バージョン管理
- 各種開発ツールのPATH設定

### エディタ環境
- **Vim**のカスタマイズ設定
- **VSCode**のVim拡張対応キーバインド
- **tmux**による画面分割・セッション管理

### アプリケーション
主要な開発ツールとアプリケーションを含む：
- Docker, Visual Studio Code, iTerm2
- 1Password, Alfred, Notion, Slack
- Google Chrome, DeepL, Postman

## 📝 メンテナンス

設定ファイルを変更した場合は、作業ブランチを切ってプルリクエストで取り込む：
```bash
git switch -c update-xxx
make lint                      # 構文チェック
for t in tests/*.test.sh; do "$t"; done   # テスト
git add .
git commit -m "[update] 設定ファイル更新"
git push -u origin update-xxx
gh pr create
```

プルリクエストは GitHub Actions（`.github/workflows/pr-review.yml`）で自動レビューされる。
macOS で `make lint` と `tests/*.test.sh` を実行し、Claude が差分を読んで、問題がなければそのままマージする。
判断が必要なときはマージせず、PR にコメントして作成者をメンションする。
- `.github/` と `claude/`（Claude Code の設定）を変える PR、`no-auto-merge` ラベルを付けた PR は自動ではマージしない。
  - ほかの変更でこれらの記述が古くなるだけなら、レビューは止めない。マージのときに、古くなった記述を直す Issue を自動で作る。
- 認証には Secret の `CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token` で作る）を使う。

他の環境で同期：
```bash
cd ~/dotfiles
git pull origin master
make install
make check
```
