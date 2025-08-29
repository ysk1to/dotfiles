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
- `vscode/` - Visual Studio Code設定
  - `settings.json` - エディタ設定
  - `keybindings.json` - キーバインド設定

### アプリケーション
- `Brewfile` - Homebrewパッケージ管理
- `iTerm.json` - iTerm2カラーテーマ設定

### スクリプト
- `bin/ide` - tmuxセッション自動構築スクリプト

## 🚀 セットアップ

### 1. リポジトリをクローン
```bash
git clone https://github.com/ysk1to/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. dotfilesをホームディレクトリに展開
```bash
make deploy
```

### 3. VSCode設定を反映
```bash
make deploy-vscode
```

### 4. Homebrewパッケージをインストール
```bash
brew bundle
```

## 📋 利用可能なコマンド

### Makeターゲット
- `make list` - リポジトリ内のdotfilesを一覧表示
- `make deploy` - dotfilesをホームディレクトリにシンボリックリンク作成
- `make deploy-vscode` - VSCode設定ファイルをアプリケーションディレクトリにコピー

### カスタムスクリプト
- `ide` - tmuxで開発環境を自動構築

## 🔧 カスタマイズ

### 新しいdotfileを追加
1. ファイルをリポジトリルートに配置（`.`で始まるファイル名）
2. `make deploy`で自動的にシンボリックリンクが作成されます

### VSCode設定の更新
1. `vscode/`ディレクトリ内のファイルを編集
2. `make deploy-vscode`で設定を反映

### Homebrewパッケージの追加
```bash
# 新しいパッケージをインストール
brew install [package-name]

# Brewfileを更新
brew bundle dump --force
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
# 変更をコミット
git add .
git commit -m "[update] 設定ファイル更新"
git push origin master
```

他の環境で同期：
```bash
cd ~/dotfiles
git pull origin master
make deploy
make deploy-vscode
```