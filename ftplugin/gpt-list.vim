" Extend the markdown plugin
runtime! ftplugin/markdown.vim
augroup gpt_list
    autocmd BufEnter * if bufname('%') == 'GPT Conversations' | set nowrap | endif
augroup END

nnoremap <silent> <buffer> <CR> :call gpt#widget#get("Conversations").select()<CR>
nnoremap <silent> <buffer> <nowait> d :call gpt#widget#get("Conversations").delete()<CR>
nnoremap <silent> <buffer> q :close<CR>

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
