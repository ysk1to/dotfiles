# 依存で入るだけのライブラリは書かない（brew bundle が自動で入れる）

tap "sanemat/font"

# -- shell / terminal ----------------------------------------------------------
brew "fzf"
brew "tmux"
brew "tree"
brew "vim"
brew "wget"

# -- git -----------------------------------------------------------------------
brew "act"
brew "gh"
brew "tig"

# -- 言語・バージョン管理 -------------------------------------------------------
brew "anyenv"
brew "goenv"
brew "maven"
brew "openjdk"
brew "python@3.11"
brew "tfenv"
brew "uv"

# -- 開発ツール ----------------------------------------------------------------
brew "awscli"
brew "jq"
brew "mkcert"
brew "ollama", restart_service: :changed
brew "qemu"
brew "repomix"
brew "serverless"
brew "shellcheck"
brew "yq"

# -- 画像・動画・フォント --------------------------------------------------------
brew "ffmpeg"
brew "fontforge"
brew "ghostscript"
brew "imagemagick"
brew "sanemat/font/ricty", args: ["with-powerline"]

# -- その他 ----------------------------------------------------------------------
brew "mas"

# -- アプリ ----------------------------------------------------------------------
cask "1password"
cask "alfred"
cask "appcleaner"
cask "chatwork"
cask "claude-code"
cask "clipy"
cask "deepl"
cask "docker-desktop"
cask "firefox"
cask "font-hackgen-nerd"
cask "google-chrome"
cask "google-japanese-ime"
cask "iterm2"
cask "kindle"
cask "notion"
cask "omnifocus"
cask "postman"
cask "sequel-ace"
cask "skitch"
cask "slack"
cask "visual-studio-code"
cask "zoom"

# -- Mac App Store ---------------------------------------------------------------
mas "1Password for Safari", id: 1569813296
mas "GarageBand", id: 682658836
mas "iMovie", id: 408981434
mas "Keynote", id: 409183694
mas "Magnet", id: 441258766
mas "MARKETSPEED", id: 946680495
mas "Numbers", id: 409203825
mas "Pages", id: 409201541
mas "Toggl Track", id: 1291898086
mas "Xcode", id: 497799835

# -- Go ツール（goenv の Go で入る） ----------------------------------------------
go "github.com/go-delve/delve/cmd/dlv"
go "github.com/golangci/golangci-lint/cmd/golangci-lint"
go "golang.org/x/tools/gopls"
