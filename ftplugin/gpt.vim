" Extend the markdown plugin
runtime! ftplugin/markdown.vim

set scrolloff=999
augroup gpt
    autocmd!
    " autocmd OptionSet * if &filetype == 'gpt' | set syntax=markdown | endif
    autocmd BufEnter,BufLeave GPT\ * set wrap
    autocmd BufEnter,BufLeave GPT\ * set nonumber
    autocmd BufEnter,BufLeave GPT\ * set norelativenumber
    autocmd BufEnter,BufLeave GPT\ * set nomodifiable
    autocmd BufEnter,BufLeave GPT\ * set nocursorline
    autocmd BufEnter,BufLeave GPT\ * set nocursorcolumn
    autocmd VimLeave GPT\ Log  call gpt#terminate()
    autocmd VimLeave GPT\ Chat  call gpt#terminate()
augroup END

" Define new key mappings
" TODO: actualy implement OpenOptions
nnoremap <silent> <buffer> o :py3 gpt_nvim.gpt.OpenOptions()<CR>
nnoremap <silent> <buffer> q :call gpt#widget#get("Chat").Hide()<CR>
nnoremap <silent> <buffer> r :call gpt#widget#get("Chat").Reset()<CR>
nnoremap <silent> <buffer> s :call gpt#widget#get("Conversations").Save()<CR>
nnoremap <silent> <buffer> L :call gpt#widget#get("Conversations").List()<CR>
setlocal syntax=markdown

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
