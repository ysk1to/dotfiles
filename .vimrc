"" Basic setting
let mapleader = ","

" tab
set tabstop=4
set expandtab
set shiftwidth=4

" delete key
set backspace=indent,eol,start

" line
set number

" not create swapfile
set noswapfile

" multibyte
set ambiwidth=double

" clipboard
set clipboard+=unnamed

" background"
highlight! Normal ctermbg=NONE guibg=NONE
highlight! NonText ctermbg=NONE guibg=NONE
highlight! LineNr ctermbg=NONE guibg=NONE

" move between windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" highlight
set hlsearch

" search (? backwords)
map <space> /
map <C-space> ?
map <silent> <leader><cr> :noh<cr>


call plug#begin()

" directory tree
Plug 'preservim/nerdtree'

" color
Plug 'tomasiser/vim-code-dark'

" tree icon
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" status line
Plug 'itchyny/lightline.vim'

" paste
Plug 'ConradIrwin/vim-bracketed-paste'

"" bracket auto close
Plug 'cohama/lexima.vim'
Plug 'tpope/vim-surround'

" comment out
Plug 'tpope/vim-commentary'

" editorconfig
Plug 'editorconfig/editorconfig-vim'

" ag
Plug 'rking/ag.vim'

" git
Plug 'tpope/vim-rhubarb'
Plug 'airblade/vim-gitgutter'

" lsp
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'
" option
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'

" emmet
Plug 'mattn/emmet-vim'

" markdown
Plug 'tpope/vim-markdown'
Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app & yarn install' }

call plug#end()

"" vim-code-dark
syntax enable
colorscheme codedark

"" NERDTree
map <leader>nn :NERDTreeToggle<cr>
map <leader>nb :NERDTreeFromBookmark
map <leader>nf :NERDTreeFind<cr>
let g:NERDTreeChDirMode=1
let g:NERDTreeShowBookmarks=1
let g:nerdtree_tabs_focus_on_files=1
let g:NERDTreeMapOpenInTabSilent = '<RightMouse>'
let g:NERDTreeWinSize = 40
let NERDTreeShowHidden=1
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'

"" GitGutter
let g:gitgutter_enabled = 1
set updatetime=100
let g:gitgutter_override_sign_column_highlight = 0
highlight GitGutterAdd ctermfg=2
highlight GitGutterChange ctermfg=3
highlight GitGutterDelete ctermfg=1
highlight GitGutterChangeDelete ctermfg=4

"" vim-markdown
let g:vim_markdown_folding_disabled=1

" vim-ag
map <leader>g :Ag

" vim-lsp
let g:lsp_signs_enabled=1
let g:lsp_diagnostics_enabled=1
let g:lsp_diagnostics_echo_cursor=1
let g:lsp_virtual_text_enabled = 1
let g:lsp_signs_error = {'text': '✗'}
let g:lsp_signs_warning = {'text': '!!'}
let g:lsp_signs_information = {'text': 'i'}
let g:lsp_signs_hint = {'text': '?'}
