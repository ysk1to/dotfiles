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
  - `settings.json` - 権限・フック・statusLineなどの設定
  - `CLAUDE.md` - 全プロジェクト共通の指示
  - `keybindings.json` - キーバインド設定（Alt+Enterで改行）
  - PCごとの設定は Git 管理外の `~/.claude/settings.local.json` に書く

### アプリケーション
- `Brewfile` - Homebrewパッケージ管理
- `iTerm.json` - iTerm2カラーテーマ設定
- `iterm2/profile.json` - iTerm2のdynamic profile（Shift+EnterでESC+CRを送りClaude Codeで改行）

### スクリプト
- `bin/claude-team` - 指定ディレクトリでClaude Codeを3ペイン起動するtmuxセッションを構築
- `bin/claude-statusline` - Claude CodeのstatusLine（モデル・effort・トークン数・コンテキスト使用率など）
- `bin/tmux-claude-usage` - Claudeプラン使用率をtmuxに表示
- `bin/tmux-weather` - wttr.inの天気をキャッシュしてtmuxに表示（既定30分）

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

設定ファイルを変更した場合：
```bash
# 構文チェックしてからコミット
make lint
git add .
git commit -m "[update] 設定ファイル更新"
git push origin master
```

他の環境で同期：
```bash
cd ~/dotfiles
git pull origin master
make install
make check
```
