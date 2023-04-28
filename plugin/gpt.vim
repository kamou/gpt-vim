if !has('python3')
    echomsg ':python3 is not available, gpt will not be loaded.'
    finish
endif

call mkdir(g:gpt#plugin_dir, 'p')

python3 import gpt

nnoremap <silent> <Plug>(gpt-vim-assist) :<C-u>call gpt#Assist(0)<cr>
xnoremap <silent> <Plug>(gpt-vim-assist-vis) :<C-u>call gpt#Assist(1)<cr>
vnoremap <silent> <Plug>(gpt-vim-assist-vis) :<C-u>call gpt#Assist(1)<cr>
nnoremap <silent> <Plug>(gpt-vim-conversations) :<C-u>call gpt#List()<cr>

" default config
nmap <silent> gpa <Plug>(gpt-vim-assist)
xmap <silent> gpa <Plug>(gpt-vim-assist-vis)
vmap <silent> gpa <Plug>(gpt-vim-assist-vis)
nmap <silent> gpl <Plug>(gpt-vim-conversations)

autocmd BufEnter,BufLeave,WinEnter,WinLeave * if getbufvar(bufnr('%'), "__GPT__") | setlocal wrap | endif
autocmd BufEnter,BufLeave,WinEnter,WinLeave * if getbufvar(bufnr('%'), "__GPT__") | setlocal nonumber | endif
autocmd BufEnter,BufLeave,WinEnter,WinLeave * if getbufvar(bufnr('%'), "__GPT__") | setlocal norelativenumber | endif
autocmd BufEnter,BufLeave,WinEnter,WinLeave * if getbufvar(bufnr('%'), "__GPT__") | setlocal nomodifiable | endif
autocmd BufEnter,BufLeave,WinEnter,WinLeave * if getbufvar(bufnr('%'), "__GPT__") | setlocal nocursorline | endif
autocmd BufEnter,BufLeave,WinEnter,WinLeave * if getbufvar(bufnr('%'), "__GPT__") | setlocal nocursorcolumn | endif
autocmd VimLeave * call gpt#terminate()
"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
