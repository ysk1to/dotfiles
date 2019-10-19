call plug#begin()

" tree icon
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" bracket auto close
Plug 'cohama/lexima.vim'
Plug 'tpope/vim-surround'

" git
Plug 'tpope/vim-rhubarb'
Plug 'airblade/vim-gitgutter'

" emmet
Plug 'mattn/emmet-vim'

" twig
Plug 'lunaru/vim-twig'

call plug#end()

"" NERDTree
let g:NERDTreeChDirMode=1
let g:NERDTreeShowBookmarks=1
let g:nerdtree_tabs_focus_on_files=1
let g:NERDTreeMapOpenInTabSilent = '<RightMouse>'
let g:NERDTreeWinSize = 40
let NERDTreeShowHidden=1

"" line
set number

"" multibyte
set ambiwidth=double

"" background"
highlight! Normal ctermbg=NONE guibg=NONE
highlight! NonText ctermbg=NONE guibg=NONE
highlight! LineNr ctermbg=NONE guibg=NONE
