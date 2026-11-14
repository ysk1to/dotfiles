DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(wildcard .??*) bin
EXCLUSIONS := .DS_Store .git .gitmodules
DOTFILES   := $(filter-out $(EXCLUSIONS), $(CANDIDATES))

.DEFAULT_GOAL := help

all:

list: ## Show dot files in this repo
	@$(foreach val, $(DOTFILES), /bin/ls -dF $(val);)

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
	@mkdir -p "$(HOME)/Library/Application Support/iTerm2/DynamicProfiles"
	@ln -sfnv $(DOTPATH)/iterm2/profile.json "$(HOME)/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"

deploy-vscode: ## Create symlink of VSCode settings
	@echo '==> Start to deploy VSCode settings.'
	@echo ''
	@mkdir -p "$(HOME)/Library/Application Support/Code/User"
	@$(foreach val, settings.json keybindings.json, ln -sfnv $(DOTPATH)/vscode/$(val) "$(HOME)/Library/Application Support/Code/User/$(val)";)
