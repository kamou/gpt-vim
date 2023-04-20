" Extend the markdown plugin
runtime! ftplugin/markdown.vim

set scrolloff=999
augroup gpt
    autocmd!
    " autocmd OptionSet * if &filetype == 'gpt' | set syntax=markdown | endif
    autocmd BufEnter * if bufname('%') == 'GPT Log' | set nocursorcolumn nocursorline | endif
    autocmd BufEnter * if bufname('%') == 'GPT Log' | set wrap | endif
    autocmd VimLeave *  call gpt#terminate()
augroup END

" Define new key mappings
" TODO: actualy implement OpenOptions
nnoremap <silent> <buffer> o :py3 gpt_nvim.gpt.OpenOptions()<CR>
nnoremap <silent> <buffer> q :q<CR>
nnoremap <silent> <buffer> r :call gpt#reset()<CR>
nnoremap <silent> <buffer> s :call gpt#save()<CR>
nnoremap <silent> <buffer> L :call gpt#list()<CR>
setlocal syntax=markdown

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
