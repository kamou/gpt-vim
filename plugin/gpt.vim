if !has('python3')
    echomsg ':python3 is not available, gpt will not be loaded.'
    finish
endif

call mkdir(g:gpt#plugin_dir, 'p')

python3 import gpt

nnoremap <silent> <Plug>(gpt-vim-assist) :<C-u>call gpt#Assist(0)<cr>
xnoremap <silent> <Plug>(gpt-vim-assist-vis) :<C-u>call gpt#Assist(1)<cr>
vnoremap <silent> <Plug>(gpt-vim-assist-vis) :<C-u>call gpt#Assist(1)<cr>

" default config
nmap <silent> gpa <Plug>(gpt-vim-assist)
xmap <silent> gpa <Plug>(gpt-vim-assist-vis)
vmap <silent> gpa <Plug>(gpt-vim-assist-vis)

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
