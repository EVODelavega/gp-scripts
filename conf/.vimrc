set nu
color elflord
set paste
set expandtab
set tabstop=4
set smarttab
set shiftwidth=4
set ch=2
set smartindent
" let &colorcolumn=join(range(81,999),",")
" set colorcolumn=81
" highlight ColorColumn ctermbg=80 guibg=#666666
" highlight ColorColumn ctermbg=235 guibg=#2c2d27
" let &colorcolumn="80,".join(range(120,999),",")
call matchadd('ColorColumn', '\%81v.\+', 100)
call plug#begin('~/.vim/plugged')

" General plugins
Plug 'junegunn/seoul256.vim'
Plug 'junegunn/vim-easy-align'
Plug 'fatih/vim-go'
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'nathanaelkane/vim-indent-guides' 

" Coulour schemes
Plug 'captbaritone/molokai'
Plug 'chriskempson/vim-tomorrow-theme'
Plug 'altercation/vim-colors-solarized'
Plug 'fxn/vim-monochrome'
Plug 'chriskempson/base16-vim'
Plug 'NLKNguyen/papercolor-theme'

" Markdown plugin
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" Lua
Plug 'https://github.com/xolox/vim-misc.git'
Plug 'https://github.com/xolox/vim-lua-ftplugin.git'

" JavaScript
Plug 'https://github.com/leafgarland/typescript-vim.git' " typescript
Plug 'jelera/vim-javascript-syntax' " JS syntax
Plug 'pangloss/vim-javascript' " Indentation for JS

" statusline
Plug 'bling/vim-airline'

call plug#end()

" http://oli.me.uk/2013/06/29/equipping-vim-for-javascript/

" Search selected text using // instead of y/ctrl+r <enter>
vnoremap // y/<C-R>"<CR>
set hlsearch
set ai
