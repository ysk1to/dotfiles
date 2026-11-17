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
  - PCごとの設定は Git 管理外の `~/.claude/settings.local.json` に書く
  - 個人の情報は Git 管理外のファイルに書き、`CLAUDE.md` から `@` で読み込む
    - `~/.claude/notion-hub.local.md` - Notion のハブと DB の URL
    - `~/.claude/todoist.local.md` - 自動実行中の判断待ちを登録する Todoist のプロジェクト
- シェルのPCごとの設定は Git 管理外の `~/.zprofile.local` に書く（`.zprofile`が読み込む。例: tmux-weather の地点 `TMUX_WEATHER_LOCATION`）

### アプリケーション
- `Brewfile` - Homebrewパッケージ管理
- `iTerm.json` - iTerm2カラーテーマ設定
- `iterm2/profile.json` - iTerm2のdynamic profile（Shift+EnterでESC+CRを送りClaude Codeで改行）

### スクリプト
- `bin/claude-team` - 指定ディレクトリでClaude Codeを3ペイン起動するtmuxセッションを構築
- `bin/claude-statusline` - Claude CodeのstatusLine（モデル・effort・トークン数・コンテキスト使用率など）
- `bin/claude-context-guard` - Claude Codeのフック。コンテキストが自動圧縮に近づいたら（既定25万トークン）、圧縮前にNotionへ途中経過を記録するよう促す
- `bin/claude-auto-dev` - launchdなどから定期的に呼ばれ、リポジトリの`auto-ready`のIssueを1件、Claude Code（`claude -p`）にPRにさせる。手順の本体はリポジトリの`.claude/auto-dev.md`。Issueがない回はClaudeを起動しない
- `bin/claude-usage-refresh` - usage APIからプラン使用率を取得してキャッシュ（Claude Codeを起動していない間の利用もtmuxに反映する）
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

### 3. iTerm2のプロファイルをデフォルトにする
iTerm2の Settings → Profiles で「ysk1to (dotfiles)」を選び、Other Actions → Set as Default でデフォルトにする

### 4. 状態を確認
```bash
make check
```

## 📋 利用可能なコマンド

### Makeターゲット
- `make` / `make help` - ターゲット一覧を表示
- `make install` - すべての設定を展開し、Homebrewパッケージをインストール
- `make check` - シンボリックリンクとHomebrewパッケージが揃っているか確認（古いだけのパッケージは問題なしとみなす）
- `make lint` - `bin/`のスクリプトをshellcheck、JSONファイルを構文チェック
- `make list` - リポジトリ内のdotfilesを一覧表示
- `make deploy` - dotfilesをホームディレクトリにシンボリックリンク作成
- `make deploy-vscode` - VSCode設定をアプリケーションディレクトリにシンボリックリンク作成
- `make deploy-claude` - Claude Code設定を`~/.claude/`にシンボリックリンク作成
- `make deploy-iterm` - iTerm2のdynamic profileをシンボリックリンク作成

### カスタムスクリプト
- `claude-auto-dev <リポジトリのパス>` - 自動開発ワークフローを1回動かす。リモートの最新から専用のworktreeを作って作業させ、終わったら片付ける
  - Claudeにはpushと`gh pr create`を許さず、編集もworktreeの中に限る。ClaudeがコミットしてPRのファイル（1行目がタイトル、2行目以降が本文）を書いたら、スクリプトが`auto-`のブランチをpushし、`auto-dev`ラベル付きのPRを作る
  - 設定（Git管理外）: `~/.config/claude-auto-dev/<リポジトリ名>.md`（プロンプトに足す内容。NotionのURL、Todoistの登録先など）、`<リポジトリ名>.tools`（追加で許すツール。1行1つ。例: `Bash(go test:*)`）
  - 環境変数: `CLAUDE_AUTO_DEV_MODEL`（既定 `opus`）、`CLAUDE_AUTO_DEV_MAX_TURNS`（既定 150）
  - ログは`~/.local/state/claude-auto-dev/logs/`。失敗したらmacOSの通知で知らせる
- `claude-team [dir] [session]` - tmuxでClaude Codeの開発環境を構築（dirは`~/Program`からの相対パス。案件名はスニペットで渡し、リポジトリには書かない）

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
- 認証には Secret の `CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token` で作る）を使う。

他の環境で同期：
```bash
cd ~/dotfiles
git pull origin master
make install
make check
```
