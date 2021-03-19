filetype plugin indent on

" Syntax hilighting
syntax on

" fzf Fuzzy finder
set rtp+=~/.fzf

" 4 spaces for tabs
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

" Show linenumbers
set number
" set relativenumber

" Colorscheme
colors zenburn

" Highlight the 80th column
set cursorline
set cc=80
highlight ColorColumn ctermbg=darkblue

"Highlight tabs and extra whitespace
highlight LiteralTabs ctermbg=darkgreen guibg=darkgreen
match LiteralTabs /\s /
highlight ExtraWhitespace ctermbg=darkgreen guibg=darkgreen
match ExtraWhitespace /\s\+$/

" Disable .swp and backup files
set nobackup
set nowritebackup
set noswapfile

"call plug#begin()

"call plug#end()
