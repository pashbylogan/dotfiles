" Syntax hilighting
syntax on
inoremap jk <ESC>
set hlsearch
set ignorecase
set incsearch

" fzf Fuzzy finder
set rtp+=~/.fzf

" Colorscheme
colors simple-dark

" Spellchecking
set spell spelllang=en_us
nnoremap <leader>s :set spell!
inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u

" 4 spaces for tabs
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

" Show linenumbers
set number

" Disable .swp and backup files
set nobackup
set nowritebackup
set noswapfile

" Plugin Config
set laststatus=2
