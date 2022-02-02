" ____  _             _
"|  _ \| |_   _  __ _(_)_ __  ___
"| |_) | | | | |/ _` | | '_ \/ __|
"|  __/| | |_| | (_| | | | | \__ \
"|_|   |_|\__,_|\__, |_|_| |_|___/
               "|___/

" Install vim-plug if not found
if empty(glob('~/.config/nvim/autoload/plug.vim'))
  silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" Plugins will be downloaded under the specified directory.
call plug#begin('~/.config/nvim/plugged') 
Plug 'neovim/nvim-lspconfig'

" Declare the list of plugins.
Plug 'morhetz/gruvbox'
"    let g:gruvbox_italic=1

Plug 'itchyny/lightline.vim'
    set laststatus=2

Plug 'ctrlpvim/ctrlp.vim'
    let g:ctrlp_map = '<c-p>'
    let g:ctrlp_cmd = 'CtrlP'
    set wildignore+=*/tmp/*,*.so,*.swp,*.zip

Plug 'Yggdroot/indentLine'

Plug 'preservim/nerdtree' |
            \ Plug 'Xuyuanp/nerdtree-git-plugin'

" Plug 'mattn/emmet-vim'
" Plug 'yuezk/vim-js'
" Plug 'HerringtonDarkholme/yats.vim'
" Plug 'maxmellon/vim-jsx-pretty'
" Plug 'tpope/vim-commentary'

" Telescope requires plenary to function
Plug 'nvim-lua/plenary.nvim'
" The main Telescope plugin
Plug 'nvim-telescope/telescope.nvim'
" An optional plugin recommended by Telescope docs
Plug 'nvim-telescope/telescope-fzf-native.nvim', {'do': 'make' }

" Autocompletion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'onsails/lspkind-nvim'

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }

" List ends here. Plugins become visible to Vim after this call.
call plug#end()

" Neovim Plugin Configs
lua require('plugin_configs')


"  ____            __
" |  _ \ _ __ ___ / _| ___ _ __ ___ _ __   ___ ___  ___
" | |_) | '__/ _ \ |_ / _ \ '__/ _ \ '_ \ / __/ _ \/ __|
" |  __/| | |  __/  _|  __/ | |  __/ | | | (_|  __/\__ \
" |_|   |_|  \___|_|  \___|_|  \___|_| |_|\___\___||___/

" Syntax highlighting
syntax on
filetype on            " enables filetype detection
filetype plugin indent on     " enables filetype specific plugins
set hlsearch
set ignorecase
set incsearch
set cursorline
set noshowmode " Don't need to show because lightline does

" Colorscheme
colors gruvbox
set bg=dark
highlight Comment cterm=italic gui=italic

" fzf Fuzzy finder
set rtp+=~/.fzf

" Spellchecking
set spell spelllang=en_us
hi clear SpellBad
hi SpellBad cterm=underline
hi SpellBad ctermfg=red

" UTF
set encoding=utf-8

set backspace=2 softtabstop=2 shiftwidth=2 expandtab
set autoindent

set foldmethod=indent
set foldlevel=99

" Show linenumbers
set number

" Set vim to autoupdate
set autoread

" Command Line Autocomplete
set wildmenu
set wildmode=longest,list,full

" Disable .swp and backup files
set nobackup
set nowritebackup
set noswapfile

" __  __                   _
"|  \/  | __ _ _ __  _ __ (_)_ __   __ _ ___
"| |\/| |/ _` | '_ \| '_ \| | '_ \ / _` / __|
"| |  | | (_| | |_) | |_) | | | | | (_| \__ \
"|_|  |_|\__,_| .__/| .__/|_|_| |_|\__, |___/
"             |_|   |_|            |___/

mapclear

inoremap jk <ESC>

" NERD Tree
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-f> :NERDTreeFind<CR>

" Enable folding with the spacebar
nnoremap <space> za

" Spellchecking
nnoremap <leader>s :set spell!
inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u
