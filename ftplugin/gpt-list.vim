" Extend the markdown plugin
runtime! ftplugin/markdown.vim
augroup gpt_list
    autocmd BufEnter * if bufname('%') == 'GPT Conversations' | set nowrap | endif
augroup END

nnoremap <silent> <buffer> <CR> :call gpt#sessions#select_list()<CR>

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
