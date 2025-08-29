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

deploy-vscode: ## Copy VSCode settings to application directory
	@echo '==> Start to deploy VSCode settings.'
	@echo ''
	@mkdir -p "$(HOME)/Library/Application Support/Code/User"
	@cp -v $(DOTPATH)/vscode/settings.json "$(HOME)/Library/Application Support/Code/User/settings.json"
	@cp -v $(DOTPATH)/vscode/keybindings.json "$(HOME)/Library/Application Support/Code/User/keybindings.json"
