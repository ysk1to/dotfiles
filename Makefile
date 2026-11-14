DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(wildcard .??*) bin
EXCLUSIONS := .DS_Store .git .gitmodules .gitignore
DOTFILES   := $(filter-out $(EXCLUSIONS), $(CANDIDATES))

VSCODE_DIR := $(HOME)/Library/Application Support/Code/User
ITERM_DIR  := $(HOME)/Library/Application Support/iTerm2/DynamicProfiles

# リンク元とリンク先の対応（check で使う）。「元,先」の形で持ち、パスの空白は @ に置き換える
LINKS := $(foreach val, $(DOTFILES), $(DOTPATH)/$(val),$(HOME)/$(val)) \
         $(foreach val, keybindings.json settings.json CLAUDE.md, $(DOTPATH)/claude/$(val),$(HOME)/.claude/$(val)) \
         $(foreach val, settings.json keybindings.json, $(DOTPATH)/vscode/$(val),$(subst $() ,@,$(VSCODE_DIR))/$(val)) \
         $(DOTPATH)/iterm2/profile.json,$(subst $() ,@,$(ITERM_DIR))/dotfiles.json

# コメントを含まない JSON（VSCode の設定は JSONC なので別扱い）
JSON_FILES  := $(wildcard claude/*.json iterm2/*.json) iTerm.json
JSONC_FILES := $(wildcard vscode/*.json)
SCRIPTS     := $(wildcard bin/*)

.DEFAULT_GOAL := help
.PHONY: help list install deploy deploy-claude deploy-iterm deploy-vscode check lint

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

list: ## Show dot files in this repo
	@$(foreach val, $(DOTFILES), /bin/ls -dF $(val);)

install: deploy deploy-claude deploy-iterm deploy-vscode ## Deploy everything and install Homebrew packages
	@echo '==> Start to install Homebrew packages.'
	@echo ''
	@brew bundle --file=$(DOTPATH)/Brewfile

deploy: ## Create symlink to home directory
	@echo '==> Start to deploy dotfiles to home directory.'
	@echo ''
	@$(foreach val, $(DOTFILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)

deploy-claude: ## Create symlink of Claude Code settings
	@echo '==> Start to deploy Claude Code settings.'
	@echo ''
	@mkdir -p $(HOME)/.claude
	@$(foreach val, keybindings.json settings.json CLAUDE.md, ln -sfnv $(DOTPATH)/claude/$(val) $(HOME)/.claude/$(val);)

deploy-iterm: ## Create symlink of iTerm2 dynamic profile
	@echo '==> Start to deploy iTerm2 dynamic profile.'
	@echo ''
	@mkdir -p "$(ITERM_DIR)"
	@ln -sfnv $(DOTPATH)/iterm2/profile.json "$(ITERM_DIR)/dotfiles.json"

deploy-vscode: ## Create symlink of VSCode settings
	@echo '==> Start to deploy VSCode settings.'
	@echo ''
	@mkdir -p "$(VSCODE_DIR)"
	@$(foreach val, settings.json keybindings.json, ln -sfnv $(DOTPATH)/vscode/$(val) "$(VSCODE_DIR)/$(val)";)

check: ## Check symlinks and Homebrew packages
	@echo '==> Checking symlinks.'
	@ng=0; for pair in $(LINKS); do \
	  src=$${pair%%,*}; dst=$$(printf '%s' "$${pair#*,}" | tr '@' ' '); \
	  if [ "$$(readlink "$$dst")" = "$$src" ]; then echo "  ok  $$dst"; \
	  else echo "  NG  $$dst（make install で作り直せます）"; ng=1; fi; \
	done; \
	echo ''; echo '==> Checking Homebrew packages.'; \
	brew bundle check --no-upgrade --file=$(DOTPATH)/Brewfile || ng=1; \
	exit $$ng

lint: ## Lint shell scripts and JSON files
	@echo '==> shellcheck'
	@shellcheck $(SCRIPTS)
	@echo '==> JSON'
	@for f in $(JSON_FILES); do jq empty "$$f" || exit 1; done
	@for f in $(JSONC_FILES); do \
	  python3 -c 'import json,re,sys; s=open(sys.argv[1]).read(); s=re.sub(r"^\s*//.*$$","",s,flags=re.M); json.loads(re.sub(r",(\s*[\]}])",r"\1",s))' "$$f" \
	  || { echo "$$f: JSON の構文エラー" >&2; exit 1; }; \
	done
	@echo 'All OK'
